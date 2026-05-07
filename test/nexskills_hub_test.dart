import 'package:flutter_test/flutter_test.dart';
import 'package:nexskills_hub/core/constants/app_constants.dart';
import 'package:nexskills_hub/core/constants/sources.dart';
import 'package:nexskills_hub/core/models/learning_path.dart';
import 'package:nexskills_hub/core/models/resource_model.dart';
import 'package:nexskills_hub/core/models/user_progress.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

ResourceModel _makeResource({
  String id = 'r1',
  String url = 'https://example.com/article',
  String type = 'article',
  bool isBookmarked = false,
  bool isRead = false,
}) =>
    ResourceModel(
      id: id,
      title: 'Test Resource',
      url: url,
      category: 'ai',
      type: type,
      sourceName: 'Test Source',
      publishedAt: DateTime(2025, 1, 1),
      isBookmarked: isBookmarked,
      isRead: isRead,
    );

UserProgress _makeProgress({
  String category = 'ai',
  String level = 'beginner',
  int streakDays = 0,
  int totalXP = 0,
  bool isPremium = false,
  Map<String, List<int>>? completedSteps,
  DateTime? lastInterstitialShown,
}) =>
    UserProgress(
      activeCategory: category,
      activeLevel: level,
      streakDays: streakDays,
      totalXP: totalXP,
      isPremium: isPremium,
      completedSteps: completedSteps,
      lastInterstitialShown: lastInterstitialShown,
    );

