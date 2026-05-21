class LearningPath {
  final String id;
  final String category;
  final String title;
  final String level;
  final String description;
  final String? prerequisitePathId;
  final List<PathStep> steps;

  const LearningPath({
    required this.id,
    required this.category,
    required this.title,
    required this.level,
    required this.description,
    this.prerequisitePathId,
    required this.steps,
  });

  factory LearningPath.fromJson(Map<String, dynamic> json) {
    return LearningPath(
      id: json['id'],
      category: json['category'],
      title: json['title'],
      level: json['level'],
      description: json['description'],
      prerequisitePathId: json['prerequisite'],
      steps: (json['steps'] as List)
          .map((s) => PathStep.fromJson(s))
          .toList(),
    );
  }

  int get totalSteps => steps.length;
}

class PathStep {
  final int order;
  final String title;
  final String type; // video | article
  final String url;
  final String duration;
  final String note;
  final String sourceName;

  const PathStep({
    required this.order,
    required this.title,
    required this.type,
    required this.url,
    required this.duration,
    required this.note,
    required this.sourceName,
  });

  factory PathStep.fromJson(Map<String, dynamic> json) {
    return PathStep(
      order: json['order'],
      title: json['title'],
      type: json['type'],
      url: json['url'],
      duration: json['duration'],
      note: json['note'] ?? '',
      sourceName: json['source'] ?? '',
    );
  }

  bool get isYoutube =>
      url.contains('youtube.com') || url.contains('youtu.be');

  String get youtubeVideoId {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
    return uri.queryParameters['v'] ?? '';
  }
}
