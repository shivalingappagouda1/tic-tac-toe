import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tic_tac_toe/main.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('Initial UI state test: Dedicated Mode Selection Page with NO board',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Page 1 header
    expect(find.text('GAME MODES'), findsOneWidget);
    expect(find.text('SELECT HOW TO PLAY'), findsOneWidget);

    // All four mode options are present
    expect(find.byKey(const Key('mode_vs_computer')), findsOneWidget);
    expect(find.byKey(const Key('mode_two_players')), findsOneWidget);
    expect(find.byKey(const Key('mode_complete_online')), findsOneWidget);
    expect(find.byKey(const Key('mode_online_with_code')), findsOneWidget);

    // CRITICAL: The gameplay board and game controls MUST NOT appear on the first page
    for (int i = 0; i < 9; i++) {
      expect(find.byKey(Key('cell_$i')), findsNothing);
    }
    expect(find.text('Player X to move'), findsNothing);
    expect(find.text('PLACE 3 IN A ROW!'), findsNothing);
    expect(find.byKey(const Key('new_game_button')), findsNothing);
    expect(find.byKey(const Key('reset_scores_button')), findsNothing);
  });

  testWidgets('1 VS 1 flow: navigates to Gameplay page, alternates turns and prevents overwrite',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Tap 1 VS 1 mode
    await tester.tap(find.byKey(const Key('mode_two_players')));
    await tester.pumpAndSettle();

    // Now in Gameplay Page
    expect(find.text('Player X to move'), findsOneWidget);
    expect(find.text('PLACE 3 IN A ROW!'), findsOneWidget);
    for (int i = 0; i < 9; i++) {
      expect(find.byKey(Key('cell_$i')), findsOneWidget);
    }

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

  testWidgets('1 VS 1 flow: detects horizontal win and updates score',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    await tester.tap(find.byKey(const Key('mode_two_players')));
    await tester.pumpAndSettle();

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

  testWidgets('1 VS 1 flow: detects draw game and updates draw count',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    await tester.tap(find.byKey(const Key('mode_two_players')));
    await tester.pumpAndSettle();

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

  testWidgets('Reset button clears scores and board on Gameplay page',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    await tester.tap(find.byKey(const Key('mode_two_players')));
    await tester.pumpAndSettle();

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

    // Initially unmuted on Mode Selection page
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

  testWidgets('Renders winning line beam when a player wins',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    await tester.tap(find.byKey(const Key('mode_two_players')));
    await tester.pumpAndSettle();

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

  testWidgets('Simulates complete multi-round game: X win, O win, and Draw',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    await tester.tap(find.byKey(const Key('mode_two_players')));
    await tester.pumpAndSettle();

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

  testWidgets('Header layout guarantees zero overlap between title and controls on Gameplay page',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    await tester.tap(find.byKey(const Key('mode_two_players')));
    await tester.pumpAndSettle();

    final titleFinder = find.text('Player X to move');
    final soundButtonFinder = find.byKey(const Key('sound_button'));
    expect(titleFinder, findsOneWidget);
    expect(soundButtonFinder, findsOneWidget);

    final titleRect = tester.getRect(titleFinder);
    final buttonRect = tester.getRect(soundButtonFinder);

    expect(titleRect.right <= buttonRect.left, isTrue,
        reason: 'Title text must not overlap or touch controls');
  });

  testWidgets('Vs Computer flow: Mode Selection -> Setup -> Difficulty Selection -> Start -> AI moves',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    // Step 1: Mode Selection
    expect(find.byKey(const Key('mode_vs_computer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mode_vs_computer')));
    await tester.pumpAndSettle();

    // Step 2: Computer Setup Page (NO board here!)
    expect(find.text('VS COMPUTER'), findsOneWidget);
    expect(find.byKey(const Key('difficulty_easy')), findsOneWidget);
    expect(find.byKey(const Key('difficulty_medium')), findsOneWidget);
    expect(find.byKey(const Key('difficulty_hard')), findsOneWidget);
    expect(find.byKey(const Key('btn_start_game')), findsOneWidget);
    for (int i = 0; i < 9; i++) {
      expect(find.byKey(Key('cell_$i')), findsNothing);
    }

    // Select Easy difficulty
    await tester.tap(find.byKey(const Key('difficulty_easy')));
    await tester.pumpAndSettle();

    // Start game
    await tester.tap(find.byKey(const Key('btn_start_game')));
    await tester.pumpAndSettle();

    // Step 3: Gameplay Page (Board is now visible!)
    expect(find.text('Your Turn'), findsOneWidget);
    expect(find.byKey(const Key('cell_0')), findsOneWidget);

    // Human taps cell 0
    await tester.tap(find.byKey(const Key('cell_0')));
    await tester.pump();

    expect(find.text('Computer Thinking...'), findsOneWidget);
    expect(find.byType(PieceXWidget), findsOneWidget);

    // Attempt to tap cell 1 while computer thinking (ignored)
    await tester.tap(find.byKey(const Key('cell_1')));
    await tester.pump();
    expect(find.text('Computer Thinking...'), findsOneWidget);

    // Fast-forward delay (400ms) for computer to make move
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(PieceOWidget), findsOneWidget);
    expect(find.text('Your Turn'), findsOneWidget);
  });

  testWidgets('Back navigation: Computer Setup back returns to Mode Selection',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    await tester.tap(find.byKey(const Key('mode_vs_computer')));
    await tester.pumpAndSettle();

    expect(find.text('VS COMPUTER'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byKey(const Key('btn_back_to_modes')));
    await tester.pumpAndSettle();

    // Returned to Mode Selection
    expect(find.text('GAME MODES'), findsOneWidget);
    expect(find.byKey(const Key('mode_vs_computer')), findsOneWidget);
  });

  testWidgets('Back navigation: Gameplay page back returns to Mode Selection',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TicTacToeApp());

    await tester.tap(find.byKey(const Key('mode_two_players')));
    await tester.pumpAndSettle();

    expect(find.text('Player X to move'), findsOneWidget);

    // Tap back button on Gameplay page
    await tester.tap(find.byKey(const Key('btn_back_to_menu')));
    await tester.pumpAndSettle();

    // Returned to Mode Selection
    expect(find.text('GAME MODES'), findsOneWidget);
    expect(find.byKey(const Key('mode_two_players')), findsOneWidget);
  });
}
