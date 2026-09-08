import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

import 'sound/audio_service.dart';
import 'ai/tic_tac_toe_ai.dart';

void main() {
  runApp(const TicTacToeApp());
}

class TicTacToeApp extends StatelessWidget {
  const TicTacToeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic-Tac-Toe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const TicTacToeGamePage(),
    );
  }
}

class TicTacToeGamePage extends StatefulWidget {
  const TicTacToeGamePage({super.key});

  @override
  State<TicTacToeGamePage> createState() => _TicTacToeGamePageState();
}

class _TicTacToeGamePageState extends State<TicTacToeGamePage>
    with TickerProviderStateMixin {
  // Game board representation: 9 cells, null = empty, 'X' or 'O'
  List<String?> _board = List.filled(9, null);

  // 'X' is Player 1, 'O' is Player 2. 'X' always starts a new round.
  String _currentPlayer = 'X';

  // Active game mode: Two Players or Vs Computer
  GameMode _gameMode = GameMode.twoPlayer;

  // Active AI difficulty level when in Vs Computer mode
  Difficulty _difficulty = Difficulty.medium;

  // Whether the computer opponent is currently calculating/making its move
  bool _isComputerThinking = false;

  // Generation epoch incremented on resets/mode switches to invalidate async computer callbacks
  int _gameEpoch = 0;

  // Game outcome: null = in progress, 'X' = X won, 'O' = O won, 'Draw' = draw
  String? _winner;

  // Stores the indices of the winning line, if any
  List<int>? _winningLine;

  // Track hovered cell index for subtle interaction preview
  int? _hoveredIndex;

  // Mouse offset normalized (-1.0 to 1.0) for subtle perspective parallax
  Offset _mouseOffset = Offset.zero;

  // Index of the most recently placed piece to trigger physical drop animation
  int? _lastPlacedIndex;

  // Session score trackers
  int _scoreX = 0;
  int _scoreO = 0;
  int _scoreDraw = 0;

  // Audio mute toggle and service
  bool _isMuted = false;
  late final AudioService _soundService;

  // Animation controller for piece placement drop & settle bounce
  late final AnimationController _placementController;
  late final Animation<double> _placementAnimation;

  // Animation controller for golden win beam sweep
  late final AnimationController _winController;
  late final Animation<double> _winAnimation;

  // All 8 possible winning combinations (rows, columns, diagonals)
  static const List<List<int>> _winningCombinations = [
    // Rows
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    // Columns
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    // Diagonals
    [0, 4, 8],
    [2, 4, 6],
  ];

  @override
  void initState() {
    super.initState();

    _soundService = AudioService();

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
  }

  @override
  void dispose() {
    _soundService.dispose();
    _placementController.dispose();
    _winController.dispose();
    super.dispose();
  }

  /// Handles player tapping a cell on the board
  void _handleTap(int index) {
    if (_board[index] != null || _winner != null || _isComputerThinking) {
      return;
    }

    // In Vs Computer mode, human is always X and can only move on X's turn
    if (_gameMode == GameMode.vsComputer && _currentPlayer != 'X') {
      return;
    }

    // Play physical move placement click
    _soundService.playMove();

    setState(() {
      _hoveredIndex = null;
      _board[index] = _currentPlayer;
      _lastPlacedIndex = index;
      _placementController.forward(from: 0.0);

      final winningCombo = _checkWinner();
      if (winningCombo != null) {
        _winner = _currentPlayer;
        _winningLine = winningCombo;
        _winController.forward(from: 0.0);
        if (_currentPlayer == 'X') {
          _scoreX++;
          _soundService.playXWin();
        } else {
          _scoreO++;
          _soundService.playOWin();
        }
      } else if (!_board.contains(null)) {
        _winner = 'Draw';
        _winningLine = null;
        _scoreDraw++;
        _soundService.playDraw();
      } else {
        _currentPlayer = _currentPlayer == 'X' ? 'O' : 'X';
      }
    });

    // In Vs Computer mode, if the match is still active and it's O's turn, trigger AI move
    if (_gameMode == GameMode.vsComputer &&
        _winner == null &&
        _currentPlayer == 'O') {
      _triggerComputerMove();
    }
  }

  /// Triggers the computer opponent's move with a short natural delay
  void _triggerComputerMove() async {
    setState(() {
      _isComputerThinking = true;
    });

    final currentEpoch = _gameEpoch;
    // Short natural delay for realistic physical tabletop feel (400ms)
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted ||
        _gameEpoch != currentEpoch ||
        _gameMode != GameMode.vsComputer ||
        _winner != null ||
        _currentPlayer != 'O') {
      return;
    }

    final aiMove = TicTacToeAi.getBestMove(_board, _difficulty);
    if (aiMove == -1 || _board[aiMove] != null) {
      if (mounted) setState(() => _isComputerThinking = false);
      return;
    }

    // Play move placement click
    _soundService.playMove();

    setState(() {
      _isComputerThinking = false;
      _board[aiMove] = 'O';
      _lastPlacedIndex = aiMove;
      _placementController.forward(from: 0.0);

      final winningCombo = _checkWinner();
      if (winningCombo != null) {
        _winner = 'O';
        _winningLine = winningCombo;
        _winController.forward(from: 0.0);
        _scoreO++;
        _soundService.playOWin();
      } else if (!_board.contains(null)) {
        _winner = 'Draw';
        _winningLine = null;
        _scoreDraw++;
        _soundService.playDraw();
      } else {
        _currentPlayer = 'X';
      }
    });
  }

  /// Checks if any winning combination is satisfied
  List<int>? _checkWinner() {
    for (final combo in _winningCombinations) {
      final a = combo[0];
      final b = combo[1];
      final c = combo[2];

      if (_board[a] != null &&
          _board[a] == _board[b] &&
          _board[a] == _board[c]) {
        return combo;
      }
    }
    return null;
  }

  /// Starts a new round while preserving the session score
  void _resetBoard() {
    _soundService.playNewRound();
    setState(() {
      _gameEpoch++;
      _isComputerThinking = false;
      _board = List.filled(9, null);
      _currentPlayer = 'X';
      _winner = null;
      _winningLine = null;
      _hoveredIndex = null;
      _lastPlacedIndex = null;
      _placementController.reset();
      _winController.reset();
    });
  }

  /// Resets both the board and the session scores
  void _resetAll() {
    _soundService.playReset();
    setState(() {
      _gameEpoch++;
      _isComputerThinking = false;
      _board = List.filled(9, null);
      _currentPlayer = 'X';
      _winner = null;
      _winningLine = null;
      _hoveredIndex = null;
      _lastPlacedIndex = null;
      _scoreX = 0;
      _scoreO = 0;
      _scoreDraw = 0;
      _placementController.reset();
      _winController.reset();
    });
  }

  /// Switches active game mode (Two Players / Vs Computer)
  void _setGameMode(GameMode mode) {
    if (_gameMode == mode) return;
    _soundService.playButton();
    setState(() {
      _gameMode = mode;
      _gameEpoch++;
      _isComputerThinking = false;
      _board = List.filled(9, null);
      _currentPlayer = 'X';
      _winner = null;
      _winningLine = null;
      _hoveredIndex = null;
      _lastPlacedIndex = null;
      _placementController.reset();
      _winController.reset();
    });
  }

  /// Changes AI difficulty in Vs Computer mode
  void _setDifficulty(Difficulty difficulty) {
    if (_difficulty == difficulty) return;
    _soundService.playButton();
    setState(() {
      _difficulty = difficulty;
    });
  }

  void _toggleMute() {
    setState(() {
      _soundService.toggleMute();
      _isMuted = _soundService.isMuted;
    });
  }

  String _getStatusText() {
    if (_winner == 'Draw') {
      return "It's a Draw!";
    }

    if (_gameMode == GameMode.vsComputer) {
      if (_winner == 'X') {
        return 'You Win!';
      } else if (_winner == 'O') {
        return 'Computer Wins!';
      } else if (_isComputerThinking) {
        return 'Computer Thinking...';
      } else {
        return 'Your Turn';
      }
    } else {
      if (_winner == 'X') {
        return 'Player X Wins!';
      } else if (_winner == 'O') {
        return 'Player O Wins!';
      } else if (_currentPlayer == 'X') {
        return 'Player X to move';
      } else {
        return 'Player O to move';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 12),
                        _buildModeAndDifficultyBar(),
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
          ],
        ),
      ),
    );
  }

  /// Top Bar with 3 Logical Regions: LEFT (reserved), CENTER (independently centered title), RIGHT (controls)
  Widget _buildTopBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // On narrow screens (< 370px), place controls in a dedicated top sub-row so title gets 100% width
        final isNarrow = availableWidth < 370;

        if (isNarrow) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _buildControlsRow(),
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

        // DESKTOP / LAPTOP HEADER:
        // LEFT: reserved spacing matching right controls width (76px)
        // CENTER: title mathematically centered relative to the whole board
        // RIGHT: controls (76px)
        const double controlsWidth = 76.0;

        return SizedBox(
          height: 44,
          child: Row(
            children: [
              // LEFT: reserved empty spacing
              const SizedBox(width: controlsWidth),
              // CENTER: title independently centered, never overlapping controls
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildTitleText(),
                  ),
                ),
              ),
              // RIGHT: dedicated controls area
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
      _getStatusText(),
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
          child: ((_gameMode == GameMode.vsComputer && _isComputerThinking) ||
                  _currentPlayer == 'O')
              ? const MiniPieceO()
              : const MiniPieceX(),
        ),
        const SizedBox(width: 8),
        // Sound / Mute toggle button
        Container(
          width: 34,
          height: 34,
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
          child: IconButton(
            key: const Key('sound_button'),
            padding: EdgeInsets.zero,
            onPressed: _toggleMute,
            icon: Icon(
              _isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              size: 18,
              color: const Color(0xFFFDE68A),
            ),
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),
        ),
      ],
    );
  }

  /// Centered physical 3D wooden board with tabletop perspective, multi-tier cast shadows, and recessed wells
  Widget _buildPhysicalBoard() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Transform(
        alignment: FractionalOffset.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0007) // subtle 3D camera perspective
          ..rotateX(0.04 + _mouseOffset.dy * 0.02) // tabletop tilt + parallax
          ..rotateY(-_mouseOffset.dx * 0.02),
        child: CustomPaint(
          painter: PhysicalBoardFramePainter(mouseOffset: _mouseOffset),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF160B05), // Deep carved basin
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
                    if (_winningLine != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _winAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: WinningLinePainter(
                                  winningLine: _winningLine!,
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
    final value = _board[index];
    final isWinningCell = _winningLine?.contains(index) ?? false;
    final isInteractive = value == null &&
        _winner == null &&
        !_isComputerThinking &&
        (_gameMode == GameMode.twoPlayer || _currentPlayer == 'X');
    final isHovered = _hoveredIndex == index && isInteractive;
    final isDraw = _winner == 'Draw';
    final isDimmed =
        _winner != null && _winner != 'Draw' && !isWinningCell;

    return MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isInteractive) {
          setState(() => _hoveredIndex = index);
        }
      },
      onExit: (_) {
        if (_hoveredIndex == index) {
          setState(() => _hoveredIndex = null);
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('cell_$index'),
          onTap: isInteractive ? () => _handleTap(index) : null,
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
                            child: _currentPlayer == 'X'
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
    if (index == _lastPlacedIndex && _placementController.isAnimating) {
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

  /// Bold arcade / board game banner below the board matching reference image
  Widget _buildBottomBanner() {
    return const Text(
      'PLACE 3 IN A ROW!',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.2,
        color: Color(0xFFFFF7ED), // Off-white cream matching reference
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
    final p1Label = _gameMode == GameMode.vsComputer ? 'YOU (X)' : 'P1 (X)';
    final p2Label = _gameMode == GameMode.vsComputer ? 'COM (O)' : 'P2 (O)';

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
            _buildPlaqueItem(p1Label, _scoreX, const Color(0xFFFF5252)),
            const SizedBox(width: 16),
            Container(
              height: 22,
              width: 1.2,
              color: const Color(0xFF6B4828),
            ),
            const SizedBox(width: 16),
            _buildPlaqueItem('TIES', _scoreDraw, const Color(0xFFFDE68A)),
            const SizedBox(width: 16),
            Container(
              height: 22,
              width: 1.2,
              color: const Color(0xFF6B4828),
            ),
            const SizedBox(width: 16),
            _buildPlaqueItem(p2Label, _scoreO, const Color(0xFFB0BEC5)),
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

  /// Polished wooden mode and difficulty controls matching the physical tabletop design
  Widget _buildModeAndDifficultyBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF180C05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF8D6236),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            offset: Offset(0, 3),
            blurRadius: 6,
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
          // Row 1: GAME MODE
          Row(
            children: [
              const Text(
                'GAME MODE:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
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
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSelectorButton(
                        buttonKey: const Key('mode_two_players'),
                        label: 'TWO PLAYERS',
                        isSelected: _gameMode == GameMode.twoPlayer,
                        onTap: () => _setGameMode(GameMode.twoPlayer),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildSelectorButton(
                        buttonKey: const Key('mode_vs_computer'),
                        label: 'VS COMPUTER',
                        isSelected: _gameMode == GameMode.vsComputer,
                        onTap: () => _setGameMode(GameMode.vsComputer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Row 2: DIFFICULTY (revealed when VS COMPUTER is active)
          if (_gameMode == GameMode.vsComputer) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'DIFFICULTY:  ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSelectorButton(
                          buttonKey: const Key('difficulty_easy'),
                          label: 'EASY',
                          isSelected: _difficulty == Difficulty.easy,
                          onTap: () => _setDifficulty(Difficulty.easy),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildSelectorButton(
                          buttonKey: const Key('difficulty_medium'),
                          label: 'MEDIUM',
                          isSelected: _difficulty == Difficulty.medium,
                          onTap: () => _setDifficulty(Difficulty.medium),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildSelectorButton(
                          buttonKey: const Key('difficulty_hard'),
                          label: 'HARD',
                          isSelected: _difficulty == Difficulty.hard,
                          onTap: () => _setDifficulty(Difficulty.hard),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
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
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x66FFA000),
                      offset: Offset(0, 1),
                      blurRadius: 3,
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
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                letterSpacing: 0.7,
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

  /// Classic tactile wooden action buttons with 3D bevel and press feedback
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PhysicalWoodButton(
            buttonKey: const Key('new_game_button'),
            label: _winner != null ? 'Play Again' : 'New Round',
            icon: Icons.refresh_rounded,
            onPressed: _resetBoard,
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
            onPressed: _resetAll,
            primary: false,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TACTILE 3D WOODEN PUSH BUTTON
// -----------------------------------------------------------------------------

class PhysicalWoodButton extends StatefulWidget {
  final Key buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  const PhysicalWoodButton({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.primary,
  });

  @override
  State<PhysicalWoodButton> createState() => _PhysicalWoodButtonState();
}

class _PhysicalWoodButtonState extends State<PhysicalWoodButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: Transform.translate(
        offset: Offset(0, _isPressed ? 2.0 : 0.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.primary
                  ? (_isPressed
                      ? const [Color(0xFF4E2C14), Color(0xFF331B0B)]
                      : const [Color(0xFF6B4022), Color(0xFF422411)])
                  : (_isPressed
                      ? const [Color(0xFF22130A), Color(0xFF150A04)]
                      : const [Color(0xFF351F10), Color(0xFF1E0F07)]),
            ),
            border: Border.all(
              color: widget.primary
                  ? const Color(0xFFD49B5B)
                  : const Color(0xFF8B5D34),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xBB000000),
                offset: Offset(0, _isPressed ? 1.5 : 4.0),
                blurRadius: _isPressed ? 3 : 6,
              ),
              if (!_isPressed)
                const BoxShadow(
                  color: Color(0x33FFE082),
                  offset: Offset(0, -1),
                  blurRadius: 1,
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: widget.buttonKey,
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: 16,
                      color: widget.primary
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFD1A877),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: widget.primary
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFE5D5C5),
                        shadows: const [
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SPOTLIGHT & CUSTOM PAINTERS: TABLETOP SPOTLIGHT, 3D BOARD FRAME & WELLS
// -----------------------------------------------------------------------------

/// Directional Key Spotlight Vignette focused over the tabletop board
class TabletopSpotlightPainter extends CustomPainter {
  final Offset mouseOffset;

  const TabletopSpotlightPainter({this.mouseOffset = Offset.zero});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2 + mouseOffset.dx * 16,
      size.height * 0.44 + mouseOffset.dy * 16,
    );
    final radius = math.max(size.width, size.height) * 0.85;

    final spotlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          mouseOffset.dx * 0.05,
          -0.12 + mouseOffset.dy * 0.05,
        ),
        radius: 0.95,
        colors: const [
          Color(0x00000000), // Pure warm light in center
          Color(0x44000000), // Soft ambient falloff
          Color(0xCC000000), // Deep vignette edge
        ],
        stops: const [0.25, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawRect(Offset.zero & size, spotlightPaint);
  }

  @override
  bool shouldRepaint(covariant TabletopSpotlightPainter oldDelegate) =>
      oldDelegate.mouseOffset != mouseOffset;
}

/// Fallback painter in case tabletop image asset fails to load
class FallbackWoodPainter extends CustomPainter {
  final Offset mouseOffset;

  const FallbackWoodPainter({this.mouseOffset = Offset.zero});

  @override
  void paint(Canvas canvas, Size size) {
    const double plankWidth = 90.0;
    final int plankCount = (size.width / plankWidth).ceil() + 1;

    final plankTones = [
      [const Color(0xFF24140A), const Color(0xFF351D0F)],
      [const Color(0xFF1D0E06), const Color(0xFF2D170B)],
      [const Color(0xFF29170D), const Color(0xFF3A2112)],
      [const Color(0xFF200F07), const Color(0xFF301A0E)],
    ];

    for (int i = 0; i < plankCount; i++) {
      final left = i * plankWidth;
      final rect = Rect.fromLTWH(left, 0, plankWidth, size.height);
      final tones = plankTones[i % plankTones.length];

      final basePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: tones,
        ).createShader(rect);

      canvas.drawRect(rect, basePaint);
    }
  }

  @override
  bool shouldRepaint(covariant FallbackWoodPainter oldDelegate) => false;
}

/// 3D Physical Board Frame Painter: Heavy beveled wooden molding, multi-tier contact shadows, and corner rivets
class PhysicalBoardFramePainter extends CustomPainter {
  final Offset mouseOffset;

  const PhysicalBoardFramePainter({this.mouseOffset = Offset.zero});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // 1. Deep Multi-tier Contact & Tabletop Shadows (dynamically responds to light angle)
    final shadowOffset = Offset(
      mouseOffset.dx * 6,
      18.0 + mouseOffset.dy * 6,
    );

    // Deep diffuse ambient shadow
    final ambientShadowPaint = Paint()
      ..color = const Color(0xBB000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(shadowOffset),
        const Radius.circular(16),
      ),
      ambientShadowPaint,
    );

    // Tight dark contact occlusion shadow
    final contactShadowPaint = Paint()
      ..color = const Color(0xEE000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(0, 8)),
        const Radius.circular(16),
      ),
      contactShadowPaint,
    );

    // 2. Base Chamfered Wooden Frame (molded walnut/oak)
    final framePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF7E4E2C), // Key-light highlight at 11 o'clock
          Color(0xFF502E19), // Rich walnut midtone
          Color(0xFF2B170D), // Deep wood shadow at 5 o'clock
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, framePaint);

    // 3. Frame Fine Wood Grain Streaks
    final woodGrainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x18000000);
    for (double y = 4; y < size.height; y += 6) {
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), woodGrainPaint);
    }

    // 4. Outer Frame Specular Highlight Bevel (gleams on top and left)
    final outerBevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x99FFE082), // Golden key light reflection
          Color(0x228B5A33),
          Color(0x88000000), // Shadowed bottom/right edge
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, outerBevelPaint);

    // 5. Corner Brass Reinforcement Brackets & Rivets
    _drawCornerHardware(canvas, size);
  }

  void _drawCornerHardware(Canvas canvas, Size size) {
    final bracketPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE5C07B), Color(0xFF8B6327), Color(0xFF533B17)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final rivetPaint = Paint()..color = const Color(0xFFFFF3D0);
    final rivetShadow = Paint()..color = const Color(0x99000000);

    const double cornerOffset = 11.0;
    final corners = [
      const Offset(cornerOffset, cornerOffset),
      Offset(size.width - cornerOffset, cornerOffset),
      Offset(cornerOffset, size.height - cornerOffset),
      Offset(size.width - cornerOffset, size.height - cornerOffset),
    ];

    for (final c in corners) {
      // Small brass mounting coin
      canvas.drawCircle(c, 4.0, bracketPaint);
      // Contact shadow of rivet
      canvas.drawCircle(c + const Offset(0.5, 1.0), 1.8, rivetShadow);
      // Raised brass dome rivet
      canvas.drawCircle(c, 1.6, rivetPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PhysicalBoardFramePainter oldDelegate) =>
      oldDelegate.mouseOffset != mouseOffset;
}

