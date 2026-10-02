import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../online/models/online_game_state.dart';
import '../widgets/wood_components.dart';
import 'gameplay_screen.dart';

class CompleteOnlineScreen extends StatefulWidget {
  final TicTacToeController controller;

  const CompleteOnlineScreen({super.key, required this.controller});

  @override
  State<CompleteOnlineScreen> createState() => _CompleteOnlineScreenState();
}

class _CompleteOnlineScreenState extends State<CompleteOnlineScreen> {
  Offset _mouseOffset = Offset.zero;
  bool _hasNavigatedToGame = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_checkGameTransition);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkGameTransition);
    super.dispose();
  }

  void _checkGameTransition() {
    if (_hasNavigatedToGame || !mounted) return;

    if (widget.controller.onlineGameState != null &&
        widget.controller.onlineGameState!.status == OnlineGameStatus.active) {
      _hasNavigatedToGame = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameplayScreen(controller: widget.controller),
        ),
      );
    }
  }

  void _handleBack() {
    widget.controller.soundService.playButton();
    if (widget.controller.isMatchmaking) {
      widget.controller.cancelMatchmaking();
    }
    Navigator.of(context).pop();
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
                            _buildMatchmakingCard(),
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
            onPressed: _handleBack,
          ),
          const Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'COMPLETE ONLINE',
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

  Widget _buildMatchmakingCard() {
    final isSearching = widget.controller.isMatchmaking;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF5A361D), Color(0xFF1E1007)],
              ),
              border: Border.all(color: const Color(0xFFC59B63), width: 1.6),
            ),
            child: const Icon(
              Icons.public_rounded,
              size: 28,
              color: Color(0xFFFDE68A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'RANDOM ONLINE MATCHMAKING',
            style: TextStyle(
              fontSize: 12.5,
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
          const SizedBox(height: 8),
          const Text(
            'Play with an online opponent matched randomly from players worldwide.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFFD4B89B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),

          if (isSearching) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF100703),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD4A359), width: 1.2),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: Color(0xFFFDE68A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Finding opponent...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFDE68A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Waiting for another player to join the matchmaking queue...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Color(0xFFA89A8E)),
                  ),
                  const SizedBox(height: 14),
                  PhysicalWoodButton(
                    buttonKey: const Key('btn_cancel_matchmaking'),
                    label: 'CANCEL',
                    icon: Icons.close_rounded,
                    onPressed: () {
                      widget.controller.soundService.playButton();
                      widget.controller.cancelMatchmaking();
                    },
                    primary: false,
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: PhysicalWoodButton(
                buttonKey: const Key('btn_find_opponent'),
                label: 'FIND OPPONENT',
                icon: Icons.search_rounded,
                onPressed: () {
                  widget.controller.soundService.playButton();
                  widget.controller.startMatchmaking();
                },
                primary: true,
              ),
            ),
          ],

          if (widget.controller.onlineErrorMessage != null ||
              widget.controller.isReconnecting ||
              widget.controller.isOpponentDisconnected) ...[
            const SizedBox(height: 14),
            _buildStatusBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    String text = '';
    IconData icon = Icons.info_outline_rounded;
    Color textColor = const Color(0xFFFDE68A);

    if (widget.controller.isReconnecting) {
      text = 'Connection lost. Reconnecting...';
      icon = Icons.sync_rounded;
    } else if (widget.controller.isOpponentDisconnected) {
      text = 'Opponent disconnected.';
      icon = Icons.person_off_rounded;
      textColor = const Color(0xFFFF8A80);
    } else if (widget.controller.onlineErrorMessage != null) {
      text = widget.controller.onlineErrorMessage!;
      icon = Icons.warning_amber_rounded;
      textColor = const Color(0xFFFF8A80);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF260C0A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8B251F)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          if (widget.controller.onlineErrorMessage != null)
            GestureDetector(
              onTap: widget.controller.clearErrorMessage,
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Color(0xFFA89A8E)),
            ),
        ],
      ),
    );
  }
}
