import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A wrapper widget that conditionally paints an animated, rotating 
/// sweep-gradient glowing border around any child widget.
class AnimatedGlowingBorder extends StatefulWidget {
  final Widget child;
  final bool isPlaying;
  final double borderWidth;
  final Color glowColor;
  final double borderRadius;

  const AnimatedGlowingBorder({
    Key? key,
    required this.child,
    required this.isPlaying,
    this.borderWidth = 3.0,
    this.glowColor = Colors.amber, // Highlighting accent from the UI
    this.borderRadius = 100.0, // High enough for total circle default
  }) : super(key: key);

  @override
  State<AnimatedGlowingBorder> createState() => _AnimatedGlowingBorderState();
}

class _AnimatedGlowingBorderState extends State<AnimatedGlowingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Rotate speed
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedGlowingBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      // Smoothly wind down and wait to disappear, 
      // or stop immediately:
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(widget.isPlaying ? widget.borderWidth : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: widget.isPlaying
            ? [
                BoxShadow(
                  color: widget.glowColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ─── Rotating Gradient Border Layer ───
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // If stopped and reset, don't waste render cycles
                if (!widget.isPlaying && _controller.value == 0.0) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  painter: _GlowingBorderPainter(
                    progress: _controller.value,
                    borderWidth: widget.borderWidth,
                    color: widget.glowColor,
                    borderRadius: widget.borderRadius,
                  ),
                );
              },
            ),
          ),
          // ─── The actual Original Button ───
          widget.child,
        ],
      ),
    );
  }
}

class _GlowingBorderPainter extends CustomPainter {
  final double progress;
  final double borderWidth;
  final Color color;
  final double borderRadius;

  _GlowingBorderPainter({
    required this.progress,
    required this.borderWidth,
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // If not animating, don't paint the stroke
    if (progress == 0.0) return;

    // Define the bounding box for the stroke, inset by half the stroke width
    final rect = Rect.fromLTWH(
      borderWidth / 2, 
      borderWidth / 2, 
      size.width - borderWidth, 
      size.height - borderWidth,
    );
    
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Create a SweepGradient that perfectly wraps around
    final sweepGradient = SweepGradient(
      colors: [
        Colors.transparent,
        Colors.transparent,
        color.withOpacity(0.5),
        color,
      ],
      stops: const [0.0, 0.5, 0.9, 1.0],
      transform: GradientRotation(progress * 2 * math.pi), // Drive rotation
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round; // Soft edges for the head of the light

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowingBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.borderWidth != borderWidth;
  }
}
