import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/game_controller.dart';
import '../online/models/online_game_state.dart';
import '../widgets/wood_components.dart';
import 'gameplay_screen.dart';

class OnlineFriendsScreen extends StatefulWidget {
  final TicTacToeController controller;

  const OnlineFriendsScreen({super.key, required this.controller});

  @override
  State<OnlineFriendsScreen> createState() => _OnlineFriendsScreenState();
}

class _OnlineFriendsScreenState extends State<OnlineFriendsScreen> {
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
    if (widget.controller.onlineRoomCode != null ||
        widget.controller.isCreatingRoom ||
        widget.controller.isJoiningRoom) {
      widget.controller.leaveOnlineGame();
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
                            _buildFriendsCard(),
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
                  'ONLINE WITH FRIENDS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
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

  Widget _buildFriendsCard() {
    final isWaitingForGuest = widget.controller.onlineRoomCode != null &&
        widget.controller.isPrivateRoomHost &&
        widget.controller.onlineGameState?.status != OnlineGameStatus.active;

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
      child: isWaitingForGuest
          ? _buildWaitingHostView()
          : Column(
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
                    Icons.vpn_key_rounded,
                    size: 26,
                    color: Color(0xFFFDE68A),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'PRIVATE ROOM SETUP',
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

                // Tabs for Create / Join
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: _buildSelectorButton(
                        buttonKey: const Key('btn_create_room_tab'),
                        label: 'CREATE ROOM',
                        isSelected: widget.controller.privateRoomTab == 0,
                        onTap: () {
                          widget.controller.soundService.playButton();
                          widget.controller.setPrivateRoomTab(0);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: _buildSelectorButton(
                        buttonKey: const Key('btn_join_room_tab'),
                        label: 'JOIN ROOM',
                        isSelected: widget.controller.privateRoomTab == 1,
                        onTap: () {
                          widget.controller.soundService.playButton();
                          widget.controller.setPrivateRoomTab(1);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (widget.controller.privateRoomTab == 0) ...[
                  _buildCreateRoomTabContent(),
                ] else ...[
                  _buildJoinRoomTabContent(),
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

  Widget _buildWaitingHostView() {
    final code = widget.controller.onlineRoomCode ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ROOM CREATED',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Color(0xFFC59B63),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF100703),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD4A359), width: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                  color: Color(0xFFFFFBF0),
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.copy_rounded,
                    size: 20, color: Color(0xFFFDE68A)),
                tooltip: 'Copy Code',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Room code copied to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Share this 6-character code with your friend.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFFD4B89B)),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: Color(0xFFFDE68A),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Waiting for friend to connect...',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFDE68A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        PhysicalWoodButton(
          buttonKey: const Key('btn_cancel_room'),
          label: 'CANCEL ROOM',
          icon: Icons.close_rounded,
          onPressed: () {
            widget.controller.soundService.playButton();
            widget.controller.leaveOnlineGame();
          },
          primary: false,
        ),
      ],
    );
  }

  Widget _buildCreateRoomTabContent() {
    return Column(
      children: [
        const Text(
          'Generate a private room and share the 6-character code with a friend to play remotely.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFFD4B89B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: PhysicalWoodButton(
            buttonKey: const Key('btn_create_room'),
            label: widget.controller.isCreatingRoom
                ? 'CREATING ROOM...'
                : 'CREATE ROOM',
            icon: Icons.add_circle_outline_rounded,
            onPressed: widget.controller.isCreatingRoom
                ? () {}
                : () {
                    widget.controller.soundService.playButton();
                    widget.controller.createPrivateRoom();
                  },
            primary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildJoinRoomTabContent() {
    return Column(
      children: [
        const Text(
          'Enter the 6-character code shared by your friend to join their game.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFFD4B89B),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 42,
          child: TextField(
            key: const Key('input_room_code'),
            controller: widget.controller.roomCodeInputController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
              color: Color(0xFFFFFBF0),
            ),
            decoration: InputDecoration(
              counterText: '',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              hintText: 'ENTER CODE',
              hintStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Color(0xFF6B4D35),
              ),
              filled: true,
              fillColor: const Color(0xFF1D0E06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF5A361D)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD4A359)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: PhysicalWoodButton(
            buttonKey: const Key('btn_submit_join_room'),
            label: widget.controller.isJoiningRoom
                ? 'JOINING...'
                : 'JOIN ROOM',
            icon: Icons.login_rounded,
            onPressed: widget.controller.isJoiningRoom
                ? () {}
                : () {
                    widget.controller.soundService.playButton();
                    widget.controller.joinPrivateRoom();
                  },
            primary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorButton({
    required Key buttonKey,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42.0,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                fontSize: 10.5,
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
