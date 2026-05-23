import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/resource_model.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/ad_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../premium/premium_screen.dart';
import '../explore/resource_viewer_screen.dart';

class ProgressScreen extends StatefulWidget {
  final void Function(ThemeMode)? onThemeModeChanged;
  const ProgressScreen({super.key, this.onThemeModeChanged});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late UserProgress _progress;
  late ThemeMode _currentTheme;

  @override
  void initState() {
    super.initState();
    _progress = HiveService.getProgress();
    _currentTheme = HiveService.getThemeMode() ?? ThemeMode.system;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() => _progress = HiveService.getProgress());
  }

  void _changeTheme(ThemeMode mode) {
    setState(() => _currentTheme = mode);
    widget.onThemeModeChanged?.call(mode);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              setState(() => _progress = HiveService.getProgress()),
          color: NexColors.primary,
          backgroundColor: c.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(c),
                const SizedBox(height: 20),
                if (!_progress.isPremium) ...[
                  _buildPremiumBanner(c),
                  const SizedBox(height: 20),
                ],
                _buildStatsRow(c),
                const SizedBox(height: 24),
                _buildCurrentPath(c),
                const SizedBox(height: 24),
                _buildBadges(c),
                const SizedBox(height: 24),
                _buildBookmarks(c),
                const SizedBox(height: 24),
                _buildSettings(c),
                const SizedBox(height: 20),
                const AdaptiveBannerWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(NexColors c) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Progress',
                  style: TextStyle(
                      color: c.textPrimary, fontSize: 28,
                      fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              Text(
                _progress.isPremium ? '👑 Premium Member' : 'Free Plan',
                style: TextStyle(
                    color: _progress.isPremium ? NexColors.gold : c.textMuted,
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (!_progress.isPremium)
          GestureDetector(
            onTap: _openPremium,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [NexColors.primary, NexColors.accent]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Go Premium',
                  style: TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  // ─── Premium banner ────────────────────────────────────────────────────────
  Widget _buildPremiumBanner(NexColors c) {
    return GestureDetector(
      onTap: _openPremium,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [NexColors.primary, NexColors.accent]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Text('👑', style: TextStyle(fontSize: 32)),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unlock Premium',
                      style: TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  Text('Remove all ads · All 5 tracks · \$9.99/mo',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── Stats ────────────────────────────────────────────────────────────────
  Widget _buildStatsRow(NexColors c) {
    return Row(
      children: [
        Expanded(child: StatPill(label: 'Day Streak',
            value: '🔥 ${_progress.streakDays}', color: NexColors.accentOrange)),
        const SizedBox(width: 12),
        Expanded(child: StatPill(label: 'Total XP',
            value: '⭐ ${_progress.totalXP}', color: NexColors.gold)),
        const SizedBox(width: 12),
        Expanded(child: StatPill(label: 'Lessons',
            value: '📚 ${_progress.totalLessonsCompleted}', color: NexColors.primary)),
      ],
    );
  }

  // ─── Active track ─────────────────────────────────────────────────────────
  Widget _buildCurrentPath(NexColors c) {
    final cat = AppCategories.all.firstWhere(
        (ct) => ct.id == _progress.activeCategory,
        orElse: () => AppCategories.all.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Active Track',
            style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Text(cat.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.title, style: TextStyle(color: c.textPrimary,
                        fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${_progress.activeLevel[0].toUpperCase()}'
                      '${_progress.activeLevel.substring(1)} path',
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_progress.activeLevel.toUpperCase(),
                    style: TextStyle(color: cat.color, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Badges ───────────────────────────────────────────────────────────────
  Widget _buildBadges(NexColors c) {
    final allBadges = {
      'first_step': ('🏅', 'First Step',    'Complete your first lesson'),
      'streak_3':   ('🔥', '3-Day Streak',  'Learn 3 days in a row'),
      'streak_7':   ('🔥🔥','7-Day Streak', 'Learn 7 days in a row'),
      'streak_30':  ('⚡', '30-Day Legend', 'Learn 30 days in a row'),
      'xp_100':     ('⭐', '100 XP Club',   'Earn 100 XP total'),
      'xp_500':     ('🌟', '500 XP Legend', 'Earn 500 XP total'),
      'lessons_10': ('📚', '10 Lessons',    'Complete 10 lessons'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Badges (${_progress.earnedBadges.length}/${allBadges.length})',
            style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, crossAxisSpacing: 10,
            mainAxisSpacing: 10, childAspectRatio: 0.8,
          ),
          itemCount: allBadges.length,
          itemBuilder: (_, i) {
            final entry  = allBadges.entries.elementAt(i);
            final earned = _progress.earnedBadges.contains(entry.key);
            final data   = entry.value;
            return GestureDetector(
              onTap: () => _showBadgeDetail(data.$1, data.$2, data.$3, earned, c),
              child: Column(
                children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      color: earned
                          ? NexColors.gold.withOpacity(0.15)
                          : c.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: earned
                              ? NexColors.gold.withOpacity(0.5)
                              : c.border),
                    ),
                    child: Center(
                      child: Text(earned ? data.$1 : '🔒',
                          style: TextStyle(
                              fontSize: 24,
                              color: earned ? null : c.textMuted.withOpacity(0.3))),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(data.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: earned ? c.textPrimary : c.textMuted,
                          fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showBadgeDetail(String emoji, String name, String desc, bool earned, NexColors c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(earned ? emoji : '🔒', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(name, style: TextStyle(color: c.textPrimary, fontSize: 18,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(desc, textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            Text(earned ? '✅ Earned!' : '🔒 Not yet earned',
                style: TextStyle(
                    color: earned ? NexColors.success : c.textMuted,
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─── Bookmarks — now CLICKABLE ─────────────────────────────────────────────
  Widget _buildBookmarks(NexColors c) {
    final bookmarks = HiveService.getBookmarks();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Bookmarks', style: TextStyle(color: c.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: NexColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${bookmarks.length}',
                  style: const TextStyle(color: NexColors.primary,
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (bookmarks.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Text('🔖', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Text('No bookmarks yet.\nSave content from Explore.',
                    style: TextStyle(color: c.textMuted, fontSize: 13)),
              ],
            ),
          )
        else
          ...bookmarks.take(5).map((r) => _BookmarkTile(resource: r, c: c)),
      ],
    );
  }

  // ─── Settings — all tiles fully wired ─────────────────────────────────────
  Widget _buildSettings(NexColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: TextStyle(color: c.textPrimary,
            fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        // Appearance
        Text('Appearance',
            style: TextStyle(color: c.textMuted, fontSize: 12,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ThemeToggleTile(current: _currentTheme, onChanged: _changeTheme),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            color: c.card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Column(
            children: [
              // Daily Reminder — opens time picker
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: 'Daily Reminder',
                subtitle: '9:00 AM every day',
                c: c,
                onTap: _openReminderPicker,
              ),
              Divider(height: 1, color: c.border),
              // Premium
              _SettingsTile(
                icon: Icons.workspace_premium_outlined,
                label: 'Premium',
                subtitle: _progress.isPremium
                    ? 'Active — \$9.99/month'
                    : 'Upgrade for ad-free learning',
                c: c,
                onTap: _openPremium,
                trailing: _progress.isPremium
                    ? const Icon(Icons.check_circle,
                        color: NexColors.success, size: 20)
                    : null,
              ),
              Divider(height: 1, color: c.border),
              // About — opens dialog
              _SettingsTile(
                icon: Icons.info_outline,
                label: 'About NexSkills Hub',
                subtitle: 'by chAs Technologies LLC · v1.0.0',
                c: c,
                onTap: _showAboutDialog,
              ),
            ],
          ),
        ),
        // ── chAs Technologies LLC footer ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Column(
            children: [
              Divider(color: Colors.white.withOpacity(0.12), height: 1),
              const SizedBox(height: 14),
              Text(
                'Made with ❤️ by chAs Technologies LLC',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.22),
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'NexSkills Hub v1.0.0',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.12), fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _openPremium() {
    AdService.showInterstitial(onDismissed: () {
      if (mounted) {
        Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()))
            .then((_) =>
                setState(() => _progress = HiveService.getProgress()));
      }
    });
  }

  Future<void> _openReminderPicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Set daily reminder time',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      try {
        await NotificationService.scheduleDailyReminder(
            hour: picked.hour, minute: picked.minute);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔔 Reminder set for ${picked.format(context)}',
            ),
            backgroundColor: NexColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (_) {}
    }
  }

  void _showAboutDialog() {
    final c = context.colors;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: c.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: NexColors.primary.withOpacity(0.12),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon — uses actual asset, falls back to branded icon
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 84, height: 84,
                  errorBuilder: (_, __, ___) => Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [NexColors.primary, NexColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(Icons.school_rounded,
                          color: Colors.white, size: 44),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('NexSkills Hub',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: NexColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Version 1.0.0',
                    style: TextStyle(
                        color: NexColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
              Text(
                'Your daily tech career journey. Master AI, Cybersecurity, '
                'No-Code, Data & Cloud — just 10 minutes a day. '
                'Structured learning paths, curated content from top creators, '
                'and progress tracking built for busy people.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 20),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [NexColors.primary, NexColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('cA', style: TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('chAs Technologies LLC',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      Text('Built with ❤️ for lifelong learners',
                          style: TextStyle(color: c.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: NexColors.primary.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Close',
                      style: TextStyle(
                          color: NexColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bookmark tile — fully clickable, navigates to ResourceViewerScreen ───────
class _BookmarkTile extends StatelessWidget {
  final ResourceModel resource;
  final NexColors c;
  const _BookmarkTile({required this.resource, required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AdService.showInterstitial(
          contentId: resource.id,
          onDismissed: () {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ResourceViewerScreen(resource: resource)),
              );
            }
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Text(resource.type == 'video' ? '📹' : '📝',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resource.title,
                      style: TextStyle(color: c.textPrimary, fontSize: 13,
                          fontWeight: FontWeight.w600),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(resource.sourceName,
                      style: TextStyle(color: c.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: c.textMuted, size: 13),
          ],
        ),
      ),
    );
  }
}

// ─── Settings tile ────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final NexColors c;

  const _SettingsTile({
    required this.icon, required this.label, required this.subtitle,
    required this.onTap, required this.c, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: NexColors.primary, size: 22),
      title: Text(label, style: TextStyle(color: c.textPrimary,
          fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(color: c.textMuted, fontSize: 12)),
      trailing: trailing ??
          Icon(Icons.arrow_forward_ios, color: c.textMuted, size: 14),
    );
  }
}
