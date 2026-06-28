import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/services/hive_service.dart';
import '../../shared/widgets/app_icon_widget.dart';

/// Full in-app YouTube player.
///
/// Fix for "hang on open":
///   _initPlayer() is deferred to the first post-frame callback so the
///   screen paints a proper loading UI BEFORE the YoutubePlayerController
///   creates its internal WebView (which can take 2–5 s on first launch).
///   A loading overlay stays visible until onReady fires.
class VideoPlayerScreen extends StatefulWidget {
  final ResourceModel resource;
  const VideoPlayerScreen({super.key, required this.resource});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  YoutubePlayerController? _controller;
  bool _isFullScreen = false;
  bool _playerReady  = false; // true once onReady fires
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // Mark consumed immediately — before the player even loads.
    HiveService.markConsumed(widget.resource.id);
    HiveService.markRead(widget.resource.id);
    // Defer heavy WebView creation to after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initPlayer());
  }

  void _initPlayer() {
    if (!mounted) return;
    final videoId = YoutubePlayer.convertUrlToId(widget.resource.url);
    if (videoId == null || videoId.isEmpty) {
      setState(() => _errorMsg = 'Could not load video. Invalid YouTube URL.');
      return;
    }
    setState(() {
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
    });
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ─── Loading state (shown before _initPlayer completes) ──────────────────
  Widget _buildLoading(NexColors c) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(color: Colors.white70),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIconWidget(size: 72),
            const SizedBox(height: 28),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: NexColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Loading video…',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────
  Widget _buildError(NexColors c) {
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
              Text(
                _errorMsg!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_errorMsg != null) return _buildError(c);
    if (_controller == null) return _buildLoading(c);

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      },
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: NexColors.primary,
        progressColors: const ProgressBarColors(
          playedColor:    NexColors.primary,
          handleColor:    NexColors.accent,
          bufferedColor:  Colors.white24,
          backgroundColor: Colors.white12,
        ),
        topActions: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.resource.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onReady: () {
          // onReady fires when the WebView is fully initialised.
          // Remove the loading overlay and start playback.
          if (mounted) setState(() => _playerReady = true);
          _controller!.play();
        },
        onEnded: (_) {},
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
                  style: const TextStyle(
                      color: NexColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.open_in_new, color: c.textMuted, size: 20),
                    tooltip: 'Open in YouTube',
                    onPressed: () {},
                  ),
                ],
              ),
        body: Column(
          children: [
            // ── Player + loading overlay ────────────────────────────────
            Stack(
              children: [
                player, // 16:9 WebView
                // Overlay covers the black WebView flash until onReady fires.
                if (!_playerReady)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: NexColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // ── Scrollable content below ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: NexColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🎬 ${widget.resource.sourceName}',
                        style: const TextStyle(
                            color: NexColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.resource.title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    if (widget.resource.description != null &&
                        widget.resource.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.resource.description!,
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 14,
                            height: 1.65),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.local_offer_outlined,
                            color: c.textMuted, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          widget.resource.category.toUpperCase(),
                          style: TextStyle(
                              color: c.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5),
                        ),
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
