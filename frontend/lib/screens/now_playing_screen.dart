import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../providers/player_provider.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

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
    final buffered =
        ref.watch(bufferedPositionStreamProvider).valueOrNull ?? Duration.zero;
    final shuffle = ref.watch(shuffleProvider);
    final repeatMode = ref.watch(repeatModeProvider);

    if (track == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('No track selected')),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              kAccent.withValues(alpha: 0.15),
              kBgDark,
            ],
            stops: const [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                      color: kTextWhite,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Now Playing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextWhite,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      color: kTextWhite,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Album art (large rounded square)
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent.withValues(alpha: 0.12),
                      blurRadius: 50,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: track.thumbnail != null
                      ? Image.network(
                          track.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(),
                          loadingBuilder: (_, child, prog) {
                            if (prog == null) return child;
                            return _placeholder();
                          },
                        )
                      : _placeholder(),
                ),
              ),

              const Spacer(flex: 2),

              // Title & artist
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: kTextWhite,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      track.artist,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: kTextMuted),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        secondaryActiveTrackColor: kTextMuted.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: position.inMilliseconds.toDouble().clamp(
                              0, (duration?.inMilliseconds ?? 1).toDouble()),
                        max: (duration?.inMilliseconds ?? 1).toDouble(),
                        secondaryTrackValue: buffered.inMilliseconds.toDouble().clamp(
                              0, (duration?.inMilliseconds ?? 1).toDouble()),
                        onChanged: (v) =>
                            audioHandler.seek(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position),
                              style: const TextStyle(fontSize: 11, color: kTextMuted)),
                          Text(_fmt(duration),
                              style: const TextStyle(fontSize: 11, color: kTextMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle
                  GestureDetector(
                    onTap: () {
                      ref.read(shuffleProvider.notifier).state = !shuffle;
                    },
                    child: Icon(Icons.shuffle_rounded,
                        color: shuffle ? kAccent : kTextMuted, size: 22),
                  ),
                  // Skip previous
                  GestureDetector(
                    onTap: () => skipPrevious(ref),
                    child: const Icon(Icons.skip_previous_rounded,
                        color: kTextWhite, size: 36),
                  ),
                  // Play/Pause
                  GestureDetector(
                    onTap: () =>
                        isPlaying ? audioHandler.pause() : audioHandler.play(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kAccent,
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 34,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // Skip next
                  GestureDetector(
                    onTap: () => skipNext(ref),
                    child: const Icon(Icons.skip_next_rounded,
                        color: kTextWhite, size: 36),
                  ),
                  // Repeat
                  GestureDetector(
                    onTap: () {
                      ref.read(repeatModeProvider.notifier).state =
                          (repeatMode + 1) % 3;
                    },
                    child: Icon(
                      repeatMode == 2
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: repeatMode > 0 ? kAccent : kTextMuted,
                      size: 22,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: kCardDark,
      child: const Center(
        child: Icon(Icons.music_note_rounded, size: 60, color: kTextMuted),
      ),
    );
  }
}
