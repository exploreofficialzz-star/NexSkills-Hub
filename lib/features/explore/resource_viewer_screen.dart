import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/services/hive_service.dart';

class ResourceViewerScreen extends StatefulWidget {
  final ResourceModel resource;
  const ResourceViewerScreen({super.key, required this.resource});

  @override
  State<ResourceViewerScreen> createState() => _ResourceViewerScreenState();
}

class _ResourceViewerScreenState extends State<ResourceViewerScreen> {
  YoutubePlayerController? _ytController;

  @override
  void initState() {
    super.initState();
    if (widget.resource.isYoutube) {
      _ytController = YoutubePlayerController(
        initialVideoId: widget.resource.youtubeVideoId,
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );
    }
    HiveService.markRead(widget.resource.id);
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          widget.resource.sourceName,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.resource.isBookmarked
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color: widget.resource.isBookmarked
                  ? AppColors.primary
                  : AppColors.textMuted,
            ),
            onPressed: () async {
              await HiveService.toggleBookmark(widget.resource.id);
              setState(() {});
            },
          ),
        ],
      ),
      body: widget.resource.isYoutube
          ? _buildYouTube()
          : _buildWebView(),
    );
  }

  Widget _buildYouTube() {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primary,
      ),
      builder: (context, player) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          player,
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.resource.title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.3)),
                const SizedBox(height: 8),
                Text(
                  '${widget.resource.sourceName}  ·  ${_timeAgo(widget.resource.publishedAt)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest:
          URLRequest(url: WebUri(widget.resource.url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }
}
