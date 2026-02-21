import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

/// Custom AudioHandler that bridges audio_service (background playback,
/// media notification, audio focus) with just_audio (ExoPlayer on Android).
class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  late final AudioPlayer _player;

  // Audio effects — Android only, null on web/other platforms.
  AndroidLoudnessEnhancer? _loudnessEnhancer;
  AndroidEqualizer? _equalizer;

  MusicAudioHandler() {
    // Set up audio effects pipeline (Android only).
    if (!kIsWeb) {
      _loudnessEnhancer = AndroidLoudnessEnhancer();
      _equalizer = AndroidEqualizer();
      _player = AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [_loudnessEnhancer!, _equalizer!],
        ),
      );
    } else {
      _player = AudioPlayer();
    }

    // Forward player state changes to audio_service so the media notification
    // and lock-screen controls stay in sync.
    _player.playbackEventStream.listen(_broadcastState);

    // Update duration when it becomes known.
    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });
  }

  AudioPlayer get player => _player;
  AndroidLoudnessEnhancer? get loudnessEnhancer => _loudnessEnhancer;
  AndroidEqualizer? get equalizer => _equalizer;

  // ─── Transport Controls ─────────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Load a track by its direct stream URL and populate the media notification.
  Future<void> playFromUrl({
    required String url,
    required String title,
    required String artist,
    String? artUri,
  }) async {
    // Set the media item metadata (shows in notification / lock-screen).
    // On web, skip artUri — media notifications aren't supported and
    // flutter_cache_manager causes 429 errors with Google CDN URLs.
    mediaItem.add(MediaItem(
      id: url,
      title: title,
      artist: artist,
      artUri: kIsWeb ? null : (artUri != null ? Uri.parse(artUri) : null),
    ));

    // Load and play the audio.
    await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
    _player.play();
  }

  // ─── Internal ───────────────────────────────────────────────

  void _broadcastState(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}
