import 'package:flutter/material.dart';

import '../ai/tic_tac_toe_ai.dart';
import '../controllers/game_controller.dart';
import '../widgets/wood_components.dart';
import 'computer_setup_screen.dart';
import 'complete_online_screen.dart';
import 'online_friends_screen.dart';
import 'gameplay_screen.dart';

class ModeSelectionScreen extends StatefulWidget {
  final TicTacToeController controller;

  const ModeSelectionScreen({super.key, required this.controller});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  Offset _mouseOffset = Offset.zero;

  void _onModeSelected(GameMode mode) {
    widget.controller.soundService.playButton();

    switch (mode) {
      case GameMode.vsComputer:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ComputerSetupScreen(controller: widget.controller),
          ),
        );
        break;

      case GameMode.twoPlayer:
        widget.controller.startLocalGame();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameplayScreen(controller: widget.controller),
          ),
        );
        break;

      case GameMode.completeOnline:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CompleteOnlineScreen(controller: widget.controller),
          ),
        );
        break;

      case GameMode.onlineWithCode:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OnlineFriendsScreen(controller: widget.controller),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Scaffold(
          body: MouseRegion(
            onHover: (event) {
              final size = MediaQuery.of(context).size;
              final center = Offset(size.width / 2, size.height / 2);
              final dx = ((event.position.dx - center.dx) / (size.width / 2))
                  .clamp(-1.0, 1.0);
              final dy = ((event.position.dy - center.dy) / (size.height / 2))
                  .clamp(-1.0, 1.0);
              if ((dx - _mouseOffset.dx).abs() > 0.04 ||
                  (dy - _mouseOffset.dy).abs() > 0.04) {
                setState(() {
                  _mouseOffset = Offset(dx, dy);
                });
              }
            },
            child: Stack(
              children: [
                // 1. High-Resolution Wood Tabletop Background Image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/wood/tabletop_wood.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        CustomPaint(painter: FallbackWoodPainter(mouseOffset: _mouseOffset)),
                  ),
                ),
                // 2. Directional Key Spotlight Vignette
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: TabletopSpotlightPainter(mouseOffset: _mouseOffset),
                    ),
                  ),
                ),
                // 3. Main Centered Tabletop UI Composition
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 20.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildTopBar(),
                            const SizedBox(height: 24),
                            _buildModeSelectionPanel(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 44), // Balances sound button on right
          const Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'GAME MODES',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Color(0xFFFFFBF0),
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2, 2.5),
                        blurRadius: 4,
                      ),
                      Shadow(
                        color: Color(0xFF221107),
                        offset: Offset(-1, -1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          PhysicalWoodSoundButton(
            isMuted: widget.controller.isMuted,
            onToggle: widget.controller.toggleMute,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectionPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF180C05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF8D6236),
          width: 1.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Color(0x22FFE082),
            offset: Offset(0, -1),
            blurRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.sports_esports_rounded, size: 16, color: Color(0xFFC59B63)),
              SizedBox(width: 6),
              Text(
                'SELECT HOW TO PLAY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: Color(0xFFC59B63),
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Column(
            children: [
              _buildModeCard(
                key: const Key('mode_vs_computer'),
                mode: GameMode.vsComputer,
                title: 'COMPUTER',
                subtitle: 'Play against AI',
                icon: Icons.smart_toy_rounded,
              ),
              const SizedBox(height: 10),
              _buildModeCard(
                key: const Key('mode_two_players'),
                mode: GameMode.twoPlayer,
                title: '1 VS 1',
                subtitle: 'Local multiplayer',
                icon: Icons.people_alt_rounded,
              ),
              const SizedBox(height: 10),
              _buildModeCard(
                key: const Key('mode_complete_online'),
                mode: GameMode.completeOnline,
                title: 'COMPLETE ONLINE',
                subtitle: 'Random online opponent',
                icon: Icons.public_rounded,
              ),
              const SizedBox(height: 10),
              _buildModeCard(
                key: const Key('mode_online_with_code'),
                mode: GameMode.onlineWithCode,
                title: 'ONLINE WITH FRIENDS',
                subtitle: 'Private room with code',
                icon: Icons.vpn_key_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required Key key,
    required GameMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        canRequestFocus: false,
        onTap: () => _onModeSelected(mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 68.0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2C190F),
                Color(0xFF190C05),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF5A361D),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: Color(0x22FFE082),
                offset: Offset(0, -1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A2B14), Color(0xFF24130A)],
                  ),
                  border: Border.all(color: const Color(0xFF8D6236)),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFFFDE68A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Color(0xFFFFFBF0),
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFD4B89B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF8D6236),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
