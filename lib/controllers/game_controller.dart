import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../sound/audio_service.dart';
import '../ai/tic_tac_toe_ai.dart';
import '../online/models/online_game_state.dart';
import '../online/services/online_backend.dart';
import '../online/services/firebase_online_backend.dart';
import '../online/services/room_code_generator.dart';
import '../online/services/session_storage_service.dart';
import '../online/firebase_options.dart';

class TicTacToeController extends ChangeNotifier {
  // Game board representation: 9 cells, null = empty, 'X' or 'O'
  List<String?> _board = List.filled(9, null);
  List<String?> get board => _board;

  // 'X' is Player 1, 'O' is Player 2. 'X' always starts a new round.
  String _currentPlayer = 'X';
  String get currentPlayer => _currentPlayer;

  // Active game mode: exactly 4 modes (COMPUTER, 1 VS 1, COMPLETE ONLINE, ONLINE WITH CODE)
  GameMode _gameMode = GameMode.twoPlayer;
  GameMode get gameMode => _gameMode;

  // Active AI difficulty level when in Vs Computer mode
  Difficulty _difficulty = Difficulty.medium;
  Difficulty get difficulty => _difficulty;

  // Whether the computer opponent is currently calculating/making its move
  bool _isComputerThinking = false;
  bool get isComputerThinking => _isComputerThinking;

  // Generation epoch incremented on resets/mode switches to invalidate async computer callbacks
  int _gameEpoch = 0;

  // Game outcome: null = in progress, 'X' = X won, 'O' = O won, 'Draw' = draw
  String? _winner;
  String? get winner => _winner;

  // Stores the indices of the winning line, if any
  List<int>? _winningLine;
  List<int>? get winningLine => _winningLine;

  // Track hovered cell index for subtle interaction preview
  int? _hoveredIndex;
  int? get hoveredIndex => _hoveredIndex;

  // Index of the most recently placed piece to trigger physical drop animation
  int? _lastPlacedIndex;
  int? get lastPlacedIndex => _lastPlacedIndex;

  // Piece placed event notification flag
  bool piecePlacedEvent = false;
  bool newRoundEvent = false;

  // Session score trackers
  int _scoreX = 0;
  int get scoreX => _scoreX;

  int _scoreO = 0;
  int get scoreO => _scoreO;

  int _scoreDraw = 0;
  int get scoreDraw => _scoreDraw;

  // Audio service
  late final AudioService _soundService;
  AudioService get soundService => _soundService;
  bool get isMuted => _soundService.isMuted;

  // Online Multiplayer State
  OnlineBackend? _onlineBackend;
  OnlineBackend? get onlineBackend => _onlineBackend;

  OnlineGameState? _onlineGameState;
  OnlineGameState? get onlineGameState => _onlineGameState;

  String? _onlineRole; // 'X' or 'O'
  String? get onlineRole => _onlineRole;

  String? _onlineRoomCode;
  String? get onlineRoomCode => _onlineRoomCode;

  bool _isMatchmaking = false;
  bool get isMatchmaking => _isMatchmaking;

  bool _isCreatingRoom = false;
  bool get isCreatingRoom => _isCreatingRoom;

  bool _isJoiningRoom = false;
  bool get isJoiningRoom => _isJoiningRoom;

  bool _isSubmittingMove = false;
  bool get isSubmittingMove => _isSubmittingMove;

  String? _onlineErrorMessage;
  String? get onlineErrorMessage => _onlineErrorMessage;

  bool _isReconnecting = false;
  bool get isReconnecting => _isReconnecting;

  bool _isOpponentDisconnected = false;
  bool get isOpponentDisconnected => _isOpponentDisconnected;

  bool _isRequestingRematch = false;
  bool get isRequestingRematch => _isRequestingRematch;

  /// Returns whether the local player has requested a rematch
  bool get hasRequestedRematch {
    if (_onlineGameState == null || _onlineRole == null) return false;
    return _onlineRole == 'X'
        ? _onlineGameState!.rematchX
        : _onlineGameState!.rematchO;
  }

