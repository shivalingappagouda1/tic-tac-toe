import 'dart:math' as math;

/// Supported game modes
enum GameMode {
  twoPlayer,
  vsComputer,
}

/// Difficulty levels for the computer opponent
enum Difficulty {
  easy,
  medium,
  hard,
}

/// Standalone AI engine for Tic-Tac-Toe.
///
/// Assumes:
/// - Human player is 'X'
/// - Computer player is 'O'
/// - Board is a `List<String?>` of length 9 where null indicates an empty cell.
class TicTacToeAi {
  static const List<List<int>> winningCombinations = [
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

  /// Corner indices
  static const List<int> _corners = [0, 2, 6, 8];

  /// Side / Edge indices
  static const List<int> _sides = [1, 3, 5, 7];

  /// Center index
  static const int _center = 4;

  /// Returns the chosen cell index (0..8) for the computer ('O') move.
  /// Returns -1 if no legal move is available.
  static int getBestMove(
    List<String?> board,
    Difficulty difficulty, {
    math.Random? random,
    bool forceTactical = false,
  }) {
    final legalMoves = getLegalMoves(board);
    if (legalMoves.isEmpty) return -1;

    final rng = random ?? math.Random();

    switch (difficulty) {
      case Difficulty.easy:
        return _getEasyMove(board, legalMoves, rng);
      case Difficulty.medium:
        return _getMediumMove(board, legalMoves, rng, forceTactical: forceTactical);
      case Difficulty.hard:
        return _getHardMove(board, legalMoves);
    }
  }

  /// Returns all empty cell indices on the board.
  static List<int> getLegalMoves(List<String?> board) {
    final moves = <int>[];
    for (int i = 0; i < board.length && i < 9; i++) {
      if (board[i] == null) {
        moves.add(i);
      }
    }
    return moves;
  }

  /// Finds an immediate winning move for [player] ('X' or 'O'), or null if none.
  static int? findWinningMove(List<String?> board, String player) {
    for (final combo in winningCombinations) {
      final a = combo[0];
      final b = combo[1];
      final c = combo[2];

      final countPlayer = (board[a] == player ? 1 : 0) +
          (board[b] == player ? 1 : 0) +
          (board[c] == player ? 1 : 0);

      final countEmpty = (board[a] == null ? 1 : 0) +
          (board[b] == null ? 1 : 0) +
          (board[c] == null ? 1 : 0);

      if (countPlayer == 2 && countEmpty == 1) {
        if (board[a] == null) return a;
        if (board[b] == null) return b;
        if (board[c] == null) return c;
      }
    }
    return null;
  }

  /// Checks if any player has won. Returns 'X', 'O', or null.
  static String? checkWinner(List<String?> board) {
    for (final combo in winningCombinations) {
      final a = combo[0];
      final b = combo[1];
      final c = combo[2];

      if (board[a] != null &&
          board[a] == board[b] &&
          board[a] == board[c]) {
        return board[a];
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // EASY DIFFICULTY
  // ---------------------------------------------------------------------------
  // - Takes an immediate winning move if available.
  // - Otherwise picks a random legal empty cell.
  static int _getEasyMove(
    List<String?> board,
    List<int> legalMoves,
    math.Random rng,
  ) {
    // 1. Take winning move if one exists
    final winMove = findWinningMove(board, 'O');
    if (winMove != null) {
      return winMove;
    }

    // 2. Otherwise random legal move
    return legalMoves[rng.nextInt(legalMoves.length)];
  }

  // ---------------------------------------------------------------------------
  // MEDIUM DIFFICULTY
  // ---------------------------------------------------------------------------
  // Tactical decision-making:
  // 1. Take immediate winning move if available.
  // 2. Block human if they have an immediate winning move.
  // 3. Prefer the center.
  // 4. Prefer corners.
  // 5. Otherwise choose an available cell.
  // 6. Deliberate 25% non-critical variance so Medium is not unbeatable.
  static int _getMediumMove(
    List<String?> board,
    List<int> legalMoves,
    math.Random rng, {
    bool forceTactical = false,
  }) {
    // Rule 1: Always take immediate winning move for 'O'
    final winMove = findWinningMove(board, 'O');
    if (winMove != null) {
      return winMove;
    }

    // Rule 2: Always block human's ('X') immediate winning move
    final blockMove = findWinningMove(board, 'X');
    if (blockMove != null) {
      return blockMove;
    }

    // Rule 6: When neither player has an immediate win, occasionally choose
    // a random legal move (25% chance) unless forceTactical is requested.
    if (!forceTactical && rng.nextDouble() < 0.25) {
      return legalMoves[rng.nextInt(legalMoves.length)];
    }

    // Rule 3: Prefer center
    if (board[_center] == null) {
      return _center;
    }

    // Rule 4: Prefer corners
    final availableCorners = _corners.where((c) => board[c] == null).toList();
    if (availableCorners.isNotEmpty) {
      return availableCorners[rng.nextInt(availableCorners.length)];
    }

    // Rule 5: Prefer sides / remaining
    final availableSides = _sides.where((s) => board[s] == null).toList();
    if (availableSides.isNotEmpty) {
      return availableSides[rng.nextInt(availableSides.length)];
    }

    return legalMoves[rng.nextInt(legalMoves.length)];
  }

  // ---------------------------------------------------------------------------
  // HARD DIFFICULTY (MINIMAX)
  // ---------------------------------------------------------------------------
  // Evaluates all future board states:
  // - Maximizing player is 'O' (+10 - depth)
  // - Minimizing player is 'X' (-10 + depth)
  // - Draw is 0
  // Never loses when a draw or win is available.
  static int _getHardMove(List<String?> board, List<int> legalMoves) {
    int bestMove = legalMoves.first;
    int bestScore = -10000;

    // Create a mutable copy of the board to simulate moves
    final boardCopy = List<String?>.from(board);

    for (final move in legalMoves) {
      boardCopy[move] = 'O';
      final score = _minimax(boardCopy, 0, false);
      boardCopy[move] = null;

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  static int _minimax(List<String?> board, int depth, bool isMaximizing) {
    final winner = checkWinner(board);
    if (winner == 'O') {
      return 10 - depth;
    } else if (winner == 'X') {
      return depth - 10;
    } else if (!board.contains(null)) {
      return 0; // Draw
    }

    if (isMaximizing) {
      int maxEval = -10000;
      for (int i = 0; i < 9; i++) {
        if (board[i] == null) {
          board[i] = 'O';
          final evaluation = _minimax(board, depth + 1, false);
          board[i] = null;
          if (evaluation > maxEval) {
            maxEval = evaluation;
          }
        }
      }
      return maxEval;
    } else {
      int minEval = 10000;
      for (int i = 0; i < 9; i++) {
        if (board[i] == null) {
          board[i] = 'X';
          final evaluation = _minimax(board, depth + 1, true);
          board[i] = null;
          if (evaluation < minEval) {
            minEval = evaluation;
          }
        }
      }
      return minEval;
    }
  }
}
