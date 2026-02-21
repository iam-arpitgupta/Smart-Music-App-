import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../database/db_helper.dart';

/// In-memory list of recently played tracks (max 20, most recent first).
class RecentlyPlayedNotifier extends StateNotifier<List<Track>> {
  RecentlyPlayedNotifier() : super([]);

  void addTrack(Track track) {
    // Remove if already present, then prepend.
    state = [
      track,
      ...state.where((t) => t.videoId != track.videoId),
    ].take(20).toList();
  }
}

final recentlyPlayedProvider =
    StateNotifierProvider<RecentlyPlayedNotifier, List<Track>>(
  (ref) => RecentlyPlayedNotifier(),
);

/// Favorites backed by SQLite.
final favoritesProvider = FutureProvider<List<Track>>((ref) async {
  final db = DbHelper.instance;
  return db.getFavorites();
});

/// Check if a track is favorited.
final isFavoriteProvider = FutureProvider.family<bool, String>((ref, videoId) async {
  final db = DbHelper.instance;
  return db.isFavorite(videoId);
});
