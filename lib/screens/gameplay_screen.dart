import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

import '../ai/tic_tac_toe_ai.dart';
import '../controllers/game_controller.dart';
import '../online/models/online_game_state.dart';
import '../widgets/wood_components.dart';

class GameplayScreen extends StatefulWidget {
  final TicTacToeController controller;

  const GameplayScreen({super.key, required this.controller});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with TickerProviderStateMixin {
  Offset _mouseOffset = Offset.zero;

  // Animation controller for piece placement drop & settle bounce
  late final AnimationController _placementController;
  late final Animation<double> _placementAnimation;

  // Animation controller for golden win beam sweep
  late final AnimationController _winController;
  late final Animation<double> _winAnimation;

  @override
  void initState() {
    super.initState();

    _placementController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _placementAnimation = CurvedAnimation(
      parent: _placementController,
      curve: Curves.easeOutBack,
    );

    _winController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _winAnimation = CurvedAnimation(
      parent: _winController,
      curve: Curves.easeOutCubic,
    );

    widget.controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    if (widget.controller.piecePlacedEvent) {
      widget.controller.piecePlacedEvent = false;
      _placementController.forward(from: 0.0);
    }

    if (widget.controller.winningLine != null &&
        !_winController.isAnimating &&
        _winController.value == 0.0) {
      _winController.forward(from: 0.0);
    }

    if (widget.controller.newRoundEvent) {
      widget.controller.newRoundEvent = false;
      _placementController.reset();
      _winController.reset();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _placementController.dispose();
    _winController.dispose();
    super.dispose();
  }

  void _handleBackNavigation() {
    widget.controller.soundService.playButton();
    if (widget.controller.gameMode == GameMode.completeOnline ||
        widget.controller.gameMode == GameMode.onlineWithCode) {
      widget.controller.leaveOnlineGame();
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                          horizontal: 16.0, vertical: 14.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildTopBar(),
                            if (widget.controller.gameMode ==
                                    GameMode.completeOnline ||
                                widget.controller.gameMode ==
                                    GameMode.onlineWithCode) ...[
                              const SizedBox(height: 10),
                              _buildOnlineMatchBadge(),
                            ],
                            if (widget.controller.onlineErrorMessage != null ||
                                widget.controller.isReconnecting ||
                                widget.controller.isOpponentDisconnected) ...[
                              const SizedBox(height: 8),
                              _buildOnlineStatusBar(),
                            ],
                            const SizedBox(height: 14),
                            _buildPhysicalBoard(),
                            const SizedBox(height: 14),
                            _buildBottomBanner(),
                            const SizedBox(height: 12),
                            _buildScorePlaque(),
                            const SizedBox(height: 14),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 4. Authoritative Online Rematch Modal Overlay
                if (_isOnlineMode && widget.controller.winner != null)
                  _buildRematchModalOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Top Bar with LEFT (back button), CENTER (status title), RIGHT (controls)
  Widget _buildTopBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isNarrow = availableWidth < 370;

        if (isNarrow) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PhysicalWoodBackButton(
                    buttonKey: const Key('btn_back_to_menu'),
                    onPressed: _handleBackNavigation,
                  ),
                  _buildControlsRow(),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildTitleText(),
                ),
              ),
            ],
          );
        }

        // Desktop / Laptop Header
        const double controlsWidth = 86.0;

        return SizedBox(
          height: 44,
          child: Row(
            children: [
              SizedBox(
                width: controlsWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PhysicalWoodBackButton(
                    buttonKey: const Key('btn_back_to_menu'),
                    onPressed: _handleBackNavigation,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildTitleText(),
                  ),
                ),
              ),
              SizedBox(
                width: controlsWidth,
                child: _buildControlsRow(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitleText() {
    return Text(
      widget.controller.getStatusText(),
      textAlign: TextAlign.center,
      maxLines: 1,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
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
    );
  }

  Widget _buildControlsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Mini active player coin badge
        Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF5A361D),
                Color(0xFF1E1007),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFC59B63),
              width: 1.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xBB000000),
                offset: Offset(0, 3),
                blurRadius: 5,
              ),
            ],
          ),
          child: ((widget.controller.gameMode == GameMode.vsComputer &&
                      widget.controller.isComputerThinking) ||
                  widget.controller.currentPlayer == 'O')
              ? const MiniPieceO()
              : const MiniPieceX(),
        ),
        const SizedBox(width: 8),
        // Sound / Mute toggle button
        PhysicalWoodSoundButton(
          isMuted: widget.controller.isMuted,
          onToggle: widget.controller.toggleMute,
        ),
      ],
    );
  }

  Widget _buildOnlineMatchBadge() {
    final role = widget.controller.onlineRole;
    final isPrivate =
        widget.controller.gameMode == GameMode.onlineWithCode;
    final roomCode = widget.controller.onlineRoomCode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF100703),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF422614)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2B170D),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFD4A359)),
            ),
            child: Text(
              role != null ? 'YOU ARE $role' : 'ONLINE',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFF8E1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isPrivate
                  ? 'Code: ${roomCode ?? ""} • Friend Match'
                  : 'Playing vs Random Opponent',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD4B89B),
              ),
            ),
          ),
          _buildSmallActionBtn(
            key: isPrivate
                ? const Key('btn_leave_room')
                : const Key('btn_leave_online'),
            label: 'LEAVE',
            icon: Icons.exit_to_app_rounded,
            onTap: _handleBackNavigation,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionBtn({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2B170D), Color(0xFF190C05)],
            ),
            border: Border.all(
              color: const Color(0xFF5A361D),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: const Color(0xFFD4B89B),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFFD4B89B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineStatusBar() {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF260C0A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF8B251F)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          if (widget.controller.onlineErrorMessage != null)
            GestureDetector(
              onTap: widget.controller.clearErrorMessage,
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Color(0xFFA89A8E)),
            ),
        ],
      ),
    );
  }

  /// Centered physical 3D wooden board with tabletop perspective, multi-tier cast shadows, and recessed wells
  Widget _buildPhysicalBoard() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Transform(
        alignment: FractionalOffset.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0007)
          ..rotateX(0.04 + _mouseOffset.dy * 0.02)
          ..rotateY(-_mouseOffset.dx * 0.02),
        child: CustomPaint(
          painter: PhysicalBoardFramePainter(mouseOffset: _mouseOffset),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF160B05),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 9,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        return _buildCell(index);
                      },
                    ),
                    if (widget.controller.winningLine != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _winAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: WinningLinePainter(
                                  winningLine: widget.controller.winningLine!,
                                  progress: _winAnimation.value,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Individual carved wooden cell pocket with physical bevel depth, hover preview, and piece drop animation
  Widget _buildCell(int index) {
    final value = widget.controller.board[index];
    final isWinningCell =
        widget.controller.winningLine?.contains(index) ?? false;

    final bool isInteractive;
    if (widget.controller.gameMode == GameMode.completeOnline ||
        widget.controller.gameMode == GameMode.onlineWithCode) {
      isInteractive = value == null &&
          widget.controller.winner == null &&
          !widget.controller.isSubmittingMove &&
          widget.controller.onlineGameState != null &&
          widget.controller.onlineGameState!.status == OnlineGameStatus.active &&
          widget.controller.onlineRole != null &&
          widget.controller.currentPlayer == widget.controller.onlineRole;
    } else {
      isInteractive = value == null &&
          widget.controller.winner == null &&
          !widget.controller.isComputerThinking &&
          (widget.controller.gameMode == GameMode.twoPlayer ||
              widget.controller.currentPlayer == 'X');
    }

    final isHovered =
        widget.controller.hoveredIndex == index && isInteractive;
    final isDraw = widget.controller.winner == 'Draw';
    final isDimmed = widget.controller.winner != null &&
        widget.controller.winner != 'Draw' &&
        !isWinningCell;

    return MouseRegion(
      cursor:
          isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isInteractive) {
          widget.controller.setHoveredIndex(index);
        }
      },
      onExit: (_) {
        if (widget.controller.hoveredIndex == index) {
          widget.controller.setHoveredIndex(null);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('cell_$index'),
          canRequestFocus: false,
          onTap: isInteractive
              ? () => widget.controller.handleTap(index)
              : null,
          borderRadius: BorderRadius.circular(6),
          child: CustomPaint(
            painter: CarvedCellWellPainter(
              isWinningCell: isWinningCell,
              isHovered: isHovered,
              isDraw: isDraw,
              isDimmed: isDimmed,
            ),
            child: Center(
              child: value != null
                  ? _buildPlacedPiece(index, value, isWinningCell)
                  : (isHovered
                      ? AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: 0.32,
                          child: Padding(
                            padding: const EdgeInsets.all(7.0),
                            child: widget.controller.currentPlayer == 'X'
                                ? const PieceXWidget()
                                : const PieceOWidget(),
                          ),
                        )
                      : const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a placed piece with physical drop-and-settle animation if freshly placed
  Widget _buildPlacedPiece(int index, String value, bool isWinningPiece) {
    if (index == widget.controller.lastPlacedIndex &&
        _placementController.isAnimating) {
      return AnimatedBuilder(
        animation: _placementAnimation,
        builder: (context, child) {
          final t = _placementAnimation.value;
          final scale = lerpDouble(1.24, 1.0, t)!;
          final dy = lerpDouble(-22.0, 0.0, t)!;
          final rot = (1.0 - t) * (value == 'X' ? -0.08 : 0.08);

          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: rot,
              child: Transform.scale(
                scale: scale,
                child: Padding(
                  padding: const EdgeInsets.all(7.0),
                  child: value == 'X'
                      ? PieceXWidget(isWinning: isWinningPiece)
                      : PieceOWidget(isWinning: isWinningPiece),
                ),
              ),
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: value == 'X'
          ? PieceXWidget(isWinning: isWinningPiece)
          : PieceOWidget(isWinning: isWinningPiece),
    );
  }

  /// Bold arcade / board game banner below the board
  Widget _buildBottomBanner() {
    return const Text(
      'PLACE 3 IN A ROW!',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.2,
        color: Color(0xFFFFF7ED),
        shadows: [
          Shadow(
            color: Colors.black,
            offset: Offset(2, 2.5),
            blurRadius: 4,
          ),
          Shadow(
            color: Color(0xFF1E0E05),
            offset: Offset(-1, -1),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }

  /// Compact classic brass/wood plaque for session score tracking
  Widget _buildScorePlaque() {
    final String p1Label;
    final String p2Label;

    if (widget.controller.gameMode == GameMode.vsComputer) {
      p1Label = 'YOU (X)';
      p2Label = 'COM (O)';
    } else if (widget.controller.gameMode == GameMode.twoPlayer) {
      p1Label = 'P1 (X)';
      p2Label = 'P2 (O)';
    } else {
      if (widget.controller.onlineRole == 'X') {
        p1Label = 'YOU (X)';
        p2Label = 'OPP (O)';
      } else {
        p1Label = 'OPP (X)';
        p2Label = 'YOU (O)';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF190C04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFB8894E),
          width: 1.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xDD000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Color(0x33FFE082),
            offset: Offset(0, -1),
            blurRadius: 1,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildPlaqueItem(
                p1Label, widget.controller.scoreX, const Color(0xFFFF5252)),
            const SizedBox(width: 16),
            Container(
              height: 22,
              width: 1.2,
              color: const Color(0xFF6B4828),
            ),
            const SizedBox(width: 16),
            _buildPlaqueItem(
                'TIES', widget.controller.scoreDraw, const Color(0xFFFDE68A)),
            const SizedBox(width: 16),
            Container(
              height: 22,
              width: 1.2,
              color: const Color(0xFF6B4828),
            ),
            const SizedBox(width: 16),
            _buildPlaqueItem(
                p2Label, widget.controller.scoreO, const Color(0xFFB0BEC5)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaqueItem(String title, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$title: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: color,
            shadows: const [
              Shadow(
                color: Colors.black,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.white,
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
    );
  }

  /// Classic tactile wooden action buttons with 3D bevel and press feedback
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PhysicalWoodButton(
            buttonKey: const Key('new_game_button'),
            label: widget.controller.winner != null
                ? 'Play Again'
                : 'New Round',
            icon: Icons.refresh_rounded,
            onPressed: widget.controller.resetBoard,
            primary: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: PhysicalWoodButton(
            buttonKey: const Key('reset_scores_button'),
            label: 'Reset',
            icon: Icons.restart_alt_rounded,
            onPressed: widget.controller.resetAll,
            primary: false,
          ),
        ),
      ],
    );
  }

  bool get _isOnlineMode =>
      widget.controller.gameMode == GameMode.completeOnline ||
      widget.controller.gameMode == GameMode.onlineWithCode;

  /// Tactile wooden rematch modal overlay that integrates seamlessly with 3D design
  Widget _buildRematchModalOverlay() {
    final winner = widget.controller.winner;
    final role = widget.controller.onlineRole;
    final isDraw = winner == 'Draw';
    final isVictory = winner != null && !isDraw && winner == role;
    final isDefeat = winner != null && !isDraw && winner != role;

    final isOpponentGone = widget.controller.isOpponentDisconnected ||
        widget.controller.onlineGameState?.status == OnlineGameStatus.abandoned;

    String titleText = 'MATCH FINISHED';
    IconData badgeIcon = Icons.sports_esports_rounded;
    Color badgeColor = const Color(0xFFFDE68A);

    if (isDraw) {
      titleText = "IT'S A DRAW!";
      badgeIcon = Icons.balance_rounded;
      badgeColor = const Color(0xFFFDE68A);
    } else if (isVictory) {
      titleText = 'VICTORY!';
      badgeIcon = Icons.emoji_events_rounded;
      badgeColor = const Color(0xFFFFD54F);
    } else if (isDefeat) {
      titleText = 'DEFEAT!';
      badgeIcon = Icons.sentiment_dissatisfied_rounded;
      badgeColor = const Color(0xFFB0BEC5);
    }

    return Positioned.fill(
      child: Container(
        color: const Color(0xB8000000),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2E1A0F),
                    Color(0xFF140A04),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFD4A359),
                  width: 1.8,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xEE000000),
                    offset: Offset(0, 8),
                    blurRadius: 24,
                  ),
                  BoxShadow(
                    color: Color(0x33FFB300),
                    offset: Offset(0, 0),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular Trophy / Result Badge
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A361D), Color(0xFF1E1007)],
                      ),
                      border: Border.all(
                        color: const Color(0xFFC59B63),
                        width: 1.6,
                      ),
                    ),
                    child: Icon(badgeIcon, size: 28, color: badgeColor),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    titleText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Color(0xFFFFFBF0),
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(1.5, 2.0),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Dynamic Handshake / Opponent Status Description
                  if (isOpponentGone) ...[
                    Text(
                      widget.controller.isOpponentDisconnected
                          ? 'Opponent disconnected.'
                          : 'Opponent left the match.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF9A9A),
                      ),
                    ),
                  ] else if (widget.controller.hasRequestedRematch) ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFFFDE68A),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Waiting for opponent to accept...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFDE68A),
                          ),
                        ),
                      ],
                    ),
                  ] else if (widget.controller.opponentRequestedRematch) ...[
                    const Text(
                      'Opponent wants a rematch!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFFFDE68A),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Play another round with the same opponent?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFD4B89B),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Action Buttons
                  if (isOpponentGone) ...[
                    PhysicalWoodButton(
                      buttonKey: const Key('btn_exit_game'),
                      label: 'EXIT TO MENU',
                      icon: Icons.arrow_back_rounded,
                      onPressed: _handleBackNavigation,
                      primary: false,
                    ),
                  ] else if (widget.controller.hasRequestedRematch) ...[
                    PhysicalWoodButton(
                      buttonKey: const Key('btn_exit_game'),
                      label: 'CANCEL & EXIT',
                      icon: Icons.close_rounded,
                      onPressed: _handleBackNavigation,
                      primary: false,
                    ),
                  ] else ...[
                    Column(
                      children: [
                        PhysicalWoodButton(
                          buttonKey: const Key('btn_rematch'),
                          label: widget.controller.opponentRequestedRematch
                              ? 'ACCEPT REMATCH'
                              : 'REMATCH',
                          icon: Icons.replay_rounded,
                          onPressed: widget.controller.requestRematch,
                          primary: true,
                        ),
                        const SizedBox(height: 10),
                        PhysicalWoodButton(
                          buttonKey: const Key('btn_exit_game'),
                          label: 'EXIT TO MENU',
                          icon: Icons.arrow_back_rounded,
                          onPressed: _handleBackNavigation,
                          primary: false,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
