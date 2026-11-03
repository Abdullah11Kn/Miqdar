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
            onRetry: () => controller.retryScaleAnalysis(failure),
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
      HistoryScreen(onAddMeal: () => setState(() => index = 1)),
      const TrendsScreen(embedded: true),
      const ProfileScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopSidebar = constraints.maxWidth >= 780;
        final c = context.mq;

        if (isDesktopSidebar) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 248,
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: BorderDirectional(end: BorderSide(color: c.border)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(s.appNameDual, style: MiqdarType.titleCard.copyWith(color: c.ink)),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => setState(() => index = 1),
                          icon: const Icon(MiqdarIcons.add),
                          label: Text(s.navAdd),
                        ),
                        const SizedBox(height: 16),
                        _SidebarItem(
                          icon: MiqdarIcons.home,
                          label: s.navHome,
                          selected: index == 0,
                          onTap: () => setState(() => index = 0),
                        ),
                        _SidebarItem(
                          icon: MiqdarIcons.addAPhoto,
                          label: s.navAdd,
                          selected: index == 1,
                          onTap: () => setState(() => index = 1),
                        ),
                        _SidebarItem(
                          icon: MiqdarIcons.calendarMonth,
                          label: s.navDiary,
                          selected: index == 2,
                          onTap: () => setState(() => index = 2),
                        ),
                        _SidebarItem(
                          icon: MiqdarIcons.insights,
                          label: s.navInsights,
                          selected: index == 3,
                          onTap: () => setState(() => index = 3),
                        ),
                        _SidebarItem(
                          icon: MiqdarIcons.person,
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
                            child: const Icon(MiqdarIcons.notifications),
                          ),
                          title: Text(s.navNotices, style: MiqdarType.label.copyWith(color: c.ink)),
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
                          leading: const Icon(MiqdarIcons.scale),
                          title: Text(s.navDevices, style: MiqdarType.label.copyWith(color: c.ink)),
                          subtitle: Text(
                            '${controller.scaleDevice.effectiveWeightG.toStringAsFixed(0)} ${s.unitG}',
                            style: MiqdarType.caption.copyWith(color: c.inkMuted),
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
          bottomNavigationBar: _MiqdarBottomNav(
            selectedIndex: index,
            onSelected: (value) => setState(() => index = value),
            items: [
              (icon: MiqdarIcons.home, label: s.navHome),
              (icon: MiqdarIcons.addAPhoto, label: s.navAdd),
              (icon: MiqdarIcons.calendarMonth, label: s.navDiary),
              (icon: MiqdarIcons.insights, label: s.navInsights),
              (icon: MiqdarIcons.person, label: s.navProfile),
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
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.mq.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${capture.weightG.toStringAsFixed(0)} ${s.unitG}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.mq.ink),
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
              Icon(MiqdarIcons.scale, size: 16, color: context.mq.primary),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.mq.ink),
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
  const _CaptureFailureSheet({
    required this.failure,
    required this.onRetry,
    required this.onChooseFood,
  });

  final ScaleCaptureFailure failure;
  final VoidCallback onRetry;
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.mq.ink),
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
            if (failure.canRetry) ...[
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                child: Text(s.tr('Ask Gemini Again', 'اسأل Gemini مرة أخرى')),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(
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

/// The five tabs. Add Meal, the second one, sits in its own outlined circle.
class _MiqdarBottomNav extends StatelessWidget {
  const _MiqdarBottomNav({required this.selectedIndex, required this.onSelected, required this.items});

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<({IconData icon, String label})> items;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(
            children: [
              for (final (i, item) in items.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelected(i),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 34,
                            child: OverflowBox(
                              maxHeight: 44,
                              child: _NavIcon(icon: item.icon, selected: i == selectedIndex, isAdd: i == 1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              style: MiqdarType.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: i == selectedIndex ? c.ink : c.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.selected, required this.isAdd});

  final IconData icon;
  final bool selected;
  final bool isAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return Container(
      width: isAdd ? 44 : 60,
      height: isAdd ? 44 : 34,
      decoration: BoxDecoration(
        color: selected ? c.primary : (isAdd ? c.surfaceSunken : Colors.transparent),
        borderRadius: BorderRadius.circular(999),
        border: isAdd && !selected ? Border.all(color: c.borderStrong, width: 1.5) : null,
      ),
      child: Icon(
        icon,
        fill: selected ? 1 : 0,
        color: selected ? c.onPrimary : (isAdd ? c.ink : c.inkMuted),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? c.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, fill: selected ? 1 : 0, color: selected ? c.onPrimary : c.inkMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: MiqdarType.bodyStrong.copyWith(color: selected ? c.onPrimary : c.ink),
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
