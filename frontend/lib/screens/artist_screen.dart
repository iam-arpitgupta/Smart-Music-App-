import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../services/api_service.dart';
import '../main.dart'; // color constants
import '../widgets/track_tile.dart';

class ArtistScreen extends ConsumerStatefulWidget {
  final String artistName;

  const ArtistScreen({super.key, required this.artistName});

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  bool _loading = true;
  String _error = '';

  String? _resolvedArtistName;
  String? _resolvedArtistThumb;
  String? _resolvedArtistSubs;
  String? _resolvedArtistDesc;
  List<Track> _artistSongs = [];

  @override
  void initState() {
    super.initState();
    _fetchArtistProfile();
  }

  Future<void> _fetchArtistProfile() async {
    try {
      final api = ref.read(apiServiceProvider);

      // 1. Search for the root Artist using the raw string
      // Limit to 1, we want the best canonical match
      final searchResults =
          await api.searchArtists(widget.artistName, limit: 1);

      if (searchResults.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error =
                "Could not find a canonical profile for '${widget.artistName}'";
          });
        }
        return;
      }

      final artist = searchResults.first;

      // 2. Load their heavy detail catalog (Songs / Desc)
      final detail = await api.getArtistDetail(artist.browseId);

      if (mounted) {
        setState(() {
          _resolvedArtistName = detail['name'] as String? ?? artist.name;
          _resolvedArtistThumb =
              detail['thumbnail'] as String? ?? artist.thumbnail;
          _resolvedArtistDesc = detail['description'] as String?;
          _resolvedArtistSubs =
              detail['subscribers'] as String? ?? artist.subscribers;
          _artistSongs = (detail['songs'] as List<dynamic>).cast<Track>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load artist profile: $e';
        });
      }
    }
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: kCardDark,
      child: const Icon(Icons.person_rounded, size: 28, color: kTextMuted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kAccent)),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_rounded,
                    size: 64, color: kTextMuted),
                const SizedBox(height: 16),
                Text(_error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: kTextMuted)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header Information ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_back_rounded,
                                  color: kTextWhite, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Artist Avatar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: _resolvedArtistThumb != null
                                ? Image.network(
                                    _resolvedArtistThumb!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatarPlaceholder(),
                                  )
                                : _avatarPlaceholder(),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Name + Sub Count
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _resolvedArtistName ?? widget.artistName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: kTextWhite,
                                ),
                              ),
                              if (_resolvedArtistSubs != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _resolvedArtistSubs!,
                                    style: const TextStyle(
                                        fontSize: 12, color: kTextMuted),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Play All Button
                        if (_artistSongs.isNotEmpty)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                playTrackWithQueue(
                                    ref, _artistSongs.first, _artistSongs);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: kAccent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow_rounded,
                                        color: Colors.black, size: 20),
                                    SizedBox(width: 6),
                                    Text(
                                      'Play All',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Artist Bio/Description
                    if (_resolvedArtistDesc != null &&
                        _resolvedArtistDesc!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Text(
                          _resolvedArtistDesc!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: kTextMuted, height: 1.5),
                        ),
                      ),

                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF2A2A2A), height: 1),

                    // Controls Header (Song count + Shuffle)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Text(
                            '${_artistSongs.length} songs',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kTextMuted,
                            ),
                          ),
                          const Spacer(),
                          if (_artistSongs.isNotEmpty)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  ref.read(shuffleProvider.notifier).state =
                                      true;
                                  playTrackWithQueue(
                                      ref, _artistSongs.first, _artistSongs);
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shuffle_rounded,
                                        size: 16, color: kAccent),
                                    SizedBox(width: 6),
                                    Text('Shuffle',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: kAccent,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Songs List ───
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final track = _artistSongs[i];
                  return TrackTile(
                    track: track,
                    isPlaying: currentTrack?.videoId == track.videoId,
                    onTap: () {
                      playTrackWithQueue(ref, track, _artistSongs);
                      ref.read(recentlyPlayedProvider.notifier).addTrack(track);
                    },
                  );
                },
                childCount: _artistSongs.length,
              ),
            ),
            // Safe bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            )
          ],
        ),
      ),
    );
  }
}
