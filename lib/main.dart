import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'online/services/online_backend.dart';
import 'online/services/firebase_online_backend.dart';
import 'online/firebase_options.dart';
import 'online/models/online_game_state.dart';
import 'controllers/game_controller.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/gameplay_screen.dart';

// Re-export components for convenience and test compatibility
export 'widgets/wood_components.dart';
export 'controllers/game_controller.dart';
export 'screens/mode_selection_screen.dart';
export 'screens/computer_setup_screen.dart';
export 'screens/complete_online_screen.dart';
export 'screens/online_friends_screen.dart';
export 'screens/gameplay_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OnlineBackend? onlineBackend;
  try {
    if (DefaultFirebaseOptions.isConfigured) {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options != null) {
        await Firebase.initializeApp(options: options);
        onlineBackend = FirebaseOnlineBackend();
      }
    }
  } catch (e) {
    debugPrint('[ONLINE] Firebase initialization skipped or failed: $e');
  }
  runApp(TicTacToeApp(onlineBackend: onlineBackend));
}

class TicTacToeApp extends StatefulWidget {
  final OnlineBackend? onlineBackend;

  const TicTacToeApp({super.key, this.onlineBackend});

  @override
  State<TicTacToeApp> createState() => _TicTacToeAppState();
}

class _TicTacToeAppState extends State<TicTacToeApp> {
  late final TicTacToeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TicTacToeController(initialBackend: widget.onlineBackend);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic-Tac-Toe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: TicTacToeRoot(controller: _controller),
    );
  }
}

class TicTacToeRoot extends StatelessWidget {
  final TicTacToeController controller;

  const TicTacToeRoot({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // If an active online session was restored, jump directly to GameplayScreen
        if (controller.onlineGameState != null &&
            controller.onlineGameState!.status == OnlineGameStatus.active) {
          return GameplayScreen(controller: controller);
        }

        // Standard entry: Page 1 — Mode Selection Only
        return ModeSelectionScreen(controller: controller);
      },
    );
  }
}

/// Backward compatibility class for tests referencing TicTacToeGamePage
class TicTacToeGamePage extends StatelessWidget {
  final OnlineBackend? onlineBackend;

  const TicTacToeGamePage({super.key, this.onlineBackend});

  @override
  Widget build(BuildContext context) {
    return TicTacToeApp(onlineBackend: onlineBackend);
  }
}