  /// Returns whether the remote opponent has requested a rematch
  bool get opponentRequestedRematch {
    if (_onlineGameState == null || _onlineRole == null) return false;
    return _onlineRole == 'X'
        ? _onlineGameState!.rematchO
        : _onlineGameState!.rematchX;
  }

  bool _isPrivateRoomHost = false;
  bool get isPrivateRoomHost => _isPrivateRoomHost;

  int _privateRoomTab = 0; // 0 = Create Room, 1 = Join Room
  int get privateRoomTab => _privateRoomTab;

  final TextEditingController roomCodeInputController = TextEditingController();

  StreamSubscription<OnlineGameState>? _gameStreamSub;
  StreamSubscription<bool>? _opponentPresenceSub;
  StreamSubscription<bool>? _connectionSub;

  // All 8 possible winning combinations (rows, columns, diagonals)
  static const List<List<int>> _winningCombinations = [
    // Rows
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    // Columns
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    // Diagonals
    [0, 4, 8],
    [2, 4, 6],
  ];

  TicTacToeController({OnlineBackend? initialBackend}) {
    _onlineBackend = initialBackend;
    _soundService = AudioService();
    _initConnectionListener();
    restoreActiveSession();
  }

  void _initConnectionListener() {
    _connectionSub?.cancel();
    _connectionSub = _onlineBackend?.connectionStream.listen((connected) {
      _isReconnecting = !connected;
      notifyListeners();
    });
  }

  void _cleanupOnlineSubscriptions() {
    _onlineBackend?.cancelMatchmaking();
    _isMatchmaking = false;
    _gameStreamSub?.cancel();
    _gameStreamSub = null;
    _opponentPresenceSub?.cancel();
    _opponentPresenceSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
  }

  Future<OnlineBackend?> ensureBackend() async {
    if (_onlineBackend != null) return _onlineBackend;

    try {
      if (DefaultFirebaseOptions.isConfigured) {
        final options = DefaultFirebaseOptions.currentPlatform;
        if (options != null) {
          await Firebase.initializeApp(options: options);
          _onlineBackend = FirebaseOnlineBackend();
          return _onlineBackend;
        }
      }
    } catch (e) {
      debugPrint('[ONLINE] Lazy Firebase init failed: $e');
    }

    _onlineErrorMessage = 'Online multiplayer requires Firebase configuration.';
    notifyListeners();
    return null;
  }

  Future<void> restoreActiveSession() async {
    try {
      final session = await SessionStorageService.instance.loadSession();
      if (session == null) return;

      final targetMode = session.mode == 'onlineWithCode'
          ? GameMode.onlineWithCode
          : GameMode.completeOnline;

      final backend = await ensureBackend();
      if (backend == null) return;

      _gameMode = targetMode;
      _isReconnecting = true;
      _onlineRoomCode = session.roomCode;
      _onlineRole = session.role;
      _isPrivateRoomHost = session.isHost;
      notifyListeners();

      final gameSnapshot = await backend.getGame(session.gameId);

      if (gameSnapshot == null ||
          gameSnapshot.status == OnlineGameStatus.abandoned) {
        await SessionStorageService.instance.clearSession();
        _isReconnecting = false;
        _onlineErrorMessage = 'Previous match was ended or abandoned.';
        notifyListeners();
        return;
      }

      _attachToGame(gameSnapshot);
      _isReconnecting = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[ONLINE] Session restoration skipped/failed: $e');
      _isReconnecting = false;
      notifyListeners();
    }
  }

  void setHoveredIndex(int? index) {
    if (_hoveredIndex != index) {
      _hoveredIndex = index;
      notifyListeners();
    }
  }

  void setPrivateRoomTab(int tab) {
    if (_privateRoomTab != tab) {
      _privateRoomTab = tab;
      notifyListeners();
    }
  }

