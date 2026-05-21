import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/resource_model.dart';
import '../constants/app_constants.dart';
import 'revenue_config.dart';

class AffiliateService {
  static const _clickBox = 'affiliateClicks';

  // ─── Build affiliate-tagged URL ───────────────────────────────
  static String buildUrl(AffiliateOffer offer) {
    final encoded = Uri.encodeComponent(offer.baseUrl);
    switch (offer.platform) {
      case AffiliatePlatform.udemy:
        // Impact Radius deep link for Udemy (mid=39197 is Udemy's program ID)
        final id = RevenueConfig.udemyAffiliateId;
        if (id == 'YOUR_UDEMY_IMPACT_ID') return offer.baseUrl;
        return 'https://click.linksynergy.com/deeplink?id=$id&mid=39197&murl=$encoded';

      case AffiliatePlatform.coursera:
        final id = RevenueConfig.courseraAffiliateId;
        if (id == 'YOUR_COURSERA_CJ_ID') return offer.baseUrl;
        return 'https://click.linksynergy.com/deeplink?id=$id&mid=40328&murl=$encoded';

      case AffiliatePlatform.linkedin:
        final id = RevenueConfig.linkedinAffiliateId;
        if (id == 'YOUR_LINKEDIN_IMPACT_ID') return offer.baseUrl;
        return 'https://click.linksynergy.com/deeplink?id=$id&mid=47513&murl=$encoded';

      case AffiliatePlatform.datacamp:
        final id = RevenueConfig.datacampAffiliateId;
        if (id == 'YOUR_DATACAMP_IMPACT_ID') return offer.baseUrl;
        return 'https://click.linksynergy.com/deeplink?id=$id&mid=44188&murl=$encoded';

      case AffiliatePlatform.brilliant:
        final id = RevenueConfig.brilliantAffiliateId;
        if (id == 'YOUR_BRILLIANT_ID') return offer.baseUrl;
        return '${offer.baseUrl}?ref=$id';
    }
  }

  // ─── Open course in browser ───────────────────────────────────
  static Future<void> openCourse(AffiliateOffer offer) async {
    await _recordClick(offer);
    final url = Uri.parse(buildUrl(offer));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ─── Get best offer for a resource ───────────────────────────
  static AffiliateOffer? getOfferForResource(ResourceModel resource) {
    final offers =
        RevenueConfig.offersByCategory[resource.category] ?? [];
    if (offers.isEmpty) return null;
    // Rotate offers so different content shows different recommendations
    final index = resource.id.hashCode.abs() % offers.length;
    return offers[index];
  }

  // ─── Get all offers for a category ───────────────────────────
  static List<AffiliateOffer> getOffersForCategory(String category) =>
      RevenueConfig.offersByCategory[category] ?? [];

  // ─── Record click for analytics ───────────────────────────────
  static Future<void> _recordClick(AffiliateOffer offer) async {
    try {
      final box = await Hive.openBox<int>(_clickBox);
      final key = '${offer.platform.name}:${offer.title}';
      final current = box.get(key, defaultValue: 0)!;
      await box.put(key, current + 1);
    } catch (_) {}
  }

  /// Total affiliate clicks today (for analytics display)
  static Future<Map<String, int>> getClickStats() async {
    try {
      final box = await Hive.openBox<int>(_clickBox);
      return {for (final k in box.keys) k.toString(): box.get(k) ?? 0};
    } catch (_) {
      return {};
    }
  }
}
