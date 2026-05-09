# NexSkills Hub — Affiliate Platform Registration Guide

## Where to register (all free, instant or 24h approval)

---

### 1. UDEMY — impact.com
**Commission: 10–15% per sale**
**Cookie: 7 days**

1. Go to: https://www.impact.com/marketplace/brands/
2. Search "Udemy"
3. Click "Apply" → create a free Impact account
4. Once approved (usually instant) go to your dashboard
5. Click "Links" → "Create Link" → paste any Udemy course URL
6. Your affiliate link looks like:
   `https://click.linksynergy.com/deeplink?id=YOUR_ID&mid=39197&murl=ENCODED_URL`

Your Impact Publisher ID → paste into `RevenueConfig.udemyAffiliateId`

---

### 2. COURSERA — impact.com (same account as Udemy)
**Commission: 45% first month subscription**
**Cookie: 30 days**

1. Same Impact account — search "Coursera" in marketplace
2. Apply → approved within 24h
3. Create deep links to any Coursera course/certificate
4. Link format:
   `https://imp.i384100.net/c/YOUR_ID/1347618/14726?u=ENCODED_URL`

Your Coursera Campaign ID → paste into `RevenueConfig.courseraAffiliateId`

---

### 3. LINKEDIN LEARNING — impact.com (same account)
**Commission: 35% per subscription**
**Cookie: 30 days**

1. Search "LinkedIn Learning" in Impact marketplace
2. Apply → 24–48h approval
3. Link format:
   `https://linkedin.com/learning?trk=AFFILIATE_TOKEN`

Your token → paste into `RevenueConfig.linkedinAffiliateId`

---

### 4. DATACAMP — impact.com (same account)
**Commission: 33% recurring**
**Cookie: 30 days**

1. Search "DataCamp" in Impact marketplace
2. Link format:
   `https://www.datacamp.com/?tap_a=5644-dce66f&tap_s=YOUR_ID`

Your ID → paste into `RevenueConfig.datacampAffiliateId`

---

### 5. BRILLIANT — brilliant.org/affiliate
**Commission: $10 per annual signup**
**Cookie: 30 days**

1. Go to: https://brilliant.org/affiliate/
2. Fill out the form → approved within 48h
3. Your link: `https://brilliant.org/nexskillshub/` (custom slug)

Your slug → paste into `RevenueConfig.brilliantAffiliateId`

---

### 6. SKILLSHARE — impact.com (same account)
**Commission: $7 per free trial signup**
**Cookie: 30 days**

1. Search "Skillshare" in Impact marketplace
2. Good for No-Code / Design / Creative tracks

---

## What to do RIGHT NOW (takes 20 minutes)

1. Create one free Impact account at https://www.impact.com/publisher/
2. Apply to: Udemy, Coursera, LinkedIn Learning, DataCamp, Skillshare
   (all in the same dashboard — one application each)
3. Apply to Brilliant separately at brilliant.org/affiliate
4. Paste your IDs into `revenue_config.dart` (see template below)

---

## revenue_config.dart — paste your IDs here

```dart
class RevenueConfig {
  // ─── YOUR AFFILIATE IDs ──────────────────────────────────────
  // Get these from impact.com after approval

  // Impact Publisher ID (same for Udemy, Coursera, LinkedIn, DataCamp)
  static const _impactPublisherId = 'PASTE_YOUR_IMPACT_ID_HERE';

  // Udemy — mid=39197 is Udemy's program ID (fixed, don't change)
  static String udemyLink(String courseUrl) =>
      'https://click.linksynergy.com/deeplink'
      '?id=$_impactPublisherId&mid=39197'
      '&murl=${Uri.encodeComponent(courseUrl)}';

  // Coursera — mid=40328 is Coursera's program ID (fixed)
  static String courseraLink(String courseUrl) =>
      'https://click.linksynergy.com/deeplink'
      '?id=$_impactPublisherId&mid=40328'
      '&murl=${Uri.encodeComponent(courseUrl)}';

  // LinkedIn Learning — mid=47513
  static String linkedinLink(String courseUrl) =>
      'https://click.linksynergy.com/deeplink'
      '?id=$_impactPublisherId&mid=47513'
      '&murl=${Uri.encodeComponent(courseUrl)}';

  // DataCamp — mid=44188
  static String datacampLink(String courseUrl) =>
      'https://click.linksynergy.com/deeplink'
      '?id=$_impactPublisherId&mid=44188'
      '&murl=${Uri.encodeComponent(courseUrl)}';

  // Brilliant — your custom slug from brilliant.org/affiliate
  static const brilliantBaseUrl = 'https://brilliant.org/nexskillshub/';

  // ─── PRICING ──────────────────────────────────────────────────
  static const monthlyPrice         = 9.99;
  static const yearlyPrice          = 59.99;
  static const monthlyPriceDisplay  = '\$9.99/month';
  static const yearlyPriceDisplay   = '\$59.99/year';
  static const yearlyPerMonthDisplay= '\$5.00/month';
  static const trialDays            = 7;
  static const learnerCount         = '12,400+';
  static const learnerCountLabel    = 'learners already growing';
  static const freeArticlesPerDay   = 5;
  static const freeVideosPerDay     = 3;

  // ─── COURSE OFFERS BY CATEGORY ────────────────────────────────
  // Replace baseUrl strings with your affiliate-tagged links
  // after you get your Impact Publisher ID above.
  static const Map<String, List<AffiliateOffer>> offersByCategory = {
    'ai': [
      AffiliateOffer(
        title: 'ChatGPT & LLM Mastery',
        subtitle: 'Bestseller · 47,000 students',
        platform: AffiliatePlatform.udemy,
        // ↓ Replace with: udemyLink('https://www.udemy.com/course/...')
        baseUrl: 'https://www.udemy.com/course/chatgpt-and-langchain-the-complete-developers-masterclass/',
        emoji: '🤖',
        originalPrice: '\$129.99',
        salePrice: '\$14.99',
      ),
      AffiliateOffer(
        title: 'Machine Learning Specialization',
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
        title: 'Build Apps with Bubble',
        subtitle: '12,000 students · Highly rated',
        platform: AffiliatePlatform.udemy,
        baseUrl: 'https://www.udemy.com/course/build-a-web-app-with-bubble-io/',
        emoji: '⚡',
        originalPrice: '\$99.99',
        salePrice: '\$14.99',
      ),
      AffiliateOffer(
        title: 'Zapier & Make Automation',
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
```

---

## Revenue projection once IDs are live

| Category | Clicks/day (at 35k DAU) | Purchase rate | Avg commission | Daily |
|----------|------------------------|---------------|----------------|-------|
| Udemy courses | 1,400 | 3% | $15 | $630 |
| Coursera trials | 700 | 8% | $26 | $145 |
| DataCamp | 300 | 4% | $20 | $24 |
| Brilliant | 200 | 5% | $10 | $10 |
| **Total** | | | | **~$810/day** |

This is passive — no ongoing work after the IDs are wired in.
