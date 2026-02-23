import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';
import 'effects_bottom_sheet.dart';
import 'animated_glowing_border.dart';

/// Full-width bottom player bar: Now Playing | Controls + Slider | Volume
class BottomPlayer extends ConsumerWidget {
  const BottomPlayer({super.key});

  String _fmt(Duration? d) {
    if (d == null) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(playingStreamProvider).valueOrNull ?? false;
    final position =
        ref.watch(positionStreamProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).valueOrNull;
    final shuffle = ref.watch(shuffleProvider);
    final repeatMode = ref.watch(repeatModeProvider);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kDivider, width: 0.5)),
      ),
      child: track == null
          ? Center(
              child: Text(
                'No track playing — search for music to begin',
                style: TextStyle(color: kTextMuted, fontSize: 13),
              ),
            )
          : Row(
              children: [
                // ─── Left: Now Playing Info ─────────────────────
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const NowPlayingScreen(),
                    ));
                  },
                  child: SizedBox(
                    width: 280,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: track.thumbnail != null
                                  ? Image.network(
                                      track.thumbnail!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _artPlaceholder(),
                                    )
                                  : _artPlaceholder(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kTextWhite,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite_border_rounded,
                                size: 18),
                            color: kTextMuted,
                            onPressed: () {},
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Center: Controls + Slider ──────────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Shuffle button
                          IconButton(
                            icon: const Icon(Icons.shuffle_rounded, size: 18),
                            color: shuffle ? kAccent : kTextMuted,
                            onPressed: () {
                              ref.read(shuffleProvider.notifier).state =
                                  !shuffle;
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                          // Skip previous
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded,
                                size: 24),
                            color: kTextWhite,
                            onPressed: () => skipPrevious(ref),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          // Play / Pause
                          AnimatedGlowingBorder(
                            isPlaying: isPlaying,
                            borderWidth: 2.0,
                            borderRadius: 18.0,
                            child: GestureDetector(
                              onTap: () {
                                isPlaying
                                    ? audioHandler.pause()
                                    : audioHandler.play();
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kAccent,
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 22,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Skip next
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded,
                                size: 24),
                            color: kTextWhite,
                            onPressed: () => skipNext(ref),
                            visualDensity: VisualDensity.compact,
                          ),
                          // Repeat button
                          IconButton(
                            icon: Icon(
                              repeatMode == 2
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              size: 18,
                            ),
                            color: repeatMode > 0 ? kAccent : kTextMuted,
                            onPressed: () {
                              ref.read(repeatModeProvider.notifier).state =
                                  (repeatMode + 1) % 3;
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 16,
                        child: Row(
                          children: [
                            const SizedBox(width: 60),
                            Text(_fmt(position),
                                style: const TextStyle(
                                    fontSize: 10, color: kTextMuted)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape:
                                      const RoundSliderThumbShape(
                                          enabledThumbRadius: 4),
                                  overlayShape:
                                      const RoundSliderOverlayShape(
                                          overlayRadius: 10),
                                ),
                                child: Slider(
                                  value: position.inMilliseconds
                                      .toDouble()
                                      .clamp(
                                        0.0,
                                        (duration?.inMilliseconds ?? 1)
                                            .toDouble(),
                                      ),
                                  max: (duration?.inMilliseconds ?? 1)
                                      .toDouble(),
                                  onChanged: (v) {
                                    audioHandler.seek(
                                        Duration(milliseconds: v.toInt()));
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_fmt(duration),
                                style: const TextStyle(
                                    fontSize: 10, color: kTextMuted)),
                            const SizedBox(width: 60),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Right: Volume + extras ─────────────────────
                SizedBox(
                  width: 280,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.queue_music_rounded, size: 18),
                        color: kTextMuted,
                        onPressed: () {},
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.equalizer_rounded, size: 18),
                        color: kTextMuted,
                        onPressed: () => showEffectsSheet(context),
                        tooltip: 'Audio Effects',
                        visualDensity: VisualDensity.compact,
                      ),
                      const Icon(Icons.volume_up_rounded,
                          size: 16, color: kTextMuted),
                      SizedBox(
                        width: 100,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 4),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10),
                          ),
                          child: Slider(
                            value: 0.7,
                            onChanged: (v) {
                              audioHandler.player.setVolume(v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _artPlaceholder() {
    return Container(
      color: kCardDark,
      child: const Icon(Icons.music_note_rounded, size: 20, color: kTextMuted),
    );
  }
}
