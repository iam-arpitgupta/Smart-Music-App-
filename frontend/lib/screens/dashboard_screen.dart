import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/premium_colors.dart';
import '../providers/player_provider.dart';
import 'home_content.dart';
import 'explore_screen.dart';
import 'smart_dj_chat.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: kPremiumBg,
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop) _buildSidebar(),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
          
          // Premium Glass Player Bar overlay positioned at bottom
          Positioned(
            left: isDesktop ? 100 : 0, 
            right: 0, 
            bottom: isDesktop ? 0 : 0,
            child: _buildPremiumPlayerBar(),
          )
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = const HomeContent();
        break;
      case 1:
        page = const ExploreScreen(key: ValueKey('explore_all'));
        break;
      case 2:
        page = const ExploreScreen(
            key: ValueKey('explore_podcasts'), initialFilter: 'podcasts');
        break;
      case 3:
        page = const ExploreScreen(
            key: ValueKey('explore_videos'), initialFilter: 'videos');
        break;
      case 4:
        page = const SmartDJChat();
        break;
      case 5:
        page = const LibraryScreen();
        break;
      default:
        page = Center(
          child: Text(
            'Placeholder $_selectedIndex',
            style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 18),
          ),
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: page,
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 100,
      decoration: const BoxDecoration(
        color: kPremiumSidebar,
        border: Border(right: BorderSide(color: kPremiumBorder, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPremiumText,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.waves_rounded, color: Colors.black, size: 28),
          ),
          const SizedBox(height: 50),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _sidebarIcon(Icons.home_filled, 0),
                  _sidebarIcon(Icons.search_rounded, 1),
                  _sidebarIcon(Icons.podcasts_rounded, 2),
                  _sidebarIcon(Icons.video_library_rounded, 3),
                  _sidebarIcon(Icons.auto_awesome, 4),
                  _sidebarIcon(Icons.library_music_rounded, 5),
                ],
              ),
            ),
          ),
          _sidebarIcon(Icons.settings, 6),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sidebarIcon(IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutExpo,
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? kPremiumAccent.withOpacity(0.1) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? kPremiumAccent : kPremiumTextMuted,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kPremiumBorder, width: 1)),
      ),
      child: BottomNavigationBar(
        backgroundColor: kPremiumSidebar,
        currentIndex: _selectedIndex > 5 ? 0 : _selectedIndex,
        selectedItemColor: kPremiumAccent,
        unselectedItemColor: kPremiumTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) => setState(() => _selectedIndex = index),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 28), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded, size: 28), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.podcasts_rounded, size: 28), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.video_library_rounded, size: 28), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome, size: 28), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.library_music_rounded, size: 28), label: ''),
        ],
      ),
    );
  }

  Widget _buildPremiumPlayerBar() {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(playingStreamProvider).value ?? false;
    final position = ref.watch(positionStreamProvider).value ?? Duration.zero;
    final duration = ref.watch(durationStreamProvider).value ?? const Duration(milliseconds: 1);
    final shuffle = ref.watch(shuffleProvider);
    final repeatMode = ref.watch(repeatModeProvider); // 0=off, 1=all, 2=one

    String formatDuration(Duration d) {
      final min = d.inMinutes;
      final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$min:$sec';
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          decoration: BoxDecoration(
            color: kPremiumCard.withOpacity(0.85),
            border: const Border(top: BorderSide(color: kPremiumBorder, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Track Info
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NowPlayingScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          image: track.thumbnail != null
                              ? DecorationImage(
                                  image: NetworkImage(track.thumbnail!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: track.thumbnail == null ? const Icon(Icons.music_note, color: kPremiumTextMuted) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(track.title, 
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: kPremiumText, fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(track.artist, 
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Player Controls
              if (MediaQuery.of(context).size.width > 600)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.shuffle_rounded, 
                                color: shuffle ? kPremiumAccent : kPremiumTextMuted, size: 22),
                              onPressed: () => ref.read(shuffleProvider.notifier).state = !shuffle,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, color: kPremiumText, size: 28),
                              onPressed: () => skipPrevious(ref),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  if (isPlaying) {
                                    audioHandler.pause();
                                  } else {
                                    audioHandler.play();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: kPremiumText,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                                    color: kPremiumBg, size: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, color: kPremiumText, size: 28),
                              onPressed: () => skipNext(ref),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                repeatMode == 2 ? Icons.repeat_one_rounded : Icons.repeat_rounded, 
                                color: repeatMode > 0 ? kPremiumAccent : kPremiumTextMuted, size: 22),
                              onPressed: () {
                                final current = ref.read(repeatModeProvider);
                                ref.read(repeatModeProvider.notifier).state = (current + 1) % 3;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(formatDuration(position), style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  activeTrackColor: kPremiumText,
                                  inactiveTrackColor: kPremiumBorder,
                                  thumbColor: kPremiumText,
                                ),
                                child: Slider(
                                  value: (position.inMilliseconds / duration.inMilliseconds)
                                      .clamp(0.0, 1.0), 
                                  onChanged: (val) {
                                    final newPosition = Duration(milliseconds: (val * duration.inMilliseconds).round());
                                    audioHandler.seek(newPosition);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(formatDuration(duration), style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
              // Actions
              if (MediaQuery.of(context).size.width > 600)
                Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {},
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.favorite_rounded, color: kPremiumTextMuted, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {},
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.menu_rounded, color: kPremiumTextMuted, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
