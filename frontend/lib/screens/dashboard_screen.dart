import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/premium_colors.dart';
import 'home_content.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _selectedIndex == 0 
          ? const HomeContent()
          : Center(
              child: Text(
                'Placeholder \$_selectedIndex',
                style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 18),
              ),
            ),
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
          _sidebarIcon(Icons.home_filled, 0),
          _sidebarIcon(Icons.music_note_rounded, 1),
          _sidebarIcon(Icons.auto_awesome, 2),
          _sidebarIcon(Icons.library_music_rounded, 3), // More appropriate than library_music
          _sidebarIcon(Icons.favorite, 4),
          const Spacer(),
          _sidebarIcon(Icons.settings, 5),
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
        currentIndex: _selectedIndex > 4 ? 0 : _selectedIndex,
        selectedItemColor: kPremiumAccent,
        unselectedItemColor: kPremiumTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) => setState(() => _selectedIndex = index),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 28), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.music_note_rounded, size: 28), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome, size: 28), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.favorite, size: 28), label: ''),
        ],
      ),
    );
  }

  Widget _buildPremiumPlayerBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: kPremiumCard.withOpacity(0.85),
            border: const Border(top: BorderSide(color: kPremiumBorder, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Track Info
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      // boxShadow: [kPremiumGlow(Colors.purple)],
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?ixlib=rb-4.0.3&auto=format&fit=crop&w=150&q=80'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Waves & Amplifiers', 
                        style: GoogleFonts.inter(color: kPremiumText, fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Stella Hayes', 
                        style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
              
              // Player Controls
              if (MediaQuery.of(context).size.width > 600)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shuffle_rounded, color: kPremiumTextMuted, size: 22),
                            const SizedBox(width: 24),
                            const Icon(Icons.skip_previous_rounded, color: kPremiumText, size: 28),
                            const SizedBox(width: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: kPremiumText,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.pause_rounded, color: kPremiumBg, size: 24),
                            ),
                            const SizedBox(width: 24),
                            const Icon(Icons.skip_next_rounded, color: kPremiumText, size: 28),
                            const SizedBox(width: 24),
                            const Icon(Icons.repeat_rounded, color: kPremiumTextMuted, size: 22),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('08:42', style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
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
                                child: Slider(value: 0.5, onChanged: (val) {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('17:24', style: GoogleFonts.inter(color: kPremiumTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
              // Actions
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: kPremiumTextMuted, size: 24),
                  const SizedBox(width: 20),
                  const Icon(Icons.menu_rounded, color: kPremiumTextMuted, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
