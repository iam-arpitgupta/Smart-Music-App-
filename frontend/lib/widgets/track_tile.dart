import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';

/// Resonance-style track tile for list views.
class TrackTile extends ConsumerStatefulWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;

  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onLongPress,
    this.isPlaying = false,
  });

  @override
  ConsumerState<TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends ConsumerState<TrackTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Square image with rounded corners
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: widget.track.thumbnail != null
                      ? Image.network(
                          widget.track.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 14),

              // Title + Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: widget.isPlaying ? kAccent : kTextWhite,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                  ],
                ),
              ),

              // Download button
              IconButton(
                icon: const Icon(Icons.download_rounded, color: kTextMuted, size: 20),
                onPressed: () async {
                  final api = ref.read(apiServiceProvider);
                  final downloadUrl = api.getDownloadUrl(widget.track.videoId);
                  final uri = Uri.parse(downloadUrl);
                  try {
                     await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                      debugPrint('Could not launch \$downloadUrl: \$e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not download track: \$e')),
                        );
                      }
                  }
                },
                tooltip: 'Download Track',
              ),
              const SizedBox(width: 8),

              // Play button
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isPlaying
                      ? kAccent
                      : kCardDark,
                ),
                child: Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                  color: widget.isPlaying ? Colors.black : kTextWhite,
                ),
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
      child: const Icon(Icons.music_note_rounded, size: 20, color: kTextMuted),
    );
  }
}
