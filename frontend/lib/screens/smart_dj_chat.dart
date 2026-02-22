import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/track.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';

/// Smart DJ Chat — AI-powered music chatbot overlay.
class SmartDJChat extends ConsumerStatefulWidget {
  const SmartDJChat({super.key});

  @override
  ConsumerState<SmartDJChat> createState() => _SmartDJChatState();
}

class _SmartDJChatState extends ConsumerState<SmartDJChat> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  // Each message: {role, content, music_data}
  final List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'content':
          'Hey! 👋 I\'m your Smart DJ. Tell me your mood, ask for an artist, '
              'or request a global blend — I\'ll curate the perfect music for you!',
      'music_data': <String, dynamic>{},
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
        'music_data': <String, dynamic>{},
      });
      _isSending = true;
    });
    _scrollToBottom();

    try {
      // Build chat history (skip welcome + current message)
      final history = <Map<String, String>>[];
      for (var i = 0; i < _messages.length - 1; i++) {
        final m = _messages[i];
        history.add({
          'role': m['role'] as String,
          'content': m['content'] as String,
        });
      }

      final api = ref.read(apiServiceProvider);
      final uri = Uri.parse('${api.baseUrl}/api/v1/chat');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text, 'history': history}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': data['reply'] ?? 'Hmm, I got lost in the music...',
            'music_data': data['music_data'] != null
                ? Map<String, dynamic>.from(data['music_data'] as Map)
                : <String, dynamic>{},
          });
          _isSending = false;
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Oops! Something went wrong (${response.statusCode}). '
                'Try again?',
            'music_data': <String, dynamic>{},
          });
          _isSending = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Network error — is the backend running?',
          'music_data': <String, dynamic>{},
        });
        _isSending = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final currentTrack = ref.watch(currentTrackProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 460,
        height: screenH * 0.72,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kAccent.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            _buildHeader(),
            const Divider(color: Color(0xFF2A2A3E), height: 1),

            // ── Messages ────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return _typingDots();

                  final msg = _messages[i];
                  final isUser = msg['role'] == 'user';
                  final rawMusicData = msg['music_data'];
                  final Map<String, dynamic> musicData =
                      rawMusicData is Map
                          ? Map<String, dynamic>.from(rawMusicData)
                          : <String, dynamic>{};
                  return _bubble(
                    msg['content'] as String,
                    isUser,
                    musicData,
                    currentTrack,
                  );
                },
              ),
            ),

            // ── Input ───────────────────────────────────────
            _buildInput(),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kAccent.withOpacity(0.12), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kAccent.withOpacity(0.2),
            ),
            child: const Icon(Icons.auto_awesome, color: kAccent, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart DJ',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kTextWhite)),
                Text('AI-powered music curator',
                    style: TextStyle(fontSize: 11, color: kTextMuted)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon:
                const Icon(Icons.close_rounded, color: kTextMuted, size: 20),
          ),
        ],
      ),
    );
  }

  // ─── Input Bar ──────────────────────────────────────────────────

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(color: kTextWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tell me your mood...',
                  hintStyle: TextStyle(
                      color: kTextMuted.withOpacity(0.5), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isSending ? kAccent.withOpacity(0.4) : kAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: Colors.black, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message Bubble ─────────────────────────────────────────────

  Widget _bubble(
    String text,
    bool isUser,
    Map<String, dynamic> musicData,
    Track? currentTrack,
  ) {
    final hasTracks =
        musicData.isNotEmpty && (musicData['data'] as List?)?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Text
          Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? kAccent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isUser ? kAccent : kTextWhite,
                height: 1.4,
              ),
            ),
          ),

          // Track cards (if any)
          if (hasTracks && !isUser) ...[
            const SizedBox(height: 8),
            _trackList(musicData, currentTrack),
          ],
        ],
      ),
    );
  }

  // ─── Track List (all agents now return "tracks") ────────────────

  Widget _trackList(Map<String, dynamic> musicData, Track? currentTrack) {
    final rawTracks = musicData['data'] as List<dynamic>? ?? [];
    if (rawTracks.isEmpty) return const SizedBox.shrink();

    // Build Track objects
    final tracks = rawTracks.map((item) {
      final m = item as Map<String, dynamic>;
      return Track(
        videoId: m['video_id'] ?? '',
        title: m['title'] ?? '',
        artist: m['artist'] ?? '',
        thumbnail: m['thumbnail'],
        duration: m['duration'],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Play All / Shuffle row
        Row(
          children: [
            _actionChip(
              icon: Icons.play_arrow_rounded,
              label: 'Play All',
              onTap: () {
                if (tracks.isNotEmpty) {
                  playTrackWithQueue(ref, tracks.first, tracks);
                  ref
                      .read(recentlyPlayedProvider.notifier)
                      .addTrack(tracks.first);
                }
              },
            ),
            const SizedBox(width: 8),
            _actionChip(
              icon: Icons.shuffle_rounded,
              label: 'Shuffle',
              onTap: () {
                if (tracks.isNotEmpty) {
                  final shuffled = List<Track>.from(tracks)..shuffle();
                  playTrackWithQueue(ref, shuffled.first, shuffled);
                  ref
                      .read(recentlyPlayedProvider.notifier)
                      .addTrack(shuffled.first);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Individual tracks
        ...tracks.take(8).map(
              (track) => _trackRow(track, tracks, currentTrack),
            ),
      ],
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: kAccent),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: kAccent,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trackRow(Track track, List<Track> queue, Track? currentTrack) {
    final isPlaying = currentTrack?.videoId == track.videoId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            playTrackWithQueue(ref, track, queue);
            ref.read(recentlyPlayedProvider.notifier).addTrack(track);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isPlaying
                  ? kAccent.withOpacity(0.12)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: track.thumbnail != null
                        ? Image.network(
                            track.thumbnail!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) =>
                                _thumbPlaceholder(),
                          )
                        : _thumbPlaceholder(),
                  ),
                ),
                const SizedBox(width: 10),
                // Title + artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPlaying ? kAccent : kTextWhite,
                          )),
                      Text(track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 10, color: kTextMuted)),
                    ],
                  ),
                ),
                // Play / Equaliser icon
                Icon(
                  isPlaying
                      ? Icons.equalizer_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                  color: isPlaying ? kAccent : kTextMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Typing Indicator ──────────────────────────────────────────

  Widget _typingDots() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _BouncingDot(delay: i * 150),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: kCardDark,
      child: const Icon(Icons.music_note_rounded, size: 16, color: kTextMuted),
    );
  }
}

// ─── Simple bouncing dot (self-contained animation) ──────────────

class _BouncingDot extends StatefulWidget {
  final int delay;
  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _anim.value),
          child: child,
        );
      },
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: kAccent,
        ),
      ),
    );
  }
}