/// Paints an individual carved sunken wooden cell well with vertical timber grain,
/// top-left inset drop shadow, bottom-right warm wood reflection lip, and winning glow.
class CarvedCellWellPainter extends CustomPainter {
  final bool isWinningCell;
  final bool isHovered;
  final bool isDraw;
  final bool isDimmed;

  const CarvedCellWellPainter({
    required this.isWinningCell,
    this.isHovered = false,
    this.isDraw = false,
    this.isDimmed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    // 1. Sunken wooden floor base
    Color topColor;
    Color bottomColor;

    if (isWinningCell) {
      topColor = const Color(0xFF6B431D);
      bottomColor = const Color(0xFF452710);
    } else if (isDraw) {
      topColor = const Color(0xFF4A341E);
      bottomColor = const Color(0xFF301E0E);
    } else if (isHovered) {
      topColor = const Color(0xFF3A2316);
      bottomColor = const Color(0xFF28170D);
    } else if (isDimmed) {
      topColor = const Color(0xFF1B0F08);
      bottomColor = const Color(0xFF120A05);
    } else {
      topColor = const Color(0xFF2D1A0F);
      bottomColor = const Color(0xFF1F1009);
    }

    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(rect);
    canvas.drawRRect(rrect, floorPaint);

    // 2. Vertical wood grain streaks inside the cell well
    final grainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x18000000);
    for (double x = 4; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grainPaint);
    }

