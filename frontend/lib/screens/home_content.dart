import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/premium_colors.dart';
import '../providers/home_data_provider.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../models/track.dart';
import '../widgets/skeleton_loader.dart';

class HomeContent extends ConsumerWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(homeDataProvider);
    final currentTrack = ref.watch(currentTrackProvider);

    // Add extra bottom padding to account for the glassmorphism player bar (100px)
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 140),
      child: asyncData.when(
        data: (data) => _buildContent(context, ref, data, currentTrack),
        loading: () => _buildLoadingState(context),
        error: (err, stack) => Center(
          child: Text('Error loading data: \$err', style: TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, HomeData data, Track? currentTrack) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildPremiumHero(ref, data)),
                  const SizedBox(width: 40),
                  Expanded(flex: 1, child: _buildMadeForYouList(ref, data.madeForYou, currentTrack)),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildPremiumHero(ref, data),
                  const SizedBox(height: 40),
                  _buildMadeForYouList(ref, data.madeForYou, currentTrack),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 48),
        _buildPopularSpeckers(data.popularSpeckers),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    // A skeleton version of the main UI
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: const SkeletonLoader(width: double.infinity, height: 400, borderRadius: 32)),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 1, 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SkeletonLoader(width: 150, height: 32),
                        const SizedBox(height: 24),
                        for (int i = 0; i < 4; i++) ...[
                          const SkeletonLoader(width: double.infinity, height: 86, borderRadius: 20),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  const SkeletonLoader(width: double.infinity, height: 400, borderRadius: 32),
                  const SizedBox(height: 40),
                  const SkeletonLoader(width: 150, height: 32),
                  const SizedBox(height: 24),
                  for (int i = 0; i < 4; i++) ...[
                    const SkeletonLoader(width: double.infinity, height: 86, borderRadius: 20),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }
          },
        ),
        const SizedBox(height: 48),
        const SkeletonLoader(width: 200, height: 32),
        const SizedBox(height: 32),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 32),
                child: Column(
                  children: [
                    const SkeletonLoader(width: 150, height: 150, borderRadius: 75),
                    const SizedBox(height: 20),
                    const SkeletonLoader(width: 100, height: 16),
                    const SizedBox(height: 8),
                    const SkeletonLoader(width: 60, height: 12),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumHero(WidgetRef ref, HomeData data) {
    return Container(
      decoration: BoxDecoration(
        gradient: kHeroPremiumGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [kPremiumGlow(kPremiumAccent)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              bottom: -20,
              child: Opacity(
                opacity: 0.9,
                child: Image.network(
                  data.heroImageUrl,
                  width: 380,
                  height: 380,
                  fit: BoxFit.cover,
                  colorBlendMode: BlendMode.luminosity,
                  color: Colors.black.withOpacity(0.1),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.black.withOpacity(0.6), width: 1.5),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '${data.heroArtist.name} • ${data.heroDuration} • ${data.heroListeners}',
                      style: GoogleFonts.inter(
                        color: Colors.black87, 
                        fontWeight: FontWeight.w700, 
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    data.heroArtist.name.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.black, 
                      fontSize: 56, 
                      fontWeight: FontWeight.w900, 
                      height: 0.9, 
                      letterSpacing: -1.5,
                    ),
                  ),
                  Text(
                    data.heroAlbum.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.black.withOpacity(0.85), 
                      fontSize: 32, 
                      fontWeight: FontWeight.w800, 
                      height: 1.1, 
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  _PremiumButton(
                    onTap: () {
                      if (data.madeForYou.isNotEmpty) {
                        playTrackWithQueue(ref, data.madeForYou.first, data.madeForYou);
                      }
                    },
                    label: 'Start Playing',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMadeForYouList(WidgetRef ref, List<Track> tracks, Track? currentTrack) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Made For You', 
              style: GoogleFonts.outfit(color: kPremiumText, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('View All', 
                style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 24),
            ...tracks.map((track) {
          final isPlaying = currentTrack?.videoId == track.videoId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildTrackItem(ref, track, tracks, isPlaying: isPlaying),
          );
        }),
      ],
    );
  }

  Widget _buildTrackItem(WidgetRef ref, Track track, List<Track> allTracks, {required bool isPlaying}) {
    return GestureDetector(
      onTap: () {
        playTrackWithQueue(ref, track, allTracks);
        try {
          ref.read(recentlyPlayedProvider.notifier).addTrack(track);
        } catch (_) {}
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: kPremiumCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPremiumBorder, width: 1),
            boxShadow: isPlaying ? [kPremiumGlow(kPremiumAccent.withOpacity(0.1))] : null,
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                   borderRadius: BorderRadius.circular(30),
                   image: track.thumbnail != null ? DecorationImage(image: NetworkImage(track.thumbnail!), fit: BoxFit.cover) : null,
                   color: kPremiumSidebar,
                   boxShadow: [
                     BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                   ]
                ),
                child: track.thumbnail == null ? const Icon(Icons.music_note, color: kPremiumTextMuted) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, style: GoogleFonts.inter(color: kPremiumText, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(track.artist, style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPlaying ? kPremiumAccent : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                  color: isPlaying ? Colors.black : Colors.white, 
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularSpeckers(List<Track> speckers) {
    // Some custom glow colors for aesthetic purposes
    final glowColors = [Colors.redAccent, Colors.purpleAccent, Colors.orangeAccent, Colors.red, Colors.pinkAccent];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
             Text('Popular Speckers', 
              style: GoogleFonts.outfit(color: kPremiumText, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('View All', 
                style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: speckers.length,
            itemBuilder: (context, index) {
              final track = speckers[index];
              return _buildSpeckerItem(
                track.title, 
                track.artist, 
                track.duration ?? 'Unknown', 
                track.thumbnail!, 
                glowColors[index % glowColors.length]
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildSpeckerItem(String title, String artist, String duration, String imageUrl, Color glowColor) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 32),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(80),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(80),
                  child: Image.network(imageUrl, width: 150, height: 150, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    ]
                  ),
                  child: Text(duration, style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(title, 
            style: GoogleFonts.inter(color: kPremiumText, fontSize: 16, fontWeight: FontWeight.w700), 
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(artist, 
            style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 13, fontWeight: FontWeight.w500), 
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _PremiumButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  const _PremiumButton({required this.onTap, required this.label});

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : (_isHovering ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(40),
              boxShadow: _isHovering 
                ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
                : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Text(
              widget.label, 
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
