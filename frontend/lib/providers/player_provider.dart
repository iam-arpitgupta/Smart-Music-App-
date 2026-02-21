import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import '../providers/library_provider.dart';
import '../services/api_service.dart';
import '../services/audio_handler.dart';

/// Global instance of the audio handler — set during app initialization.
late final MusicAudioHandler audioHandler;

/// Provider for the API service.
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// ─── Player State ─────────────────────────────────────────────

/// The currently playing track (null if nothing loaded).
final currentTrackProvider = StateProvider<Track?>((ref) => null);

/// Whether the player is currently loading a new track.
final isLoadingProvider = StateProvider<bool>((ref) => false);

/// Stream provider for the playing state (true/false).
final playingStreamProvider = StreamProvider<bool>((ref) {
  return audioHandler.player.playingStream;
});

/// Stream provider for the current playback position.
final positionStreamProvider = StreamProvider<Duration>((ref) {
  return audioHandler.player.positionStream;
});

/// Stream provider for the total duration of the current track.
final durationStreamProvider = StreamProvider<Duration?>((ref) {
  return audioHandler.player.durationStream;
});

/// Stream provider for the buffered position.
final bufferedPositionStreamProvider = StreamProvider<Duration>((ref) {
  return audioHandler.player.bufferedPositionStream;
});

/// Stream provider for the player processing state.
final processingStateStreamProvider = StreamProvider<ProcessingState>((ref) {
  return audioHandler.player.processingStateStream;
});

// ─── Queue & Autoplay ─────────────────────────────────────────

/// Shuffle mode toggle.
final shuffleProvider = StateProvider<bool>((ref) => false);

/// Repeat mode: 0=off, 1=repeat-all, 2=repeat-one
final repeatModeProvider = StateProvider<int>((ref) => 0);

/// Queue state — a list of tracks and the current index.
class QueueNotifier extends StateNotifier<List<Track>> {
  QueueNotifier() : super([]);

  int _currentIndex = -1;
  int get currentIndex => _currentIndex;

  /// Set the queue and start playing from a given index.
  void setQueue(List<Track> tracks, int startIndex) {
    state = tracks;
    _currentIndex = startIndex;
  }

  /// Add tracks to end of queue.
  void addToQueue(List<Track> tracks) {
    state = [...state, ...tracks];
  }

  /// Clear the queue.
  void clear() {
    state = [];
    _currentIndex = -1;
  }

  /// Advance to next track. Returns the track or null if at end.
  Track? next({bool shuffle = false, int repeatMode = 0}) {
    if (state.isEmpty) return null;

    if (repeatMode == 2) {
      // Repeat one — replay current
      return state[_currentIndex];
    }

    if (shuffle) {
      // Pick a random track that isn't the current one
      if (state.length == 1) return state[0];
      int nextIdx;
      do {
        nextIdx = Random().nextInt(state.length);
      } while (nextIdx == _currentIndex);
      _currentIndex = nextIdx;
      return state[_currentIndex];
    }

    // Normal sequential
    if (_currentIndex < state.length - 1) {
      _currentIndex++;
      return state[_currentIndex];
    } else if (repeatMode == 1) {
      // Repeat all — wrap to beginning
      _currentIndex = 0;
      return state[_currentIndex];
    }

    return null; // End of queue, no repeat
  }

  /// Go to previous track.
  Track? previous() {
    if (state.isEmpty) return null;
    if (_currentIndex > 0) {
      _currentIndex--;
      return state[_currentIndex];
    }
    // Wrap to end if at beginning
    _currentIndex = state.length - 1;
    return state[_currentIndex];
  }
}

final queueProvider = StateNotifierProvider<QueueNotifier, List<Track>>(
  (ref) => QueueNotifier(),
);

// ─── Play Actions ─────────────────────────────────────────────

/// Plays a [Track] by fetching its stream URL from the backend.
Future<void> playTrack(WidgetRef ref, Track track) async {
  ref.read(isLoadingProvider.notifier).state = true;
  ref.read(currentTrackProvider.notifier).state = track;

  try {
    final api = ref.read(apiServiceProvider);
    final streamUrl = await api.getStreamUrl(track.videoId);

    await audioHandler.playFromUrl(
      url: streamUrl,
      title: track.title,
      artist: track.artist,
      artUri: track.thumbnail,
    );
  } catch (e) {
    ref.read(currentTrackProvider.notifier).state = null;
    rethrow;
  } finally {
    ref.read(isLoadingProvider.notifier).state = false;
  }
}

/// Play a track and set the queue context (e.g. from a search results list).
Future<void> playTrackWithQueue(
    WidgetRef ref, Track track, List<Track> queue) async {
  final idx = queue.indexWhere((t) => t.videoId == track.videoId);
  ref.read(queueProvider.notifier).setQueue(queue, idx >= 0 ? idx : 0);
  await playTrack(ref, track);
}

/// Skip to next track in queue.
Future<void> skipNext(WidgetRef ref) async {
  final shuffle = ref.read(shuffleProvider);
  final repeat = ref.read(repeatModeProvider);
  final next = ref.read(queueProvider.notifier).next(
        shuffle: shuffle,
        repeatMode: repeat,
      );
  if (next != null) {
    await playTrack(ref, next);
    ref.read(recentlyPlayedImporter).addTrack(next);
  }
}

/// Skip to previous track in queue.
Future<void> skipPrevious(WidgetRef ref) async {
  // If more than 3 seconds in, restart current track instead
  final pos = audioHandler.player.position;
  if (pos.inSeconds > 3) {
    await audioHandler.seek(Duration.zero);
    return;
  }
  final prev = ref.read(queueProvider.notifier).previous();
  if (prev != null) {
    await playTrack(ref, prev);
  }
}

// ─── Recently Played (import helper) ─────────────────────────

final recentlyPlayedImporter = Provider<RecentlyPlayedNotifier>((ref) {
  return ref.read(recentlyPlayedProvider.notifier);
});

// ─── Autoplay Initializer ────────────────────────────────────

/// Call this once during app startup to listen for track completion
/// and auto-advance to next track.
void initAutoplay(WidgetRef ref) {
  audioHandler.player.processingStateStream.listen((state) {
    if (state == ProcessingState.completed) {
      skipNext(ref);
    }
  });
}