  void clearErrorMessage() {
    _onlineErrorMessage = null;
    notifyListeners();
  }

  void toggleMute() {
    _soundService.toggleMute();
    notifyListeners();
  }

  void setDifficulty(Difficulty diff) {
    if (_difficulty == diff) return;
    _soundService.playButton();
    _difficulty = diff;
    notifyListeners();
  }

  /// Sets up and starts local 1 VS 1 mode
  void startLocalGame() {
    _soundService.playButton();
    SessionStorageService.instance.clearSession();
    _cleanupOnlineSubscriptions();
    _setGameMode(GameMode.twoPlayer);
    resetBoard();
  }

  /// Sets up and starts computer mode
  void startComputerGame(Difficulty diff) {
    _soundService.playButton();
    SessionStorageService.instance.clearSession();
    _cleanupOnlineSubscriptions();
    _difficulty = diff;
    _setGameMode(GameMode.vsComputer);
    resetBoard();
  }

  /// Switches active game mode cleanly between all four modes
  void _setGameMode(GameMode mode) {
    if (_gameMode == mode && _onlineGameState == null) return;

    // Safely leave / cleanup previous online mode if switching away
    if (_gameMode == GameMode.completeOnline ||
        _gameMode == GameMode.onlineWithCode) {
      SessionStorageService.instance.clearSession();
      _cleanupOnlineSubscriptions();
      _onlineBackend?.cancelMatchmaking();
      if (_onlineGameState?.gameId != null) {
        _onlineBackend?.leaveGame(_onlineGameState!.gameId);
      }
    }

    _gameMode = mode;
    _gameEpoch++;
    _isComputerThinking = false;
    _board = List.filled(9, null);
    _currentPlayer = 'X';
    _winner = null;
    _winningLine = null;
    _hoveredIndex = null;
    _lastPlacedIndex = null;
    _onlineGameState = null;
    _onlineRole = null;
    _onlineRoomCode = null;
    _isMatchmaking = false;
    _isCreatingRoom = false;
    _isJoiningRoom = false;
    _onlineErrorMessage = null;
    _isReconnecting = false;
    _isOpponentDisconnected = false;
    _isRequestingRematch = false;

    if (mode == GameMode.completeOnline || mode == GameMode.onlineWithCode) {
      _initConnectionListener();
    }

    notifyListeners();
  }

  /// Handles player tapping a cell on the board
  void handleTap(int index) {
    if (_gameMode == GameMode.completeOnline ||
        _gameMode == GameMode.onlineWithCode) {
      _handleOnlineTap(index);
      return;
    }

    if (_board[index] != null || _winner != null || _isComputerThinking) {
      return;
    }

    // In Vs Computer mode, human is always X and can only move on X's turn
    if (_gameMode == GameMode.vsComputer && _currentPlayer != 'X') {
      return;
    }

    // Play physical move placement click
    _soundService.playMove();

    _hoveredIndex = null;
    _board[index] = _currentPlayer;
    _lastPlacedIndex = index;
    piecePlacedEvent = true;

    final winningCombo = _checkWinner();
    if (winningCombo != null) {
      _winner = _currentPlayer;
      _winningLine = winningCombo;
      if (_currentPlayer == 'X') {
        _scoreX++;
        _soundService.playXWin();
      } else {
        _scoreO++;
        _soundService.playOWin();
      }
    } else if (!_board.contains(null)) {
      _winner = 'Draw';
      _winningLine = null;
      _scoreDraw++;
      _soundService.playDraw();
    } else {
      _currentPlayer = _currentPlayer == 'X' ? 'O' : 'X';
    }

    notifyListeners();

    // In Vs Computer mode, if the match is still active and it's O's turn, trigger AI move
    if (_gameMode == GameMode.vsComputer &&
        _winner == null &&
        _currentPlayer == 'O') {
      _triggerComputerMove();
    }
  }

