import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/services/hive_service.dart';

/// Full in-app YouTube player — no redirect to the YouTube app.
/// Uses youtube_player_flutter (already in pubspec) with:
///   • Auto-play on open
///   • Progress bar in brand colour
///   • Full-screen support (landscape lock)
///   • Title + description below the player
///   • Marks resource as consumed on open
class VideoPlayerScreen extends StatefulWidget {
  final ResourceModel resource;
  const VideoPlayerScreen({super.key, required this.resource});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  YoutubePlayerController? _controller;
  bool _isFullScreen = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    // Mark as consumed immediately on open
    HiveService.markConsumed(widget.resource.id);
    HiveService.markRead(widget.resource.id);
  }

  void _initPlayer() {
    final videoId = YoutubePlayer.convertUrlToId(widget.resource.url);
    if (videoId == null || videoId.isEmpty) {
      setState(() => _errorMsg = 'Could not load video. Invalid YouTube URL.');
      return;
    }
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        captionLanguage: 'en',
        forceHD: false,
        loop: false,
        isLive: false,
      ),
    )..addListener(_onPlayerStateChange);
  }

  void _onPlayerStateChange() {
    if (_controller == null) return;
    if (_controller!.value.isFullScreen && !_isFullScreen) {
      setState(() => _isFullScreen = true);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (!_controller!.value.isFullScreen && _isFullScreen) {
      setState(() => _isFullScreen = false);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerStateChange);
    _controller?.dispose();
    // Always restore portrait on exit
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(backgroundColor: c.background),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('😕', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(_errorMsg!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textMuted, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null) {
      return Scaffold(
        backgroundColor: c.background,
        body: Center(
            child: CircularProgressIndicator(color: NexColors.primary)),
      );
    }

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      },
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: NexColors.primary,
        progressColors: const ProgressBarColors(
          playedColor: NexColors.primary,
          handleColor: NexColors.accent,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        topActions: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.resource.title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onReady: () => _controller!.play(),
        onEnded: (_) {
          // Optionally loop or show next
        },
      ),
      builder: (context, player) => Scaffold(
        backgroundColor: c.background,
        appBar: _isFullScreen
            ? null
            : AppBar(
                backgroundColor: c.background,
                elevation: 0,
                leading: BackButton(color: c.textPrimary),
                title: Text(
                  widget.resource.sourceName,
                  style: TextStyle(
                      color: NexColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.open_in_new, color: c.textMuted, size: 20),
                    tooltip: 'Open in YouTube',
                    onPressed: () async {
                      // Fallback: open in YouTube if user wants
                    },
                  ),
                ],
              ),
        body: Column(
          children: [
            // Video player (full-width, 16:9)
            player,
            // Scrollable content below
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: NexColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('🎬 ${widget.resource.sourceName}',
                          style: const TextStyle(
                              color: NexColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      widget.resource.title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    // Description
                    if (widget.resource.description != null &&
                        widget.resource.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.resource.description!,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 14, height: 1.65),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Category tag
                    Row(
                      children: [
                        Icon(Icons.local_offer_outlined,
                            color: c.textMuted, size: 14),
                        const SizedBox(width: 6),
                        Text(widget.resource.category.toUpperCase(),
                            style: TextStyle(
                                color: c.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