LearningPath _makePath({String id = 'p1', int stepCount = 3}) => LearningPath(
      id: id,
      category: 'ai',
      title: 'Intro to AI',
      level: 'beginner',
      description: 'Learn AI basics',
      steps: List.generate(
        stepCount,
        (i) => PathStep(
          order: i + 1,
          title: 'Step ${i + 1}',
          type: 'video',
          url: 'https://www.youtube.com/watch?v=abc${i}xyz',
          duration: '10 min',
          note: '',
          sourceName: 'YouTube',
        ),
      ),
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ── ResourceModel ──────────────────────────────────────────────────────────

  group('ResourceModel', () {
    group('construction', () {
      test('stores all required fields correctly', () {
        final now = DateTime(2025, 6, 15);
        final r = ResourceModel(
          id: 'id-1',
          title: 'My Article',
          url: 'https://example.com',
          category: 'cloud',
          type: 'article',
          sourceName: 'AWS Blog',
          publishedAt: now,
          description: 'A great read',
          thumbnail: 'https://example.com/thumb.jpg',
        );

        expect(r.id, 'id-1');
        expect(r.title, 'My Article');
        expect(r.url, 'https://example.com');
        expect(r.category, 'cloud');
        expect(r.type, 'article');
        expect(r.sourceName, 'AWS Blog');
        expect(r.publishedAt, now);
        expect(r.description, 'A great read');
        expect(r.thumbnail, 'https://example.com/thumb.jpg');
      });

      test('defaults isBookmarked and isRead to false', () {
        final r = _makeResource();
        expect(r.isBookmarked, isFalse);
        expect(r.isRead, isFalse);
      });

      test('accepts explicit isBookmarked and isRead values', () {
        final r = _makeResource(isBookmarked: true, isRead: true);
        expect(r.isBookmarked, isTrue);
        expect(r.isRead, isTrue);
      });

      test('thumbnail and description are nullable', () {
        final r = ResourceModel(
          id: 'r',
          title: 't',
          url: 'https://x.com',
          category: 'data',
          type: 'article',
          sourceName: 's',
          publishedAt: DateTime.now(),
        );
        expect(r.thumbnail, isNull);
        expect(r.description, isNull);
      });
    });

    group('isYoutube', () {
      test('returns true for youtube.com watch URL', () {
        expect(
          _makeResource(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ')
              .isYoutube,
          isTrue,
        );
      });

      test('returns true for youtu.be short URL', () {
        expect(
          _makeResource(url: 'https://youtu.be/dQw4w9WgXcQ').isYoutube,
          isTrue,
        );
      });

      test('returns false for a regular blog URL', () {
        expect(
          _makeResource(url: 'https://krebsonsecurity.com/2025/01/post/')
              .isYoutube,
          isFalse,
        );
      });
    });

    group('youtubeVideoId', () {
      test('extracts id from standard watch URL', () {
        expect(
          _makeResource(url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ')
              .youtubeVideoId,
          'dQw4w9WgXcQ',
        );
      });

      test('extracts id from youtu.be short URL', () {
        expect(
          _makeResource(url: 'https://youtu.be/dQw4w9WgXcQ').youtubeVideoId,
          'dQw4w9WgXcQ',
        );
      });

      test('returns empty string for non-YouTube URL', () {
        expect(
          _makeResource(url: 'https://example.com/post').youtubeVideoId,
          '',
        );
      });

      test('returns empty string for malformed URL', () {
        expect(_makeResource(url: ':::bad:::').youtubeVideoId, '');
      });
    });

    group('copyWith', () {
      test('updates isBookmarked only', () {
        final r = _makeResource(isBookmarked: false, isRead: false);
        final copy = r.copyWith(isBookmarked: true);
        expect(copy.isBookmarked, isTrue);
        expect(copy.isRead, isFalse);
        expect(copy.id, r.id);
        expect(copy.title, r.title);
      });

      test('updates isRead only', () {
        final r = _makeResource(isBookmarked: false, isRead: false);
        final copy = r.copyWith(isRead: true);
        expect(copy.isRead, isTrue);
        expect(copy.isBookmarked, isFalse);
      });

      test('updates both flags simultaneously', () {
        final r = _makeResource(isBookmarked: false, isRead: false);
        final copy = r.copyWith(isBookmarked: true, isRead: true);
        expect(copy.isBookmarked, isTrue);
        expect(copy.isRead, isTrue);
      });

      test('preserves all other fields unchanged', () {
        final now = DateTime(2025, 3, 10);
        final r = ResourceModel(
          id: 'x',
          title: 'T',
          url: 'https://u.com',
          category: 'cyber',
          type: 'podcast',
          sourceName: 'S',
          publishedAt: now,
          description: 'D',
          thumbnail: 'thumb.png',
        );
        final copy = r.copyWith(isRead: true);
        expect(copy.id, 'x');
        expect(copy.url, 'https://u.com');
        expect(copy.category, 'cyber');
        expect(copy.type, 'podcast');
        expect(copy.publishedAt, now);
        expect(copy.description, 'D');
        expect(copy.thumbnail, 'thumb.png');
      });

      test('passing no arguments preserves current state', () {
        final r = _makeResource(isBookmarked: true, isRead: true);
        final copy = r.copyWith();
        expect(copy.isBookmarked, isTrue);
        expect(copy.isRead, isTrue);
      });
    });
  });

  // ── UserProgress ───────────────────────────────────────────────────────────

  group('UserProgress', () {
    group('defaults', () {
      test('has sensible initial values', () {
        final p = UserProgress();
        expect(p.activeCategory, 'ai');
        expect(p.activeLevel, 'beginner');
        expect(p.streakDays, 0);
        expect(p.totalXP, 0);
        expect(p.isPremium, isFalse);
        expect(p.dailyGoalMinutes, 20);
        expect(p.totalLessonsCompleted, 0);
        expect(p.completedSteps, isEmpty);
        expect(p.earnedBadges, isEmpty);
        expect(p.lastActiveDate, isNull);
        expect(p.lastInterstitialShown, isNull);
      });
    });

    group('isStepCompleted', () {
      test('returns false when path has no completed steps', () {
        final p = _makeProgress();
        expect(p.isStepCompleted('path-1', 1), isFalse);
      });

      test('returns true for a step that has been recorded', () {
        final p = _makeProgress(
          completedSteps: {
            'path-1': [1, 2, 3],
          },
        );
        expect(p.isStepCompleted('path-1', 2), isTrue);
      });

      test('returns false for a step not in the list', () {
        final p = _makeProgress(
          completedSteps: {
            'path-1': [1, 2],
          },
        );
        expect(p.isStepCompleted('path-1', 5), isFalse);
      });

      test('returns false for an unknown path', () {
        final p = _makeProgress(
          completedSteps: {
            'path-1': [1],
          },
        );
        expect(p.isStepCompleted('path-99', 1), isFalse);
      });
    });

    group('completedCount', () {
      test('returns 0 for unknown path', () {
        final p = _makeProgress();
        expect(p.completedCount('path-X'), 0);
      });

      test('returns correct count', () {
        final p = _makeProgress(
          completedSteps: {
            'path-1': [1, 2, 3, 4],
          },
        );
        expect(p.completedCount('path-1'), 4);
      });

      test('counts are independent per path', () {
        final p = _makeProgress(
          completedSteps: {
            'path-a': [1, 2],
            'path-b': [1],
          },
        );
        expect(p.completedCount('path-a'), 2);
        expect(p.completedCount('path-b'), 1);
      });
    });

    group('canShowInterstitial', () {
      test('returns false when user is premium', () {
        final p = _makeProgress(isPremium: true);
        expect(p.canShowInterstitial, isFalse);
      });

      test('returns true when no interstitial has ever been shown', () {
        final p = _makeProgress(isPremium: false);
        expect(p.canShowInterstitial, isTrue);
      });

      test('returns false within the 180-second cooldown window', () {
        final recent = DateTime.now().subtract(const Duration(seconds: 60));
        final p = _makeProgress(lastInterstitialShown: recent);
        expect(p.canShowInterstitial, isFalse);
      });

      test('returns true after the 180-second cooldown has elapsed', () {
        final old = DateTime.now().subtract(const Duration(seconds: 200));
        final p = _makeProgress(lastInterstitialShown: old);
        expect(p.canShowInterstitial, isTrue);
      });

      test('returns false at exactly 179 seconds elapsed', () {
        final recent = DateTime.now().subtract(const Duration(seconds: 179));
        final p = _makeProgress(lastInterstitialShown: recent);
        expect(p.canShowInterstitial, isFalse);
      });
    });
  });

  // ── LearningPath & PathStep ────────────────────────────────────────────────

  group('LearningPath', () {
    group('fromJson', () {
      final json = {
        'id': 'ai-beginner',
        'category': 'ai',
        'title': 'AI for Beginners',
        'level': 'beginner',
        'description': 'Start your AI journey',
        'prerequisite': null,
        'steps': [
          {
            'order': 1,
            'title': 'What is AI?',
            'type': 'video',
            'url': 'https://www.youtube.com/watch?v=abc123',
            'duration': '12 min',
            'note': 'Great intro',
            'source': 'IBM Technology',
          },
          {
            'order': 2,
            'title': 'ML Basics',
            'type': 'article',
            'url': 'https://towardsdatascience.com/ml-basics',
            'duration': '8 min',
            'note': '',
            'source': 'Towards Data Science',
          },
        ],
      };

      test('parses top-level fields', () {
        final path = LearningPath.fromJson(json);
        expect(path.id, 'ai-beginner');
        expect(path.category, 'ai');
        expect(path.title, 'AI for Beginners');
        expect(path.level, 'beginner');
        expect(path.description, 'Start your AI journey');
        expect(path.prerequisitePathId, isNull);
      });

      test('parses steps list', () {
        final path = LearningPath.fromJson(json);
        expect(path.steps.length, 2);
      });

      test('parses individual step fields', () {
        final step = LearningPath.fromJson(json).steps.first;
        expect(step.order, 1);
        expect(step.title, 'What is AI?');
        expect(step.type, 'video');
        expect(step.url, 'https://www.youtube.com/watch?v=abc123');
        expect(step.duration, '12 min');
        expect(step.note, 'Great intro');
        expect(step.sourceName, 'IBM Technology');
      });

      test('note defaults to empty string when absent from JSON', () {
        final jsonNoNote = {
          'order': 1,
          'title': 'Step',
          'type': 'video',
          'url': 'https://youtube.com/watch?v=x',
          'duration': '5 min',
          // no 'note' key
          'source': 'S',
        };
        final step = PathStep.fromJson(jsonNoNote);
        expect(step.note, '');
      });

      test('sourceName defaults to empty string when absent from JSON', () {
        final jsonNoSource = {
          'order': 1,
          'title': 'Step',
          'type': 'article',
          'url': 'https://example.com',
          'duration': '5 min',
          'note': '',
          // no 'source' key
        };
        final step = PathStep.fromJson(jsonNoSource);
        expect(step.sourceName, '');
      });
    });

    group('totalSteps', () {
      test('returns 0 for empty path', () {
        expect(_makePath(stepCount: 0).totalSteps, 0);
      });

      test('returns correct count', () {
        expect(_makePath(stepCount: 5).totalSteps, 5);
      });
    });
  });

  group('PathStep', () {
    PathStep _makeStep(String url) => PathStep(
          order: 1,
          title: 'Step',
          type: 'video',
          url: url,
          duration: '5 min',
          note: '',
          sourceName: 'S',
        );

    group('isYoutube', () {
      test('true for youtube.com URL', () {
        expect(_makeStep('https://www.youtube.com/watch?v=xyz').isYoutube, isTrue);
      });

      test('true for youtu.be short URL', () {
        expect(_makeStep('https://youtu.be/xyz').isYoutube, isTrue);
      });

      test('false for non-YouTube URL', () {
        expect(_makeStep('https://towardsdatascience.com/post').isYoutube, isFalse);
      });
    });

    group('youtubeVideoId', () {
      test('extracts id from watch URL', () {
        expect(
          _makeStep('https://www.youtube.com/watch?v=dQw4w9WgXcQ').youtubeVideoId,
          'dQw4w9WgXcQ',
        );
      });

      test('extracts id from youtu.be URL', () {
        expect(
          _makeStep('https://youtu.be/dQw4w9WgXcQ').youtubeVideoId,
          'dQw4w9WgXcQ',
        );
      });

      test('returns empty for non-YouTube URL', () {
        expect(_makeStep('https://example.com').youtubeVideoId, '');
      });
    });
  });

  // ── AppSources ─────────────────────────────────────────────────────────────

  group('AppSources', () {
    test('all list is non-empty', () {
      expect(AppSources.all, isNotEmpty);
    });

    test('byCategory returns only matching sources', () {
      for (final cat in ['ai', 'cybersecurity', 'nocode', 'data', 'cloud']) {
        final filtered = AppSources.byCategory(cat);
        expect(filtered, isNotEmpty, reason: 'Category "$cat" has no sources');
        expect(
          filtered.every((s) => s.category == cat),
          isTrue,
          reason: 'Category "$cat" has mismatched entries',
        );
      }
    });

    test('byCategory returns empty list for unknown category', () {
      expect(AppSources.byCategory('quantum'), isEmpty);
    });

    test('all sources have non-empty feedUrl', () {
      for (final source in AppSources.all) {
        expect(
          source.feedUrl,
          isNotEmpty,
          reason: '${source.name} has an empty feedUrl',
        );
      }
    });

    test('YouTube sources have youtube.com in their feed URL', () {
      final ytSources =
          AppSources.all.where((s) => s.type == SourceType.youtube);
      for (final s in ytSources) {
        expect(
          s.feedUrl,
          contains('youtube.com'),
          reason: '${s.name} is typed as YouTube but feedUrl looks wrong',
        );
      }
    });

    test('all sources have a non-empty name and icon', () {
      for (final source in AppSources.all) {
        expect(source.name, isNotEmpty, reason: 'A source has an empty name');
        expect(source.icon, isNotEmpty, reason: '${source.name} has no icon');
      }
    });
  });

  // ── AppCategories & constants ───────────────────────────────────────────────

  group('AppCategories', () {
    test('contains exactly 5 categories', () {
      expect(AppCategories.all.length, 5);
    });

    test('category ids match the 5 known topics', () {
      final ids = AppCategories.all.map((c) => c.id).toSet();
      expect(ids, containsAll(['ai', 'cybersecurity', 'nocode', 'data', 'cloud']));
    });

    test('every category has a non-empty title, icon and description', () {
      for (final cat in AppCategories.all) {
        expect(cat.title, isNotEmpty, reason: '${cat.id} has no title');
        expect(cat.icon, isNotEmpty, reason: '${cat.id} has no icon');
        expect(cat.description, isNotEmpty, reason: '${cat.id} has no description');
      }
    });
  });

  group('AppStrings', () {
    test('appName is NexSkills Hub', () {
      expect(AppStrings.appName, 'NexSkills Hub');
    });

    test('premium product IDs are non-empty', () {
      expect(AppStrings.premiumMonthlyId, isNotEmpty);
      expect(AppStrings.premiumYearlyId, isNotEmpty);
    });
  });

  group('AdConstants', () {
    test('cooldown is 180 seconds', () {
      expect(AdConstants.interstitialCooldownSeconds, 180);
    });

    test('all ad IDs are non-empty', () {
      expect(AdConstants.androidBannerId, isNotEmpty);
      expect(AdConstants.androidInterstitialId, isNotEmpty);
      expect(AdConstants.androidRewardedId, isNotEmpty);
      expect(AdConstants.iosBannerId, isNotEmpty);
      expect(AdConstants.iosInterstitialId, isNotEmpty);
      expect(AdConstants.iosRewardedId, isNotEmpty);
    });
  });
}