  /// Handles move in online multiplayer modes
  Future<void> _handleOnlineTap(int index) async {
    if (_board[index] != null ||
        _winner != null ||
        _isSubmittingMove ||
        _onlineGameState == null ||
        _onlineGameState!.status != OnlineGameStatus.active ||
        _onlineRole == null ||
        _currentPlayer != _onlineRole) {
      return;
    }

    final backend = _onlineBackend;
    if (backend == null) return;

    _isSubmittingMove = true;
    _onlineErrorMessage = null;
    notifyListeners();

    try {
      await backend.makeMove(_onlineGameState!.gameId, index);
    } catch (e) {
      _isSubmittingMove = false;
      _onlineErrorMessage =
          e is OnlineException ? e.message : 'Move rejected by server.';
      notifyListeners();
    }
  }

  /// Incoming stream updates from authoritative backend
  void _onOnlineGameUpdated(OnlineGameState newState) {
    final prevBoard = _board;
    final newBoard = newState.board;
    int? remoteMoveIndex;

    // Detect if a new remote move was placed
    if (newState.lastMoveIndex != null &&
        newState.lastMovePlayer != null &&
        newState.lastMovePlayer != _onlineRole) {
      remoteMoveIndex = newState.lastMoveIndex;
    } else {
      for (int i = 0; i < 9; i++) {
        if (prevBoard[i] == null &&
            newBoard[i] != null &&
            newBoard[i] != _onlineRole) {
          remoteMoveIndex = i;
          break;
        }
      }
    }

    _isSubmittingMove = false;
    _onlineGameState = newState;
    _board = List.from(newBoard);
    _currentPlayer = newState.currentTurn;

    // Physical piece drop animation and move sound for remote move
    if (remoteMoveIndex != null && prevBoard[remoteMoveIndex] == null) {
      _lastPlacedIndex = remoteMoveIndex;
      piecePlacedEvent = true;
      _soundService.playMove();
    }

    // Check authoritative game conclusion
    if (newState.winner != null && _winner == null) {
      _winner = newState.winner;
      _winningLine = newState.winningCells;

      if (_winner == 'Draw') {
        _scoreDraw++;
        _soundService.playDraw();
      } else if (_winner == _onlineRole) {
        if (_onlineRole == 'X') {
          _scoreX++;
          _soundService.playXWin();
        } else {
          _scoreO++;
          _soundService.playOWin();
        }
      } else {
        // Opponent won
        if (_onlineRole == 'X') {
          _scoreO++;
          _soundService.playOWin();
        } else {
          _scoreX++;
          _soundService.playXWin();
        }
      }
    } else if (newState.winner == null && _winner != null) {
      // Rematch agreement -> clean board for next round
      _winner = null;
      _winningLine = null;
      _lastPlacedIndex = null;
      newRoundEvent = true;
      _soundService.playNewRound();
    }

    if (newState.status == OnlineGameStatus.abandoned) {
      SessionStorageService.instance.clearSession();
    }

    notifyListeners();
  }

  void _attachToGame(OnlineGameState game) {
    _cleanupOnlineSubscriptions();
    final uid = _onlineBackend?.currentUserId;
    final role = game.roleOf(uid) ?? 'X';

    SessionStorageService.instance.saveSession(ActiveSessionData(
      gameId: game.gameId,
      roomCode: _onlineRoomCode,
      role: role,
      mode: _gameMode == GameMode.onlineWithCode
          ? 'onlineWithCode'
          : 'completeOnline',
      isHost: _isPrivateRoomHost,
    ));

    _isMatchmaking = false;
    _onlineGameState = game;
    _onlineRole = role;
    _board = List.from(game.board);
    _currentPlayer = game.currentTurn;
    _winner = game.winner;
    _winningLine = game.winningCells;
    _onlineErrorMessage = null;
    notifyListeners();

    _gameStreamSub =
        _onlineBackend!.streamGame(game.gameId).listen(_onOnlineGameUpdated);

    final opponentUid = (role == 'X') ? game.playerO : game.playerX;
    if (opponentUid != null && opponentUid.isNotEmpty) {
      _opponentPresenceSub = _onlineBackend!
          .streamOpponentPresence(opponentUid)
          .listen((online) {
        _isOpponentDisconnected = !online;
        notifyListeners();
      });
    }

    _connectionSub = _onlineBackend!.connectionStream.listen((connected) {
      _isReconnecting = !connected;
      notifyListeners();
    });
  }

