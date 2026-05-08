/// Centralized revenue configuration.
/// Replace placeholder IDs with your real affiliate and AdMob IDs.
class RevenueConfig {
  // ─── Affiliate IDs ────────────────────────────────────────────
  // Register at impact.com for Udemy, LinkedIn Learning, DataCamp
  // Register at cj.com for Coursera
  static const udemyAffiliateId = 'YOUR_UDEMY_IMPACT_ID';       // impact.com
  static const courseraAffiliateId = 'YOUR_COURSERA_CJ_ID';     // cj.com
  static const linkedinAffiliateId = 'YOUR_LINKEDIN_IMPACT_ID'; // impact.com
  static const datacampAffiliateId = 'YOUR_DATACAMP_IMPACT_ID'; // impact.com
  static const brilliantAffiliateId = 'YOUR_BRILLIANT_ID';      // brilliant.org/affiliate

  // ─── Pricing ─────────────────────────────────────────────────
  static const monthlyPrice = 9.99;
  static const yearlyPrice = 59.99;
  static const monthlyPriceDisplay = '\$9.99/month';
  static const yearlyPriceDisplay = '\$59.99/year';
  static const yearlyPerMonthDisplay = '\$5.00/month';
  static const monthlySavings = 'Save 50% vs monthly';

  // ─── Trial ───────────────────────────────────────────────────
  // Configure matching trial in Play Console & App Store Connect
  static const trialDays = 7;
  static const trialCTAMonthly = 'Start Free Trial — then \$9.99/mo';
  static const trialCTAYearly = 'Start Free Trial — then \$59.99/yr';

  // ─── Social proof ─────────────────────────────────────────────
  // Update this number periodically as you grow
  static const learnerCount = '12,400+';
  static const learnerCountLabel = 'learners already growing';

  // ─── Soft paywall ─────────────────────────────────────────────
  // Free users can read this many items per day before paywall
  static const freeArticlesPerDay = 5;
  static const freeVideosPerDay = 3;

  // ─── Referral ─────────────────────────────────────────────────
  static const referralRewardDays = 7;   // days of free premium per referral
  static const refereeRewardDays = 3;    // days for the referred user
  static const referralBaseUrl = 'https://nexskillshub.app/ref/';

  // ─── Affiliate course offers by category ─────────────────────
  static const Map<String, List<AffiliateOffer>> offersByCategory = {
    'ai': [
      AffiliateOffer(
        title: 'ChatGPT & LLM Mastery',
        subtitle: 'Bestseller · 47,000 students',
        platform: AffiliatePlatform.udemy,
        baseUrl: 'https://www.udemy.com/course/chatgpt-and-langchain-the-complete-developers-masterclass/',
        emoji: '🤖',
        originalPrice: '\$129.99',
        salePrice: '\$14.99',
      ),
      AffiliateOffer(
        title: 'Machine Learning — Coursera',
        subtitle: 'Stanford · Andrew Ng · 4.9★',
        platform: AffiliatePlatform.coursera,
        baseUrl: 'https://www.coursera.org/specializations/machine-learning-introduction',
        emoji: '🎓',
        originalPrice: '\$79/mo',
        salePrice: '7-day free trial',
      ),
    ],
    'cybersecurity': [
      AffiliateOffer(
        title: 'Complete Ethical Hacking Bootcamp',
        subtitle: 'Bestseller · 120,000 students',
        platform: AffiliatePlatform.udemy,
        baseUrl: 'https://www.udemy.com/course/python-and-ethical-hacking-from-scratch/',
        emoji: '🔐',
        originalPrice: '\$149.99',
        salePrice: '\$14.99',
      ),
      AffiliateOffer(
        title: 'Google Cybersecurity Certificate',
        subtitle: 'Coursera · Job-ready in 6 months',
        platform: AffiliatePlatform.coursera,
        baseUrl: 'https://www.coursera.org/professional-certificates/google-cybersecurity',
        emoji: '🛡️',
        originalPrice: '\$59/mo',
        salePrice: '7-day free trial',
      ),
    ],
    'nocode': [
      AffiliateOffer(
        title: 'Build Apps with Bubble — Zero Code',
        subtitle: '12,000 students · Highly rated',
        platform: AffiliatePlatform.udemy,
        baseUrl: 'https://www.udemy.com/course/build-a-web-app-with-bubble-io/',
        emoji: '⚡',
        originalPrice: '\$99.99',
        salePrice: '\$14.99',
      ),
      AffiliateOffer(
        title: 'No-Code Automation with Make',
        subtitle: 'Automate any workflow',
        platform: AffiliatePlatform.udemy,
        baseUrl: 'https://www.udemy.com/course/the-complete-make-course/',
        emoji: '🔄',
        originalPrice: '\$84.99',
        salePrice: '\$12.99',
      ),
    ],
    'data': [
      AffiliateOffer(
        title: 'Python for Data Science & ML',
        subtitle: 'Bestseller · 650,000 students',
        platform: AffiliatePlatform.udemy,
        baseUrl: 'https://www.udemy.com/course/python-for-data-science-and-machine-learning-bootcamp/',
        emoji: '📊',
        originalPrice: '\$149.99',
        salePrice: '\$14.99',
      ),
      AffiliateOffer(
        title: 'Google Data Analytics Certificate',
        subtitle: 'Coursera · 480,000 enrolled',
        platform: AffiliatePlatform.coursera,
        baseUrl: 'https://www.coursera.org/professional-certificates/google-data-analytics',
        emoji: '📈',
        originalPrice: '\$59/mo',
        salePrice: '7-day free trial',
      ),
    ],
    'cloud': [
      AffiliateOffer(
        title: 'AWS Certified Solutions Architect',
        subtitle: 'Bestseller · 630,000 students',
        platform: AffiliatePlatform.udemy,
        baseUrl: 'https://www.udemy.com/course/aws-certified-solutions-architect-associate-saa-c03/',
        emoji: '☁️',
        originalPrice: '\$149.99',
        salePrice: '\$14.99',
      ),
      AffiliateOffer(
        title: 'Google Cloud Professional Certificate',
        subtitle: 'Coursera · In-demand certification',
        platform: AffiliatePlatform.coursera,
        baseUrl: 'https://www.coursera.org/professional-certificates/google-cloud-digital-leader-training',
        emoji: '🚀',
        originalPrice: '\$59/mo',
        salePrice: '7-day free trial',
      ),
    ],
  };
}

enum AffiliatePlatform { udemy, coursera, linkedin, datacamp, brilliant }

class AffiliateOffer {
  final String title;
  final String subtitle;
  final AffiliatePlatform platform;
  final String baseUrl;
  final String emoji;
  final String originalPrice;
  final String salePrice;

  const AffiliateOffer({
    required this.title,
    required this.subtitle,
    required this.platform,
    required this.baseUrl,
    required this.emoji,
    required this.originalPrice,
    required this.salePrice,
  });

  String get platformName => switch (platform) {
        AffiliatePlatform.udemy => 'Udemy',
        AffiliatePlatform.coursera => 'Coursera',
        AffiliatePlatform.linkedin => 'LinkedIn Learning',
        AffiliatePlatform.datacamp => 'DataCamp',
        AffiliatePlatform.brilliant => 'Brilliant',
      };

  String get platformEmoji => switch (platform) {
        AffiliatePlatform.udemy => '🎯',
        AffiliatePlatform.coursera => '🎓',
        AffiliatePlatform.linkedin => '💼',
        AffiliatePlatform.datacamp => '📉',
        AffiliatePlatform.brilliant => '🧠',
      };
}
