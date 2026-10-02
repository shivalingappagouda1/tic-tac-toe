import 'package:flutter/material.dart';

import '../ai/tic_tac_toe_ai.dart';
import '../controllers/game_controller.dart';
import '../widgets/wood_components.dart';
import 'gameplay_screen.dart';

class ComputerSetupScreen extends StatefulWidget {
  final TicTacToeController controller;

  const ComputerSetupScreen({super.key, required this.controller});

  @override
  State<ComputerSetupScreen> createState() => _ComputerSetupScreenState();
}

class _ComputerSetupScreenState extends State<ComputerSetupScreen> {
  Offset _mouseOffset = Offset.zero;
  late Difficulty _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.controller.difficulty;
  }

  void _onDifficultyTap(Difficulty diff) {
    widget.controller.soundService.playButton();
    setState(() {
      _selectedDifficulty = diff;
    });
  }

  void _startGame() {
    widget.controller.startComputerGame(_selectedDifficulty);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameplayScreen(controller: widget.controller),
      ),
    );
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
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/wood/tabletop_wood.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        CustomPaint(painter: FallbackWoodPainter(mouseOffset: _mouseOffset)),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: TabletopSpotlightPainter(mouseOffset: _mouseOffset),
                    ),
                  ),
                ),
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
                            _buildSetupCard(),
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
          PhysicalWoodBackButton(
            buttonKey: const Key('btn_back_to_modes'),
            onPressed: () {
              widget.controller.soundService.playButton();
              Navigator.of(context).pop();
            },
          ),
          const Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'VS COMPUTER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
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

  Widget _buildSetupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF5A361D), Color(0xFF1E1007)],
              ),
              border: Border.all(color: const Color(0xFFC59B63), width: 1.6),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 26,
              color: Color(0xFFFDE68A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'CHOOSE AI DIFFICULTY',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
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
          const SizedBox(height: 16),

          // Difficulty buttons column
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: _buildDifficultyButton(
                  buttonKey: const Key('difficulty_easy'),
                  label: 'EASY',
                  diff: Difficulty.easy,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _buildDifficultyButton(
                  buttonKey: const Key('difficulty_medium'),
                  label: 'MEDIUM',
                  diff: Difficulty.medium,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _buildDifficultyButton(
                  buttonKey: const Key('difficulty_hard'),
                  label: 'HARD',
                  diff: Difficulty.hard,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Difficulty explanation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF100703),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF422614)),
            ),
            child: Text(
              _getDifficultyDescription(_selectedDifficulty),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFFD4B89B),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Start Game button
          SizedBox(
            width: double.infinity,
            child: PhysicalWoodButton(
              buttonKey: const Key('btn_start_game'),
              label: 'START GAME',
              icon: Icons.play_arrow_rounded,
              onPressed: _startGame,
              primary: true,
            ),
          ),
        ],
      ),
    );
  }

  String _getDifficultyDescription(Difficulty diff) {
    switch (diff) {
      case Difficulty.easy:
        return 'Easy Mode: Computer makes random casual moves with occasional mistakes. Great for beginners.';
      case Difficulty.medium:
        return 'Medium Mode: Tactical AI blocks wins and seizes opportunities with moderate variance.';
      case Difficulty.hard:
        return 'Hard Mode: Unbeatable Minimax AI evaluates all permutations. A master-level challenge!';
    }
  }

  Widget _buildDifficultyButton({
    required Key buttonKey,
    required String label,
    required Difficulty diff,
  }) {
    final isSelected = _selectedDifficulty == diff;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        canRequestFocus: false,
        onTap: () => _onDifficultyTap(diff),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42.0,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: isSelected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF8A5528),
                      Color(0xFF532E11),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF26150B),
                      Color(0xFF140A04),
                    ],
                  ),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD4A359)
                  : const Color(0xFF4A311D),
              width: 1.6,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x66FFA000),
                      offset: Offset(0, 1),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: Color(0x33FFE082),
                      offset: Offset(0, -1),
                      blurRadius: 1,
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x44000000),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                letterSpacing: 0.8,
                color: isSelected
                    ? const Color(0xFFFFF8E1)
                    : const Color(0xFFA89A8E),
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