  /// Start complete online random matchmaking
  Future<void> startMatchmaking() async {
    final backend = await ensureBackend();
    if (backend == null) return;

    _cleanupOnlineSubscriptions();

    _gameMode = GameMode.completeOnline;
    _isMatchmaking = true;
    _onlineErrorMessage = null;
    _onlineGameState = null;
    _onlineRole = null;
    _board = List.filled(9, null);
    _winner = null;
    _winningLine = null;
    _lastPlacedIndex = null;
    notifyListeners();

    try {
      final matchedGame = await backend.findMatch();
      if (matchedGame != null &&
          _gameMode == GameMode.completeOnline &&
          _isMatchmaking) {
        _attachToGame(matchedGame);
      }
    } catch (e) {
      if (_gameMode == GameMode.completeOnline && _isMatchmaking) {
        _isMatchmaking = false;
        _onlineErrorMessage =
            e is OnlineException ? e.message : 'Matchmaking failed.';
        notifyListeners();
      }
    }
  }

  Future<void> cancelMatchmaking() async {
    try {
      await _onlineBackend?.cancelMatchmaking();
    } catch (_) {}
    _isMatchmaking = false;
    notifyListeners();
  }

  /// Create private room
  Future<void> createPrivateRoom() async {
    final backend = await ensureBackend();
    if (backend == null) return;

    _cleanupOnlineSubscriptions();

    _gameMode = GameMode.onlineWithCode;
    _isCreatingRoom = true;
    _onlineErrorMessage = null;
    _onlineGameState = null;
    _onlineRole = 'X';
    _board = List.filled(9, null);
    _winner = null;
    _winningLine = null;
    _lastPlacedIndex = null;
    notifyListeners();

    try {
      final room = await backend.createRoom();

      SessionStorageService.instance.saveSession(ActiveSessionData(
        gameId: room.gameId,
        roomCode: room.roomCode,
        role: 'X',
        mode: 'onlineWithCode',
        isHost: true,
      ));

      _isCreatingRoom = false;
      _onlineRoomCode = room.roomCode;
      _isPrivateRoomHost = true;
      notifyListeners();

      _gameStreamSub =
          backend.streamGame(room.gameId).listen((gameState) {
        final opponentUid = gameState.playerO;
        if (opponentUid != null &&
            opponentUid.isNotEmpty &&
            _opponentPresenceSub == null) {
          _opponentPresenceSub = backend
              .streamOpponentPresence(opponentUid)
              .listen((online) {
            _isOpponentDisconnected = !online;
            notifyListeners();
          });
        }
        _onOnlineGameUpdated(gameState);
      });

      _connectionSub?.cancel();
      _connectionSub = backend.connectionStream.listen((connected) {
        _isReconnecting = !connected;
        notifyListeners();
      });
    } catch (e) {
      _isCreatingRoom = false;
      _onlineErrorMessage =
          e is OnlineException ? e.message : 'Failed to create room.';
      notifyListeners();
    }
  }

