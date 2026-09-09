import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/online_game_state.dart';
import 'online_backend.dart';
import 'room_code_generator.dart';

/// Production implementation of [OnlineBackend] backed by Firebase Authentication
/// and Firebase Realtime Database.
class FirebaseOnlineBackend implements OnlineBackend {
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  StreamSubscription<DatabaseEvent>? _matchNotificationSub;
  String? _activeRoomCode;
  String? _activeGameId;
  String? get activeGameId => _activeGameId;

  FirebaseOnlineBackend({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _database = database ??
            (Firebase.apps.isNotEmpty &&
                    Firebase.app().options.databaseURL != null &&
                    Firebase.app().options.databaseURL!.isNotEmpty
                ? FirebaseDatabase.instanceFor(
                    app: Firebase.app(),
                    databaseURL: Firebase.app().options.databaseURL!,
                  )
                : FirebaseDatabase.instance) {
    _initConnectionMonitor();
  }

  void _initConnectionMonitor() {
    try {
      _connectionSubscription =
          _database.ref('.info/connected').onValue.listen((event) {
        final connected = event.snapshot.value == true;
        _isConnected = connected;
        _connectionController.add(connected);
      });
    } catch (_) {}
  }

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  Future<String> signInAnonymously() async {
    try {
      var user = _auth.currentUser;
      if (user == null) {
        final credential = await _auth.signInAnonymously();
        user = credential.user;
      }
      if (user == null) {
        throw const OnlineException('Unable to establish anonymous session.');
      }

      // Configure Realtime presence for this device
      final presenceRef = _database.ref('presence/${user.uid}');
      await presenceRef.onDisconnect().set({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });
      await presenceRef.set({
        'online': true,
        'lastSeen': ServerValue.timestamp,
      });

      return user.uid;
    } catch (e) {
      if (e is OnlineException) rethrow;
      throw OnlineException('Online authentication failed: $e');
    }
  }

  String _sanitizeErrorMessage(dynamic e) {
    var msg = e.toString().split('\n').first;
    msg = msg.replaceAll(RegExp(r'(key|token|auth|apiKey)=[a-zA-Z0-9_\-]+'), r'$1=***');
    return msg;
  }

  @override
  Future<OnlineGameState?> findMatch() async {
    final uid = await signInAnonymously();
    final queueRef = _database.ref('matchmaking_queue/waiting');
    final matchNotificationRef =
        _database.ref('matchmaking_queue/matches/$uid');

    // Clean up any stale notification entry for self
    await matchNotificationRef.remove();

    final matchCompleter = Completer<OnlineGameState?>();

    // Listen for match notification if we are placed in waiting state
    _matchNotificationSub = matchNotificationRef.onValue.listen((event) async {
      if (event.snapshot.value != null && !matchCompleter.isCompleted) {
        try {
          // Cancel onDisconnect on waiting slot because we are paired
          try {
            await queueRef.onDisconnect().cancel();
          } catch (_) {}

          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          final gameId = data['gameId']?.toString();
          if (gameId != null) {
            final gameSnapshot = await _database.ref('games/$gameId').get();
            if (gameSnapshot.value != null) {
              final gameData =
                  Map<dynamic, dynamic>.from(gameSnapshot.value as Map);
              final state = OnlineGameState.fromMap(gameId, gameData);
              _activeGameId = gameId;
              try {
                await matchNotificationRef.remove();
              } catch (_) {}
              matchCompleter.complete(state);
            }
          }
        } catch (e) {
          if (!matchCompleter.isCompleted) {
            matchCompleter.completeError(
              OnlineException('Failed loading matched game: ${_sanitizeErrorMessage(e)}'),
            );
          }
        }
      }
    });

    String? matchedWaitingUid;

    // Run atomic transaction on the waiting slot
    final transactionResult = await queueRef.runTransaction((mutableData) {
      if (mutableData == null) {
        // No one waiting, place self in queue
        return Transaction.success({
          'uid': uid,
          'joinedAt': ServerValue.timestamp,
        });
      }

      final data = Map<dynamic, dynamic>.from(mutableData as Map);
      final waitingUid = data['uid']?.toString();
      final joinedAt = int.tryParse(data['joinedAt']?.toString() ?? '0') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (waitingUid == null || waitingUid == uid) {
        // Refresh self in queue
        return Transaction.success({
          'uid': uid,
          'joinedAt': ServerValue.timestamp,
        });
      }

      // Check for stale queue entry (older than 60s)
      if (joinedAt > 0 && now - joinedAt > 60000) {
        return Transaction.success({
          'uid': uid,
          'joinedAt': ServerValue.timestamp,
        });
      }

      // Pair with the waiting player! Clear the slot.
      matchedWaitingUid = waitingUid;
      return Transaction.success(null);
    });

    if (!transactionResult.committed) {
      throw const OnlineException('Matchmaking failed. Please try again.');
    }

    final postValue = transactionResult.snapshot.value;

    // Set onDisconnect cleanup on waiting slot if self is waiting
    if (postValue is Map && postValue['uid'] == uid) {
      await queueRef.onDisconnect().remove();
      // Wait for someone to pair with us
      try {
        final result = await matchCompleter.future.timeout(
          const Duration(seconds: 45),
          onTimeout: () async {
            await cancelMatchmaking();
            throw const OnlineException('Matchmaking timed out. No opponent found.');
          },
        );
        _activeGameId = result?.gameId;
        return result;
      } finally {
        await _matchNotificationSub?.cancel();
        _matchNotificationSub = null;
      }
    } else if (matchedWaitingUid != null) {
      // We are the second player who completed the pair with matchedWaitingUid
      final gameId = 'game_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
      _activeGameId = gameId;

      // Randomize X and O assignment
      final isSelfX = math.Random().nextBool();
      final playerX = isSelfX ? uid : matchedWaitingUid!;
      final playerO = isSelfX ? matchedWaitingUid! : uid;

      final gameRef = _database.ref('games/$gameId');
      final newGame = OnlineGameState(
        gameId: gameId,
        playerX: playerX,
        playerO: playerO,
        board: List.filled(9, null),
        currentTurn: 'X',
        status: OnlineGameStatus.active,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      try {
        await gameRef.set(newGame.toMap());

        // Notify the waiting player with the game ID
        await _database.ref('matchmaking_queue/matches/$matchedWaitingUid').set({
          'gameId': gameId,
          'matchedAt': ServerValue.timestamp,
        });

        return newGame;
      } on OnlineException {
        rethrow;
      } catch (e) {
        throw OnlineException('Failed to start matched game: ${_sanitizeErrorMessage(e)}');
      }
    } else {
      throw const OnlineException('Matchmaking error: failed to resolve pairing.');
    }
  }

  @override
  Future<void> cancelMatchmaking() async {
    final uid = currentUserId;
    if (uid != null) {
      final queueRef = _database.ref('matchmaking_queue/waiting');
      try {
        await queueRef.onDisconnect().cancel();
      } catch (_) {}
      final snapshot = await queueRef.get();
      if (snapshot.value is Map) {
        final data = snapshot.value as Map;
        if (data['uid'] == uid) {
          await queueRef.remove();
        }
      }
      await _database.ref('matchmaking_queue/matches/$uid').remove();
    }
    await _matchNotificationSub?.cancel();
    _matchNotificationSub = null;
  }

  @override
  Future<RoomState> createRoom() async {
    final uid = await signInAnonymously();
    final code = RoomCodeGenerator.generate();
    final gameId = 'game_room_$code';
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + (15 * 60 * 1000);

    final room = RoomState(
      roomCode: code,
      hostUid: uid,
      guestUid: null,
      gameId: gameId,
      status: 'waiting',
      createdAt: now,
      expiresAt: expiresAt,
    );

    try {
      final roomRef = _database.ref('rooms/$code');
      await roomRef.set(room.toMap());
      await roomRef.onDisconnect().update({'status': 'abandoned'});

      // Initialize waiting game
      final game = OnlineGameState(
        gameId: gameId,
        playerX: uid,
        playerO: null,
        board: List.filled(9, null),
        currentTurn: 'X',
        status: OnlineGameStatus.waiting,
        createdAt: now,
        updatedAt: now,
      );
      await _database.ref('games/$gameId').set(game.toMap());

      _activeRoomCode = code;
      _activeGameId = gameId;
      return room;
    } on OnlineException {
      rethrow;
    } catch (e) {
      throw OnlineException('Failed to create room: ${_sanitizeErrorMessage(e)}');
    }
  }

  @override
  Future<RoomState> joinRoom(String roomCode) async {
    final uid = await signInAnonymously();
    final code = RoomCodeGenerator.normalize(roomCode);
    final roomRef = _database.ref('rooms/$code');

    try {
      final result = await roomRef.runTransaction((mutableData) {
        if (mutableData == null) {
          return Transaction.abort();
        }

        final data = Map<dynamic, dynamic>.from(mutableData as Map);
        final hostUid = data['hostUid']?.toString();
        final guestUid = data['guestUid']?.toString();
        final expiresAt = int.tryParse(data['expiresAt']?.toString() ?? '0') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (expiresAt > 0 && now > expiresAt) {
          data['status'] = 'expired';
          return Transaction.success(data);
        }

        if (guestUid != null && guestUid != uid && guestUid.isNotEmpty) {
          // Room full
          return Transaction.abort();
        }

        if (hostUid == uid) {
          // Re-joining own room
          return Transaction.success(data);
        }

        data['guestUid'] = uid;
        data['status'] = 'active';
        return Transaction.success(data);
      });

      if (!result.committed || result.snapshot.value == null) {
        // Check why it failed
        final snapshot = await roomRef.get();
        if (snapshot.value == null) {
          throw const OnlineException('Room not found.');
        }
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        if (data['guestUid'] != null && data['guestUid'] != uid) {
          throw const OnlineException('Room is full.');
        }
        throw const OnlineException('Unable to join room.');
      }

      final data = Map<dynamic, dynamic>.from(result.snapshot.value as Map);
      if (data['status'] == 'expired') {
        throw const OnlineException('Room expired.');
      }

      final updatedRoom = RoomState.fromMap(code, data);
      _activeRoomCode = code;
      _activeGameId = updatedRoom.gameId;

      // Transition game to active
      final gameRef = _database.ref('games/${updatedRoom.gameId}');
      await gameRef.update({
        'playerO': uid,
        'status': 'active',
        'updatedAt': ServerValue.timestamp,
      });

      return updatedRoom;
    } on OnlineException {
      rethrow;
    } catch (e) {
      throw OnlineException('Failed to join room: ${_sanitizeErrorMessage(e)}');
    }
  }

  @override
  Future<void> leaveRoom(String roomCode) async {
    final uid = currentUserId;
    final code = RoomCodeGenerator.normalize(roomCode);
    final roomRef = _database.ref('rooms/$code');

    final snapshot = await roomRef.get();
    if (snapshot.value is Map) {
      final data = snapshot.value as Map;
      if (data['hostUid'] == uid) {
        await roomRef.update({'status': 'abandoned'});
        final gameId = data['gameId']?.toString();
        if (gameId != null) {
          await _database.ref('games/$gameId').update({'status': 'abandoned'});
        }
      } else if (data['guestUid'] == uid) {
        await roomRef.update({'guestUid': null, 'status': 'waiting'});
      }
    }
    _activeRoomCode = null;
  }

  @override
  Future<bool> makeMove(String gameId, int cellIndex) async {
    final uid = currentUserId;
    if (uid == null) {
      throw const OnlineException('User not authenticated.');
    }
    if (cellIndex < 0 || cellIndex >= 9) {
      throw const OnlineException('Invalid cell index.');
    }

    try {
      final gameRef = _database.ref('games/$gameId');

      final transactionResult = await gameRef.runTransaction((mutableData) {
        if (mutableData == null) {
          return Transaction.abort();
        }

        final data = Map<dynamic, dynamic>.from(mutableData as Map);
        final status = data['status']?.toString();
        if (status != 'active') {
          return Transaction.abort();
        }

        final playerX = data['playerX']?.toString();
        final playerO = data['playerO']?.toString();
        final currentTurn = data['currentTurn']?.toString() ?? 'X';

        String? role;
        if (uid == playerX) role = 'X';
        if (uid == playerO) role = 'O';

        if (role == null || role != currentTurn) {
          return Transaction.abort();
        }

        // Check cell vacancy
        final rawBoard = data['board'];
        List<dynamic> boardList;
        if (rawBoard is List) {
          boardList = List<dynamic>.from(rawBoard);
        } else if (rawBoard is Map) {
          boardList = List.filled(9, null);
          for (int i = 0; i < 9; i++) {
            boardList[i] = rawBoard['$i'] ?? rawBoard[i];
          }
        } else {
          boardList = List.filled(9, null);
        }

        if (boardList[cellIndex] != null) {
          return Transaction.abort();
        }

        boardList[cellIndex] = role;

        // Serialize board as map containing only non-null occupied cells
        final boardMap = <String, String>{};
        for (int i = 0; i < 9; i++) {
          final cell = boardList[i];
          if (cell != null) {
            boardMap['$i'] = cell.toString();
          }
        }
        data['board'] = boardMap;

        // Evaluate win / draw
        final winningCombo = _evaluateWinner(boardList.cast<String?>());
        if (winningCombo != null) {
          data['winner'] = role;
          data['winningCells'] = winningCombo;
          data['status'] = 'finished';
        } else if (!boardList.contains(null)) {
          data['winner'] = 'Draw';
          data['winningCells'] = null;
          data['status'] = 'finished';
        } else {
          data['currentTurn'] = (role == 'X') ? 'O' : 'X';
        }

        final moveCount = int.tryParse(data['moveCount']?.toString() ?? '0') ?? 0;
        data['moveCount'] = moveCount + 1;
        data['lastMoveIndex'] = cellIndex;
        data['lastMovePlayer'] = role;
        data['updatedAt'] = ServerValue.timestamp;

        return Transaction.success(data);
      });

      if (!transactionResult.committed) {
        throw const OnlineException('Move rejected by authoritative game server.');
      }
      return true;
    } on OnlineException {
      rethrow;
    } catch (e) {
      throw OnlineException('Failed to execute move: ${_sanitizeErrorMessage(e)}');
    }
  }

  @override
  Future<void> requestRematch(String gameId) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final gameRef = _database.ref('games/$gameId');

      await gameRef.runTransaction((mutableData) {
        if (mutableData == null) return Transaction.abort();
        final data = Map<dynamic, dynamic>.from(mutableData as Map);
        final playerX = data['playerX']?.toString();
        final playerO = data['playerO']?.toString();

        Map<dynamic, dynamic> rematch = {};
        if (data['rematch'] is Map) {
          rematch = Map<dynamic, dynamic>.from(data['rematch'] as Map);
        }

        if (uid == playerX) rematch['requestX'] = true;
        if (uid == playerO) rematch['requestO'] = true;

        if (rematch['requestX'] == true && rematch['requestO'] == true) {
          // Both agreed -> reset board to empty non-sparse map
          data['board'] = <String, String>{};
          data['currentTurn'] = 'X';
          data['status'] = 'active';
          data['winner'] = null;
          data['winningCells'] = null;
          data['moveCount'] = 0;
          data['rematch'] = {'requestX': false, 'requestO': false};
        } else {
          data['rematch'] = rematch;
        }
        data['updatedAt'] = ServerValue.timestamp;
        return Transaction.success(data);
      });
    } on OnlineException {
      rethrow;
    } catch (e) {
      throw OnlineException('Failed to request rematch: ${_sanitizeErrorMessage(e)}');
    }
  }

  @override
  Future<void> resetRound(String gameId) async {
    try {
      await _database.ref('games/$gameId').update({
        'board': <String, String>{},
        'currentTurn': 'X',
        'status': 'active',
        'winner': null,
        'winningCells': null,
        'moveCount': 0,
        'rematch': {'requestX': false, 'requestO': false},
        'updatedAt': ServerValue.timestamp,
      });
    } on OnlineException {
      rethrow;
    } catch (e) {
      throw OnlineException('Failed to reset round: ${_sanitizeErrorMessage(e)}');
    }
  }

  @override
  Stream<OnlineGameState> streamGame(String gameId) {
    return _database.ref('games/$gameId').onValue.map((event) {
      if (event.snapshot.value == null) {
        return OnlineGameState(
          gameId: gameId,
          board: List.filled(9, null),
          status: OnlineGameStatus.abandoned,
        );
      }
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return OnlineGameState.fromMap(gameId, data);
    });
  }

  @override
  Future<OnlineGameState?> getGame(String gameId) async {
    try {
      final snapshot = await _database.ref('games/$gameId').get();
      if (snapshot.value == null) return null;
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return OnlineGameState.fromMap(gameId, data);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<bool> streamOpponentPresence(String opponentUid) {
    return _database
        .ref('presence/$opponentUid/online')
        .onValue
        .map((event) => event.snapshot.value == true);
  }

  @override
  Future<void> leaveGame(String gameId) async {
    try {
      await _database.ref('games/$gameId').update({
        'status': 'abandoned',
        'updatedAt': ServerValue.timestamp,
      });
      if (_activeRoomCode != null) {
        await leaveRoom(_activeRoomCode!);
      }
    } catch (_) {}
    _activeGameId = null;
  }

  @override
  void dispose() {
    cancelMatchmaking();
    _connectionSubscription?.cancel();
    _matchNotificationSub?.cancel();
    _connectionController.close();
  }

  static List<int>? _evaluateWinner(List<String?> board) {
    const winningCombinations = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (final combo in winningCombinations) {
      final a = combo[0];
      final b = combo[1];
      final c = combo[2];
      if (board[a] != null &&
          board[a] == board[b] &&
          board[a] == board[c]) {
        return combo;
      }
    }
    return null;
  }
}
