import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../models/artist.dart';

class HomeData {
  final Artist heroArtist;
  final String heroAlbum;
  final String heroDuration;
  final String heroListeners;
  final String heroImageUrl;
  final List<Track> madeForYou;
  final List<Track> popularSpeckers;

  HomeData({
    required this.heroArtist,
    required this.heroAlbum,
    required this.heroDuration,
    required this.heroListeners,
    required this.heroImageUrl,
    required this.madeForYou,
    required this.popularSpeckers,
  });
}

import '../providers/player_provider.dart';

// Inject the repository class that makes HTTP calls.
final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final api = ref.read(apiServiceProvider);

  // Fetch real data from the backend proxy
  try {
    final tracks = await api.searchTracks('trending hits 2024', limit: 4);
    final artists = await api.searchArtists('top pop artists', limit: 5);

    Artist hero = artists.isNotEmpty 
        ? artists.first 
        : const Artist(browseId: '', name: 'TOP CHARTS', thumbnail: 'https://images.unsplash.com/photo-1493225457124-a1a2a4f4e1f7?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80');

    return HomeData(
      heroArtist: hero,
      heroAlbum: 'LATEST HITS',
      heroDuration: 'Various Playlists',
      heroListeners: hero.subscribers ?? 'Millions of Listeners',
      heroImageUrl: hero.thumbnail ?? 'https://images.unsplash.com/photo-1493225457124-a1a2a4f4e1f7?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80',
      madeForYou: tracks,
      popularSpeckers: artists.map((a) => Track(
        videoId: '', // Representing an artist here, no direct audio videoId
        title: a.name, 
        artist: 'Artist',
        thumbnail: a.thumbnail,
        duration: a.subscribers,
      )).toList(),
    );
  } catch (e) {
    // Fallback if backend is down while developing
    throw Exception('Failed to load real data: \$e');
  }
});
