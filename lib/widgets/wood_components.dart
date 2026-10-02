import 'dart:math' as math;
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// SPOTLIGHT & FALLBACK WOOD PAINTERS
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

// -----------------------------------------------------------------------------
// 3D PHYSICAL BOARD FRAME & CARVED CELL WELL PAINTERS
// -----------------------------------------------------------------------------

/// 3D Physical Board Frame Painter: Heavy beveled wooden molding, multi-tier contact shadows, and corner rivets
class PhysicalBoardFramePainter extends CustomPainter {
  final Offset mouseOffset;

  const PhysicalBoardFramePainter({this.mouseOffset = Offset.zero});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // 1. Deep Multi-tier Contact & Tabletop Shadows
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

    // 2. Base Chamfered Wooden Frame
    final framePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF7E4E2C),
          Color(0xFF502E19),
          Color(0xFF2B170D),
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

    // 4. Outer Frame Specular Highlight Bevel
    final outerBevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x99FFE082),
          Color(0x228B5A33),
          Color(0x88000000),
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
      canvas.drawCircle(c, 4.0, bracketPaint);
      canvas.drawCircle(c + const Offset(0.5, 1.0), 1.8, rivetShadow);
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

    // 4. Inset Top Cast Shadow
    final topShadow = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xEE000000), Color(0x77000000), Colors.transparent],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 9.0));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 9.0), topShadow);

    // 5. Inset Left Cast Shadow
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

    canvas.drawLine(
      Offset(2, size.height - 0.7),
      Offset(size.width - 2, size.height - 0.7),
      lipPaint,
    );
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
            Transform.translate(
              offset: shadowOffset,
              child: Image.asset(
                'assets/images/pieces/piece_x_shadow.png',
                fit: BoxFit.contain,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
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
            Transform.translate(
              offset: shadowOffset,
              child: Image.asset(
                'assets/images/pieces/piece_o_shadow.png',
                fit: BoxFit.contain,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
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

// -----------------------------------------------------------------------------
// TACTILE 3D WOODEN BUTTONS & CONTROLS
// -----------------------------------------------------------------------------

/// Classic tactile wooden action buttons with 3D bevel and press feedback
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
    return SizedBox(
      key: widget.buttonKey,
      height: 44.0,
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
              offset: const Offset(0, 3.0),
              blurRadius: _isPressed ? 3 : 5,
            ),
            BoxShadow(
              color: _isPressed
                  ? const Color(0x11FFE082)
                  : const Color(0x33FFE082),
              offset: const Offset(0, -1),
              blurRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            canRequestFocus: false,
            onTap: widget.onPressed,
            onHighlightChanged: (value) => setState(() => _isPressed = value),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
    );
  }
}

/// Circular tactile wooden back button matching the design aesthetic
class PhysicalWoodBackButton extends StatelessWidget {
  final Key? buttonKey;
  final VoidCallback onPressed;
  final String tooltip;

  const PhysicalWoodBackButton({
    super.key,
    this.buttonKey,
    required this.onPressed,
    this.tooltip = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
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
        key: buttonKey,
        focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 19,
          color: Color(0xFFFDE68A),
        ),
        tooltip: tooltip,
      ),
    );
  }
}

/// Circular tactile sound toggle button
class PhysicalWoodSoundButton extends StatelessWidget {
  final Key? buttonKey;
  final bool isMuted;
  final VoidCallback onToggle;

  const PhysicalWoodSoundButton({
    super.key,
    this.buttonKey,
    required this.isMuted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
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
        key: buttonKey ?? const Key('sound_button'),
        focusNode: FocusNode(skipTraversal: true, canRequestFocus: false),
        padding: EdgeInsets.zero,
        onPressed: onToggle,
        icon: Icon(
          isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          size: 18,
          color: const Color(0xFFFDE68A),
        ),
        tooltip: isMuted ? 'Unmute' : 'Mute',
      ),
    );
  }
}
