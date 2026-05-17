# NexSkills Hub — Fix & Enhancement Delivery Notes

## Files Changed / Created

### NEW files
| File | Purpose |
|------|---------|
| `lib/core/services/ad_manager.dart` | AdManager singleton — every-other-tap, 60s cooldown, Hive-persisted section counters, test/real IDs |
| `lib/core/services/content_health_service.dart` | Background URL health checker — HTTP HEAD, 24h TTL, `content_health_log` Hive box |

### MODIFIED files
| File | Key changes |
|------|------------|
| `lib/main.dart` | Global error boundary widget; `AdService.initializeSdkOnly()` — no ad preload before first frame |
| `lib/core/services/ad_service.dart` | Split `initialize()` into SDK-only init; added `preloadAllPostFrame()` called from HomeScreen postFrameCallback |
| `lib/core/services/hive_service.dart` | Added `explore_consumed`, `content_health_log`, `ad_tap_counters` boxes; `markConsumed()`, `isConsumed()`, `getAllConsumedIds()`, `clearConsumedItems()`, `incrementTapCounter()` |
| `lib/core/services/rss_service.dart` | `fetchAll()` now uses `Future.wait` for concurrent category fetching; `_parseSource` moved to `compute()` isolate; `hqdefault.jpg` thumbnails |
| `lib/core/constants/sources.dart` | Fixed Andrej Karpathy channel ID to `UCH-kyQ9Q-6yS1XcNj8nNPPA`; added TechWorld with Nana (`UCdngmbVKX1Tgre699-XLlUA`) to AI + Cloud categories |
| `lib/features/home/home_screen.dart` | `AdManager.instance.init()` + `AdService.preloadAllPostFrame()` in `addPostFrameCallback`; `ContentHealthService.runDailyCheckInBackground()`; `RepaintBoundary` around `IndexedStack` |
| `lib/features/today/today_screen.dart` | `AdManager.showInterstitialWithTimeout(3s)` before lesson navigation; isolated `_WeeklyGoalCard` StatefulWidget with `TweenAnimationBuilder`; `BouncingScrollPhysics`; `RepaintBoundary` on streak card; banner load moved to `addPostFrameCallback` |
| `lib/features/paths/paths_screen.dart` | `AdManager.showInterstitialForSection('path_cards', …)` — every-other-tap rule; `AutomaticKeepAliveClientMixin` added |
| `lib/features/paths/path_detail_screen.dart` | `AdManager.showInterstitialForSection('lesson_taps', …)` — every-other-tap; rewarded ad dialog for locked lessons; "Unavailable" badge + broken-link report dialog using `ContentHealthService`; `BouncingScrollPhysics` |
| `lib/features/explore/explore_screen.dart` | Consumed-to-bottom sort; `✓ Watched`/`✓ Read` chip on consumed items; long-press + header button to clear history; sticky bottom `BannerAd`; native ad every 5 items; video play-button overlay on thumbnails; teal Video badge vs purple Article badge; `url_launcher` to open YouTube app; `memCacheWidth/Height` on `CachedNetworkImage`; `RepaintBoundary` on screen root and bottom banner |

---

## pubspec.yaml — No new dependencies required

All packages needed are already in your `pubspec.yaml`:

```yaml
# Already present — no additions needed:
http: ^1.2.0            # ContentHealthService HEAD requests
hive: ^2.2.3            # New Hive boxes
hive_flutter: ^1.1.0
google_mobile_ads: ^5.1.0  # AdManager, NativeAd, BannerAd
url_launcher: ^6.3.0    # YouTube app launch in ExploreScreen
cached_network_image: ^3.3.1  # memCacheWidth/Height
dart_rss: ^3.0.2        # RSS parsing in isolate
```

**One annotation to verify:** `NativeAd` with `NativeTemplateStyle` is available in
`google_mobile_ads ^5.1.0`. If you're on an older patch version and `NativeTemplateStyle`
doesn't resolve, upgrade to `^5.2.0`.

---

## AdManager — Real Ad Unit IDs

Replace the placeholder strings in `ad_manager.dart` before release:

```dart
// lib/core/services/ad_manager.dart  (lines ~19-22)
static const _realInterstitialId  = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const _realRewardedId      = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const _realBannerId        = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const _realRewardedIntId   = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
```

In `kDebugMode` the test IDs (`ca-app-pub-3940256099942544/…`) are used automatically.

---

## QA Checklist — Manual Testing on a Real Android Device

### Section 1 — Global Performance
- [ ] **Cold start:** App opens without a red error box. Check for any red screen on startup.
- [ ] **No ad on splash:** Verify no ad banner or interstitial appears before HomeScreen is visible.
- [ ] **Tab switching:** Switch between all 4 tabs repeatedly. Confirm no jank and that each tab retains its scroll position (IndexedStack + KeepAlive working).
- [ ] **Memory:** Open the Today tab, scroll, switch to Explore and back — the Today tab should not reload (KeepAlive active).
- [ ] **Error boundary:** Force a widget exception (temporarily throw in a build method) — confirm the friendly fallback screen appears instead of a red box. Remove the throw afterwards.

