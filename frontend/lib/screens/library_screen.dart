import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/track_tile.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final recentlyPlayed = ref.watch(recentlyPlayedProvider);
    final currentTrack = ref.watch(currentTrackProvider);
    final accent = Theme.of(context).colorScheme.primary;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          // ─── Header ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'My Music',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Filter Chips ────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                children: [
                  _Chip(label: 'All', isActive: true, accent: accent),
                  _Chip(label: 'Playlists', isActive: false, accent: accent),
                  _Chip(label: 'Liked Songs', isActive: false, accent: accent),
                  _Chip(label: 'Downloads', isActive: false, accent: accent),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ─── Liked Songs Card ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        accent.withOpacity(0.15),
                        const Color(0xFF1E1E1E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            colors: [accent, accent.withOpacity(0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: Colors.black, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Liked Songs',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            favorites.when(
                              data: (list) => Text(
                                '${list.length} songs',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                              loading: () => Text(
                                'Loading…',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                              error: (_, _) => Text(
                                '0 songs',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Recently Played Section ─────────────────────────
          if (recentlyPlayed.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Recently played',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = recentlyPlayed[index];
                  return TrackTile(
                    track: track,
                    isPlaying: currentTrack?.videoId == track.videoId,
                    onTap: () => playTrack(ref, track),
                  );
                },
                childCount: recentlyPlayed.length,
              ),
            ),
          ],

          // ─── Empty State ─────────────────────────────────────
          if (recentlyPlayed.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.library_music_rounded,
                      size: 64,
                      color: Colors.white.withOpacity(0.12),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your library is empty',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Songs you play will appear here',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom spacing for floating nav
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color accent;

  const _Chip({required this.label, required this.isActive, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accent : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
