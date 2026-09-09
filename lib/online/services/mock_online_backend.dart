import 'dart:async';
import 'dart:math' as math;

import '../models/online_game_state.dart';
import 'online_backend.dart';
import 'room_code_generator.dart';

/// Central in-memory shared database simulating the Firebase Realtime Database
/// for unit and widget testing across multiple client instances.
class MockSharedDatabase {
  static final MockSharedDatabase instance = MockSharedDatabase();

  final Map<String, OnlineGameState> games = {};
  final Map<String, RoomState> rooms = {};
  final Map<String, bool> presence = {};
  final Map<String, StreamController<OnlineGameState>> gameStreams = {};
  final Map<String, StreamController<bool>> presenceStreams = {};

  // Waiting matchmaking queue: map of uid -> Completer<OnlineGameState?>
  final Map<String, Completer<OnlineGameState?>> matchmakingQueue = {};

  void reset() {
    games.clear();
    rooms.clear();
    presence.clear();
    matchmakingQueue.clear();
    for (final controller in gameStreams.values) {
      controller.close();
    }
    gameStreams.clear();
    for (final controller in presenceStreams.values) {
      controller.close();
    }
    presenceStreams.clear();
  }

  StreamController<OnlineGameState> getOrCreateGameStream(String gameId) {
    return gameStreams.putIfAbsent(
      gameId,
      () => StreamController<OnlineGameState>.broadcast(),
    );
  }

  StreamController<bool> getOrCreatePresenceStream(String uid) {
    return presenceStreams.putIfAbsent(
      uid,
      () => StreamController<bool>.broadcast(),
    );
  }

  void broadcastGameState(OnlineGameState state) {
    games[state.gameId] = state;
    if (gameStreams.containsKey(state.gameId)) {
      gameStreams[state.gameId]!.add(state);
    }
  }

  void broadcastPresence(String uid, bool online) {
    presence[uid] = online;
    if (presenceStreams.containsKey(uid)) {
      presenceStreams[uid]!.add(online);
    }
  }
}

/// In-memory implementation of [OnlineBackend] for automated testing and simulation.
class MockOnlineBackend implements OnlineBackend {
  final MockSharedDatabase _db;
  String? _uid;
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _isConnected = true;
  String? _activeRoomCode;
  String? _activeGameId;

  MockOnlineBackend({
    MockSharedDatabase? database,
    String? initialUid,
  })  : _db = database ?? MockSharedDatabase.instance,
        _uid = initialUid;

  @override
  String? get currentUserId => _uid;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  void simulateConnectionChange(bool connected) {
    _isConnected = connected;
    _connectionController.add(connected);
    if (_uid != null) {
      _db.broadcastPresence(_uid!, connected);
    }
  }

  @override
  Future<String> signInAnonymously() async {
    if (!_isConnected) {
      throw const OnlineException('No internet connection.');
    }
    _uid ??= 'mock_user_${math.Random().nextInt(999999)}';
    _db.broadcastPresence(_uid!, true);
    return _uid!;
  }