  /// Join private room by code
  Future<void> joinPrivateRoom() async {
    final code = roomCodeInputController.text.trim();
    if (!RoomCodeGenerator.isValid(code)) {
      _onlineErrorMessage = 'Please enter a valid 6-character room code.';
      notifyListeners();
      return;
    }

    final backend = await ensureBackend();
    if (backend == null) return;

    _cleanupOnlineSubscriptions();

    _gameMode = GameMode.onlineWithCode;
    _isJoiningRoom = true;
    _onlineErrorMessage = null;
    _onlineGameState = null;
    _onlineRole = 'O';
    _board = List.filled(9, null);
    _winner = null;
    _winningLine = null;
    _lastPlacedIndex = null;
    notifyListeners();

    try {
      final room = await backend.joinRoom(code);

      SessionStorageService.instance.saveSession(ActiveSessionData(
        gameId: room.gameId,
        roomCode: room.roomCode,
        role: 'O',
        mode: 'onlineWithCode',
        isHost: false,
      ));

      _isJoiningRoom = false;
      _onlineRoomCode = room.roomCode;
      _isPrivateRoomHost = false;
      notifyListeners();

      _gameStreamSub =
          backend.streamGame(room.gameId).listen(_onOnlineGameUpdated);

      _opponentPresenceSub?.cancel();
      _opponentPresenceSub =
          backend.streamOpponentPresence(room.hostUid).listen((online) {
        _isOpponentDisconnected = !online;
        notifyListeners();
      });

      _connectionSub?.cancel();
      _connectionSub = backend.connectionStream.listen((connected) {
        _isReconnecting = !connected;
        notifyListeners();
      });
    } catch (e) {
      _isJoiningRoom = false;
      _onlineErrorMessage =
          e is OnlineException ? e.message : 'Unable to join room.';
      notifyListeners();
    }
  }

  Future<void> leaveOnlineGame() async {
    SessionStorageService.instance.clearSession();
    _cleanupOnlineSubscriptions();
    if (_onlineGameState?.gameId != null) {
      await _onlineBackend?.leaveGame(_onlineGameState!.gameId);
    } else if (_onlineRoomCode != null) {
      await _onlineBackend?.leaveRoom(_onlineRoomCode!);
    }

    _onlineGameState = null;
    _onlineRole = null;
    _onlineRoomCode = null;
    _isMatchmaking = false;
    _isCreatingRoom = false;
    _isJoiningRoom = false;
    _onlineErrorMessage = null;
    _isReconnecting = false;
    _isOpponentDisconnected = false;
    _isRequestingRematch = false;
    _board = List.filled(9, null);
    _winner = null;
    _winningLine = null;
    _lastPlacedIndex = null;
    notifyListeners();
  }

  /// Triggers the computer opponent's move with a short natural delay
  void _triggerComputerMove() async {
    _isComputerThinking = true;
    notifyListeners();

    final currentEpoch = _gameEpoch;
    // Short natural delay for realistic physical tabletop feel (400ms)
    await Future.delayed(const Duration(milliseconds: 400));

    if (_gameEpoch != currentEpoch ||
        _gameMode != GameMode.vsComputer ||
        _winner != null ||
        _currentPlayer != 'O') {
      return;
    }

    final aiMove = TicTacToeAi.getBestMove(_board, _difficulty);
    if (aiMove == -1 || _board[aiMove] != null) {
      _isComputerThinking = false;
      notifyListeners();
      return;
    }

    // Play move placement click
    _soundService.playMove();

    _isComputerThinking = false;
    _board[aiMove] = 'O';
    _lastPlacedIndex = aiMove;
    piecePlacedEvent = true;

    final winningCombo = _checkWinner();
    if (winningCombo != null) {
      _winner = 'O';
      _winningLine = winningCombo;
      _scoreO++;
      _soundService.playOWin();
    } else if (!_board.contains(null)) {
      _winner = 'Draw';
      _winningLine = null;
      _scoreDraw++;
      _soundService.playDraw();
    } else {
      _currentPlayer = 'X';
    }

    notifyListeners();
  }

  /// Checks if any winning combination is satisfied
  List<int>? _checkWinner() {
    for (final combo in _winningCombinations) {
      final a = combo[0];
      final b = combo[1];
      final c = combo[2];

      if (_board[a] != null &&
          _board[a] == _board[b] &&
          _board[a] == _board[c]) {
        return combo;
      }
    }
    return null;
  }

