import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'describe_meal_sheet.dart';
import 'diary_and_detail_screen.dart';
import 'home_screen.dart';
import 'insights_and_goals_screen.dart';
import 'motion.dart';
import 'profile_and_device_screen.dart';
import 'scan_and_add_screen.dart';
import 'widgets/charts_and_gauges.dart';

export 'auth_screens.dart';
export 'body_profile_screen.dart';
export 'describe_meal_sheet.dart';
export 'diary_and_detail_screen.dart';
export 'home_screen.dart';
export 'insights_and_goals_screen.dart';
export 'motion.dart';
export 'profile_and_device_screen.dart';
export 'reminders_screen.dart';
export 'scan_and_add_screen.dart';

/// The app's frame. On a phone, the scale bar and the tab capsule float over the content.
/// From 780 px wide, a sidebar takes their place.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  late int index = widget.initialIndex;

  // How the phone layout moves between tabs. Add Meal grows out of the scale bar when the bar
  // is tapped, and shrinks back into it; every other change, the Add Meal button included,
  // is a quiet fade.
  final _stageKey = GlobalKey();
  final _barKey = GlobalKey();
  Rect? _growRect;
  bool _sidebar = false;

  /// The tab still on screen while the next one arrives.
  int? _leaving;

  late final AnimationController _fade = AnimationController(vsync: this, duration: MiqdarMotion.quick)
    ..addStatusListener(_settled);
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: MiqdarMotion.open,
    reverseDuration: MiqdarMotion.close,
    value: widget.initialIndex == 1 ? 1 : 0,
  )..addStatusListener(_settled);
  late final CurvedAnimation _growCurve =
      CurvedAnimation(parent: _grow, curve: MiqdarMotion.travel, reverseCurve: MiqdarMotion.travel.flipped);

  @override
  void dispose() {
    _growCurve.dispose();
    _fade.dispose();
    _grow.dispose();
    super.dispose();
  }

  void _settled(AnimationStatus status) {
    if (!status.isAnimating && !_fade.isAnimating && !_grow.isAnimating && _leaving != null && mounted) {
      setState(() => _leaving = null);
    }
  }

  /// Opens tab [next]. Add Meal grows out of the scale bar when that is what was tapped
  /// ([fromBar]); from the Add Meal button or anywhere else it fades in like a tab.
  void _go(int next, {bool fromBar = false}) {
    if (next == index) return;
    if (_sidebar || MiqdarMotion.reduced(context)) {
      setState(() {
        index = next;
        _leaving = null;
      });
      _grow.value = next == 1 ? 1 : 0;
      return;
    }
    setState(() {
      _leaving = index;
      index = next;
    });
    if (next == 1 && fromBar) {
      _growRect = _measure(_barKey);
      _grow.forward();
    } else if (_leaving == 1 && _grow.value > 0) {
      // It grew out of the bar, so it goes back into it.
      _grow.reverse();
    } else {
      _fade.forward(from: 0);
    }
  }

  /// Where [key]'s widget sits on the tab stage, or null when it is not on screen.
  Rect? _measure(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stage = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stage == null || !box.attached || !box.hasSize || !stage.hasSize) return null;
    return stage.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
  }
  /// Every scale capture lands here and is consumed, so one capture opens one screen
  /// even though saving a meal rebuilds this shell.
  void _checkExternalCapture(MiqdarController controller) {
    final shellRoute = ModalRoute.of(context);
    if (controller.closeScaleScreens) {
      controller.closeScaleScreens = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route == shellRoute);
      });
    }
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
            hostContext: context,
            failure: failure,
            onRetry: () => controller.retryScaleAnalysis(failure),
            onChooseFood: () => _go(1),
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
        onScan: () => _go(1),
        onOpenTab: _go,
      ),
      const ScanScreen(),
      HistoryScreen(onAddMeal: () => _go(1)),
      const TrendsScreen(embedded: true),
      const ProfileScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopSidebar = constraints.maxWidth >= 780;
        _sidebar = isDesktopSidebar;
        final c = context.mq;

        if (isDesktopSidebar) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 268,
                    decoration: BoxDecoration(
                      border: BorderDirectional(end: BorderSide(color: c.border)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(s.appNameDual, style: MiqdarType.titleSection.copyWith(color: c.ink)),
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
                        _ScaleBar(onOpenAddMeal: () => setState(() => index = 1)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: IndexedStack(index: index, children: pages),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // extendBody lets content scroll under the bars, and adds their height to the
        // bottom padding each tab reads to keep its last row clear of them.
        return Scaffold(
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: _stage(pages),
          ),
          bottomNavigationBar: _FloatingBars(
            selectedIndex: index,
            onSelected: _go,
            onOpenAddMealFromBar: () => _go(1, fromBar: true),
            barKey: _barKey,
            growth: _growCurve,
          ),
        );
      },
    );
  }
}

