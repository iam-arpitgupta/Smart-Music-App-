import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../widgets/bottom_player.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'smart_dj_chat.dart';

/// Navigation index: 0=Home, 1=Explore(Search), 2=Library
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Root layout: Sidebar | Main Content | Bottom Player + Smart DJ FAB
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ─── Dynamic gradient background ─────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: appGradientColors,
                stops: const [0.0, 0.6],
              ),
            ),
          ),

          // ─── Main layout: Sidebar + Content ──────────────────
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // ─── Left Sidebar ──────────────────────────
                    _Sidebar(
                      selectedIndex: selectedTab,
                      onItemSelected: (i) =>
                          ref.read(selectedTabProvider.notifier).state = i,
                    ),

                    // ─── Main Content Area ─────────────────────
                    Expanded(
                      child: _buildContent(selectedTab),
                    ),
                  ],
                ),
              ),

              // ─── Bottom Player ───────────────────────────────
              const BottomPlayer(),
            ],
          ),

          // ─── Smart DJ FAB ────────────────────────────────────
          Positioned(
            right: 24,
            bottom: 90, // above the bottom player
            child: FloatingActionButton(
              onPressed: () {
                _showSmartDJDialog(context);
              },
              backgroundColor: kAccent,
              elevation: 8,
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.black,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(int tab) {
    switch (tab) {
      case 1:
        return const ExploreScreen();
      case 2:
        // Library — will be built out later
        return const Center(
          child: Text('Library', style: TextStyle(color: kTextMuted)),
        );
      default:
        return const HomeScreen();
    }
  }

  void _showSmartDJDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SmartDJChat(),
    );
  }
}

// ─── Sidebar ────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _Sidebar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: kSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Resonance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kTextWhite,
                  ),
                ),
              ],
            ),
          ),

          // Navigation items
          _SidebarItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isActive: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _SidebarItem(
            icon: Icons.explore_rounded,
            label: 'Explore',
            isActive: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),
          _SidebarItem(
            icon: Icons.library_music_rounded,
            label: 'Library',
            isActive: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: kDivider, height: 1),
          ),
          const SizedBox(height: 24),

          // Playlist actions
          _SidebarItem(
            icon: Icons.add_rounded,
            label: 'New playlist',
            isActive: false,
            onTap: () {},
          ),
          _SidebarItem(
            icon: Icons.favorite_rounded,
            label: 'Liked Music',
            isActive: false,
            onTap: () {},
            iconColor: kAccent,
          ),

          const Spacer(),

          // User avatar at bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: kAccent.withValues(alpha: 0.2),
                  child: const Icon(Icons.person_rounded,
                      color: kAccent, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'User',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.iconColor,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isActive || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? kAccent.withValues(alpha: 0.12)
                : _hovered
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.iconColor ??
                    (widget.isActive ? kAccent : kTextMuted),
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isHighlighted ? FontWeight.w600 : FontWeight.w400,
                  color: isHighlighted ? kTextWhite : kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
