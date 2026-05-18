import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/learning_path.dart';

class PathService {
  static List<LearningPath>? _cached;

  static Future<List<LearningPath>> loadAll() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/json/learning_paths.json');
    final json = jsonDecode(raw);
    _cached = (json['paths'] as List)
        .map((p) => LearningPath.fromJson(p))
        .toList();
    return _cached!;
  }

  static Future<List<LearningPath>> byCategory(String category) async {
    final all = await loadAll();
    return all.where((p) => p.category == category).toList();
  }

  static Future<LearningPath?> getById(String id) async {
    final all = await loadAll();
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<LearningPath?> getActivePath(
      String category, String level) async {
    final all = await loadAll();
    try {
      return all.firstWhere(
          (p) => p.category == category && p.level == level);
    } catch (_) {
      return null;
    }
  }
}
