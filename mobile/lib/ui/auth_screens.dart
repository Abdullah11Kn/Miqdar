import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/charts_and_gauges.dart';
import 'widgets/miqdar_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// The logo draws itself: the bowl's outline is traced, food fills it from the foot, the star
/// lands and the bowl dips and settles like a weighed plate, then the name arrives letter by
/// letter. A tap skips it. With reduced motion the finished logo shows at once.
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _length = Duration(milliseconds: 2600);
  static const _hold = Duration(milliseconds: 450);

  late final AnimationController _anim = AnimationController(vsync: this, duration: _length);
  Timer? _leaveTimer;
  bool _left = false;
  bool _buzzed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_anim.isAnimating || _anim.isCompleted || _leaveTimer != null) return;
    if (MediaQuery.of(context).disableAnimations) {
      _anim.value = 1;
      _leaveTimer = Timer(const Duration(milliseconds: 900), _leave);
      return;
    }
    _anim.addListener(_onTick);
    _anim.forward().whenComplete(() {
      if (mounted) _leaveTimer ??= Timer(_hold, _leave);
    });
  }

  void _onTick() {
    if (!_buzzed && _anim.value >= _starLands) {
      _buzzed = true;
      HapticFeedback.lightImpact();
    }
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    final controller = MiqdarScope.of(context);
    final returning = controller.onboarded;
    final needsProfile = controller.needsBodyProfile;
    final firstRun = controller.bodyProfileIsFirstRun;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => !returning
            ? const WelcomeScreen()
            : needsProfile
                ? BodyProfileScreen(firstRun: firstRun)
                : const MainShell(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _leaveTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  // The timeline, as parts of the whole animation.
  static const _starLands = 0.60;

  static double _part(double t, double from, double to, [Curve curve = Curves.linear]) =>
      curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  static MiqdarMarkFrame _markAt(double t) {
    // After the star lands the bowl dips and settles, a damped spring like a scale reading.
    final since = (t - _starLands) * _length.inMilliseconds / 1000;
    final dip = since <= 0 ? 0.0 : 22 * math.exp(-since * 5.5) * math.sin(since * 22);
    return MiqdarMarkFrame(
      outline: _part(t, 0.00, 0.40, Curves.easeInOutCubic),
      fill: _part(t, 0.24, 0.54, Curves.easeInOutSine),
      outlineFade: _part(t, 0.46, 0.60),
      star: _part(t, 0.46, _starLands + 0.06, Curves.easeOutBack),
      burst: _part(t, _starLands - 0.02, 0.88),
      dip: dip,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Always on black, whatever the theme: the launch screen before it is black too, so the
    // logo appears with no white flash, and the colored logo is the white-on-black version.
    const c = MiqdarTokens.dark;
    final width = MediaQuery.sizeOf(context).width;
    final markWidth = math.min(width * 0.5, 240.0);
    final wordWidth = markWidth * 0.86;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.bg,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final t = _anim.value;
                final arabic = _part(t, 0.70, 0.90, Curves.easeOutCubic);
                final tagline = _part(t, 0.80, 1.00, Curves.easeOut);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 5),
                    Semantics(
                      label: 'Miqdar · مقدار',
                      image: true,
                      child: Column(
                        children: [
                          CustomPaint(
                            size: Size(markWidth, MiqdarMarkPainter.heightFor(markWidth)),
                            painter: MiqdarMarkPainter(frame: _markAt(t), ink: c.ink, green: c.logoGreen),
                          ),
                          const SizedBox(height: 36),
                          CustomPaint(
                            size: Size(wordWidth, MiqdarWordmarkPainter.heightFor(wordWidth)),
                            painter: MiqdarWordmarkPainter(
                              ink: c.ink,
                              letters: [
                                for (var i = 0; i < 6; i++)
                                  _part(t, 0.56 + i * 0.035, 0.76 + i * 0.035, Curves.easeOutCubic),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Opacity(
                            opacity: arabic,
                            child: Transform.translate(
                              offset: Offset(0, 10 * (1 - arabic)),
                              child: Text(
                                'مقدار',
                                textDirection: TextDirection.rtl,
                                style: MiqdarType.titleScreen.copyWith(color: c.ink, height: 1.2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 6),
                    Opacity(
                      opacity: tagline,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                        child: Text(
                          s.tagline,
                          textAlign: TextAlign.center,
                          style: MiqdarType.body.copyWith(color: c.inkMuted),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _selectedPreview = 0;

  static const _previews = [
    (
      asset: 'assets/demo/kabsa.jpg',
      nameEn: 'Chicken Kabsa',
      nameAr: 'كبسة دجاج',
      grams: 380,
      kcal: 692,
      protein: 41,
      carbs: 70,
      fat: 26,
    ),
    (
      asset: 'assets/demo/shawarma.jpeg',
      nameEn: 'Chicken Shawarma',
      nameAr: 'شاورما دجاج',
      grams: 190,
      kcal: 408,
      protein: 27,
      carbs: 34,
      fat: 18,
    ),
    (
      asset: 'assets/demo/jareesh.jpeg',
      nameEn: 'Saudi Jareesh',
      nameAr: 'جريش سعودي',
      grams: 260,
      kcal: 364,
      protein: 19,
      carbs: 52,
      fat: 9,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final c = context.mq;
    final dish = _previews[_selectedPreview];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Miqdar • مقدار', style: MiqdarType.titleSection.copyWith(color: c.ink)),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: c.ink,
                          backgroundColor: c.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: controller.toggleLocale,
                        child: Text(
                          controller.isAr ? 'EN' : 'العربية',
                          style: MiqdarType.label,
                        ),
                      ),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        tooltip: s.tr('Toggle theme', 'تبديل المظهر'),
                        onPressed: controller.toggleThemeMode,
                        icon: c.isDark ? MiqdarIcons.lightMode : MiqdarIcons.darkMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Real food photography with sample numbers on top
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Image.asset(
                              dish.asset,
                              key: ValueKey(dish.asset),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          // Keeps the labels readable over any photo
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.28),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),

                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: c.bg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      NutrientDot(color: c.primary, size: 8),
                                      const SizedBox(width: 7),
                                      Text(
                                        '${dish.grams} ${s.unitG} · ${s.tr("Smart Scale", "الميزان الذكي")}',
                                        style: MiqdarType.label.copyWith(color: c.ink),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(_previews.length, (idx) {
                                      final active = idx == _selectedPreview;
                                      return GestureDetector(
                                        onTap: () => setState(() => _selectedPreview = idx),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: active ? c.bg : Colors.transparent,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            s.tr(
                                              _previews[idx].nameEn.split(' ').last,
                                              _previews[idx].nameAr.split(' ').first,
                                            ),
                                            style: MiqdarType.caption.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: active ? c.ink : Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: c.bg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    s.tr(dish.nameEn, dish.nameAr),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: MiqdarType.titleCard.copyWith(color: c.ink),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              s.tr(
                                                'Sample meal · ${dish.grams} g',
                                                'وجبة نموذجية · ${dish.grams} غ',
                                              ),
                                              style: MiqdarType.caption.copyWith(color: c.inkMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${dish.kcal}',
                                              style: MiqdarType.numberLg.copyWith(fontSize: 24, height: 28 / 24, color: c.ink),
                                            ),
                                            TextSpan(
                                              text: ' ${s.unitKcal}',
                                              style: MiqdarType.label.copyWith(color: c.inkMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _NaturalMacroPill(
                                          dotColor: c.nProtein,
                                          label: s.protein,
                                          value: '${dish.protein}${s.unitG}',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _NaturalMacroPill(
                                          dotColor: c.nCarbs,
                                          label: s.carbs,
                                          value: '${dish.carbs}${s.unitG}',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _NaturalMacroPill(
                                          dotColor: c.nFat,
                                          label: s.fat,
                                          value: '${dish.fat}${s.unitG}',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    s.tr(
                      'Know what’s on your plate, down to the gram.',
                      'اعرف القيمة الغذائية لطبقك، بدقة الغرام.',
                    ),
                    style: MiqdarType.titleScreen.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.tr(
                      'Put your food on the Miqdar scale. It weighs and photographs it, and Gemini estimates the calories and nutrients.',
                      'ضع طعامك على ميزان مقدار. يزنه ويصوّره، ويقدّر Gemini السعرات والعناصر الغذائية.',
                    ),
                    style: MiqdarType.reading.copyWith(fontSize: 16, height: 26 / 16, color: c.inkMuted),
                  ),
                  const SizedBox(height: 20),

                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () {
                      controller.signIn(email: '');
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => controller.needsBodyProfile
                              ? BodyProfileScreen(firstRun: controller.bodyProfileIsFirstRun)
                              : const MainShell(),
                        ),
                      );
                    },
                    child: Text(s.tr('Get Started', 'ابدأ الآن'), style: MiqdarType.button.copyWith(fontSize: 17)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () {
                      controller.signIn(email: '', displayName: 'Demo', isDemo: true);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainShell()),
                      );
                    },
                    child: Text(s.exploreDemo),
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

/// One nutrient as plain type under its dot and name.
class _NaturalMacroPill extends StatelessWidget {
  const _NaturalMacroPill({required this.dotColor, required this.label, required this.value});

  final Color dotColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: MiqdarType.bodyStrong.copyWith(color: c.ink)),
        Row(
          children: [
            NutrientDot(color: dotColor, size: 7),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MiqdarType.caption.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