/// The phone layout's tabs. Every tab stays built, as in an IndexedStack, so each keeps its
/// scroll and state; only the tab on screen and, for a moment, the one leaving are painted.
extension on _MainShellState {
  static const _tabOrder = [0, 2, 3, 4];

  Widget _stage(List<Widget> pages) {
    return LayoutBuilder(
      key: _stageKey,
      builder: (context, constraints) => AnimatedBuilder(
        animation: Listenable.merge([_fade, _grow]),
        builder: (context, _) {
          final c = context.mq;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final growing = _grow.isAnimating;
          final fading = !growing && _fade.isAnimating;
          // During Add Meal's growth it is on top, over the tab it leaves or returns to.
          final top = growing ? 1 : index;
          final under = growing ? (index == 1 ? _leaving : index) : (fading ? _leaving : null);

          final p = _growCurve.value;
          final full = Offset.zero & constraints.biggest;
          if (growing && _grow.status == AnimationStatus.reverse) {
            // The scale bar comes back as Add Meal closes, so follow where it really is.
            _growRect = _measure(_barKey) ?? _growRect;
          }
          final origin = _growRect ?? Rect.fromCenter(center: full.bottomCenter, width: 64, height: 64);
          final originColor = Color.alphaBlend(c.surfaceFloat, c.bg);

          // Fade-through: the old tab goes first, then the new one arrives from the side it is on.
          final f = _fade.value;
          final fromPos = _tabOrder.indexOf(_leaving ?? index);
          final toPos = _tabOrder.indexOf(index);
          final side = (toPos >= fromPos ? 1.0 : -1.0) * (rtl ? -1 : 1);
          final arrive = MiqdarMotion.settle.transform(const Interval(0.3, 1).transform(f));

          Widget frame(int i) {
            final visible = i == top || i == under;
            var opacity = 1.0;
            var dx = 0.0;
            var dy = 0.0;
            Rect? clip;
            var radius = 0.0;
            Color? shadow;
            var fill = Colors.transparent;
            var scrim = 0.0;
            var content = 1.0;
            if (growing && i == 1) {
              clip = Rect.lerp(origin, full, p);
              radius = ui.lerpDouble(16, 0, p)!;
              fill = Color.lerp(originColor, c.bg, const Interval(0, 0.6).transform(p))!;
              // Opening shows the screen once it has room; closing keeps it in view until it is small.
              content = _grow.status == AnimationStatus.reverse
                  ? const Interval(0.1, 0.55).transform(p)
                  : const Interval(0.3, 0.85).transform(p);
              // An edge to see it by, white over white, gone as it fills the screen.
              shadow = Colors.black.withValues(alpha: (1 - p) * (c.isDark ? 0.7 : 0.22));
            } else if (growing && i == under) {
              scrim = p * (c.isDark ? 0.45 : 0.12);
            } else if (fading && i == _leaving) {
              opacity = 1 - const Interval(0, 0.35).transform(f);
            } else if (fading && i == index) {
              opacity = arrive;
              // Add Meal is not in the tab row, so it rises a little instead of coming from a side.
              if (i == 1) {
                dy = (1 - arrive) * 12;
              } else {
                dx = (1 - arrive) * 16 * side;
              }
            }
            return KeyedSubtree(
              key: ValueKey(i),
              child: Offstage(
                offstage: !visible,
                child: TickerMode(
                  enabled: visible,
                  child: HeroMode(
                    enabled: i == index,
                    child: IgnorePointer(
                      ignoring: i != index,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(dx, dy),
                          child: CustomPaint(
                            painter: clip == null || shadow == null ? null : _GrowShadow(clip, radius, shadow),
                            child: ClipPath(
                              clipper: _GrowClip(clip, radius),
                              clipBehavior: clip == null ? Clip.none : Clip.antiAlias,
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: fill),
                                child: DecoratedBox(
                                  position: DecorationPosition.foreground,
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: scrim)),
                                  child: Opacity(opacity: content, child: pages[i]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // A fixed order, never reshuffled: Add Meal is last, so it paints over the tab it grows
          // from or shrinks into. Between other tabs the old one fades out before the new one
          // shows, so their order does not matter.
          final order = [for (var i = 0; i < pages.length; i++) if (i != 1) i, 1];
          return Stack(fit: StackFit.expand, children: [for (final i in order) frame(i)]);
        },
      ),
    );
  }
}

/// The soft shadow under Add Meal while it grows or shrinks.
class _GrowShadow extends CustomPainter {
  const _GrowShadow(this.rect, this.radius, this.color);

  final Rect rect;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)).shift(const Offset(0, 6)),
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  @override
  bool shouldRepaint(_GrowShadow old) => old.rect != rect || old.radius != radius || old.color != color;
}

/// Add Meal's outline while it grows: from the scale bar or the button to the whole screen.
class _GrowClip extends CustomClipper<Path> {
  const _GrowClip(this.rect, this.radius);

  final Rect? rect;
  final double radius;

  @override
  Path getClip(Size size) {
    final r = rect;
    if (r == null) return Path()..addRect(Offset.zero & size);
    return Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
  }

  @override
  bool shouldReclip(_GrowClip old) => old.rect != rect || old.radius != radius;
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
                    borderRadius: BorderRadius.circular(24),
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
                    style: MiqdarType.titleCard.copyWith(color: context.mq.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${capture.weightG.toStringAsFixed(0)} ${s.unitG}',
                    textAlign: TextAlign.center,
                    style: MiqdarType.bodyStrong.copyWith(color: context.mq.inkMuted),
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

/// Shows why a scale capture produced no calories, with the photo it was based on.
class _CaptureFailureSheet extends StatelessWidget {
  const _CaptureFailureSheet({
    required this.hostContext,
    required this.failure,
    required this.onRetry,
    required this.onChooseFood,
  });

  final BuildContext hostContext;
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
              style: MiqdarType.titleSection.copyWith(color: context.mq.ink),
            ),
            const SizedBox(height: 12),
            if (image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
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
                openDescribeMeal(hostContext);
              },
              child: Text(s.tr('Describe It Instead', 'صِفه بدلاً من ذلك')),
            ),
            const SizedBox(height: 8),
            if (failure.plate != null) ...[
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  controller.openPlateForNaming(failure.plate!);
                },
                child: Text(s.tr('Name the Foods Myself', 'سأسمي الأطعمة بنفسي')),
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

/// What floats at the bottom of the phone layout, over content that fades out beneath it.
class _FloatingBars extends StatelessWidget {
  const _FloatingBars({
    required this.selectedIndex,
    required this.onSelected,
    required this.onOpenAddMealFromBar,
    required this.barKey,
    required this.growth,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onOpenAddMealFromBar;
  final GlobalKey barKey;

  /// How far Add Meal has grown. The scale bar shows again as Add Meal shrinks back into it.
  final Animation<double> growth;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: const [0.55, 1],
                  colors: [c.bg, c.bg.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 30, 20, bottomInset > 12 ? bottomInset : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add Meal already has the weight and Capture, as its whole screen.
              if (selectedIndex != 1) ...[
                FadeTransition(
                  opacity: growth.drive(CurveTween(curve: const Interval(0, 0.25))).drive(Tween(begin: 1.0, end: 0.0)),
                  child: _ScaleBar(key: barKey, onOpenAddMeal: onOpenAddMealFromBar),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _TabCapsule(
                      selectedIndex: selectedIndex,
                      onSelected: onSelected,
                      items: [
                        (index: 0, icon: MiqdarIcons.home, label: s.navHome),
                        (index: 2, icon: MiqdarIcons.calendarMonth, label: s.navDiary),
                        (index: 3, icon: MiqdarIcons.insights, label: s.navInsights),
                        (index: 4, icon: MiqdarIcons.person, label: s.navProfile),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: s.navAdd,
                    child: Semantics(
                      button: true,
                      label: s.navAdd,
                      excludeSemantics: true,
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: c.floatShadow),
                        child: Material(
                          key: const ValueKey('addMealButton'),
                          color: c.primary,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onSelected(1),
                            child: SizedBox.square(
                              dimension: 64,
                              child: Icon(MiqdarIcons.addAPhoto, fill: 1, size: 26, color: c.onPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Glass for what floats: `surfaceFloat` over a 20 px blur.
class _FloatingGlass extends StatelessWidget {
  const _FloatingGlass({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: c.floatShadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(color: c.surfaceFloat, child: child),
        ),
      ),
    );
  }
}

class _TabCapsule extends StatefulWidget {
  const _TabCapsule({required this.selectedIndex, required this.onSelected, required this.items});

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<({int index, IconData icon, String label})> items;

  @override
  State<_TabCapsule> createState() => _TabCapsuleState();
}

/// The pill under the selected tab slides to the next one. On Add Meal no tab is selected,
/// so it fades where it stands.
class _TabCapsuleState extends State<_TabCapsule> {
  int _lastSlot = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    final items = widget.items;
    final slot = items.indexWhere((item) => item.index == widget.selectedIndex);
    if (slot >= 0) _lastSlot = slot;
    final duration = MiqdarMotion.reduced(context) ? Duration.zero : MiqdarMotion.quick;
    return _FloatingGlass(
      radius: 32,
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedPositionedDirectional(
                  duration: duration,
                  curve: MiqdarMotion.settle,
                  start: _lastSlot * width,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: slot >= 0 ? 1 : 0,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(color: c.surfaceSunken, shape: const StadiumBorder()),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final item in items)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: item.index == widget.selectedIndex,
                          child: Material(
                            type: MaterialType.transparency,
                            shape: const StadiumBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => widget.onSelected(item.index),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.icon,
                                    fill: item.index == widget.selectedIndex ? 1 : 0,
                                    color: item.index == widget.selectedIndex ? c.ink : c.inkMuted,
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      style: MiqdarType.caption.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: item.index == widget.selectedIndex ? c.ink : c.inkMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The scale on every tab, the way a music app shows what is playing: weight, one line of
/// status and a round Capture button. A plate in progress finishes on Add Meal.
class _ScaleBar extends StatelessWidget {
  const _ScaleBar({super.key, required this.onOpenAddMeal});

  final VoidCallback onOpenAddMeal;

  Future<void> _capture(BuildContext context, MiqdarController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.captureFromScale();
    } on RecognitionException catch (error) {
      // The scale published this failure with its photo; MainShell is already showing it.
      if (error.eventId != null) return;
      messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    final controller = MiqdarScope.of(context);
    final scale = controller.scaleDevice;
    final state = scale.visualState;
    final hasWeight = state == ScaleVisualState.connected || state == ScaleVisualState.simulated;
    final grams = scale.effectiveWeightG < 0 ? 0.0 : scale.effectiveWeightG;
    final working = controller.scaleWorking;
    final plate = controller.scalePlate;
    final plateOpen = plate != null && plate.isOpen;
    final canCapture = hasWeight && !working && (grams >= 5 || scale.simulated);

    final String status;
    var statusColor = c.inkMuted;
    var liveDot = false;
    if (working) {
      status = controller.analyzingScalePhoto
          ? s.tr('Gemini is analyzing your food…', 'Gemini يحلل طعامك…')
          : s.tr('Taking the photo. Keep your hands off the plate.', 'جارٍ التقاط الصورة. أبعد يدك عن الطبق.');
    } else if (state == ScaleVisualState.disconnected || state == ScaleVisualState.fault) {
      status = s.tr('Tap to connect', 'اضغط للاتصال');
      statusColor = c.accentInk;
    } else if (state == ScaleVisualState.simulated) {
      status = s.tr('Simulated scale, not real food', 'ميزان محاكاة، ليس طعاماً حقيقياً');
      statusColor = c.accentInk;
    } else if (plateOpen) {
      status = s.tr('Add the next food, or Finish.', 'أضف الطعام التالي، أو اضغط إنهاء.');
      liveDot = true;
    } else if (grams < 5) {
      status = s.tr('Put your food on the plate', 'ضع طعامك على الطبق');
      liveDot = true;
    } else {
      status = scale.isStable ? s.tr('Ready to capture', 'جاهز للالتقاط') : s.tr('On the scale', 'على الميزان');
      liveDot = true;
    }

    final Widget title = hasWeight
        ? Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: ui.TextDirection.ltr,
            children: [
              LockedNumber(grams.toStringAsFixed(0), style: MiqdarType.titleCard.copyWith(fontSize: 16, color: c.ink)),
              const SizedBox(width: 4),
              Text(s.unitG, style: MiqdarType.titleCard.copyWith(fontSize: 16, color: c.ink)),
            ],
          )
        : Text(
            state == ScaleVisualState.fault
                ? s.tr('Weight sensor not responding', 'حساس الوزن لا يستجيب')
                : s.tr('Scale not connected', 'الميزان غير متصل'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MiqdarType.titleCard.copyWith(fontSize: 16, color: c.ink),
          );

    void connect() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
        );

    return _FloatingGlass(
      radius: 16,
      child: InkWell(
        onTap: hasWeight ? onOpenAddMeal : connect,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(10)),
                    child: Icon(MiqdarIcons.scale, color: c.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(alignment: AlignmentDirectional.centerStart, child: title),
                        Row(
                          children: [
                            if (liveDot) ...[
                              NutrientDot(color: c.primary, size: 7),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MiqdarType.body.copyWith(fontSize: 13, height: 18 / 13, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!hasWeight)
                    _BarButton(
                      tooltip: s.tr('Connect', 'اتصال'),
                      background: c.surfaceSunken,
                      foreground: c.ink,
                      onPressed: connect,
                      child: const Icon(MiqdarIcons.link),
                    )
                  else if (plateOpen)
                    _BarButton(
                      tooltip: s.navAdd,
                      background: c.action,
                      foreground: c.onAction,
                      onPressed: onOpenAddMeal,
                      child: const Icon(MiqdarIcons.add),
                    )
                  else
                    _BarButton(
                      tooltip: s.tr('Capture', 'التقاط'),
                      background: c.action,
                      foreground: c.onAction,
                      onPressed: canCapture ? () => _capture(context, controller) : null,
                      child: working
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onAction),
                            )
                          : const Icon(MiqdarIcons.photoCamera, fill: 1),
                    ),
                ],
              ),
            ),
            if (working)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1,
          child: Material(
            color: background,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 44,
                child: IconTheme.merge(data: IconThemeData(color: foreground), child: Center(child: child)),
              ),
            ),
          ),
        ),
      );
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
        color: selected ? c.surfaceSunken : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, fill: selected ? 1 : 0, color: selected ? c.ink : c.inkMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: MiqdarType.bodyStrong.copyWith(color: selected ? c.ink : c.inkMuted),
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
