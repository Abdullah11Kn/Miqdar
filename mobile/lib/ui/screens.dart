import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'diary_and_detail_screen.dart';
import 'home_screen.dart';
import 'insights_and_goals_screen.dart';
import 'profile_and_device_screen.dart';
import 'scan_and_add_screen.dart';
import 'widgets/brand.dart';
import 'widgets/miq_icons.dart';

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
      HistoryScreen(onAddMeal: () => setState(() => index = 1)),
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
                        const Row(
                          children: [
                            MiqdarMark(size: 34),
                            SizedBox(width: 10),
                            MiqdarWordmark(size: 18),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => setState(() => index = 1),
                          icon: const Icon(MiqIcons.plusCircle),
                          label: Text(s.navAdd),
                        ),
                        const SizedBox(height: 18),
                        _SidebarItem(
                          icon: MiqIcons.house,
                          selectedIcon: MiqIcons.house,
                          label: s.navHome,
                          selected: index == 0,
                          onTap: () => setState(() => index = 0),
                        ),
                        _SidebarItem(
                          icon: MiqIcons.crosshair,
                          selectedIcon: MiqIcons.crosshair,
                          label: s.navAdd,
                          selected: index == 1,
                          onTap: () => setState(() => index = 1),
                        ),
                        _SidebarItem(
                          icon: MiqIcons.calendarBlank,
                          selectedIcon: MiqIcons.calendarBlank,
                          label: s.navDiary,
                          selected: index == 2,
                          onTap: () => setState(() => index = 2),
                        ),
                        _SidebarItem(
                          icon: MiqIcons.chartLineUp,
                          selectedIcon: MiqIcons.chartLineUp,
                          label: s.navInsights,
                          selected: index == 3,
                          onTap: () => setState(() => index = 3),
                        ),
                        _SidebarItem(
                          icon: MiqIcons.user,
                          selectedIcon: MiqIcons.user,
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
                              MiqIcons.bell,
                              color: MiqdarColors.primary,
                            ),
                          ),
                          title: Text(
                            s.navNotices,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                          leading: const Icon(MiqIcons.scales, color: MiqdarColors.primary),
                          title: Text(
                            s.navDevices,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
          bottomNavigationBar: _MiqdarNavBar(
            index: index,
            onSelect: (value) => setState(() => index = value),
          ),
        );
      },
    );
  }
}

/// Home, Diary, Insights and Profile, with Add Meal as the dial in the middle.
class _MiqdarNavBar extends StatelessWidget {
  const _MiqdarNavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final miq = Miq.of(context);

    Widget item(int page, IconData icon, IconData selectedIcon, String label) {
      final selected = index == page;
      final color = selected ? miq.text : miq.muted;
      return Expanded(
        child: InkResponse(
          key: ValueKey('nav-$page'),
          radius: 40,
          onTap: () => onSelect(page),
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 24),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final addSelected = index == 1;
    return Container(
      decoration: BoxDecoration(
        color: miq.surface,
        border: Border(top: BorderSide(color: miq.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            item(0, MiqIcons.house, MiqIcons.houseFill, s.navHome),
            item(2, MiqIcons.bookOpen, MiqIcons.bookOpenFill, s.navDiary),
            Expanded(
              child: InkResponse(
                key: const ValueKey('nav-1'),
                radius: 44,
                onTap: () => onSelect(1),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: addSelected ? miq.text : MiqdarColors.saffron,
                        ),
                        child: Icon(
                          MiqIcons.plus,
                          size: 24,
                          color: addSelected ? miq.canvas : MiqdarColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.navAdd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: miq.text,
                          fontWeight: addSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            item(3, MiqIcons.chartLineUp, MiqIcons.chartLineUp, s.navInsights),
            item(4, MiqIcons.user, MiqIcons.userFill, s.navProfile),
          ],
        ),
      ),
    );
  }
}

/// The photo from the scale, shown the moment it arrives, on a dial turning while Gemini reads it.
class _ScaleAnalyzingScreen extends StatefulWidget {
  const _ScaleAnalyzingScreen({required this.capture});

  final PendingScaleCapture capture;

  @override
  State<_ScaleAnalyzingScreen> createState() => _ScaleAnalyzingScreenState();
}

class _ScaleAnalyzingScreenState extends State<_ScaleAnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final size = MediaQuery.sizeOf(context).shortestSide.clamp(240.0, 360.0) - 40;
    return Scaffold(
      backgroundColor: MiqdarColors.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: MiqdarColors.paper,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: size,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(size * 0.075),
                        child: ClipOval(
                          child: Image.memory(widget.capture.imageBytes, fit: BoxFit.cover),
                        ),
                      ),
                      RotationTransition(
                        turns: turn,
                        child: Theme(
                          data: Theme.of(context).copyWith(brightness: Brightness.dark),
                          child: MeasureDial(
                            size: size,
                            progress: 0.28,
                            strokeWidth: 7,
                            ticks: 0,
                            child: const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  '${widget.capture.weightG.toStringAsFixed(0)} ${s.unitG}',
                  style: MiqType.display(54, color: MiqdarColors.paper, height: 1.1),
                ),
                const SizedBox(height: 6),
                Text(
                  s.tr('Gemini is analyzing your food…', 'Gemini يحلل طعامك…'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15.5, color: Color(0xFFBFB1A0), fontWeight: FontWeight.w500),
                ),
              ],
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
              const MiqdarMark(size: 20),
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
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
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
              style: MiqType.display(28, color: Miq.of(context).text, height: 1.2),
            ),
            const SizedBox(height: 12),
            if (image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
                ? MiqdarColors.accentBright.withValues(alpha: 0.18)
                : MiqdarColors.accentWash)
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
                      ? (isDark ? MiqdarColors.accentGlow : MiqdarColors.primary)
                      : (isDark ? MiqdarColors.darkMuted : MiqdarColors.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w600,
                      color: selected
                          ? (isDark ? MiqdarColors.accentGlow : MiqdarColors.primary)
                          : (isDark ? MiqdarColors.darkText : MiqdarColors.ink),
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
