import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../models/artist.dart';
import '../providers/player_provider.dart';

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


// Inject the repository class that makes HTTP calls.
final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final api = ref.read(apiServiceProvider);
  final rand = Random();

  final trackQueries = [
    'trending hits', 'top pop 2024', 'global top 50', 'indie mix', 'lofi beats',
    'chill vibes', 'hip hop hits', 'rock classics', 'latest edm', 'acoustic covers'
  ];
  
  final artistQueries = [
    'top pop artists', 'famous rock bands', 'popular indie artists', 
    'hip hop legends', 'trending edm djs', 'r&b superstars', 'jazz icons'
  ];

  final albumTitles = [
    'LATEST HITS', 'TOP PICKS', 'ESSENTIALS', 'DISCOVER', 'DAILY MIX', 'FRESH FINDS'
  ];

  final tQuery = trackQueries[rand.nextInt(trackQueries.length)];
  final aQuery = artistQueries[rand.nextInt(artistQueries.length)];
  final randomAlbum = albumTitles[rand.nextInt(albumTitles.length)];

  // Fetch real data from the backend proxy
  try {
    final tracks = await api.searchTracks(tQuery, limit: 4);
    final artists = await api.searchArtists(aQuery, limit: 8);

    // Shuffle artists to pick a random hero
    final shuffledArtists = List<Artist>.from(artists)..shuffle(rand);

    Artist hero = shuffledArtists.isNotEmpty 
        ? shuffledArtists.first 
        : const Artist(browseId: '', name: 'TOP CHARTS', thumbnail: 'https://images.unsplash.com/photo-1493225457124-a1a2a4f4e1f7?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80', subscribers: 'Millions of Listeners');

    return HomeData(
      heroArtist: hero,
      heroAlbum: randomAlbum,
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
