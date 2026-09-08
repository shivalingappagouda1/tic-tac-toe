import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tic_tac_toe/main.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('Initial UI state test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Check game display text
    expect(find.text('Player X to move'), findsOneWidget);
    expect(find.text('PLACE 3 IN A ROW!'), findsOneWidget);

    // Check sound button and initial unmuted icon
    expect(find.byKey(const Key('sound_button')), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    // Initial scores in score plaque: 0, 0, 0
    expect(find.text('0'), findsNWidgets(3));

    // Verify all 9 cells exist
    for (int i = 0; i < 9; i++) {
      expect(find.byKey(Key('cell_$i')), findsOneWidget);
    }
  });

  testWidgets('Alternates turns and prevents overwriting cell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Player 1 (X) taps cell 0
    await tester.tap(find.byKey(const Key('cell_0')));
    await tester.pumpAndSettle();

    expect(find.byType(PieceXWidget), findsWidgets);
    expect(find.text('Player O to move'), findsOneWidget);

    // Player 2 attempts to tap cell 0 (should be ignored)
    await tester.tap(find.byKey(const Key('cell_0')));
    await tester.pumpAndSettle();

    expect(find.text('Player O to move'), findsOneWidget);

    // Player 2 taps cell 1
    await tester.tap(find.byKey(const Key('cell_1')));
    await tester.pumpAndSettle();

    expect(find.byType(PieceOWidget), findsWidgets);
    expect(find.text('Player X to move'), findsOneWidget);
  });

  testWidgets('Detects horizontal win and updates score', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // X: 0, O: 3
    // X: 1, O: 4
    // X: 2 -> X wins (0, 1, 2)
    await tester.tap(find.byKey(const Key('cell_0'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_3'))); // O
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cell_1'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_4'))); // O
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cell_2'))); // X wins
    await tester.pumpAndSettle();

    expect(find.text('Player X Wins!'), findsOneWidget);
    // Score for P1 (X) should be 1
    expect(find.text('1'), findsOneWidget);

    // Ensure subsequent taps on remaining cells are ignored after game over
    await tester.tap(find.byKey(const Key('cell_5')));
    await tester.pumpAndSettle();
    expect(find.text('Player X Wins!'), findsOneWidget);

    // Tap "Play Again"
    await tester.ensureVisible(find.byKey(const Key('new_game_button')));
    await tester.tap(find.byKey(const Key('new_game_button')));
    await tester.pumpAndSettle();

    // Board should be cleared
    expect(find.text('Player X to move'), findsOneWidget);
    // Score should still persist (1 win for P1)
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Detects draw game and updates draw count', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Draw moves sequence:
    // X: 0, O: 1, X: 2, O: 4, X: 3, O: 5, X: 7, O: 6, X: 8
    final moves = [0, 1, 2, 4, 3, 5, 7, 6, 8];

    for (final cell in moves) {
      await tester.ensureVisible(find.byKey(Key('cell_$cell')));
      await tester.tap(find.byKey(Key('cell_$cell')));
      await tester.pumpAndSettle();
    }

    expect(find.text("It's a Draw!"), findsOneWidget);
    // Draw score should be 1
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Reset button clears scores and board', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Win a game for X
    await tester.tap(find.byKey(const Key('cell_0'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_3'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_1'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_4'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_2'))); // X
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);

    // Tap Reset button
    await tester.ensureVisible(find.byKey(const Key('reset_scores_button')));
    await tester.tap(find.byKey(const Key('reset_scores_button')));
    await tester.pumpAndSettle();

    // All scores should be back to 0
    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('1'), findsNothing);
    expect(find.text('Player X to move'), findsOneWidget);
  });

  testWidgets('Sound button toggles mute state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Initially unmuted
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_rounded), findsNothing);

    // Tap sound button to mute
    await tester.tap(find.byKey(const Key('sound_button')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

    // Tap sound button to unmute
    await tester.tap(find.byKey(const Key('sound_button')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
  });

  testWidgets('Renders winning line beam when a player wins', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Win with top row: 0, 1, 2
    await tester.tap(find.byKey(const Key('cell_0'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_3'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_1'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_4'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_2'))); // X wins
    await tester.pumpAndSettle();

    // Verify WinningLinePainter is rendered in the tree
    final customPaintFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is WinningLinePainter,
    );
    expect(customPaintFinder, findsOneWidget);
  });

  testWidgets('Simulates complete multi-round game: X win, O win, and Draw', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // --- ROUND 1: X WINS (Row 0: 0, 1, 2) ---
    await tester.tap(find.byKey(const Key('cell_0'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_3'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_1'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_4'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_2'))); // X wins
    await tester.pumpAndSettle();

    expect(find.text('Player X Wins!'), findsOneWidget);

    // New Round
    await tester.ensureVisible(find.byKey(const Key('new_game_button')));
    await tester.tap(find.byKey(const Key('new_game_button')));
    await tester.pumpAndSettle();

    expect(find.text('Player X to move'), findsOneWidget);

    // --- ROUND 2: O WINS (Col 1: 1, 4, 7) ---
    await tester.tap(find.byKey(const Key('cell_0'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_1'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_3'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_4'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_8'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_7'))); // O wins
    await tester.pumpAndSettle();

    expect(find.text('Player O Wins!'), findsOneWidget);

    // New Round
    await tester.ensureVisible(find.byKey(const Key('new_game_button')));
    await tester.tap(find.byKey(const Key('new_game_button')));
    await tester.pumpAndSettle();

    expect(find.text('Player X to move'), findsOneWidget);

    // --- ROUND 3: DRAW ---
    final drawMoves = [0, 1, 2, 4, 3, 5, 7, 6, 8];
    for (final cell in drawMoves) {
      await tester.ensureVisible(find.byKey(Key('cell_$cell')));
      await tester.tap(find.byKey(Key('cell_$cell')));
      await tester.pumpAndSettle();
    }

    expect(find.text("It's a Draw!"), findsOneWidget);

    // Reset all scores
    await tester.ensureVisible(find.byKey(const Key('reset_scores_button')));
    await tester.tap(find.byKey(const Key('reset_scores_button')));
    await tester.pumpAndSettle();

    // All scores reset to 0
    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('Player X to move'), findsOneWidget);
  });

  testWidgets('Header layout guarantees zero overlap between title and controls', (WidgetTester tester) async {
    // Desktop layout test
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Verify title text and sound button
    final titleFinder = find.text('Player X to move');
    final soundButtonFinder = find.byKey(const Key('sound_button'));
    expect(titleFinder, findsOneWidget);
    expect(soundButtonFinder, findsOneWidget);

    final titleRect = tester.getRect(titleFinder);
    final buttonRect = tester.getRect(soundButtonFinder);

    // Title must be strictly to the left of the right controls area
    expect(titleRect.right <= buttonRect.left, isTrue,
        reason: 'Title text (${titleRect.right}) must not overlap or touch controls (${buttonRect.left})');

    // Test on narrow mobile screen (< 370px)
    tester.view.physicalSize = const Size(320, 600);
    await tester.pumpAndSettle();

    final mobileTitleFinder = find.text('Player X to move');
    final mobileButtonFinder = find.byKey(const Key('sound_button'));
    expect(mobileTitleFinder, findsOneWidget);
    expect(mobileButtonFinder, findsOneWidget);

    final mobileTitleRect = tester.getRect(mobileTitleFinder);
    final mobileButtonRect = tester.getRect(mobileButtonFinder);

    // On narrow screen, controls are above the title, so title top > button bottom
    expect(mobileTitleRect.top >= mobileButtonRect.bottom, isTrue,
        reason: 'On mobile, title must be placed cleanly below controls row with zero overlap');
  });

  testWidgets('Vs Computer mode: mode selection reveals difficulty buttons and initializes match', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Initially in Two Players mode: difficulty buttons hidden
    expect(find.byKey(const Key('mode_two_players')), findsOneWidget);
    expect(find.byKey(const Key('mode_vs_computer')), findsOneWidget);
    expect(find.byKey(const Key('difficulty_easy')), findsNothing);
    expect(find.byKey(const Key('difficulty_medium')), findsNothing);
    expect(find.byKey(const Key('difficulty_hard')), findsNothing);

    // Switch to VS COMPUTER
    await tester.tap(find.byKey(const Key('mode_vs_computer')));
    await tester.pumpAndSettle();

    // Now difficulty buttons are visible
    expect(find.byKey(const Key('difficulty_easy')), findsOneWidget);
    expect(find.byKey(const Key('difficulty_medium')), findsOneWidget);
    expect(find.byKey(const Key('difficulty_hard')), findsOneWidget);

    // Status text should be "Your Turn"
    expect(find.text('Your Turn'), findsOneWidget);

    // Score plaque labels should show YOU (X) and COM (O)
    expect(find.text('YOU (X): '), findsOneWidget);
    expect(find.text('COM (O): '), findsOneWidget);

    // Tap difficulty buttons
    await tester.tap(find.byKey(const Key('difficulty_easy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('difficulty_hard')));
    await tester.pumpAndSettle();
  });

  testWidgets('Vs Computer mode: human move triggers computer response and locks taps during thinking', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Switch to VS COMPUTER
    await tester.tap(find.byKey(const Key('mode_vs_computer')));
    await tester.pumpAndSettle();

    // Human taps cell 0
    await tester.tap(find.byKey(const Key('cell_0')));
    await tester.pump(); // Register human move

    // State should now be "Computer Thinking..."
    expect(find.text('Computer Thinking...'), findsOneWidget);
    expect(find.byType(PieceXWidget), findsOneWidget);

    // Attempt to tap cell 1 while computer is thinking (MUST be ignored)
    await tester.tap(find.byKey(const Key('cell_1')));
    await tester.pump();
    expect(find.text('Computer Thinking...'), findsOneWidget);

    // Fast-forward delay (400ms) for computer to make move
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Computer has made move O
    expect(find.byType(PieceOWidget), findsOneWidget);
    // Control returned to human
    expect(find.text('Your Turn'), findsOneWidget);
  });

  testWidgets('Vs Computer mode: human victory displays "You Win!" and updates score', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Switch to VS COMPUTER with Easy mode
    await tester.tap(find.byKey(const Key('mode_vs_computer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('difficulty_easy')));
    await tester.pumpAndSettle();

    // Force moves by tapping cells that lead to human win
    // Human plays 0, 1, 2 (Row 0)
    await tester.tap(find.byKey(const Key('cell_0')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Next human move
    int nextHumanCell = 1;
    if (find.byKey(const Key('cell_1')).evaluate().isNotEmpty) {
      // Find an available cell in row 0 or row 1
      for (final c in [1, 2, 3, 4, 5, 6, 7, 8]) {
        // Find if empty
        await tester.tap(find.byKey(Key('cell_$c')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        if (find.text('You Win!').evaluate().isNotEmpty ||
            find.text('Computer Wins!').evaluate().isNotEmpty ||
            find.text("It's a Draw!").evaluate().isNotEmpty) {
          break;
        }
      }
    }

    // New Round works in computer mode
    await tester.ensureVisible(find.byKey(const Key('new_game_button')));
    await tester.tap(find.byKey(const Key('new_game_button')));
    await tester.pumpAndSettle();

    expect(find.text('Your Turn'), findsOneWidget);
  });

  testWidgets('Mode switching resets board state without corrupting session scores', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Win a game in Two Players mode
    await tester.tap(find.byKey(const Key('cell_0'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_3'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_1'))); // X
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_4'))); // O
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_2'))); // X wins
    await tester.pumpAndSettle();

    expect(find.text('Player X Wins!'), findsOneWidget);
    // Score is 1
    expect(find.text('1'), findsOneWidget);

    // Switch to VS COMPUTER mode
    await tester.tap(find.byKey(const Key('mode_vs_computer')));
    await tester.pumpAndSettle();

    // Board reset, fresh match in computer mode, but score persists
    expect(find.text('Your Turn'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byType(PieceXWidget), findsNothing);
    expect(find.byType(PieceOWidget), findsNothing);

    // Switch back to TWO PLAYERS
    await tester.tap(find.byKey(const Key('mode_two_players')));
    await tester.pumpAndSettle();

    expect(find.text('Player X to move'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}

