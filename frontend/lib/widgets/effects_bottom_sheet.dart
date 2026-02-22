import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../main.dart';
import '../providers/player_provider.dart';

/// Shows a dark-themed bottom sheet with Bass Boost and Loudness controls.
void showEffectsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _EffectsSheet(),
  );
}

class _EffectsSheet extends StatefulWidget {
  const _EffectsSheet();

  @override
  State<_EffectsSheet> createState() => _EffectsSheetState();
}

class _EffectsSheetState extends State<_EffectsSheet> {
  // Loudness
  bool _loudnessEnabled = false;
  double _loudnessGain = 0.0; // dB, range: -1 to 15

  // Bass boost (EQ low band)
  bool _bassEnabled = false;
  double _bassGain = 0.0; // range: 0.0 to 1.0 (normalized)

  // EQ parameters (loaded asynchronously on Android)
  AndroidEqualizerParameters? _eqParams;

  @override
  void initState() {
    super.initState();
    _initEffects();
  }

  Future<void> _initEffects() async {
    if (kIsWeb) return;

    final loudness = audioHandler.loudnessEnhancer;
    final eq = audioHandler.equalizer;

    if (loudness != null) {
      _loudnessEnabled = loudness.enabled;
      _loudnessGain = loudness.targetGain;
    }

    if (eq != null) {
      _bassEnabled = eq.enabled;
      try {
        _eqParams = await eq.parameters;
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  // ─── Loudness ──────────────────────────────────────────────

  Future<void> _toggleLoudness(bool value) async {
    setState(() => _loudnessEnabled = value);
    final loudness = audioHandler.loudnessEnhancer;
    if (loudness == null) return;
    await loudness.setEnabled(value);
  }

  Future<void> _setLoudnessGain(double db) async {
    setState(() => _loudnessGain = db);
    final loudness = audioHandler.loudnessEnhancer;
    if (loudness == null) return;
    await loudness.setTargetGain(db);
  }

  // ─── Bass ──────────────────────────────────────────────────

  Future<void> _toggleBass(bool value) async {
    setState(() => _bassEnabled = value);
    final eq = audioHandler.equalizer;
    if (eq == null) return;
    await eq.setEnabled(value);
  }

  Future<void> _setBassGain(double normalized) async {
    setState(() => _bassGain = normalized);
    if (_eqParams == null) return;

    final bands = _eqParams!.bands;
    if (bands.isEmpty) return;

    // Boost only the lowest 2 frequency bands (typically 60Hz and 230Hz)
    final minGain = _eqParams!.minDecibels;
    final maxGain = _eqParams!.maxDecibels;
    final range = maxGain - minGain;

    for (int i = 0; i < bands.length && i < 2; i++) {
      // Scale: first band gets full boost, second gets 60%
      final scale = i == 0 ? 1.0 : 0.6;
      final gain = minGain + (range * normalized * scale);
      await bands[i].setGain(gain.clamp(minGain, maxGain));
    }
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAvailable = !kIsWeb;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.equalizer_rounded,
                    color: kAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Audio Effects',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kTextWhite,
                ),
              ),
            ],
          ),

          if (!isAvailable) ...[
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: kAccent, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Audio effects require Android. '
                      'Build & run on an Android device to enable '
                      'Bass Boost and Loudness Enhancement.',
                      style: TextStyle(
                        fontSize: 12,
                        color: kTextMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 8),

          // ─── Loudness Enhancer ──────────────────────────────
          _EffectSection(
            icon: Icons.volume_up_rounded,
            title: 'Loudness Enhancer',
            subtitle: '${_loudnessGain.toStringAsFixed(1)} dB',
            enabled: _loudnessEnabled,
            available: isAvailable,
            onToggle: _toggleLoudness,
            child: _StyledSlider(
              value: _loudnessGain,
              min: -1,
              max: 15,
              enabled: _loudnessEnabled && isAvailable,
              label: '${_loudnessGain.toStringAsFixed(1)} dB',
              onChanged: _setLoudnessGain,
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Color(0xFF2A2A2A), height: 1),
          ),

          // ─── Bass Boost ────────────────────────────────────
          _EffectSection(
            icon: Icons.graphic_eq_rounded,
            title: 'Bass Boost',
            subtitle: '${(_bassGain * 100).toInt()}%',
            enabled: _bassEnabled,
            available: isAvailable,
            onToggle: _toggleBass,
            child: _StyledSlider(
              value: _bassGain,
              min: 0,
              max: 1,
              enabled: _bassEnabled && isAvailable,
              label: '${(_bassGain * 100).toInt()}%',
              onChanged: _setBassGain,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────

class _EffectSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool available;
  final ValueChanged<bool> onToggle;
  final Widget child;

  const _EffectSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.available,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: enabled ? kAccent : kTextMuted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: enabled ? kTextWhite : kTextMuted,
                      ),
                    ),
                    if (enabled)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: kAccent.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: available ? onToggle : null,
                activeColor: kAccent,
                activeTrackColor: kAccent.withOpacity(0.3),
                inactiveThumbColor: const Color(0xFF555555),
                inactiveTrackColor: const Color(0xFF333333),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _StyledSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final String label;
  final ValueChanged<double> onChanged;

  const _StyledSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: enabled ? kAccent : const Color(0xFF444444),
        inactiveTrackColor: const Color(0xFF2A2A2A),
        thumbColor: enabled ? kAccent : const Color(0xFF555555),
        overlayColor: kAccent.withOpacity(0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
