import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'diary_and_detail_screen.dart';
import 'home_screen.dart';
import 'insights_and_goals_screen.dart';
import 'profile_and_device_screen.dart';
import 'scan_and_add_screen.dart';

export 'auth_screens.dart';
export 'diary_and_detail_screen.dart';
export 'home_screen.dart';
export 'insights_and_goals_screen.dart';
export 'profile_and_device_screen.dart';
export 'scan_and_add_screen.dart';

/// Responsive Main Application Shell (Section 4.1 & DES-04):
/// - Compact screens (< 720 px): Bottom NavigationBar with Home, Diary, Add Meal, Insights, Profile.
/// - Medium/Wide screens (>= 720 px): Sleek NavigationRail / Sidebar + multi-column content area.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int index = widget.initialIndex;
  /// Every scale capture lands here and is consumed, so one capture opens one screen
  /// even though saving a meal rebuilds this shell.
  void _checkExternalCapture(MiqdarController controller) {
    final shellRoute = ModalRoute.of(context);
    final pending = controller.pendingScaleCapture;
    if (pending != null) {
      controller.clearPendingScaleCapture();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // A newer capture replaces whatever was left open.
        final navigator = Navigator.of(context);
        navigator.popUntil((route) => route == shellRoute);
        navigator.push(
          MaterialPageRoute(builder: (_) => _ScaleAnalyzingScreen(capture: pending)),
        );
      });
    }
    final capture = controller.latestExternalScaleCapture;
    if (capture != null) {
      controller.clearExternalScaleCapture();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // A newer capture replaces a review that was left open.
        final navigator = Navigator.of(context);
        navigator.popUntil((route) => route == shellRoute);
        navigator.push(
          MaterialPageRoute(
            builder: (_) => RecognitionResultScreen(
              result: capture,
              previewBytes: capture.imageBytes,
            ),
          ),
        );
      });
    }
    final failure = controller.latestScaleCaptureFailure;
    if (failure != null) {
      controller.clearScaleCaptureFailure();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route == shellRoute);
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _CaptureFailureSheet(
            failure: failure,
            onChooseFood: () => setState(() => index = 1),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _checkExternalCapture(controller);

    // 5 Primary Destinations (Section 4.1):
    // 0: Home
    // 1: Add / Capture
    // 2: Diary
    // 3: Insights
    // 4: Profile
    final pages = [
      HomeScreen(
        onScan: () => setState(() => index = 1),
        onOpenTab: (newIdx) => setState(() => index = newIdx),
      ),
      const ScanScreen(),
      const HistoryScreen(),
      const TrendsScreen(embedded: true),
      const ProfileScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopSidebar = constraints.maxWidth >= 780;

        if (isDesktopSidebar) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 248,
                    decoration: BoxDecoration(
                      color: isDark ? MiqdarColors.darkSurface : Colors.white,
                      border: BorderDirectional(
                        end: BorderSide(
                          color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: MiqdarColors.border),
                              ),
                              child: Image.asset('assets/branding/miqdar-logo.png'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.appNameDual,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: MiqdarColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'v3.0 • Smart Nutrition',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => setState(() => index = 1),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: Text(s.navAdd),
                        ),
                        const SizedBox(height: 18),
                        _SidebarItem(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          label: s.navHome,
                          selected: index == 0,
                          onTap: () => setState(() => index = 0),
                        ),
                        _SidebarItem(
                          icon: Icons.center_focus_weak_rounded,
                          selectedIcon: Icons.center_focus_strong_rounded,
                          label: s.navAdd,
                          selected: index == 1,
                          onTap: () => setState(() => index = 1),
                        ),
                        _SidebarItem(
                          icon: Icons.calendar_today_outlined,
                          selectedIcon: Icons.calendar_month_rounded,
                          label: s.navDiary,
                          selected: index == 2,
                          onTap: () => setState(() => index = 2),
                        ),
                        _SidebarItem(
                          icon: Icons.insights_outlined,
                          selectedIcon: Icons.insights_rounded,
                          label: s.navInsights,
                          selected: index == 3,
                          onTap: () => setState(() => index = 3),
                        ),
                        _SidebarItem(
                          icon: Icons.person_outline_rounded,
                          selectedIcon: Icons.person_rounded,
                          label: s.navProfile,
                          selected: index == 4,
                          onTap: () => setState(() => index = 4),
                        ),
                        const Spacer(),
                        const Divider(),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: Badge(
                            isLabelVisible: controller.unreadAlertsCount > 0,
                            label: Text('${controller.unreadAlertsCount}'),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: MiqdarColors.primary,
                            ),
                          ),
                          title: Text(
                            s.navNotices,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(s.navNotices)),
                                body: const SafeArea(child: AlertsScreen()),
                              ),
                            ),
                          ),
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.scale_rounded, color: MiqdarColors.primary),
                          title: Text(
                            controller.scaleDevice.deviceId,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${controller.scaleDevice.effectiveWeightG.toStringAsFixed(0)} ${s.unitG}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          children: [
                            if (controller.scaleWorking) const _CaptureProgressStrip(),
                            Expanded(child: IndexedStack(index: index, children: pages)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Compact Mobile Layout (< 780 px)
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                if (controller.scaleWorking) const _CaptureProgressStrip(),
                Expanded(child: IndexedStack(index: index, children: pages)),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: s.navHome,
              ),
              NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: MiqdarColors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, color: MiqdarColors.primary, size: 20),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: MiqdarColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                ),
                label: s.navAdd,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_today_outlined),
                selectedIcon: const Icon(Icons.calendar_month_rounded),
                label: s.navDiary,
              ),
              NavigationDestination(
                icon: const Icon(Icons.insights_outlined),
                selectedIcon: const Icon(Icons.insights_rounded),
                label: s.navInsights,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: s.navProfile,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The photo from the scale, shown the moment it arrives while Gemini analyzes it.
class _ScaleAnalyzingScreen extends StatelessWidget {
  const _ScaleAnalyzingScreen({required this.capture});

  final PendingScaleCapture capture;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.tr('Captured Scale Photo', 'صورة كاميرا الميزان'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.memory(capture.imageBytes, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 18),
                  Text(
                    s.tr('Gemini is analyzing your food…', 'Gemini يحلل طعامك…'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${capture.weightG.toStringAsFixed(0)} ${s.unitG}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells the user the scale is working, on whichever tab they happen to be.
class _CaptureProgressStrip extends StatelessWidget {
  const _CaptureProgressStrip();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final controller = MiqdarScope.of(context);
    final grams = controller.scaleDevice.effectiveWeightG;
    return Column(
      children: [
        const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.scale_rounded, size: 16, color: MiqdarColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.analyzingScalePhoto
                      ? s.tr(
                          'Gemini is analyzing your food (${grams.toStringAsFixed(0)} g)…',
                          'Gemini يحلل طعامك (${grams.toStringAsFixed(0)} غ)…',
                        )
                      : s.tr(
                          'Scale is photographing your food (${grams.toStringAsFixed(0)} g)…',
                          'الميزان يصوّر طعامك (${grams.toStringAsFixed(0)} غ)…',
                        ),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows why a scale capture produced no calories, with the photo it was based on.
class _CaptureFailureSheet extends StatelessWidget {
  const _CaptureFailureSheet({required this.failure, required this.onChooseFood});

  final ScaleCaptureFailure failure;
  final VoidCallback onChooseFood;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final controller = MiqdarScope.of(context);
    final error = failure.error;
    final image = failure.imageBytes;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              error.localizedTitle(controller.isAr),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(image, height: 200, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
            ],
            if (error.candidates.isNotEmpty) ...[
              Text('${s.tr('The AI saw', 'رأى الذكاء الاصطناعي')}: ${error.candidates.join(', ')}'),
              const SizedBox(height: 8),
            ],
            Text(error.recoveryAdvice(controller.isAr)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onChooseFood();
              },
              child: Text(s.tr('Back to Add Meal', 'العودة إلى إضافة وجبة')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? (isDark
                ? MiqdarColors.emeraldBright.withValues(alpha: 0.18)
                : MiqdarColors.softGreen)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 21,
                  color: selected
                      ? (isDark ? MiqdarColors.mintGlow : MiqdarColors.primary)
                      : (isDark ? MiqdarColors.darkMuted : MiqdarColors.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? (isDark ? MiqdarColors.mintGlow : MiqdarColors.primary)
                          : (isDark ? Colors.white : MiqdarColors.dark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
