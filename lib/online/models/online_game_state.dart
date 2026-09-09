/// Status of an authoritative online game session
enum OnlineGameStatus {
  waiting,
  active,
  finished,
  abandoned,
}

/// Authoritative online Tic-Tac-Toe game state model
class OnlineGameState {
  final String gameId;
  final String? playerX;
  final String? playerO;
  final List<String?> board;
  final String currentTurn;
  final OnlineGameStatus status;
  final String? winner;
  final List<int>? winningCells;
  final int moveCount;
  final int? lastMoveIndex;
  final String? lastMovePlayer;
  final bool rematchX;
  final bool rematchO;
  final int? createdAt;
  final int? updatedAt;

  const OnlineGameState({
    required this.gameId,
    this.playerX,
    this.playerO,
    required this.board,
    this.currentTurn = 'X',
    this.status = OnlineGameStatus.active,
    this.winner,
    this.winningCells,
    this.moveCount = 0,
    this.lastMoveIndex,
    this.lastMovePlayer,
    this.rematchX = false,
    this.rematchO = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Returns whether [uid] is Player X
  bool isPlayerX(String? uid) => uid != null && uid == playerX;

  /// Returns whether [uid] is Player O
  bool isPlayerO(String? uid) => uid != null && uid == playerO;

  /// Returns 'X', 'O', or null depending on participant identity
  String? roleOf(String? uid) {
    if (isPlayerX(uid)) return 'X';
    if (isPlayerO(uid)) return 'O';
    return null;
  }

  /// Returns true if it is the turn of [uid]
  bool isMyTurn(String? uid) {
    final role = roleOf(uid);
    return role != null && role == currentTurn && status == OnlineGameStatus.active && winner == null;
  }

  /// Deserializes Realtime Database map into strongly typed model
  factory OnlineGameState.fromMap(String gameId, Map<dynamic, dynamic> map) {
    // Parse board safely
    final rawBoard = map['board'];
    List<String?> parsedBoard = List.filled(9, null);
    if (rawBoard is List) {
      for (int i = 0; i < 9 && i < rawBoard.length; i++) {
        final val = rawBoard[i]?.toString();
        parsedBoard[i] = (val == 'X' || val == 'O') ? val : null;
      }
    } else if (rawBoard is Map) {
      for (int i = 0; i < 9; i++) {
        final val = rawBoard[i]?.toString() ?? rawBoard['$i']?.toString();
        parsedBoard[i] = (val == 'X' || val == 'O') ? val : null;
      }
    }

    // Parse winning cells
    final rawCells = map['winningCells'];
    List<int>? parsedWinningCells;
    if (rawCells is List) {
      parsedWinningCells = rawCells.map((e) => int.tryParse(e.toString()) ?? 0).toList();
    }

    // Parse status
    OnlineGameStatus parsedStatus = OnlineGameStatus.active;
    final statusStr = map['status']?.toString();
    if (statusStr == 'waiting') {
      parsedStatus = OnlineGameStatus.waiting;
    } else if (statusStr == 'finished') {
      parsedStatus = OnlineGameStatus.finished;
    } else if (statusStr == 'abandoned') {
      parsedStatus = OnlineGameStatus.abandoned;
    }

    final rematch = map['rematch'];
    bool rX = false;
    bool rO = false;
    if (rematch is Map) {
      rX = rematch['requestX'] == true;
      rO = rematch['requestO'] == true;
    }

    return OnlineGameState(
      gameId: gameId,
      playerX: map['playerX']?.toString(),
      playerO: map['playerO']?.toString(),
      board: parsedBoard,
      currentTurn: map['currentTurn']?.toString() ?? 'X',
      status: parsedStatus,
      winner: map['winner']?.toString(),
      winningCells: parsedWinningCells,
      moveCount: int.tryParse(map['moveCount']?.toString() ?? '0') ?? 0,
      lastMoveIndex: map['lastMoveIndex'] != null
          ? int.tryParse(map['lastMoveIndex'].toString())
          : null,
      lastMovePlayer: map['lastMovePlayer']?.toString(),
      rematchX: rX,
      rematchO: rO,
      createdAt: int.tryParse(map['createdAt']?.toString() ?? '0'),
      updatedAt: int.tryParse(map['updatedAt']?.toString() ?? '0'),
    );
  }

  /// Serializes to Firebase Realtime Database map
  Map<String, dynamic> toMap() {
    final boardMap = <String, String>{};
    for (int i = 0; i < board.length; i++) {
      final cell = board[i];
      if (cell != null) {
        boardMap['$i'] = cell;
      }
    }

    return {
      'gameId': gameId,
      'playerX': playerX,
      'playerO': playerO,
      'board': boardMap,
      'currentTurn': currentTurn,
      'status': status.name,
      'winner': winner,
      'winningCells': winningCells,
      'moveCount': moveCount,
      'lastMoveIndex': lastMoveIndex,
      'lastMovePlayer': lastMovePlayer,
      'rematch': {
        'requestX': rematchX,
        'requestO': rematchO,
      },
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  OnlineGameState copyWith({
    String? gameId,
    String? playerX,
    String? playerO,
    List<String?>? board,
    String? currentTurn,
    OnlineGameStatus? status,
    String? winner,
    List<int>? winningCells,
    int? moveCount,
    int? lastMoveIndex,
    String? lastMovePlayer,
    bool? rematchX,
    bool? rematchO,
    int? createdAt,
    int? updatedAt,
  }) {
    return OnlineGameState(
      gameId: gameId ?? this.gameId,
      playerX: playerX ?? this.playerX,
      playerO: playerO ?? this.playerO,
      board: board ?? List.from(this.board),
      currentTurn: currentTurn ?? this.currentTurn,
      status: status ?? this.status,
      winner: winner ?? this.winner,
      winningCells: winningCells ?? this.winningCells,
      moveCount: moveCount ?? this.moveCount,
      lastMoveIndex: lastMoveIndex ?? this.lastMoveIndex,
      lastMovePlayer: lastMovePlayer ?? this.lastMovePlayer,
      rematchX: rematchX ?? this.rematchX,
      rematchO: rematchO ?? this.rematchO,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Authoritative room state for Online With Code
class RoomState {
  final String roomCode;
  final String hostUid;
  final String? guestUid;
  final String gameId;
  final String status; // 'waiting', 'active', 'abandoned', 'expired'
  final int createdAt;
  final int expiresAt;

  const RoomState({
    required this.roomCode,
    required this.hostUid,
    this.guestUid,
    required this.gameId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isWaiting => status == 'waiting' && guestUid == null;
  bool get isActive => status == 'active' && guestUid != null;
  bool get isExpired =>
      status == 'expired' ||
      (DateTime.now().millisecondsSinceEpoch > expiresAt && guestUid == null);

  factory RoomState.fromMap(String roomCode, Map<dynamic, dynamic> map) {
    return RoomState(
      roomCode: roomCode,
      hostUid: map['hostUid']?.toString() ?? '',
      guestUid: map['guestUid']?.toString(),
      gameId: map['gameId']?.toString() ?? '',
      status: map['status']?.toString() ?? 'waiting',
      createdAt: int.tryParse(map['createdAt']?.toString() ?? '0') ?? 0,
      expiresAt: int.tryParse(map['expiresAt']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'hostUid': hostUid,
      'guestUid': guestUid,
      'gameId': gameId,
      'status': status,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
    };
  }
}
