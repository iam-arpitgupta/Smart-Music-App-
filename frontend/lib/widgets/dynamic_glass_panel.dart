import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// A reusable glassmorphism wrapper that automatically tints itself 
/// by extracting the dominant or vibrant color from `albumArtProvider`.
class DynamicGlassPanel extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final ImageProvider? albumArtProvider;

  const DynamicGlassPanel({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 24.0,
    this.albumArtProvider,
  }) : super(key: key);

  @override
  State<DynamicGlassPanel> createState() => _DynamicGlassPanelState();
}

class _DynamicGlassPanelState extends State<DynamicGlassPanel> {
  Color _extractedColor = Colors.transparent;
  bool _isLoadingPalette = true;

  @override
  void initState() {
    super.initState();
    _updatePalette();
  }

  @override
  void didUpdateWidget(DynamicGlassPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.albumArtProvider != oldWidget.albumArtProvider) {
      _updatePalette();
    }
  }

  Future<void> _updatePalette() async {
    if (widget.albumArtProvider == null) {
      if (mounted) {
        setState(() {
          _extractedColor = Colors.transparent;
          _isLoadingPalette = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingPalette = true);
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        widget.albumArtProvider!,
        maximumColorCount: 10,
      );

      // Prefer vibrant over dominant for better glow, fallback to amber
      final newColor = palette.vibrantColor?.color ??
                       palette.dominantColor?.color ??
                       Colors.amber;

      if (mounted) {
        setState(() {
          _extractedColor = newColor;
          _isLoadingPalette = false;
        });
      }
    } catch (e) {
      // Fallback on network errors or parsing failure
      if (mounted) {
        setState(() {
          _extractedColor = Colors.amber;
          _isLoadingPalette = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the glow color.
    final glowColor = widget.albumArtProvider == null || _isLoadingPalette
        ? Colors.amber.withOpacity(0.02)
        : _extractedColor.withOpacity(0.25);

    return Stack(
      children: [
        // 1. The Background Layer (Lowest in Stack)
        // This fills the entire parent container to establish the dynamic environment.
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black, // Dark base
                  glowColor,    // Extracted dynamic tint
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // 2 & 3. The Foreground UI & Glass Pill Implementation
        // Wraps the provided child (controls container) in a distinct, floating frosted glass pill.
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(24.0), // Visibly floating away from edges
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40.0), // High border radius
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0), // Heavy blur effect
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2), // Smoked glass tint
                    borderRadius: BorderRadius.circular(40.0),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15), 
                      width: 1.5, // Physical edge of the glass
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
