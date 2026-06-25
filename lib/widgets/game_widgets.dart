import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class EmberParticle {
  double x;
  double y;
  double size;
  double speed;
  double angle;
  double opacity;
  double angleSpeed;

  EmberParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.angle,
    required this.opacity,
    required this.angleSpeed,
  });
}

class EmbersBackground extends StatefulWidget {
  final Widget child;
  const EmbersBackground({super.key, required this.child});

  @override
  State<EmbersBackground> createState() => _EmbersBackgroundState();
}

class _EmbersBackgroundState extends State<EmbersBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<EmberParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Generate initial particles scattered across the screen height
    for (int i = 0; i < 35; i++) {
      _particles.add(_createParticle(isInitial: true));
    }
  }

  EmberParticle _createParticle({bool isInitial = false}) {
    return EmberParticle(
      x: _random.nextDouble(),
      y: isInitial ? _random.nextDouble() : 1.1,
      size: _random.nextDouble() * 5 + 1.5,
      speed: _random.nextDouble() * 0.04 + 0.015,
      angle: _random.nextDouble() * pi * 2,
      angleSpeed: (_random.nextDouble() - 0.5) * 1.5,
      opacity: _random.nextDouble() * 0.6 + 0.2,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.y -= p.speed * 0.05; // slow rising
      p.x += sin(p.angle) * 0.0006;
      p.angle += p.angleSpeed * 0.01;

      // Recycle offscreen
      if (p.y < -0.1 || p.x < -0.1 || p.x > 1.1) {
        _particles[i] = _createParticle();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Parchment paper backing with rich golden-brown gradient
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFFF2DFBD), // Warm light parchment cream in center
                  Color(0xFFB58B5C), // Rich warm golden-brown oak wood at edges
                ],
                center: Alignment.center,
                radius: 1.1,
              ),
            ),
            child: Opacity(
              opacity: 0.82,
              child: Image.asset(
                'assets/parchment_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // Slow Rotating Ambient Rays
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: AmbientRaysPainter(rotationAngle: _controller.value * 2 * pi),
              );
            },
          ),
        ),
        // Glow gradient backplate
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  const Color(0xFFFFD54F).withOpacity(0.25),
                  const Color(0xFFFAF6EE).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Drifting Embers Custom Painter
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              _updateParticles();
              return CustomPaint(
                painter: EmbersPainter(particles: _particles),
              );
            },
          ),
        ),
        // Forefront Child
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class AmbientRaysPainter extends CustomPainter {
  final double rotationAngle;
  AmbientRaysPainter({required this.rotationAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = max(size.width, size.height) * 1.3;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD54F).withOpacity(0.08),
          const Color(0xFFFFD54F).withOpacity(0.01),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle * 0.05); // Very slow rotation

    const int rayCount = 12;
    const double rayAngle = (2 * pi) / rayCount;

    for (int i = 0; i < rayCount; i++) {
      final double angle = i * rayAngle;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(radius * cos(angle - rayAngle / 5), radius * sin(angle - rayAngle / 5))
        ..lineTo(radius * cos(angle + rayAngle / 5), radius * sin(angle + rayAngle / 5))
        ..close();
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AmbientRaysPainter oldDelegate) =>
      oldDelegate.rotationAngle != rotationAngle;
}

class EmbersPainter extends CustomPainter {
  final List<EmberParticle> particles;
  EmbersPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final posX = p.x * size.width;
      final posY = p.y * size.height;

