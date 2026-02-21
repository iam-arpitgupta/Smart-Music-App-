import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/track_tile.dart';
import '../widgets/album_card.dart';

/// Main content area — search bar + horizontal music sections.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(searchResultsProvider);
    final recentlyPlayed = ref.watch(recentlyPlayedProvider);
    final currentTrack = ref.watch(currentTrackProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Search Bar ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: kCardDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kDivider),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
              style: const TextStyle(
                color: kTextWhite,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: 'Search songs, artists, albums...',
                hintStyle: TextStyle(
                  color: kTextMuted.withOpacity(0.6),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: kTextMuted, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: kTextMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                          _focusNode.unfocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ─── Content ─────────────────────────────────────────────
        Expanded(
          child: query.isNotEmpty
              ? _buildSearchResults(searchResults, currentTrack)
              : _buildHomeSections(recentlyPlayed, currentTrack),
        ),
      ],
    );
  }

  // ─── Search results ────────────────────────────────────────────
  Widget _buildSearchResults(
    AsyncValue<List<dynamic>> results,
    dynamic currentTrack,
  ) {
    return results.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: kAccent),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFCF6679), size: 48),
            const SizedBox(height: 12),
            Text('$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextMuted, fontSize: 13)),
          ],
        ),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 56, color: kTextMuted.withOpacity(0.3)),
                const SizedBox(height: 12),
                const Text('No results found',
                    style: TextStyle(color: kTextMuted)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: tracks.length,
          itemBuilder: (context, i) {
            final track = tracks[i];
            return TrackTile(
              track: track,
              isPlaying: currentTrack?.videoId == track.videoId,
              onTap: () {
                playTrackWithQueue(ref, track, tracks.cast<Track>());
                ref.read(recentlyPlayedProvider.notifier).addTrack(track);
              },
            );
          },
        );
      },
    );
  }

  // ─── Home sections ─────────────────────────────────────────────
  Widget _buildHomeSections(List<dynamic> recentlyPlayed, dynamic currentTrack) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ─── Listen again (horizontal scroll) ────────────────
        if (recentlyPlayed.isNotEmpty) ...[
          _sectionHeader('Listen again'),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: recentlyPlayed.length,
              itemBuilder: (context, i) {
                final track = recentlyPlayed[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: AlbumCard(
                    track: track,
                    onTap: () => playTrack(ref, track),
                  ),
                );
              },
            ),
          ),
        ],

        // ─── Recommended (horizontal scroll) ─────────────────
        if (recentlyPlayed.length > 3) ...[
          _sectionHeader('Recommended'),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: recentlyPlayed.length,
              itemBuilder: (context, i) {
                // Show in reverse order to look like different recommendations
                final track =
                    recentlyPlayed[recentlyPlayed.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: AlbumCard(
                    track: track,
                    onTap: () => playTrack(ref, track),
                  ),
                );
              },
            ),
          ),
        ],

        // ─── Empty state ─────────────────────────────────────
        if (recentlyPlayed.isEmpty)
          SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headphones_rounded,
                      size: 64, color: kTextMuted.withOpacity(0.2)),
                  const SizedBox(height: 20),
                  const Text(
                    'Start listening',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kTextWhite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search for songs above to get started',
                    style: TextStyle(color: kTextMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kTextWhite,
            ),
          ),
          Text(
            'See all',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kAccent,
            ),
          ),
        ],
      ),
    );
  }
}