    // 3. Golden underglow if winning cell or draw state
    if (isWinningCell) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.65,
          colors: const [Color(0xEEF59E0B), Colors.transparent],
        ).createShader(rect);
      canvas.drawRRect(rrect, glowPaint);
    } else if (isDraw) {
      final drawGlowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.7,
          colors: const [Color(0x66D97706), Colors.transparent],
        ).createShader(rect);
      canvas.drawRRect(rrect, drawGlowPaint);
    }

    // 4. Inset Top Cast Shadow (deep shadow cast by upper divider rail)
    final topShadow = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xEE000000), Color(0x77000000), Colors.transparent],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 9.0));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 9.0), topShadow);

    // 5. Inset Left Cast Shadow (shadow cast by left divider rail)
    final leftShadow = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xEE000000), Color(0x77000000), Colors.transparent],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, 9.0, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, 9.0, size.height), leftShadow);

    // 6. Bottom and Right inner wall warm specular reflection lips
    final lipPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = isWinningCell
          ? const Color(0xFFFBBF24)
          : (isHovered
              ? const Color(0xAA9E7245)
              : (isDimmed
                  ? const Color(0x338A5B36)
                  : const Color(0x778A5B36)));

    // Bottom lip
    canvas.drawLine(
      Offset(2, size.height - 0.7),
      Offset(size.width - 2, size.height - 0.7),
      lipPaint,
    );
    // Right lip
    canvas.drawLine(
      Offset(size.width - 0.7, 2),
      Offset(size.width - 0.7, size.height - 2),
      lipPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CarvedCellWellPainter oldDelegate) =>
      oldDelegate.isWinningCell != isWinningCell ||
      oldDelegate.isHovered != isHovered ||
      oldDelegate.isDraw != isDraw ||
      oldDelegate.isDimmed != isDimmed;
}