      // Radial Glow gradient
      final radialGlow = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE87A24).withOpacity(p.opacity * 0.6),
            const Color(0xFFFFD54F).withOpacity(p.opacity * 0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(posX, posY), radius: p.size * 2.8));

      canvas.drawCircle(Offset(posX, posY), p.size * 2.8, radialGlow);

      // Bright Core
      paint.color = const Color(0xFFFFEE58).withOpacity(p.opacity);
      canvas.drawCircle(Offset(posX, posY), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GameButton3D extends StatefulWidget {
  final VoidCallback? onTap;
  final String text;
  final Color color;
  final double width;
  final double height;
  final TextStyle? textStyle;

  const GameButton3D({
    super.key,
    required this.onTap,
    required this.text,
    this.color = const Color(0xFFE87A24),
    this.width = double.infinity,
    this.height = 42, // Shorter default height (was 50)
    this.textStyle,
  });

  @override
  State<GameButton3D> createState() => _GameButton3DState();
}

class _GameButton3DState extends State<GameButton3D> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double depth = 4.0.h; // Reduced depth (was 5)
    final isEnabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: SizedBox(
        width: widget.width,
        height: widget.height.h + depth,
        child: Stack(
          children: [
            // Dark base baseplate
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: widget.height.h,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF271308),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFF271308), width: 1.5.w),
                ),
              ),
            ),
            // Main Button Surface
            AnimatedPositioned(
              duration: const Duration(milliseconds: 50),
              top: _isPressed ? depth : 0,
              left: 0,
              right: 0,
              height: widget.height.h,
              child: Container(
                decoration: BoxDecoration(
                  color: isEnabled ? widget.color : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFF271308), width: 1.5.w),
                  boxShadow: [
                    if (!_isPressed && isEnabled)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 3,
                        offset: Offset(0, 3.h),
                      ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.textStyle ?? GoogleFonts.outfit(
                      fontSize: 13.sp, // Smaller default font size (was 15)
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
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
}

class GameBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const GameBounce({super.key, required this.child, this.onTap});

  @override
  State<GameBounce> createState() => _GameBounceState();
}

class _GameBounceState extends State<GameBounce> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _controller.forward() : null,
      onTapUp: isEnabled
          ? (_) {
              _controller.reverse();
              widget.onTap!();
            }
          : null,
      onTapCancel: isEnabled ? () => _controller.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class GameShimmerText extends StatefulWidget {
  final String text;
  final double fontSize;
  final Color outlineColor;
  final double strokeWidth;
  final TextAlign textAlign;

  const GameShimmerText({
    super.key,
    required this.text,
    required this.fontSize,
    this.outlineColor = const Color(0xFF3C2415),
    this.strokeWidth = 4.0,
    this.textAlign = TextAlign.center,
  });

  @override
  State<GameShimmerText> createState() => _GameShimmerTextState();
}

class _GameShimmerTextState extends State<GameShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outlined Text Stroke (3D Comic/Game style outline)
            Text(
              widget.text,
              textAlign: widget.textAlign,
              style: GoogleFonts.outfit(
                fontSize: widget.fontSize.sp,
                fontWeight: FontWeight.w900,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = widget.strokeWidth.w
                  ..color = widget.outlineColor,
              ),
            ),
            // Shimmer Overlay inside the text bounds
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: const [
                    Color(0xFFFFD54F),
                    Color(0xFFFFF9C4),
                    Color(0xFFFFD54F),
                    Color(0xFFFFB300),
                    Color(0xFFFFD54F),
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                  transform: GradientRotation(_controller.value * 2 * pi),
                ).createShader(bounds);
              },
              child: Text(
                widget.text,
                textAlign: widget.textAlign,
                style: GoogleFonts.outfit(
                  fontSize: widget.fontSize.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class GameTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final int? maxLength;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;

  const GameTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8D3B9),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF3C2415), width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3C2415).withOpacity(0.06),
            blurRadius: 3,
            offset: Offset(0, 1.5.h),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLength: maxLength,
        textAlign: textAlign,
        textCapitalization: textCapitalization,
        style: GoogleFonts.outfit(
          fontSize: 14.sp, // Smaller font size (was 15)
          fontWeight: FontWeight.bold,
          color: const Color(0xFF3C2415),
        ),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: GoogleFonts.outfit(
            fontSize: 12.sp, // Smaller label size (was 13)
            fontWeight: FontWeight.w800,
            color: const Color(0xFF5D4037).withOpacity(0.8),
          ),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF5D4037), size: 18.sp), // Smaller icon (was 20)
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h), // Shorter padding
          counterText: '',
        ),
      ),
    );
  }
}
