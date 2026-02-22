import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/artist.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/track_tile.dart';

/// Explore screen — unified search for both songs and artists with live
/// suggestions, plus artist directory (all songs by a selected artist).
class ExploreScreen extends ConsumerStatefulWidget {
  final String? initialFilter;

  const ExploreScreen({super.key, this.initialFilter});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String? _searchFilter;

  @override
  void initState() {
    super.initState();
    _searchFilter = widget.initialFilter;
    
    // Load default content immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaults();
    });
  }

  // ─── Default Content Generator ──────────────────────────────────
  
  void _loadDefaults() {
    final rand = Random();
    String defaultQuery = '';

    if (_searchFilter == 'podcasts') {
      final podcastTopics = [
        'comedy podcasts', 'tech podcasts', 'true crime podcasts', 
        'business podcasts', 'history podcasts', 'interview podcasts'
      ];
      defaultQuery = podcastTopics[rand.nextInt(podcastTopics.length)];
    } else if (_searchFilter == 'videos') {
      final videoTopics = [
        'live music videos', 'trending music videos', 'acoustic sessions',
        'tiny desk concerts', 'pop music videos', 'rock music videos'
      ];
      defaultQuery = videoTopics[rand.nextInt(videoTopics.length)];
    } else {
      final generalTopics = [
        'trending artists', 'top chart hits', 'discover weekly',
        'new releases', 'global top 50', 'viral hits'
      ];
      defaultQuery = generalTopics[rand.nextInt(generalTopics.length)];
    }

    // Run the search silently in the background for defaults
    _runSearch(defaultQuery, isDefaultContent: true);
  }

  // Search results
  List<Artist> _artists = [];
  List<Track> _songs = [];
  bool _isSearching = false;
  String _error = '';

  // Artist detail state
  bool _loadingDetail = false;
  String? _selectedArtistName;
  String? _selectedArtistThumb;
  String? _selectedArtistSubs;
  String? _selectedArtistDesc;
  List<Track> _artistSongs = [];

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Unified Search ─────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _loadDefaults(); // Load random defaults instead of showing blank screen
      return;
    }
    setState(() {}); // Update suffix icon
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query, {bool isDefaultContent = false}) async {
    setState(() {
      _isSearching = true;
      _error = '';
      if (!isDefaultContent) {
        _artists = []; // Clear only if it is an active user search typing
        _songs = [];
      }
    });

    try {
      final api = ref.read(apiServiceProvider);
      // Fire both searches in parallel
      final results = await Future.wait([
        api.searchArtists(query, limit: 5),
        api.searchTracks(query, limit: 10, filterMode: _searchFilter),
      ]);

      if (mounted) {
        setState(() {
          _artists = results[0] as List<Artist>;
          _songs = results[1] as List<Track>;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Search failed. Please try again.';
          _isSearching = false;
        });
      }
    }
  }

  // ─── Artist Detail ──────────────────────────────────────────────

  Future<void> _loadArtist(Artist artist) async {
    setState(() {
      _loadingDetail = true;
      _selectedArtistName = artist.name;
      _selectedArtistThumb = artist.thumbnail;
      _selectedArtistSubs = artist.subscribers;
      _selectedArtistDesc = null;
      _artistSongs = [];
    });

    try {
      final api = ref.read(apiServiceProvider);
      final detail = await api.getArtistDetail(artist.browseId);
      if (mounted) {
        setState(() {
          _selectedArtistName = detail['name'] as String? ?? artist.name;
          _selectedArtistThumb =
              detail['thumbnail'] as String? ?? artist.thumbnail;
          _selectedArtistDesc = detail['description'] as String?;
          _selectedArtistSubs =
              detail['subscribers'] as String? ?? artist.subscribers;
          _artistSongs = (detail['songs'] as List<dynamic>).cast<Track>();
          _loadingDetail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load artist: $e';
          _loadingDetail = false;
        });
      }
    }
  }

  void _clearArtist() {
    setState(() {
      _selectedArtistName = null;
      _selectedArtistThumb = null;
      _selectedArtistSubs = null;
      _selectedArtistDesc = null;
      _artistSongs = [];
    });
  }

  void _clearAll() {
    _searchController.clear();
    _searchFilter = null;
    _clearArtist();
    _loadDefaults();
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);

    return Column(
      children: [
        // ─── Search Bar ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? kAccent.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: kTextWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search songs, artists...',
                hintStyle: TextStyle(color: kTextMuted.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: kTextMuted, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: kTextMuted, size: 18),
                        onPressed: _clearAll,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // ─── Filter Chips ─────────────────────────────────────────
        if (_searchController.text.isNotEmpty || _searchFilter != null)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                _buildFilterChip('All', null),
                const SizedBox(width: 8),
                _buildFilterChip('Songs', 'songs'),
                const SizedBox(width: 8),
                _buildFilterChip('Podcasts', 'podcasts'),
                const SizedBox(width: 8),
                _buildFilterChip('Videos', 'videos'),
              ],
            ),
          ),

        // ─── Content ──────────────────────────────────────────────
        Expanded(
          child: _selectedArtistName != null
              ? _buildArtistDetail(currentTrack)
              : _buildSearchResults(currentTrack),
        ),
      ],
    );
  }

  // ─── Filter Builder ─────────────────────────────────────────────

  Widget _buildFilterChip(String label, String? filterValue) {
    final isSelected = _searchFilter == filterValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchFilter = filterValue;
          if (_searchController.text.isNotEmpty) {
            _onSearchChanged(_searchController.text);
          } else {
            // Load new random defaults for the selected filter tab
            _loadDefaults();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kAccent : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : kTextWhite,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ─── Combined Search Results ────────────────────────────────────

  Widget _buildSearchResults(Track? currentTrack) {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: kAccent),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: kTextMuted, size: 40),
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: kTextMuted)),
            ],
          ),
        ),
      );
    }

    if (_artists.isEmpty && _songs.isEmpty) {
      // Very unlikely to happen with auto-loading, but good fallback
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_rounded,
                size: 64, color: kTextMuted.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'Discover music & artists',
              style: TextStyle(
                color: kTextWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        // ─── Header logic based on context ────────────────────────
        if (_searchController.text.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            child: Text(
              _searchFilter == 'podcasts' 
                  ? 'Recommended Podcasts' 
                  : _searchFilter == 'videos' 
                      ? 'Trending Videos' 
                      : 'Made for You',
              style: const TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w700, 
                color: kTextWhite
              ),
            ),
          ),
        // ─── Artists Section ──────────────────────────────────────
        if (_artists.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.person_rounded,
            title: 'Artists',
            count: _artists.length,
          ),
          ..._artists.map((artist) => _ArtistTile(
                artist: artist,
                onTap: () => _loadArtist(artist),
              )),
          const SizedBox(height: 8),
        ],

        // ─── Songs Section ───────────────────────────────────────
        if (_songs.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.music_note_rounded,
            title: 'Songs',
            count: _songs.length,
          ),
          ..._songs.map((track) => TrackTile(
                track: track,
                isPlaying: currentTrack?.videoId == track.videoId,
                onTap: () {
                  playTrackWithQueue(ref, track, _songs);
                  ref.read(recentlyPlayedProvider.notifier).addTrack(track);
                },
              )),
        ],
      ],
    );
  }

  // ─── Artist Detail (Songs Directory) ────────────────────────────

  Widget _buildArtistDetail(Track? currentTrack) {
    return CustomScrollView(
      slivers: [
        // Artist Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    // Back button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _clearArtist,
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

                    // Artist avatar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: _selectedArtistThumb != null
                            ? Image.network(
                                _selectedArtistThumb!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _avatarPlaceholder(),
                              )
                            : _avatarPlaceholder(),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Name + subscribers
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedArtistName ?? '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: kTextWhite,
                            ),
                          ),
                          if (_selectedArtistSubs != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _selectedArtistSubs!,
                                style: const TextStyle(
                                    fontSize: 12, color: kTextMuted),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Play All button
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

                if (_selectedArtistDesc != null &&
                    _selectedArtistDesc!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _selectedArtistDesc!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: kTextMuted, height: 1.4),
                    ),
                  ),

                const SizedBox(height: 8),
                const Divider(color: Color(0xFF2A2A2A), height: 1),

                // Song count + Shuffle
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                              ref.read(shuffleProvider.notifier).state = true;
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

        // Loading indicator
        if (_loadingDetail)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: kAccent),
            ),
          )
        else
          // Song list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final track = _artistSongs[i];
                return TrackTile(
                  track: track,
                  isPlaying: currentTrack?.videoId == track.videoId,
                  onTap: () {
                    playTrackWithQueue(ref, track, _artistSongs);
                    ref
                        .read(recentlyPlayedProvider.notifier)
                        .addTrack(track);
                  },
                );
              },
              childCount: _artistSongs.length,
            ),
          ),
      ],
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: kCardDark,
      child: const Icon(Icons.person_rounded, color: kTextMuted, size: 32),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kTextWhite,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Artist Tile Widget ──────────────────────────────────────────

class _ArtistTile extends StatefulWidget {
  final Artist artist;
  final VoidCallback onTap;

  const _ArtistTile({required this.artist, required this.onTap});

  @override
  State<_ArtistTile> createState() => _ArtistTileState();
}

class _ArtistTileState extends State<_ArtistTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Circular artist avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: widget.artist.thumbnail != null
                      ? Image.network(
                          widget.artist.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 14),

              // Name + subscribers
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.artist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: kTextWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.artist.subscribers ?? 'Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chevron_right_rounded,
                    color: kAccent, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: kCardDark,
      child: const Icon(Icons.person_rounded, size: 22, color: kTextMuted),
    );
  }
}
