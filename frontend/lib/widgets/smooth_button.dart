import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A premium, buttery smooth button that subtly scales down when pressed
/// to provide a high-quality tactile feel.
class SmoothButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  
  const SmoothButton({
    Key? key,
    required this.child,
    required this.onTap,
  }) : super(key: key);

  @override
  State<SmoothButton> createState() => _SmoothButtonState();
}

class _SmoothButtonState extends State<SmoothButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Padding(
          // Ensure a large enough hit target (min 48x48 typical)
          padding: const EdgeInsets.all(12.0),
          child: widget.child,
        ),
      ),
    );
  }
}
