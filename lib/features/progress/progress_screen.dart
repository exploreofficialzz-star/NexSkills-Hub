import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/user_progress.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/ad_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../premium/premium_screen.dart';

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
    _progress     = HiveService.getProgress();
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

  Widget _buildHeader(NexColors c) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Progress',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8)),
              Text(
                _progress.isPremium ? '👑 Premium Member' : 'Free Plan',
                style: TextStyle(
                    color: _progress.isPremium
                        ? NexColors.gold
                        : c.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
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
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

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
        child: Row(
          children: [
            const Text('👑', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unlock Premium',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  Text('Remove all ads · All 5 tracks · \$9.99/mo',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(NexColors c) {
    return Row(
      children: [
        Expanded(child: StatPill(label: 'Day Streak', value: '🔥 ${_progress.streakDays}', color: NexColors.accentOrange)),
        const SizedBox(width: 12),
        Expanded(child: StatPill(label: 'Total XP',   value: '⭐ ${_progress.totalXP}',   color: NexColors.gold)),
        const SizedBox(width: 12),
        Expanded(child: StatPill(label: 'Lessons',    value: '📚 ${_progress.totalLessonsCompleted}', color: NexColors.primary)),
      ],
    );
  }

  Widget _buildCurrentPath(NexColors c) {
    final cat = AppCategories.all
        .firstWhere((c) => c.id == _progress.activeCategory,
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
              border: Border.all(color: c.border, width: 0.5)),
          child: Row(
            children: [
              Text(cat.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.title,
                        style: TextStyle(
                            color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${_progress.activeLevel[0].toUpperCase()}${_progress.activeLevel.substring(1)} path',
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(_progress.activeLevel.toUpperCase(),
                    style: TextStyle(
                        color: cat.color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadges(NexColors c) {
    final allBadges = {
      'first_step': ('🏅', 'First Step',    'Complete your first lesson'),
      'streak_3':   ('🔥', '3-Day Streak',  'Learn 3 days in a row'),
      'streak_7':   ('🔥🔥', '7-Day Streak','Learn 7 days in a row'),
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
            return Column(
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
                    child: Text(
                      earned ? data.$1 : '🔒',
                      style: TextStyle(
                          fontSize: 24,
                          color: earned ? null : c.textMuted.withOpacity(0.3)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(data.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: earned ? c.textPrimary : c.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBookmarks(NexColors c) {
    final bookmarks = HiveService.getBookmarks();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Bookmarks',
                style: TextStyle(
                    color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: NexColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${bookmarks.length}',
                  style: const TextStyle(
                      color: NexColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (bookmarks.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border, width: 0.5)),
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
          ...bookmarks.take(5).map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border, width: 0.5)),
                child: Row(
                  children: [
                    Text(r.type == 'video' ? '📹' : '📝',
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text(r.sourceName,
                              style: TextStyle(color: c.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildSettings(NexColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings',
            style: TextStyle(
                color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        // ── Appearance / theme toggle ─────────────────────────
        Text('Appearance',
            style: TextStyle(
                color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        ThemeToggleTile(current: _currentTheme, onChanged: _changeTheme),
        const SizedBox(height: 16),

        // ── Other settings ────────────────────────────────────
        Container(
          decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border, width: 0.5)),
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: 'Daily Reminder',
                subtitle: '9:00 AM every day',
                onTap: () {},
                c: c,
              ),
              Divider(height: 1, color: c.border),
              _SettingsTile(
                icon: Icons.workspace_premium_outlined,
                label: 'Premium',
                subtitle: _progress.isPremium
                    ? 'Active — \$9.99/month'
                    : 'Upgrade for ad-free learning',
                onTap: _openPremium,
                c: c,
                trailing: _progress.isPremium
                    ? const Icon(Icons.check_circle,
                        color: NexColors.success, size: 20)
                    : null,
              ),
              Divider(height: 1, color: c.border),
              _SettingsTile(
                icon: Icons.info_outline,
                label: 'About NexSkills Hub',
                subtitle: 'by chAs Tech Group · v1.0.0',
                onTap: () {},
                c: c,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openPremium() {
    AdService.showInterstitial(onDismissed: () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        ).then((_) => setState(() => _progress = HiveService.getProgress()));
      }
    });
  }
}

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
      title: Text(label,
          style: TextStyle(
              color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(color: c.textMuted, fontSize: 12)),
      trailing: trailing ??
          Icon(Icons.arrow_forward_ios, color: c.textMuted, size: 14),
    );
  }
}