  @override
  Future<OnlineGameState?> findMatch() async {
    if (_uid == null) {
      await signInAnonymously();
    }
    if (!_isConnected) {
      throw const OnlineException('No internet connection.');
    }

    final uid = _uid!;

    // Prevent duplicate entries in queue
    if (_db.matchmakingQueue.containsKey(uid)) {
      _db.matchmakingQueue.remove(uid)?.complete(null);
    }

    // Check if another player is already waiting in queue
    String? waitingOpponentUid;
    for (final entry in _db.matchmakingQueue.entries) {
      if (entry.key != uid) {
        waitingOpponentUid = entry.key;
        break;
      }
    }

    if (waitingOpponentUid != null) {
      // Pair with waiting opponent
      final opponentCompleter = _db.matchmakingQueue.remove(waitingOpponentUid)!;
      final gameId = 'game_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

      // Fair coin toss for X and O
      final isSelfX = math.Random().nextBool();
      final playerX = isSelfX ? uid : waitingOpponentUid;
      final playerO = isSelfX ? waitingOpponentUid : uid;

      final gameState = OnlineGameState(
        gameId: gameId,
        playerX: playerX,
        playerO: playerO,
        board: List.filled(9, null),
        currentTurn: 'X',
        status: OnlineGameStatus.active,
        moveCount: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      _db.broadcastGameState(gameState);
      opponentCompleter.complete(gameState);
      _activeGameId = gameId;
      return gameState;
    } else {
      // Enqueue self and wait
      final completer = Completer<OnlineGameState?>();
      _db.matchmakingQueue[uid] = completer;

      try {
        final matchedGame = await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            _db.matchmakingQueue.remove(uid);
            throw const OnlineException('Matchmaking timed out. Please try again.');
          },
        );
        if (matchedGame != null) {
          _activeGameId = matchedGame.gameId;
        }
        return matchedGame;
      } catch (e) {
        _db.matchmakingQueue.remove(uid);
        rethrow;
      }
    }
  }

  @override
  Future<void> cancelMatchmaking() async {
    if (_uid != null && _db.matchmakingQueue.containsKey(_uid)) {
      final completer = _db.matchmakingQueue.remove(_uid);
      if (completer != null && !completer.isCompleted) {
        completer.complete(null);
      }
    }
  }

  @override
  Future<RoomState> createRoom() async {
    await signInAnonymously();
    if (!_isConnected) {
      throw const OnlineException('No internet connection.');
    }

    final code = RoomCodeGenerator.generate();
    final gameId = 'game_room_$code';
    final now = DateTime.now().millisecondsSinceEpoch;
    final room = RoomState(
      roomCode: code,
      hostUid: _uid!,
      guestUid: null,
      gameId: gameId,
      status: 'waiting',
      createdAt: now,
      expiresAt: now + (15 * 60 * 1000), // 15 mins expiry
    );

    _db.rooms[code] = room;
    _activeRoomCode = code;
    _activeGameId = gameId;

    // Create placeholder game in waiting state
    final game = OnlineGameState(
      gameId: gameId,
      playerX: _uid,
      playerO: null,
      board: List.filled(9, null),
      currentTurn: 'X',
      status: OnlineGameStatus.waiting,
      createdAt: now,
      updatedAt: now,
    );
    _db.broadcastGameState(game);

    return room;
  }

  @override
  Future<RoomState> joinRoom(String roomCode) async {
    await signInAnonymously();
    if (!_isConnected) {
      throw const OnlineException('No internet connection.');
    }

    final normalized = RoomCodeGenerator.normalize(roomCode);
    final room = _db.rooms[normalized];

    if (room == null) {
      throw const OnlineException('Room not found.');
    }

    if (room.isExpired) {
      throw const OnlineException('Room expired.');
    }

    if (room.guestUid != null && room.guestUid != _uid) {
      throw const OnlineException('Room is full.');
    }

    if (room.hostUid == _uid) {
      // Re-joining own room as host
      return room;
    }

    // Guest joins room: host is X, guest is O
    final updatedRoom = RoomState(
      roomCode: room.roomCode,
      hostUid: room.hostUid,
      guestUid: _uid,
      gameId: room.gameId,
      status: 'active',
      createdAt: room.createdAt,
      expiresAt: room.expiresAt,
    );
    _db.rooms[normalized] = updatedRoom;
    _activeRoomCode = normalized;
    _activeGameId = room.gameId;

    // Transition game to active
    final currentGame = _db.games[room.gameId];
    final updatedGame = (currentGame ??
            OnlineGameState(
              gameId: room.gameId,
              playerX: room.hostUid,
              board: List.filled(9, null),
            ))
        .copyWith(
      playerX: room.hostUid,
      playerO: _uid,
      status: OnlineGameStatus.active,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    _db.broadcastGameState(updatedGame);
    return updatedRoom;
  }

  @override
  Future<void> leaveRoom(String roomCode) async {
    final normalized = RoomCodeGenerator.normalize(roomCode);
    final room = _db.rooms[normalized];
    if (room != null) {
      if (room.hostUid == _uid) {
        _db.rooms.remove(normalized);
        if (_db.games.containsKey(room.gameId)) {
          final game = _db.games[room.gameId]!;
          _db.broadcastGameState(
            game.copyWith(status: OnlineGameStatus.abandoned),
          );
        }
      } else if (room.guestUid == _uid) {
        final updatedRoom = RoomState(
          roomCode: room.roomCode,
          hostUid: room.hostUid,
          guestUid: null,
          gameId: room.gameId,
          status: 'waiting',
          createdAt: room.createdAt,
          expiresAt: room.expiresAt,
        );
        _db.rooms[normalized] = updatedRoom;
      }
    }
    _activeRoomCode = null;
  }

  @override
  Future<bool> makeMove(String gameId, int cellIndex) async {
    if (!_isConnected) {
      throw const OnlineException('No internet connection.');
    }
    if (_uid == null) {
      throw const OnlineException('User not authenticated.');
    }
    if (cellIndex < 0 || cellIndex >= 9) {
      throw const OnlineException('Invalid cell index.');
    }

    final game = _db.games[gameId];
    if (game == null) {
      throw const OnlineException('Game not found.');
    }
    if (game.status != OnlineGameStatus.active) {
      throw const OnlineException('Game is not active.');
    }

    final role = game.roleOf(_uid);
    if (role == null) {
      throw const OnlineException('Unauthorized move: player not in game.');
    }
    if (game.currentTurn != role) {
      throw const OnlineException("It is not your turn.");
    }
    if (game.board[cellIndex] != null) {
      throw const OnlineException('Cell is already occupied.');
    }

    // Apply move authoritatively
    final newBoard = List<String?>.from(game.board);
    newBoard[cellIndex] = role;

    // Check winner
    final winningCombo = _evaluateWinner(newBoard);
    String? winner;
    List<int>? winningCells;
    OnlineGameStatus newStatus = OnlineGameStatus.active;
    String nextTurn = role == 'X' ? 'O' : 'X';

    if (winningCombo != null) {
      winner = role;
      winningCells = winningCombo;
      newStatus = OnlineGameStatus.finished;
    } else if (!newBoard.contains(null)) {
      winner = 'Draw';
      winningCells = null;
      newStatus = OnlineGameStatus.finished;
    }

    final updatedState = game.copyWith(
      board: newBoard,
      currentTurn: nextTurn,
      status: newStatus,
      winner: winner,
      winningCells: winningCells,
      moveCount: game.moveCount + 1,
      lastMoveIndex: cellIndex,
      lastMovePlayer: role,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    _db.broadcastGameState(updatedState);
    return true;
  }

  @override
  Future<void> requestRematch(String gameId) async {
    final game = _db.games[gameId];
    if (game == null) return;
    final role = game.roleOf(_uid);
    if (role == null) return;

    bool rX = game.rematchX;
    bool rO = game.rematchO;
    if (role == 'X') rX = true;
    if (role == 'O') rO = true;

    if (rX && rO) {
      // Both agreed -> reset for new round
      await resetRound(gameId);
    } else {
      final updated = game.copyWith(rematchX: rX, rematchO: rO);
      _db.broadcastGameState(updated);
    }
  }

  @override
  Future<void> resetRound(String gameId) async {
    final game = _db.games[gameId];
    if (game == null) return;

    final resetGame = OnlineGameState(
      gameId: gameId,
      playerX: game.playerX,
      playerO: game.playerO,
      board: List.filled(9, null),
      currentTurn: 'X',
      status: OnlineGameStatus.active,
      winner: null,
      winningCells: null,
      moveCount: 0,
      rematchX: false,
      rematchO: false,
      createdAt: game.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _db.broadcastGameState(resetGame);
  }

  @override
  Stream<OnlineGameState> streamGame(String gameId) {
    final controller = _db.getOrCreateGameStream(gameId);
    final currentGame = _db.games[gameId];
    if (currentGame != null) {
      // Emit current authoritative state immediately on subscription
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add(currentGame);
        }
      });
    }
    return controller.stream;
  }

  @override
  Future<OnlineGameState?> getGame(String gameId) async {
    return _db.games[gameId];
  }

  @override
  Stream<bool> streamOpponentPresence(String opponentUid) {
    final controller = _db.getOrCreatePresenceStream(opponentUid);
    final currentPresence = _db.presence[opponentUid] ?? true;
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(currentPresence);
      }
    });
    return controller.stream;
  }

  @override
  Future<void> leaveGame(String gameId) async {
    final game = _db.games[gameId];
    if (game != null) {
      final updated = game.copyWith(
        status: OnlineGameStatus.abandoned,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _db.broadcastGameState(updated);
    }
    if (_activeRoomCode != null) {
      await leaveRoom(_activeRoomCode!);
    }
    _activeGameId = null;
  }

  @override
  void dispose() {
    cancelMatchmaking();
    if (_activeGameId != null) {
      leaveGame(_activeGameId!);
    }
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
