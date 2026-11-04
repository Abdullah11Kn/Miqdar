import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/charts_and_gauges.dart';

/// The name, set in type until the app has a logo.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.hero, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(MiqdarIcons.scale, color: c.onHero, size: size / 2),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      final controller = MiqdarScope.of(context);
      final returning = controller.onboarded;
      final needsProfile = controller.needsBodyProfile;
      final firstRun = controller.bodyProfileIsFirstRun;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => !returning
              ? const WelcomeScreen()
              : needsProfile
                  ? BodyProfileScreen(firstRun: firstRun)
                  : const MainShell(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BrandMark(size: 72),
                const SizedBox(height: 20),
                Text('Miqdar • مقدار', style: MiqdarType.titleScreen.copyWith(color: c.ink)),
                const SizedBox(height: 8),
                Text(
                  s.tagline,
                  textAlign: TextAlign.center,
                  style: MiqdarType.body.copyWith(color: c.inkMuted),
                ),
              ],
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
                      const _BrandMark(size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Miqdar • مقدار', style: MiqdarType.titleCard.copyWith(color: c.ink)),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: c.ink,
                          backgroundColor: c.surfaceSunken,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
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
                      borderRadius: BorderRadius.circular(22),
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
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      NutrientDot(color: c.primary, size: 8),
                                      const SizedBox(width: 7),
                                      Text(
                                        '${dish.grams} ${s.unitG} • ${s.tr("Smart Scale", "الميزان الذكي")}',
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
                                            color: active ? c.surface : Colors.transparent,
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

                          Center(
                            child: IgnorePointer(
                              child: SizedBox(
                                width: 140,
                                height: 100,
                                child: CustomPaint(painter: _MinimalFocusPainter()),
                              ),
                            ),
                          ),

                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(22),
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
                                                const SizedBox(width: 6),
                                                Icon(MiqdarIcons.autoAwesome, size: 16, color: c.primary),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              s.tr(
                                                'Sample meal • ${dish.grams} g',
                                                'وجبة نموذجية • ${dish.grams} غ',
                                              ),
                                              style: MiqdarType.caption.copyWith(color: c.inkMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      MiqdarPill(text: '${dish.kcal} ${s.unitKcal}'),
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
                    style: MiqdarType.titleScreen.copyWith(fontSize: 26, height: 32 / 26, color: c.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.tr(
                      'Put your food on the Miqdar scale. It weighs and photographs it, and Gemini estimates the calories and nutrients.',
                      'ضع طعامك على ميزان مقدار. يزنه ويصوّره، ويقدّر Gemini السعرات والعناصر الغذائية.',
                    ),
                    style: MiqdarType.body.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(height: 20),

                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.tr('Get Started', 'ابدأ الآن'), style: MiqdarType.button.copyWith(fontSize: 17)),
                        const SizedBox(width: 8),
                        const Icon(MiqdarIcons.arrowForward, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
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

class _MinimalFocusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const len = 18.0;
    const r = 12.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, len),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - r)
        ..quadraticBezierTo(0, size.height, r, size.height)
        ..lineTo(len, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - r, size.height)
        ..quadraticBezierTo(size.width, size.height, size.width, size.height - r)
        ..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NaturalMacroPill extends StatelessWidget {
  const _NaturalMacroPill({
    required this.dotColor,
    required this.label,
    required this.value,
  });

  final Color dotColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NutrientDot(color: dotColor, size: 7),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$value $label', maxLines: 1, style: MiqdarType.label.copyWith(color: c.ink)),
            ),
          ),
        ],
      ),
    );
  }
}
