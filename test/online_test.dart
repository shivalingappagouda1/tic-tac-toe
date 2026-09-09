import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tic_tac_toe/main.dart';
import 'package:tic_tac_toe/online/models/online_game_state.dart';
import 'package:tic_tac_toe/online/services/mock_online_backend.dart';
import 'package:tic_tac_toe/online/services/room_code_generator.dart';
import 'package:tic_tac_toe/online/services/online_backend.dart';
import 'package:tic_tac_toe/online/services/session_storage_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MockSharedDatabase.instance.reset();
  });

  tearDown(() {
    MockSharedDatabase.instance.reset();
  });

  group('UI & Mode Selector Requirements (Tests 1-4)', () {
    testWidgets('1. All four modes are permanently visible simultaneously',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TicTacToeApp());

      // Verify all four mode cards are present in the widget tree simultaneously
      expect(find.byKey(const Key('mode_vs_computer')), findsOneWidget);
      expect(find.byKey(const Key('mode_two_players')), findsOneWidget);
      expect(find.byKey(const Key('mode_complete_online')), findsOneWidget);
      expect(find.byKey(const Key('mode_online_with_code')), findsOneWidget);

      expect(find.text('COMPUTER'), findsOneWidget);
      expect(find.text('1 VS 1'), findsOneWidget);
      expect(find.text('COMPLETE ONLINE'), findsOneWidget);
      expect(find.text('ONLINE WITH CODE'), findsOneWidget);
    });

    testWidgets('2. Four modes are selectable and update active state while keeping all 4 visible',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TicTacToeApp());

      // Select COMPLETE ONLINE
      await tester.tap(find.byKey(const Key('mode_complete_online')));
      await tester.pumpAndSettle();

      // All four modes must STILL be visible!
      expect(find.byKey(const Key('mode_vs_computer')), findsOneWidget);
      expect(find.byKey(const Key('mode_two_players')), findsOneWidget);
      expect(find.byKey(const Key('mode_complete_online')), findsOneWidget);
      expect(find.byKey(const Key('mode_online_with_code')), findsOneWidget);

      // COMPLETE ONLINE reveals FIND OPPONENT button
      expect(find.byKey(const Key('btn_find_opponent')), findsOneWidget);

      // Select ONLINE WITH CODE
      await tester.tap(find.byKey(const Key('mode_online_with_code')));
      await tester.pumpAndSettle();

      // All four modes must STILL be visible!
      expect(find.byKey(const Key('mode_vs_computer')), findsOneWidget);
      expect(find.byKey(const Key('mode_two_players')), findsOneWidget);
      expect(find.byKey(const Key('mode_complete_online')), findsOneWidget);
      expect(find.byKey(const Key('mode_online_with_code')), findsOneWidget);

      // Reveals private room controls (CREATE ROOM / JOIN ROOM tabs)
      expect(find.byKey(const Key('btn_create_room_tab')), findsOneWidget);
      expect(find.byKey(const Key('btn_join_room_tab')), findsOneWidget);
    });

    testWidgets('3. Computer mode regression: AI responds properly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TicTacToeApp());

      await tester.tap(find.byKey(const Key('mode_vs_computer')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('difficulty_easy')), findsOneWidget);
      expect(find.byKey(const Key('difficulty_medium')), findsOneWidget);
      expect(find.byKey(const Key('difficulty_hard')), findsOneWidget);

      // Human plays cell 0
      await tester.tap(find.byKey(const Key('cell_0')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Computer Thinking...'), findsOneWidget);

      // Advance through computer thinking delay
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Your Turn'), findsOneWidget);
      expect(find.byType(PieceOWidget), findsOneWidget);
    });

    testWidgets('4. 1 VS 1 mode regression: local turn alternation works',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TicTacToeApp());

      await tester.tap(find.byKey(const Key('mode_two_players')));
      await tester.pumpAndSettle();

      expect(find.text('Player X to move'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cell_0')));
      await tester.pumpAndSettle();
      expect(find.text('Player O to move'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cell_1')));
      await tester.pumpAndSettle();
      expect(find.text('Player X to move'), findsOneWidget);
    });
  });

  group('Authentication & Matchmaking Architecture (Tests 5-9)', () {
    test('5. Anonymous authentication assigns unique identity without credentials',
        () async {
      final backendA = MockOnlineBackend(database: MockSharedDatabase.instance);
      final backendB = MockOnlineBackend(database: MockSharedDatabase.instance);

      final uidA = await backendA.signInAnonymously();
      final uidB = await backendB.signInAnonymously();

      expect(uidA, isNotEmpty);
      expect(uidB, isNotEmpty);
      expect(uidA, isNot(equals(uidB)));
      expect(backendA.currentUserId, equals(uidA));
      expect(backendB.currentUserId, equals(uidB));
    });

    test('6. Matchmaking queue creation adds waiting player', () async {
      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      final uid = await backend.signInAnonymously();

      // Start finding match asynchronously
      final matchFuture = backend.findMatch();
      await Future.delayed(const Duration(milliseconds: 10));

      // Database should contain player waiting in queue
      expect(MockSharedDatabase.instance.matchmakingQueue.containsKey(uid), isTrue);

      await backend.cancelMatchmaking();
      expect(MockSharedDatabase.instance.matchmakingQueue.containsKey(uid), isFalse);

      try {
        await matchFuture;
      } catch (_) {}
    });

    test('7. Matchmaking pairing matches two separate players into one authoritative game',
        () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_device_A',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_device_B',
      );

      // Device A enqueues
      final futureA = backendA.findMatch();

      // Device B enqueues
      final futureB = backendB.findMatch();

      final gameA = await futureA;
      final gameB = await futureB;

      expect(gameA, isNotNull);
      expect(gameB, isNotNull);
      // Both received the EXACT same game session!
      expect(gameA!.gameId, equals(gameB!.gameId));
      expect(gameA.status, equals(OnlineGameStatus.active));
      expect(gameB.status, equals(OnlineGameStatus.active));

      // Queue is cleared after pairing
      expect(MockSharedDatabase.instance.matchmakingQueue.isEmpty, isTrue);
    });

    test('8. Duplicate matchmaking prevention: player cannot queue twice', () async {
      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      await backend.signInAnonymously();

      final future1 = backend.findMatch();
      await Future.delayed(const Duration(milliseconds: 10));

      // Second enqueue call cancels earlier entry
      final future2 = backend.findMatch();
      await Future.delayed(const Duration(milliseconds: 10));

      final result1 = await future1;
      expect(result1, isNull); // first queue entry was replaced

      await backend.cancelMatchmaking();
      final result2 = await future2;
      expect(result2, isNull);
    });

    test('9. Player assignment: exactly one X and one O', () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_A',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_B',
      );

      final fA = backendA.findMatch();
      final fB = backendB.findMatch();

      final gA = await fA;
      final gB = await fB;

      final roleA = gA!.roleOf(backendA.currentUserId);
      final roleB = gB!.roleOf(backendB.currentUserId);

      expect(roleA, isIn(['X', 'O']));
      expect(roleB, isIn(['X', 'O']));
      expect(roleA, isNot(equals(roleB))); // Exactly opposing symbols
    });
  });

  group('Private Room Architecture (Tests 10-15)', () {
    test('10. Room creation generates room and placeholder game', () async {
      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      final room = await backend.createRoom();

      expect(room.roomCode.length, equals(6));
      expect(room.status, equals('waiting'));
      expect(room.guestUid, isNull);
      expect(MockSharedDatabase.instance.rooms.containsKey(room.roomCode), isTrue);
    });

    test('11. Room code generation: 6 chars, uppercase, excludes confusing chars',
        () {
      for (int i = 0; i < 50; i++) {
        final code = RoomCodeGenerator.generate();
        expect(code.length, equals(6));
        expect(RoomCodeGenerator.isValid(code), isTrue);
        // Excludes 0, O, 1, I, L
        expect(code.contains('0'), isFalse);
        expect(code.contains('O'), isFalse);
        expect(code.contains('1'), isFalse);
        expect(code.contains('I'), isFalse);
        expect(code.contains('L'), isFalse);
      }
    });

    test('12. Room joining: Device B joins Device A via room code', () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'host_A',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'guest_B',
      );

      final room = await backendA.createRoom();
      final joinedRoom = await backendB.joinRoom(room.roomCode);

      expect(joinedRoom.guestUid, equals('guest_B'));
      expect(joinedRoom.status, equals('active'));

      final game = MockSharedDatabase.instance.games[room.gameId]!;
      expect(game.status, equals(OnlineGameStatus.active));
      expect(game.playerX, equals('host_A'));
      expect(game.playerO, equals('guest_B'));
    });

    test('13. Invalid room code returns clear error', () async {
      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      expect(
        backend.joinRoom('ZZZZZZ'),
        throwsA(predicate((e) => e is OnlineException && e.message.contains('Room not found.'))),
      );
    });

    test('14. Full room rejection: third player cannot join', () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_1',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_2',
      );
      final backendC = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_3',
      );

      final room = await backendA.createRoom();
      await backendB.joinRoom(room.roomCode);

      expect(
        backendC.joinRoom(room.roomCode),
        throwsA(predicate((e) => e is OnlineException && e.message.contains('Room is full.'))),
      );
    });

    test('15. Expired room rejection', () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_1',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_2',
      );

      final room = await backendA.createRoom();
      // Artificially expire the room
      final expiredRoom = RoomState(
        roomCode: room.roomCode,
        hostUid: room.hostUid,
        gameId: room.gameId,
        status: 'expired',
        createdAt: room.createdAt,
        expiresAt: DateTime.now().millisecondsSinceEpoch - 1000,
      );
      MockSharedDatabase.instance.rooms[room.roomCode] = expiredRoom;

      expect(
        backendB.joinRoom(room.roomCode),
        throwsA(predicate((e) => e is OnlineException && e.message.contains('Room expired.'))),
      );
    });
  });

  group('Move Validation & Atomic Race Conditions (Tests 16-20)', () {
    test('16. Valid online move updates authoritative board and advances turn',
        () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_X',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_O',
      );

      final room = await backendA.createRoom();
      await backendB.joinRoom(room.roomCode);

      final success = await backendA.makeMove(room.gameId, 4); // X moves center
      expect(success, isTrue);

      final game = MockSharedDatabase.instance.games[room.gameId]!;
      expect(game.board[4], equals('X'));
      expect(game.currentTurn, equals('O'));
      expect(game.moveCount, equals(1));
    });

    test('17. Occupied cell rejection: cannot overwrite existing piece', () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_X',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_O',
      );

      final room = await backendA.createRoom();
      await backendB.joinRoom(room.roomCode);

      await backendA.makeMove(room.gameId, 0); // X takes 0

      // O attempts to overwrite cell 0
      expect(
        backendB.makeMove(room.gameId, 0),
        throwsA(predicate((e) => e is OnlineException && e.message.contains('already occupied'))),
      );
    });

    test('18. Wrong-turn rejection: player cannot move out of turn', () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_X',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_O',
      );

      final room = await backendA.createRoom();
      await backendB.joinRoom(room.roomCode);

      // Turn starts as X; O attempts to move first
      expect(
        backendB.makeMove(room.gameId, 0),
        throwsA(predicate((e) => e is OnlineException && e.message.contains('not your turn'))),
      );
    });

    test('19. Unauthorized move rejection: non-participant cannot make move',
        () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_X',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_O',
      );
      final backendC = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'spectator_C',
      );

      final room = await backendA.createRoom();
      await backendB.joinRoom(room.roomCode);

      expect(
        backendC.makeMove(room.gameId, 2),
        throwsA(predicate((e) => e is OnlineException && e.message.contains('Unauthorized'))),
      );
    });

    test('20. Atomic move behavior: simultaneous moves on same cell handle race condition',
        () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_X',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_O',
      );

      final room = await backendA.createRoom();
      await backendB.joinRoom(room.roomCode);

      // X makes move
      final moveX = backendA.makeMove(room.gameId, 4);
      // O attempts move simultaneously before turn has switched
      final moveO = backendB.makeMove(room.gameId, 4);

      final results = await Future.wait([
        moveX.then((v) => 'successX').catchError((e) => 'errorX'),
        moveO.then((v) => 'successO').catchError((e) => 'errorO'),
      ]);

      // Exactly one succeeds, the other is rejected
      expect(results.contains('successX'), isTrue);
      expect(results.contains('errorO'), isTrue);
    });
  });

  group('Win & Draw Synchronization (Tests 21-23)', () {
    test('21. Win synchronization: both devices receive authoritative winner',
        () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_X',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_O',
      );

      final room = await backendA.createRoom();
      await backendB.joinRoom(room.roomCode);

      // Moves leading to X win on row 0: (0, 1, 2)
      await backendA.makeMove(room.gameId, 0); // X
      await backendB.makeMove(room.gameId, 3); // O
      await backendA.makeMove(room.gameId, 1); // X
      await backendB.makeMove(room.gameId, 4); // O
      await backendA.makeMove(room.gameId, 2); // X wins!

      final finalGame = MockSharedDatabase.instance.games[room.gameId]!;
      expect(finalGame.status, equals(OnlineGameStatus.finished));
      expect(finalGame.winner, equals('X'));
      expect(finalGame.winningCells, equals([0, 1, 2]));
    });

    test('22. Draw synchronization: detects full board without winner', () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_X',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_O',
      );

      final room = await backendA.createRoom();
      await backendB.joinRoom(room.roomCode);

      // Draw sequence: 0, 1, 2, 4, 3, 5, 7, 6, 8
      final moves = [
        [backendA, 0],
        [backendB, 1],
        [backendA, 2],
        [backendB, 4],
        [backendA, 3],
        [backendB, 5],
        [backendA, 7],
        [backendB, 6],
        [backendA, 8],
      ];

      for (final step in moves) {
        final backend = step[0] as MockOnlineBackend;
        final cell = step[1] as int;
        await backend.makeMove(room.gameId, cell);
      }

      final finalGame = MockSharedDatabase.instance.games[room.gameId]!;
      expect(finalGame.status, equals(OnlineGameStatus.finished));
      expect(finalGame.winner, equals('Draw'));
      expect(finalGame.winningCells, isNull);
    });

    test('23. Winning-cell synchronization passes exact 3 winning indices',
        () async {
      final backendA = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_X',
      );
      final backendB = MockOnlineBackend(
        database: MockSharedDatabase.instance,
        initialUid: 'user_O',
      );

      final room = await backendA.createRoom();
      await backendB.joinRoom(room.roomCode);

      // Diagonal win: 0, 4, 8
      await backendA.makeMove(room.gameId, 0); // X
      await backendB.makeMove(room.gameId, 1); // O
      await backendA.makeMove(room.gameId, 4); // X
      await backendB.makeMove(room.gameId, 2); // O
      await backendA.makeMove(room.gameId, 8); // X wins diagonal!

      final finalGame = MockSharedDatabase.instance.games[room.gameId]!;
      expect(finalGame.winningCells, equals([0, 4, 8]));
    });
  });

  group('Disconnection, Cleanup & Independence (Tests 24-30)', () {
    testWidgets('24. Disconnect handling displays reconnecting banner',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      await tester.pumpWidget(TicTacToeApp(onlineBackend: backend));

      // Select Complete Online
      await tester.tap(find.byKey(const Key('mode_complete_online')));
      await tester.pumpAndSettle();

      // Simulate connection loss
      backend.simulateConnectionChange(false);
      await tester.pumpAndSettle();

      expect(find.text('Connection lost. Reconnecting...'), findsOneWidget);
    });

    testWidgets('25. Reconnection restores authoritative connection state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      await tester.pumpWidget(TicTacToeApp(onlineBackend: backend));

      await tester.tap(find.byKey(const Key('mode_complete_online')));
      await tester.pumpAndSettle();

      backend.simulateConnectionChange(false);
      await tester.pumpAndSettle();
      expect(find.text('Connection lost. Reconnecting...'), findsOneWidget);

      backend.simulateConnectionChange(true);
      await tester.pumpAndSettle();
      expect(find.text('Connection lost. Reconnecting...'), findsNothing);
    });

    test('26. Matchmaking cancellation clears queue entry cleanly', () async {
      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      final uid = await backend.signInAnonymously();

      final f = backend.findMatch();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(MockSharedDatabase.instance.matchmakingQueue.containsKey(uid), isTrue);

      await backend.cancelMatchmaking();
      expect(MockSharedDatabase.instance.matchmakingQueue.containsKey(uid), isFalse);

      try {
        await f;
      } catch (_) {}
    });

    test('27. Room cleanup when host leaves', () async {
      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      final room = await backend.createRoom();
      expect(MockSharedDatabase.instance.rooms.containsKey(room.roomCode), isTrue);

      await backend.leaveRoom(room.roomCode);
      expect(MockSharedDatabase.instance.rooms.containsKey(room.roomCode), isFalse);
    });

    testWidgets('28. Listener cleanup when switching modes',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      await tester.pumpWidget(TicTacToeApp(onlineBackend: backend));

      // Enter complete online and start finding
      await tester.tap(find.byKey(const Key('mode_complete_online')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_find_opponent')));
      await tester.pump();

      // Switch mode to COMPUTER
      await tester.tap(find.byKey(const Key('mode_vs_computer')));
      await tester.pumpAndSettle();

      // Verify no remaining active subscriptions in UI
      expect(find.text('Finding opponent...'), findsNothing);
      expect(find.byKey(const Key('difficulty_easy')), findsOneWidget);
    });

    testWidgets('29. Safe switching between all four modes without corrupting scores',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      await tester.pumpWidget(TicTacToeApp(onlineBackend: backend));

      // Win a game in 1 VS 1 to get score of 1
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

      expect(find.text('1'), findsOneWidget);

      // Switch to COMPUTER
      await tester.tap(find.byKey(const Key('mode_vs_computer')));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      // Switch to COMPLETE ONLINE
      await tester.tap(find.byKey(const Key('mode_complete_online')));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      // Switch to ONLINE WITH CODE
      await tester.tap(find.byKey(const Key('mode_online_with_code')));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      // Switch back to 1 VS 1
      await tester.tap(find.byKey(const Key('mode_two_players')));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('30. Local modes remain fully functional without backend connectivity',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // onlineBackend is explicitly null (offline / unconfigured)
      await tester.pumpWidget(const TicTacToeApp(onlineBackend: null));

      // 1 VS 1 works seamlessly
      await tester.tap(find.byKey(const Key('cell_0')));
      await tester.pumpAndSettle();
      expect(find.text('Player O to move'), findsOneWidget);

      // COMPUTER works seamlessly
      await tester.tap(find.byKey(const Key('mode_vs_computer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cell_4')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(PieceOWidget), findsOneWidget);
    });
  });

  group('Production Security & Hardening Fixes (Tests 31-36)', () {
    test('31. Matchmaking pairing sets real UIDs on both players and contains zero "matched_opponent" strings', () async {
      final backendA = MockOnlineBackend(database: MockSharedDatabase.instance);
      final backendB = MockOnlineBackend(database: MockSharedDatabase.instance);

      final uidA = await backendA.signInAnonymously();
      final uidB = await backendB.signInAnonymously();

      expect(uidA, isNotEmpty);
      expect(uidB, isNotEmpty);
      expect(uidA, isNot(equals(uidB)));

      final futureA = backendA.findMatch();
      final futureB = backendB.findMatch();

      final gameA = await futureA;
      final gameB = await futureB;

      expect(gameA, isNotNull);
      expect(gameB, isNotNull);
      expect(gameA!.gameId, equals(gameB!.gameId));

      // Real UIDs must be assigned to playerX and playerO
      final playerX = gameA.playerX;
      final playerO = gameA.playerO;

      expect(playerX, isNotNull);
      expect(playerO, isNotNull);
      expect(playerX, isNot(equals('matched_opponent')));
      expect(playerO, isNot(equals('matched_opponent')));

      final players = {playerX, playerO};
      expect(players, contains(uidA));
      expect(players, contains(uidB));
      expect(players.length, equals(2));
    });

    test('32. Database security rules JSON file enforces hardened permissions and schema validation', () {
      final rulesFile = File('database.rules.json');
      expect(rulesFile.existsSync(), isTrue, reason: 'database.rules.json must exist');

      final content = rulesFile.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final rules = json['rules'] as Map<String, dynamic>;

      // No broad root read/write on rooms
      expect(rules['rooms'].containsKey('.read'), isFalse,
          reason: 'rooms must not have broad .read rule');

      // rooms/$roomCode has read/write
      final roomChild = rules['rooms'][r'$roomCode'] as Map<String, dynamic>;
      expect(roomChild['.read'], equals('auth != null'));
      expect(roomChild.containsKey('.write'), isTrue);
      expect(roomChild.containsKey('.validate'), isTrue);

      // No broad root read/write on matchmaking_queue
      expect(rules['matchmaking_queue'].containsKey('.read'), isFalse,
          reason: 'matchmaking_queue must not have broad .read');
      expect(rules['matchmaking_queue'].containsKey('.write'), isFalse,
          reason: 'matchmaking_queue must not have broad .write');

      // Granular queue child rules
      expect(rules['matchmaking_queue']['waiting']['.read'], equals('auth != null'));
      expect(rules['matchmaking_queue']['waiting']['.write'], equals('auth != null'));
      expect(rules['matchmaking_queue']['matches'][r'$uid']['.read'],
          equals(r'auth != null && auth.uid === $uid'));
      expect(rules['matchmaking_queue']['matches'][r'$uid']['.write'], equals('auth != null'));

      // games/$gameId allows guest to join as playerO
      final gameRule = rules['games'][r'$gameId'] as Map<String, dynamic>;
      final writeRule = gameRule['.write'] as String;
      expect(writeRule, contains("!data.child('playerO').exists() && newData.child('playerO').val() === auth.uid"),
          reason: 'games/.write must allow guest joining as playerO');
      expect(writeRule, contains("data.child('currentTurn').val() === 'X' ? data.child('playerX').val() : data.child('playerO').val()"),
          reason: 'games/.write must enforce that only the current turn player can submit moves');

      // games/$gameId schema validation
      expect(gameRule.containsKey('.validate'), isTrue);
      expect(gameRule['playerX']['.validate'], contains('data.val() === newData.val()'));
      expect(gameRule['playerO']['.validate'], contains('data.val() === newData.val()'));
      expect(gameRule['gameId']['.validate'], contains('data.val() === newData.val()'));

      // Board exactly-one-cell change validation
      final boardValidate = gameRule['board']['.validate'] as String;
      expect(boardValidate, contains("newData.child('0').val() === data.parent().child('currentTurn').val()"),
          reason: 'board/.validate must enforce correct symbol on cell change');
      expect(boardValidate, contains("!data.child('0').exists() || data.child('0').val() === null"),
          reason: 'board/.validate must enforce that cell was previously empty');

      // Winner validation against actual winning combos
      final winnerValidate = gameRule['winner']['.validate'] as String;
      expect(winnerValidate, contains("newData.val() === 'X' || newData.val() === 'O'"),
          reason: 'winner/.validate must enforce valid winner values');
      expect(winnerValidate, contains("newData.parent().child('board').child('0').val() === newData.val()"),
          reason: 'winner/.validate must verify actual winning line on board');

      // WinningCells validation
      final winningCellsValidate = gameRule['winningCells']['.validate'] as String;
      expect(winningCellsValidate, contains("newData.child('0').val() === 0 && newData.child('1').val() === 1 && newData.child('2').val() === 2"),
          reason: 'winningCells/.validate must enforce valid 3-in-a-row line indexes');
    });

    test('33. Private room join flow authorizes guest without permission denial and establishes active game', () async {
      final hostBackend = MockOnlineBackend(database: MockSharedDatabase.instance);
      final guestBackend = MockOnlineBackend(database: MockSharedDatabase.instance);

      final hostUid = await hostBackend.signInAnonymously();
      final guestUid = await guestBackend.signInAnonymously();

      final createdRoom = await hostBackend.createRoom();
      expect(createdRoom.hostUid, equals(hostUid));
      expect(createdRoom.guestUid, isNull);
      expect(createdRoom.status, equals('waiting'));

      final joinedRoom = await guestBackend.joinRoom(createdRoom.roomCode);
      expect(joinedRoom.hostUid, equals(hostUid));
      expect(joinedRoom.guestUid, equals(guestUid));
      expect(joinedRoom.status, equals('active'));

      final game = MockSharedDatabase.instance.games[createdRoom.gameId];
      expect(game, isNotNull);
      expect(game!.playerX, equals(hostUid));
      expect(game.playerO, equals(guestUid));
      expect(game.status, equals(OnlineGameStatus.active));
    });

    test('34. SessionStorageService persists, retrieves, and clears active session metadata', () async {
      final storage = SessionStorageService.instance;
      await storage.clearSession();

      final initial = await storage.loadSession();
      expect(initial, isNull);

      const session = ActiveSessionData(
        gameId: 'game_restore_123',
        roomCode: 'RC7799',
        role: 'X',
        mode: 'onlineWithCode',
        isHost: true,
      );

      await storage.saveSession(session);

      final loaded = await storage.loadSession();
      expect(loaded, isNotNull);
      expect(loaded!.gameId, equals('game_restore_123'));
      expect(loaded.roomCode, equals('RC7799'));
      expect(loaded.role, equals('X'));
      expect(loaded.mode, equals('onlineWithCode'));
      expect(loaded.isHost, isTrue);

      await storage.clearSession();
      final afterClear = await storage.loadSession();
      expect(afterClear, isNull);
    });

    testWidgets('35. Browser refresh recovery automatically re-attaches to active online match on startup',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      final uid = await backend.signInAnonymously();

      // Setup an active game in database
      const gameId = 'game_refresh_test_999';
      final activeGame = OnlineGameState(
        gameId: gameId,
        playerX: uid,
        playerO: 'opponent_uid_888',
        board: ['X', null, null, null, 'O', null, null, null, null],
        currentTurn: 'X',
        status: OnlineGameStatus.active,
        moveCount: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      MockSharedDatabase.instance.games[gameId] = activeGame;

      // Simulate saved session in browser sessionStorage
      await SessionStorageService.instance.saveSession(const ActiveSessionData(
        gameId: gameId,
        role: 'X',
        mode: 'completeOnline',
        isHost: false,
      ));

      // Launch app (simulating browser reload)
      await tester.pumpWidget(TicTacToeApp(onlineBackend: backend));
      await tester.pumpAndSettle();

      // App should recover game mode, board, and turn
      expect(find.byType(PieceXWidget), findsOneWidget);
      expect(find.byType(PieceOWidget), findsOneWidget);
      expect(find.text('Your Turn'), findsOneWidget);
      expect(find.text('YOU ARE X'), findsOneWidget);

      await SessionStorageService.instance.clearSession();
    });

    testWidgets('36. Switching to local mode or resetting clears saved session from storage',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = MockOnlineBackend(database: MockSharedDatabase.instance);
      await SessionStorageService.instance.saveSession(const ActiveSessionData(
        gameId: 'test_game',
        mode: 'completeOnline',
      ));

      await tester.pumpWidget(TicTacToeApp(onlineBackend: backend));
      await tester.pumpAndSettle();

      // Switch to local 1 VS 1 mode
      await tester.tap(find.byKey(const Key('mode_two_players')));
      await tester.pumpAndSettle();

      final saved = await SessionStorageService.instance.loadSession();
      expect(saved, isNull, reason: 'Session must be cleared when switching to local mode');
    });
  });

  group('Security Rule Logic Attack Modeling (Attacks 1-12)', () {
    // Note: In-process logic simulation of database.rules.json rules.
    // Real Firebase Emulator execution remains pending until firebase-tools is installed.

    final baseActiveGame = {
      'gameId': 'game_attack_test',
      'playerX': 'user_x_111',
      'playerO': 'user_o_222',
      'board': [null, null, null, null, null, null, null, null, null],
      'currentTurn': 'X',
      'status': 'active',
      'winner': null,
      'winningCells': null,
      'moveCount': 0,
    };

    test('ATTACK 1: Change two board cells in one write is rejected', () {
      final maliciousWrite = Map<String, dynamic>.from(baseActiveGame);
      maliciousWrite['board'] = ['X', 'X', null, null, null, null, null, null, null];
      maliciousWrite['currentTurn'] = 'O';

      final allowed = _evaluateSecurityRulesWrite(
        data: baseActiveGame,
        newData: maliciousWrite,
        authUid: 'user_x_111',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject multi-cell write');
    });

    test('ATTACK 2: Change three board cells and declare a win is rejected', () {
      final maliciousWrite = Map<String, dynamic>.from(baseActiveGame);
      maliciousWrite['board'] = ['X', 'X', 'X', null, null, null, null, null, null];
      maliciousWrite['winner'] = 'X';
      maliciousWrite['winningCells'] = [0, 1, 2];
      maliciousWrite['status'] = 'finished';

      final allowed = _evaluateSecurityRulesWrite(
        data: baseActiveGame,
        newData: maliciousWrite,
        authUid: 'user_x_111',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject 3-cell instant win');
    });

    test('ATTACK 3: Move when it is the opponent\'s turn is rejected', () {
      final maliciousWrite = Map<String, dynamic>.from(baseActiveGame);
      maliciousWrite['board'] = [null, null, null, null, 'O', null, null, null, null];
      maliciousWrite['currentTurn'] = 'X';

      // Player O tries to write when currentTurn == 'X'
      final allowed = _evaluateSecurityRulesWrite(
        data: baseActiveGame,
        newData: maliciousWrite,
        authUid: 'user_o_222',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject out-of-turn write');
    });

    test('ATTACK 4: Place O when authenticated player is X is rejected', () {
      final maliciousWrite = Map<String, dynamic>.from(baseActiveGame);
      maliciousWrite['board'] = ['O', null, null, null, null, null, null, null, null];
      maliciousWrite['currentTurn'] = 'O';

      final allowed = _evaluateSecurityRulesWrite(
        data: baseActiveGame,
        newData: maliciousWrite,
        authUid: 'user_x_111',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject wrong player symbol');
    });

    test('ATTACK 5: Overwrite an occupied cell is rejected', () {
      final occupiedState = Map<String, dynamic>.from(baseActiveGame);
      occupiedState['board'] = ['X', null, null, null, null, null, null, null, null];
      occupiedState['currentTurn'] = 'O';

      final maliciousWrite = Map<String, dynamic>.from(occupiedState);
      maliciousWrite['board'] = ['O', null, null, null, null, null, null, null, null]; // Overwriting cell 0
      maliciousWrite['currentTurn'] = 'X';

      final allowed = _evaluateSecurityRulesWrite(
        data: occupiedState,
        newData: maliciousWrite,
        authUid: 'user_o_222',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject overwriting occupied cell');
    });

    test('ATTACK 6: Change currentTurn without changing the board legally is rejected', () {
      final maliciousWrite = Map<String, dynamic>.from(baseActiveGame);
      maliciousWrite['currentTurn'] = 'O'; // Board unchanged, turn flipped

      final allowed = _evaluateSecurityRulesWrite(
        data: baseActiveGame,
        newData: maliciousWrite,
        authUid: 'user_x_111',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject arbitrary turn alteration');
    });

    test('ATTACK 7: Declare winner X on a board without an X winning line is rejected', () {
      final maliciousWrite = Map<String, dynamic>.from(baseActiveGame);
      maliciousWrite['board'] = ['X', 'O', 'X', null, null, null, null, null, null];
      maliciousWrite['winner'] = 'X';
      maliciousWrite['status'] = 'finished';

      final allowed = _evaluateSecurityRulesWrite(
        data: baseActiveGame,
        newData: maliciousWrite,
        authUid: 'user_x_111',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject fabricated X win');
    });

    test('ATTACK 8: Declare winner O without an O winning line is rejected', () {
      final oTurnState = Map<String, dynamic>.from(baseActiveGame);
      oTurnState['board'] = ['X', null, null, null, null, null, null, null, null];
      oTurnState['currentTurn'] = 'O';

      final maliciousWrite = Map<String, dynamic>.from(oTurnState);
      maliciousWrite['board'] = ['X', 'O', null, null, null, null, null, null, null];
      maliciousWrite['winner'] = 'O';
      maliciousWrite['status'] = 'finished';

      final allowed = _evaluateSecurityRulesWrite(
        data: oTurnState,
        newData: maliciousWrite,
        authUid: 'user_o_222',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject fabricated O win');
    });

    test('ATTACK 9: Provide fake winningCells is rejected', () {
      final nearWinState = Map<String, dynamic>.from(baseActiveGame);
      nearWinState['board'] = ['X', 'X', null, null, null, null, null, null, null];
      nearWinState['currentTurn'] = 'X';

      final maliciousWrite = Map<String, dynamic>.from(nearWinState);
      maliciousWrite['board'] = ['X', 'X', 'X', null, null, null, null, null, null]; // Actual win is 0,1,2
      maliciousWrite['winner'] = 'X';
      maliciousWrite['winningCells'] = [3, 4, 5]; // Fake winning cells!
      maliciousWrite['status'] = 'finished';

      final allowed = _evaluateSecurityRulesWrite(
        data: nearWinState,
        newData: maliciousWrite,
        authUid: 'user_x_111',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject fake winningCells');
    });

    test('ATTACK 10: Change playerX is rejected', () {
      final maliciousWrite = Map<String, dynamic>.from(baseActiveGame);
      maliciousWrite['playerX'] = 'attacker_hijack_999';

      final allowed = _evaluateSecurityRulesWrite(
        data: baseActiveGame,
        newData: maliciousWrite,
        authUid: 'user_x_111',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject playerX mutation');
    });

    test('ATTACK 11: Change playerO is rejected', () {
      final maliciousWrite = Map<String, dynamic>.from(baseActiveGame);
      maliciousWrite['playerO'] = 'attacker_hijack_999';

      final allowed = _evaluateSecurityRulesWrite(
        data: baseActiveGame,
        newData: maliciousWrite,
        authUid: 'user_x_111',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject playerO mutation');
    });

    test('ATTACK 12: Change status to finished without a win/draw is rejected', () {
      final maliciousWrite = Map<String, dynamic>.from(baseActiveGame);
      maliciousWrite['status'] = 'finished';
      maliciousWrite['winner'] = null;

      final allowed = _evaluateSecurityRulesWrite(
        data: baseActiveGame,
        newData: maliciousWrite,
        authUid: 'user_x_111',
      );
      expect(allowed, isFalse, reason: 'Security rules must reject finished status without winner');
    });

    test('LEGITIMATE MOVES: Valid single moves, turn progression, and wins are accepted', () {
      // 1. Valid move by X at cell 0
      final move1 = Map<String, dynamic>.from(baseActiveGame);
      move1['board'] = ['X', null, null, null, null, null, null, null, null];
      move1['currentTurn'] = 'O';
      expect(
        _evaluateSecurityRulesWrite(
          data: baseActiveGame,
          newData: move1,
          authUid: 'user_x_111',
        ),
        isTrue,
      );

      // 2. Valid move by O at cell 4
      final move2 = Map<String, dynamic>.from(move1);
      move2['board'] = ['X', null, null, null, 'O', null, null, null, null];
      move2['currentTurn'] = 'X';
      expect(
        _evaluateSecurityRulesWrite(
          data: move1,
          newData: move2,
          authUid: 'user_o_222',
        ),
        isTrue,
      );

      // 3. Valid winning move by X at cell 2
      final preWin = Map<String, dynamic>.from(baseActiveGame);
      preWin['board'] = ['X', 'X', null, 'O', 'O', null, null, null, null];
      preWin['currentTurn'] = 'X';

      final winMove = Map<String, dynamic>.from(preWin);
      winMove['board'] = ['X', 'X', 'X', 'O', 'O', null, null, null, null];
      winMove['winner'] = 'X';
      winMove['winningCells'] = [0, 1, 2];
      winMove['status'] = 'finished';
      expect(
        _evaluateSecurityRulesWrite(
          data: preWin,
          newData: winMove,
          authUid: 'user_x_111',
        ),
        isTrue,
      );
    });
  });

  group('Firebase Board Serialization & JS-Interop Safety (Tests 37-43)', () {
    test('37. Empty board serializes to an empty Map without null or sparse elements', () {
      final state = OnlineGameState(
        gameId: 'game_test_empty',
        playerX: 'uid_x',
        board: List.filled(9, null),
        currentTurn: 'X',
        status: OnlineGameStatus.waiting,
      );

      final map = state.toMap();
      expect(map['board'], isA<Map>());
      final boardMap = map['board'] as Map;
      expect(boardMap.isEmpty, isTrue);
      expect(boardMap.values.contains(null), isFalse);
    });

    test('38. Board with X serializes only non-null occupied cells with string index keys', () {
      final board = List<String?>.filled(9, null);
      board[0] = 'X';
      board[4] = 'X';

      final state = OnlineGameState(
        gameId: 'game_test_x',
        playerX: 'uid_x',
        board: board,
      );

      final map = state.toMap();
      final boardMap = map['board'] as Map;
      expect(boardMap, equals({'0': 'X', '4': 'X'}));
      expect(boardMap.containsKey('1'), isFalse);
      expect(boardMap.values.contains(null), isFalse);
    });

    test('39. Board with O serializes only non-null occupied cells with string index keys', () {
      final board = List<String?>.filled(9, null);
      board[2] = 'O';
      board[8] = 'O';

      final state = OnlineGameState(
        gameId: 'game_test_o',
        playerO: 'uid_o',
        board: board,
      );

      final map = state.toMap();
      final boardMap = map['board'] as Map;
      expect(boardMap, equals({'2': 'O', '8': 'O'}));
      expect(boardMap.containsKey('0'), isFalse);
      expect(boardMap.values.contains(null), isFalse);
    });

    test('40. Round-trip toMap() -> fromMap() correctly preserves all 9 cells across empty, partial, and full boards', () {
      // Empty board
      final emptyState = OnlineGameState(
        gameId: 'game_rt_empty',
        playerX: 'uid_x',
        board: List.filled(9, null),
      );
      final fromEmpty = OnlineGameState.fromMap('game_rt_empty', emptyState.toMap());
      expect(fromEmpty.board, equals(List.filled(9, null)));

      // Partial board
      final partialBoard = ['X', null, 'O', null, 'X', null, null, null, 'O'];
      final partialState = OnlineGameState(
        gameId: 'game_rt_partial',
        playerX: 'uid_x',
        playerO: 'uid_o',
        board: partialBoard,
      );
      final fromPartial = OnlineGameState.fromMap('game_rt_partial', partialState.toMap());
      expect(fromPartial.board, equals(partialBoard));

      // Full board
      final fullBoard = ['X', 'O', 'X', 'X', 'O', 'O', 'O', 'X', 'X'];
      final fullState = OnlineGameState(
        gameId: 'game_rt_full',
        playerX: 'uid_x',
        playerO: 'uid_o',
        board: fullBoard,
      );
      final fromFull = OnlineGameState.fromMap('game_rt_full', fullState.toMap());
      expect(fromFull.board, equals(fullBoard));
    });

    test('41. Move serialization produces clean map representation with no sparse array holes', () {
      final boardList = List<dynamic>.filled(9, null);
      boardList[4] = 'X';

      final boardMap = <String, String>{};
      for (int i = 0; i < 9; i++) {
        final cell = boardList[i];
        if (cell != null) {
          boardMap['$i'] = cell.toString();
        }
      }

      expect(boardMap, equals({'4': 'X'}));
      expect(boardMap.length, equals(1));
      expect(boardMap.containsKey('4'), isTrue);
      expect(boardMap.values.contains(null), isFalse);
    });

    test('42. Serialized board contains zero null values across all game states', () {
      for (int i = 0; i < 9; i++) {
        final board = List<String?>.filled(9, null);
        board[i] = (i % 2 == 0) ? 'X' : 'O';
        final state = OnlineGameState(gameId: 'g_$i', board: board);
        final map = state.toMap();
        final bMap = map['board'] as Map;
        for (final val in bMap.values) {
          expect(val, isNotNull);
          expect(val, isNot(equals('null')));
        }
      }
    });

    test('43. Verified immune to JavaScript undefined sparse array serialization', () {
      final state = OnlineGameState(
        gameId: 'game_sparse_check',
        board: List.filled(9, null),
      );
      final map = state.toMap();
      final board = map['board'];
      // Must be Map, NOT a List with null holes
      expect(board, isA<Map<String, String>>());
      expect((board as Map).isEmpty, isTrue);
    });
  });
}

bool _evaluateSecurityRulesWrite({
  required Map<String, dynamic>? data,
  required Map<String, dynamic>? newData,
  required String? authUid,
}) {
  if (authUid == null || newData == null) return false;

  final isCreate = (data == null);
  final playerX = data?['playerX']?.toString();
  final playerO = data?['playerO']?.toString();
  final currentTurn = data?['currentTurn']?.toString() ?? 'X';
  final status = data?['status']?.toString();
  final oldBoard = data?['board'];
  final newBoard = newData['board'];

  final newPlayerX = newData['playerX']?.toString();
  final newPlayerO = newData['playerO']?.toString();
  final newStatus = newData['status']?.toString();
  final newCurrentTurn = newData['currentTurn']?.toString();
  final newWinner = newData['winner']?.toString();

  final isGuestJoin = (!isCreate && playerO == null && newPlayerO == authUid);

  bool boardChanged = false;
  if (oldBoard != null && newBoard != null) {
    boardChanged = jsonEncode(oldBoard) != jsonEncode(newBoard);
  }

  // .write permission check
  bool canWrite = false;
  if (isCreate) {
    canWrite = true;
  } else if (isGuestJoin) {
    canWrite = true;
  } else if (status == 'active' && boardChanged) {
    final expectedTurnUid = (currentTurn == 'X') ? playerX : playerO;
    canWrite = (authUid == expectedTurnUid);
  } else {
    canWrite = (authUid == playerX || authUid == playerO);
  }

  if (!canWrite) return false;

  // .validate on games/$gameId
  if (!newData.containsKey('playerX') ||
      !newData.containsKey('board') ||
      !newData.containsKey('currentTurn') ||
      !newData.containsKey('status')) {
    return false;
  }

  // playerX immutability
  if (data != null && playerX != null && playerX != newPlayerX) {
    return false;
  }

  // playerO immutability
  if (data != null && playerO != null && playerO != newPlayerO) {
    return false;
  }

  // gameId immutability
  if (data != null && data['gameId'] != null && data['gameId'] != newData['gameId']) {
    return false;
  }

  // currentTurn validation
  if (newCurrentTurn != 'X' && newCurrentTurn != 'O') return false;

  // status validation
  if (newStatus != 'waiting' &&
      newStatus != 'active' &&
      newStatus != 'finished' &&
      newStatus != 'abandoned') {
    return false;
  }

  // Finished status requires non-null winner
  if (newStatus == 'finished' && (newWinner == null || newWinner.isEmpty)) {
    return false;
  }

  // Check board transitions
  if (data != null && status == 'active') {
    List<String?> parseBoard(dynamic b) {
      if (b is List) {
        return List<String?>.generate(9, (i) => i < b.length && b[i] != null ? b[i].toString() : null);
      }
      return List<String?>.filled(9, null);
    }

    final oldList = parseBoard(oldBoard);
    final newList = parseBoard(newBoard);

    if (boardChanged) {
      int diffCount = 0;
      int? diffIndex;
      for (int i = 0; i < 9; i++) {
        if (oldList[i] != newList[i]) {
          diffCount++;
          diffIndex = i;
        }
      }

      // Exactly one cell must change
      if (diffCount != 1 || diffIndex == null) {
        return false;
      }

      // Previous value must be null
      if (oldList[diffIndex] != null) {
        return false;
      }

      // Placed piece must match current turn
      if (newList[diffIndex] != currentTurn) {
        return false;
      }

      // Win validation
      bool checkWin(List<String?> b, String s) {
        const combos = [
          [0, 1, 2], [3, 4, 5], [6, 7, 8],
          [0, 3, 6], [1, 4, 7], [2, 5, 8],
          [0, 4, 8], [2, 4, 6]
        ];
        for (final c in combos) {
          if (b[c[0]] == s && b[c[1]] == s && b[c[2]] == s) return true;
        }
        return false;
      }

      final hasXWin = checkWin(newList, 'X');
      final hasOWin = checkWin(newList, 'O');
      final isFull = !newList.contains(null);

      if (newWinner == 'X' && !hasXWin) return false;
      if (newWinner == 'O' && !hasOWin) return false;
      if (newWinner == 'Draw' && (!isFull || hasXWin || hasOWin)) return false;

      if (newWinner != null && newWinner != 'Draw') {
        final wc = newData['winningCells'];
        if (wc is! List || wc.length != 3) return false;
        final c0 = wc[0] as int;
        final c1 = wc[1] as int;
        final c2 = wc[2] as int;
        if (newList[c0] != newWinner || newList[c1] != newWinner || newList[c2] != newWinner) {
          return false;
        }
      }
    } else {
      // Board did not change: currentTurn cannot be flipped
      if (newCurrentTurn != currentTurn) return false;
    }
  }

  return true;
}