  /// Requests or accepts an authoritative online rematch with the same opponent
  Future<void> requestRematch() async {
    if (_isRequestingRematch) return; // Prevent duplicate concurrent requests
    if (_gameMode != GameMode.completeOnline &&
        _gameMode != GameMode.onlineWithCode) {
      return;
    }
    if (_onlineGameState == null || _winner == null) {
      return;
    }
    if (_onlineGameState!.status != OnlineGameStatus.finished) {
      return;
    }

    final backend = _onlineBackend;
    if (backend == null) return;

    _soundService.playButton();
    _isRequestingRematch = true;
    _onlineErrorMessage = null;
    notifyListeners();

    try {
      await backend.requestRematch(_onlineGameState!.gameId);
    } catch (e) {
      _onlineErrorMessage =
          e is OnlineException ? e.message : 'Failed to request rematch.';
    } finally {
      _isRequestingRematch = false;
      notifyListeners();
    }
  }

  /// Starts a new round while preserving the session score
  void resetBoard() {
    _soundService.playNewRound();
    if (_gameMode == GameMode.completeOnline ||
        _gameMode == GameMode.onlineWithCode) {
      requestRematch();
      return;
    }

    _gameEpoch++;
    _isComputerThinking = false;
    _board = List.filled(9, null);
    _currentPlayer = 'X';
    _winner = null;
    _winningLine = null;
    _hoveredIndex = null;
    _lastPlacedIndex = null;
    newRoundEvent = true;
    notifyListeners();
  }

  /// Resets both the board and the session scores
  void resetAll() {
    _soundService.playReset();
    if (_gameMode == GameMode.completeOnline ||
        _gameMode == GameMode.onlineWithCode) {
      leaveOnlineGame();
    }

    _gameEpoch++;
    _isComputerThinking = false;
    _board = List.filled(9, null);
    _currentPlayer = 'X';
    _winner = null;
    _winningLine = null;
    _hoveredIndex = null;
    _lastPlacedIndex = null;
    _scoreX = 0;
    _scoreO = 0;
    _scoreDraw = 0;
    newRoundEvent = true;
    notifyListeners();
  }

  String getStatusText() {
    if (_winner == 'Draw') {
      return "It's a Draw!";
    }

    if (_gameMode == GameMode.vsComputer) {
      if (_winner == 'X') {
        return 'You Win!';
      } else if (_winner == 'O') {
        return 'Computer Wins!';
      } else if (_isComputerThinking) {
        return 'Computer Thinking...';
      } else {
        return 'Your Turn';
      }
    } else if (_gameMode == GameMode.twoPlayer) {
      if (_winner == 'X') {
        return 'Player X Wins!';
      } else if (_winner == 'O') {
        return 'Player O Wins!';
      } else if (_currentPlayer == 'X') {
        return 'Player X to move';
      } else {
        return 'Player O to move';
      }
    } else {
      // Online modes (Complete Online & Online With Code)
      if (_isReconnecting) {
        return 'Reconnecting...';
      }
      if (_isOpponentDisconnected) {
        return 'Opponent Disconnected';
      }
      if (_onlineGameState == null ||
          _onlineGameState!.status == OnlineGameStatus.waiting) {
        if (_gameMode == GameMode.completeOnline) {
          return _isMatchmaking ? 'Finding Opponent...' : 'Complete Online';
        } else {
          return _onlineRoomCode != null
              ? 'Waiting for Opponent...'
              : 'Private Room';
        }
      }
      if (_winner != null) {
        if (_winner == _onlineRole) {
          return 'You Win!';
        } else {
          return 'Opponent Wins!';
        }
      }
      if (_currentPlayer == _onlineRole) {
        return 'Your Turn';
      } else {
        return "Opponent's Turn";
      }
    }
  }

  @override
  void dispose() {
    _cleanupOnlineSubscriptions();
    roomCodeInputController.dispose();
    _soundService.dispose();
    super.dispose();
  }
}
