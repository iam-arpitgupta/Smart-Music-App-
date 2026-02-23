import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A standalone wrapper that creates an n8n-style rotating "comet tail" 
/// neon border around any child widget.
class RotatingGlowingBorder extends StatefulWidget {
  final Widget child;
  final Stream<bool> isPlayingStream;
  final double borderWidth;
  final Color baseColor;

  const RotatingGlowingBorder({
    Key? key,
    required this.child,
    required this.isPlayingStream,
    this.borderWidth = 3.0,
    this.baseColor = Colors.amber,
  }) : super(key: key);

  @override
  State<RotatingGlowingBorder> createState() => _RotatingGlowingBorderState();
}

class _RotatingGlowingBorderState extends State<RotatingGlowingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription<bool>? _subscription;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // 2. The Animation Controller (roughly 2 seconds, linear)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // 1. The Async State listening to the stream
    _subscription = widget.isPlayingStream.listen((isPlaying) {
      if (isPlaying) {
        if (mounted) setState(() => _isVisible = true);
        _controller.repeat();
      } else {
        if (mounted) setState(() => _isVisible = false);
        _controller.stop();
        _controller.value = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 5. Sizing: Orbit slightly outside the button boundary
        if (_isVisible)
          Positioned(
            top: -6.0,
            bottom: -6.0,
            left: -6.0,
            right: -6.0,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // 4. Transform.rotate driven by animation controller
                return Transform.rotate(
                  angle: _controller.value * 2 * math.pi,
                  child: CustomPaint(
                    painter: _CometTailPainter(
                      strokeWidth: widget.borderWidth,
                      baseColor: widget.baseColor,
                    ),
                  ),
                );
              },
            ),
          ),
        
        // Original Widget
        widget.child,
      ],
    );
  }
}

class _CometTailPainter extends CustomPainter {
  final double strokeWidth;
  final Color baseColor;

  _CometTailPainter({
    required this.strokeWidth,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2, 
      strokeWidth / 2, 
      size.width - strokeWidth, 
      size.height - strokeWidth
    );

    // 3. The Comet Tail (SweepGradient)
    final sweepGradient = SweepGradient(
      colors: [
        Colors.transparent,
        baseColor.withOpacity(0.4),
        baseColor,
        Colors.white,
      ],
      stops: const [0.0, 0.6, 0.95, 1.0], // Compresses the head of the comet
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      // 3. The Glow: Neon aura effect
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 5.0);

    canvas.drawArc(rect, 0.0, 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _CometTailPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.baseColor != baseColor;
  }
}
