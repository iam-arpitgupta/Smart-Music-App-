import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/player_provider.dart';
import 'services/audio_handler.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  audioHandler = await AudioService.init(
    builder: () => MusicAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.musicapp.frontend.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(const ProviderScope(child: MusicApp()));
}

// ─── Design tokens ──────────────────────────────────────────────
const Color kBgDark      = Color(0xFF0D0D0D);
const Color kSurface     = Color(0xFF161616);
const Color kCardDark    = Color(0xFF1C1C1E);
const Color kSidebar     = Color(0xFF111111);
const Color kAccent      = Color(0xFFE8A838); // amber / orange
const Color kAccentDark  = Color(0xFFC48820);
const Color kTextWhite   = Color(0xFFFFFFFF);
const Color kTextMuted   = Color(0xFF8E8E93);
const Color kDivider     = Color(0xFF2C2C2E);

// ─── Dynamic gradient presets ───────────────────────────────────
final List<List<Color>> _gradientPresets = [
  [const Color(0xFF1A0E00), const Color(0xFF0D0D0D)], // warm amber
  [const Color(0xFF1A1000), const Color(0xFF0D0D0D)], // golden dark
  [const Color(0xFF0D1A0F), const Color(0xFF0D0D0D)], // forest dim
  [const Color(0xFF0D0F1A), const Color(0xFF0D0D0D)], // midnight blue
  [const Color(0xFF1A0D14), const Color(0xFF0D0D0D)], // berry dark
  [const Color(0xFF1A1408), const Color(0xFF0D0D0D)], // bronze
  [const Color(0xFF14100D), const Color(0xFF0D0D0D)], // cocoa
  [const Color(0xFF0D1518), const Color(0xFF0D0D0D)], // teal dark
];

/// Randomly selected on each app initialization.
final List<Color> appGradientColors =
    _gradientPresets[Random().nextInt(_gradientPresets.length)];

class MusicApp extends ConsumerStatefulWidget {
  const MusicApp({super.key});

  @override
  ConsumerState<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends ConsumerState<MusicApp> {
  @override
  void initState() {
    super.initState();
    // Start listening for track completion to auto-advance queue
    initAutoplay(ref);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AppShell(),
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: kBgDark,
      colorScheme: const ColorScheme.dark(
        primary: kAccent,
        onPrimary: Color(0xFF1A1A1A),
        secondary: kAccent,
        surface: kBgDark,
        onSurface: kTextWhite,
        onSurfaceVariant: kTextMuted,
        surfaceContainerHighest: kCardDark,
        surfaceContainer: kSurface,
        outline: kDivider,
        outlineVariant: kDivider,
        error: Color(0xFFCF6679),
      ),
      cardColor: kCardDark,
      dividerColor: kDivider,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700, color: kTextWhite, fontSize: 26,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700, color: kTextWhite, fontSize: 22,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700, color: kTextWhite, fontSize: 18,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600, color: kTextWhite,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: kTextWhite),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: kTextMuted),
        bodySmall: textTheme.bodySmall?.copyWith(color: kTextMuted),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: kAccent,
        inactiveTrackColor: kDivider,
        thumbColor: kAccent,
        overlayColor: kAccent.withValues(alpha: 0.15),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      iconTheme: const IconThemeData(color: kTextMuted),
    );
  }
}
