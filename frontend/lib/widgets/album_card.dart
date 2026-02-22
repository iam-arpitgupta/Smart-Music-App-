import 'package:flutter/material.dart';
import '../main.dart';
import '../models/track.dart';

/// Square album card with slightly rounded corners for horizontal scroll lists.
class AlbumCard extends StatefulWidget {
  final Track track;
  final VoidCallback onTap;

  const AlbumCard({
    super.key,
    required this.track,
    required this.onTap,
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 155,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 155,
                      height: 155,
                      child: widget.track.thumbnail != null
                          ? Image.network(
                              widget.track.thumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                  ),
                  if (_hovered)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kAccent,
                          boxShadow: [
                            BoxShadow(
                              color: kAccent.withOpacity(0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.black, size: 22),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: kTextWhite,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: kTextMuted),
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
      child: const Icon(
          Icons.music_note_rounded, size: 36, color: kTextMuted),
    );
  }
}