### Section 2 — Today Tab
- [ ] **Interstitial before lesson:** Tap "Start Today's Lesson". An interstitial should appear (in debug: a test ad). After dismissing it, navigate to the lesson. If no ad is ready, navigation should happen automatically within 3 seconds.
- [ ] **60s cooldown:** Dismiss the ad, go back, and immediately tap "Start Today's Lesson" again. The second tap should navigate immediately (cooldown active).
- [ ] **WeeklyGoal animation:** The progress bar in Weekly Goal should animate smoothly when the tab loads, without causing the rest of the tab to flicker or rebuild.
- [ ] **Bouncing scroll:** The Today tab scroll should bounce at top/bottom on Android.
- [ ] **Banner load timing:** Banner between streak card and lesson should appear after the tab is rendered, not during initial build.

### Section 3 — My Path Tab
- [ ] **Every-other-tap on path cards:** Tap a path card (Tap 1) → interstitial appears → after dismiss, enter the path detail. Go back. Tap the same or different card again (Tap 2) → navigate immediately, NO interstitial. Tap again (Tap 3) → interstitial. Pattern holds across app restarts (counter is in Hive).
- [ ] **Every-other-tap on lessons:** Inside a path, tap a lesson (Tap 1) → interstitial → content. Back. Tap another lesson (Tap 2) → no interstitial. Back. Tap (Tap 3) → interstitial. This counter is separate from the path-card counter.
- [ ] **Unavailable badge:** If `ContentHealthService` has run and flagged a URL, the step tile should show a red "Unavailable" badge and `link_off` icon. Tapping it should show a dialog with a "Report" option.
- [ ] **Rewarded unlock:** If a step is `isLocked == true`, tapping it should show the rewarded unlock dialog. Tapping "Watch Ad" should show a rewarded test ad. After earning the reward, the content opens.

### Section 4 — Explore Tab
- [ ] **All tab shows videos + articles:** In the "All" filter, confirm the feed contains both video items (🎬 Video badge, play overlay) and article items (📄 Article badge). Scroll through at least 10+ items.
- [ ] **Videos filter:** Tap "Videos" type filter — only items with 🎬 Video badge should appear.
- [ ] **Articles filter:** Tap "Articles" type filter — only items with 📄 Article badge should appear.
- [ ] **Video tap → YouTube app:** Tap a video item. The YouTube app should open. After returning to the app (wait ~30 seconds), the item should show "✓ Watched" and move toward the bottom of the feed.
- [ ] **Article read → moves to bottom:** Open an article, scroll to the bottom (or stay for a moment), then go back. The article should now show "✓ Read" and appear below unread items in the feed.
- [ ] **Consumed-at-bottom persistence:** Close and reopen the app. Previously consumed items should still be at the bottom of the Explore feed.
- [ ] **Clear history:** Tap the history icon (top-right of Explore header). Confirm dialog appears. After confirming, all items should reappear at the top (no consumed state).
- [ ] **Long-press consumed item:** Long-press a ✓ Watched or ✓ Read item. Confirm a snackbar says "History cleared" and items reset to top.
- [ ] **Sticky bottom banner:** A banner ad should appear at the bottom of the Explore tab, below the list, fixed (not scrolling with content). It should not overlap the floating nav bar.
- [ ] **Native ad every 5 items:** Every 5th card in the list should be an ad slot (either a native ad or a placeholder box labeled "Advertisement").
- [ ] **TechWorld with Nana + Karpathy:** After pulling to refresh, check that AI/Cloud categories include content from these channels.

### Section 5 — AdMob Policy
- [ ] **Premium user:** Toggle `isPremium = true` in Hive (or via the premium screen). Verify no ads appear anywhere in the app — no banners, no interstitials, no rewarded prompts.
- [ ] **60s global cooldown:** Trigger an interstitial. Immediately tap another lesson/card. The second action should navigate without an ad. Wait 60+ seconds and verify ads resume.
- [ ] **No ads on unavailable content:** Mark a URL as unavailable in `content_health_log`. Tap its lesson — no interstitial should appear, only the "unavailable" dialog.
- [ ] **Rewarded interstitial (Progress tab XP boost):** If implemented, verify the "Watch ad → double XP" button only appears as an opt-in; it never auto-shows.
- [ ] **No ad on app open / splash:** Cold-start the app 3 times. No ad should appear during launch or onboarding.

### General
- [ ] **`flutter analyze`:** Run in the project root. Confirm zero errors (warnings are okay).
- [ ] **Release build:** Run `flutter build apk --release`. Confirm it compiles cleanly. In release mode, verify `AdManager` switches to real ad unit IDs (check logcat for the real unit ID being requested).