/// Dynamic Winning Line Painter: Draws an illuminated golden connection beam sweeping across winning cells
/// Calibrated to pass through the exact geometric center of all 3 cells taking divider spacing into account.
class WinningLinePainter extends CustomPainter {
  final List<int> winningLine;
  final double progress;

  const WinningLinePainter({
    required this.winningLine,
    this.progress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (winningLine.length < 3) return;

    // GridView uses crossAxisSpacing: 8, mainAxisSpacing: 8
    const double spacing = 8.0;
    final cellW = (size.width - 2 * spacing) / 3;
    final cellH = (size.height - 2 * spacing) / 3;

    Offset getCellCenter(int idx) {
      final col = idx % 3;
      final row = idx ~/ 3;
      return Offset(
        col * (cellW + spacing) + cellW / 2,
        row * (cellH + spacing) + cellH / 2,
      );
    }

    final p1 = getCellCenter(winningLine.first);
    final p2 = getCellCenter(winningLine.last);

    // Vector from p1 to p2
    final dir = p2 - p1;
    final distance = dir.distance;
    final unitDir = distance > 0 ? dir / distance : Offset.zero;
    final extendAmount = cellW * 0.22;

    final startPoint = p1 - unitDir * extendAmount;
    final fullEndPoint = p2 + unitDir * extendAmount;
    final currentEndPoint = Offset.lerp(startPoint, fullEndPoint, progress)!;

    // 1. Ambient outer golden radiant aura
    final glowPaint = Paint()
      ..color = const Color(0xAAFFA000)
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawLine(startPoint, currentEndPoint, glowPaint);

    // 2. Crisp bright core beam
    final corePaint = Paint()
      ..color = const Color(0xFFFFE082)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(startPoint, currentEndPoint, corePaint);

    // 3. Radiant spark at the traveling tip
    final sparkPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(currentEndPoint, 3.5, sparkPaint);

    // 4. Node flares at exact cell centers
    final nodePaint = Paint()..color = const Color(0xFFFFF8E1);
    canvas.drawCircle(p1, 4.2, nodePaint);
    if (progress > 0.5) {
      final midPoint = getCellCenter(winningLine[1]);
      canvas.drawCircle(midPoint, 4.2, nodePaint);
    }
    if (progress >= 0.95) {
      canvas.drawCircle(p2, 4.2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant WinningLinePainter oldDelegate) =>
      oldDelegate.winningLine != winningLine ||
      oldDelegate.progress != progress;
}

// -----------------------------------------------------------------------------
// PHYSICAL 3D PIECES: CHISELED RED LACQUERED X & MACHINED METALLIC O
// -----------------------------------------------------------------------------

/// Physical 3D Chiseled Red Lacquered 'X' Piece with Directional Contact Shadow
class PieceXWidget extends StatelessWidget {
  final bool isWinning;

  const PieceXWidget({super.key, this.isWinning = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shadowOffset = Offset(
          constraints.maxWidth * 0.05,
          constraints.maxHeight * 0.08,
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            if (isWinning)
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xDDFFB300),
                      blurRadius: 18,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            // Contact shadow projected onto wooden cell floor
            Transform.translate(
              offset: shadowOffset,
              child: Image.asset(
                'assets/images/pieces/piece_x_shadow.png',
                fit: BoxFit.contain,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
            // High-resolution physical 3D piece
            Image.asset(
              'assets/images/pieces/piece_x.png',
              fit: BoxFit.contain,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            ),
          ],
        );
      },
    );
  }
}

/// Physical 3D Machined Metallic 'O' Ring Puck with Directional Contact Shadow
class PieceOWidget extends StatelessWidget {
  final bool isWinning;

  const PieceOWidget({super.key, this.isWinning = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shadowOffset = Offset(
          constraints.maxWidth * 0.05,
          constraints.maxHeight * 0.08,
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            if (isWinning)
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xDDFFB300),
                      blurRadius: 18,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            // Contact shadow projected onto wooden cell floor
            Transform.translate(
              offset: shadowOffset,
              child: Image.asset(
                'assets/images/pieces/piece_o_shadow.png',
                fit: BoxFit.contain,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
            // High-resolution physical 3D piece
            Image.asset(
              'assets/images/pieces/piece_o.png',
              fit: BoxFit.contain,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            ),
          ],
        );
      },
    );
  }
}

/// Mini 3D 'X' for top indicator coin badge
class MiniPieceX extends StatelessWidget {
  const MiniPieceX({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/pieces/piece_x.png',
      fit: BoxFit.contain,
    );
  }
}

/// Mini 3D 'O' for top indicator coin badge
class MiniPieceO extends StatelessWidget {
  const MiniPieceO({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/pieces/piece_o.png',
      fit: BoxFit.contain,
    );
  }
}
