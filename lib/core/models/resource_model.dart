import 'package:hive/hive.dart';

part 'resource_model.g.dart';

@HiveType(typeId: 0)
class ResourceModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String url;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final String type; // 'video' | 'article' | 'podcast'

  @HiveField(5)
  final String sourceName;

  @HiveField(6)
  final String? thumbnail;

  @HiveField(7)
  final DateTime publishedAt;

  @HiveField(8)
  final String? description;

  @HiveField(9)
  bool isBookmarked;

  @HiveField(10)
  bool isRead;

  ResourceModel({
    required this.id,
    required this.title,
    required this.url,
    required this.category,
    required this.type,
    required this.sourceName,
    this.thumbnail,
    required this.publishedAt,
    this.description,
    this.isBookmarked = false,
    this.isRead = false,
  });

  String get youtubeVideoId {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
    return uri.queryParameters['v'] ?? '';
  }

  bool get isYoutube =>
      url.contains('youtube.com') || url.contains('youtu.be');

  ResourceModel copyWith({bool? isBookmarked, bool? isRead}) {
    return ResourceModel(
      id: id,
      title: title,
      url: url,
      category: category,
      type: type,
      sourceName: sourceName,
      thumbnail: thumbnail,
      publishedAt: publishedAt,
      description: description,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isRead: isRead ?? this.isRead,
    );
  }
}
