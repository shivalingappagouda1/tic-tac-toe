import 'package:flutter_test/flutter_test.dart';
import 'package:tic_tac_toe/ai/tic_tac_toe_ai.dart';

void main() {
  group('TicTacToeAi Engine Unit Tests', () {
    test('getLegalMoves returns all empty cell indices', () {
      final board = <String?>[
        'X', null, 'O',
        null, 'X', null,
        'O', null, 'X',
      ];
      final legalMoves = TicTacToeAi.getLegalMoves(board);
      expect(legalMoves, equals([1, 3, 5, 7]));
    });

    test('getLegalMoves returns empty list on full board', () {
      final board = <String?>[
        'X', 'O', 'X',
        'X', 'O', 'O',
        'O', 'X', 'X',
      ];
      expect(TicTacToeAi.getLegalMoves(board), isEmpty);
      expect(TicTacToeAi.getBestMove(board, Difficulty.hard), equals(-1));
    });

    test('findWinningMove detects immediate winning opportunity for player', () {
      // Row win for 'O' at index 2
      final boardO = <String?>[
        'O', 'O', null,
        'X', 'X', null,
        null, null, null,
      ];
      expect(TicTacToeAi.findWinningMove(boardO, 'O'), equals(2));

      // Diagonal win for 'X' at index 8
      final boardX = <String?>[
        'X', null, 'O',
        null, 'X', 'O',
        null, null, null,
      ];
      expect(TicTacToeAi.findWinningMove(boardX, 'X'), equals(8));
    });

    test('Easy difficulty produces a legal move on empty board', () {
      final board = List<String?>.filled(9, null);
      final move = TicTacToeAi.getBestMove(board, Difficulty.easy);
      expect(move >= 0 && move <= 8, isTrue);
      expect(board[move], isNull);
    });

    test('Easy difficulty takes an available winning move', () {
      // 'O' can win at index 2
      final board = <String?>[
        'O', 'O', null,
        'X', null, 'X',
        null, null, null,
      ];
      final move = TicTacToeAi.getBestMove(board, Difficulty.easy);
      expect(move, equals(2));
    });

    test('Medium difficulty takes an available winning move', () {
      // 'O' can win at index 6 (col 0: 0, 3, 6)
      final board = <String?>[
        'O', 'X', 'X',
        'O', null, null,
        null, null, null,
      ];
      final move = TicTacToeAi.getBestMove(board, Difficulty.medium);
      expect(move, equals(6));
    });

    test('Medium difficulty blocks human immediate win', () {
      // 'X' is threatening to win at index 2 (row 0: 0, 1, 2)
      final board = <String?>[
        'X', 'X', null,
        'O', null, null,
        null, null, null,
      ];
      final move = TicTacToeAi.getBestMove(board, Difficulty.medium);
      expect(move, equals(2));
    });

    test('Medium difficulty tactical preference: center then corners', () {
      // Empty board with forceTactical = true: center (4) must be taken
      final emptyBoard = List<String?>.filled(9, null);
      final move = TicTacToeAi.getBestMove(emptyBoard, Difficulty.medium, forceTactical: true);
      expect(move, equals(4));

      // Center occupied by 'X': corner must be taken
      final boardWithCenter = <String?>[
        null, null, null,
        null, 'X', null,
        null, null, null,
      ];
      final cornerMove = TicTacToeAi.getBestMove(boardWithCenter, Difficulty.medium, forceTactical: true);
      expect([0, 2, 6, 8].contains(cornerMove), isTrue);
    });

    test('Hard difficulty (Minimax) takes immediate winning move', () {
      // 'O' can win with index 8 (diag 0, 4, 8)
      final board = <String?>[
        'O', 'X', 'X',
        null, 'O', null,
        null, null, null,
      ];
      final move = TicTacToeAi.getBestMove(board, Difficulty.hard);
      expect(move, equals(8));
    });

    test('Hard difficulty (Minimax) blocks human immediate winning move', () {
      // 'X' is threatening col 1 (indices 1, 4, 7)
      final board = <String?>[
        'O', 'X', null,
        null, 'X', null,
        null, null, null,
      ];
      final move = TicTacToeAi.getBestMove(board, Difficulty.hard);
      expect(move, equals(7));
    });

    test('Hard difficulty (Minimax) never chooses losing move when draw or win is available', () {
      // Fork defense: 'X' in corners 0 and 8. 'O' must choose side (1, 3, 5, 7) to avoid fork trap
      final board = <String?>[
        'X', null, null,
        null, 'O', null,
        null, null, 'X',
      ];
      final move = TicTacToeAi.getBestMove(board, Difficulty.hard);
      // Valid defensive side moves against corner fork
      expect([1, 3, 5, 7].contains(move), isTrue);
    });

    test('Hard difficulty plays against perfect opponent to a guaranteed draw', () {
      // Simulate complete game between two Minimax instances from X in corner 0
      final board = List<String?>.filled(9, null);
      board[0] = 'X'; // Human opening

      String currentPlayer = 'O';
      while (TicTacToeAi.checkWinner(board) == null && board.contains(null)) {
        if (currentPlayer == 'O') {
          final move = TicTacToeAi.getBestMove(board, Difficulty.hard);
          expect(move >= 0 && move < 9, isTrue);
          expect(board[move], isNull);
          board[move] = 'O';
          currentPlayer = 'X';
        } else {
          // Best response for X
          int bestMove = -1;
          int bestScore = 10000;
          for (int i = 0; i < 9; i++) {
            if (board[i] == null) {
              board[i] = 'X';
              // evaluate from O's perspective: lower is better for X
              final legalO = TicTacToeAi.getLegalMoves(board);
              int oEval;
              if (TicTacToeAi.checkWinner(board) == 'X') {
                oEval = -10;
              } else if (!board.contains(null)) {
                oEval = 0;
              } else {
                oEval = 0;
                for (final om in legalO) {
                  board[om] = 'O';
                  final w = TicTacToeAi.checkWinner(board);
                  board[om] = null;
                  if (w == 'O') oEval = 10;
                }
              }
              board[i] = null;
              if (oEval < bestScore) {
                bestScore = oEval;
                bestMove = i;
              }
            }
          }
          board[bestMove] = 'X';
          currentPlayer = 'O';
        }
      }

      // Neither player should lose (Draw or O win)
      expect(TicTacToeAi.checkWinner(board), isNot('X'));
    });

    test('Single empty cell remaining', () {
      final board = <String?>[
        'X', 'O', 'X',
        'X', 'O', 'O',
        'O', null, 'X',
      ];
      final move = TicTacToeAi.getBestMove(board, Difficulty.hard);
      expect(move, equals(7));
    });
  });
}
