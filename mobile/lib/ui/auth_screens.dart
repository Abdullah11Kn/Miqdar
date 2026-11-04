import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/charts_and_gauges.dart';

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
                // The name, set in type until the app has a logo.
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
