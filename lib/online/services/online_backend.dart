import '../models/online_game_state.dart';

/// Exceptions specific to online operations
class OnlineException implements Exception {
  final String message;
  final String? code;
  const OnlineException(this.message, [this.code]);

  @override
  String toString() => message;
}

/// Abstract contract for real-time online multiplayer backend.
/// Supports both Firebase Realtime Database (production) and Mock (automated testing).
abstract class OnlineBackend {
  /// Ensures the client has an anonymous authenticated identity and returns its UID.
  Future<String> signInAnonymously();

  /// Current authenticated user ID, or null if unauthenticated.
  String? get currentUserId;

  /// Stream of network connection state (true = connected, false = disconnected).
  Stream<bool> get connectionStream;

  /// Joins matchmaking queue and returns paired game, or null if cancelled/timed out.
  Future<OnlineGameState?> findMatch();

  /// Cancels active matchmaking queue entry.
  Future<void> cancelMatchmaking();

  /// Creates a private room with a generated 6-character code.
  Future<RoomState> createRoom();

  /// Joins an existing private room with the provided [roomCode].
  Future<RoomState> joinRoom(String roomCode);

  /// Leaves/cancels an active room.
  Future<void> leaveRoom(String roomCode);

  /// Attempts to make an atomic authoritative move on [cellIndex] (0..8).
  /// Returns true if move succeeded; false or throws OnlineException if rejected.
  Future<bool> makeMove(String gameId, int cellIndex);

  /// Requests or accepts a rematch / new round for [gameId].
  Future<void> requestRematch(String gameId);

  /// Resets board for next round when rematch agreed.
  Future<void> resetRound(String gameId);

  /// Real-time stream of authoritative game state updates.
  Stream<OnlineGameState> streamGame(String gameId);

  /// Retrieves current snapshot of the game, or null if not found.
  Future<OnlineGameState?> getGame(String gameId);

  /// Real-time stream of opponent's online presence (true = active, false = disconnected).
  Stream<bool> streamOpponentPresence(String opponentUid);

  /// Leaves or resigns from the active game.
  Future<void> leaveGame(String gameId);

  /// Cleans up resources, timers, and subscriptions.
  void dispose();
}
