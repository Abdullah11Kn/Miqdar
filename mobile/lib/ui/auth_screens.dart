import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../app.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/brand.dart';
import 'widgets/miq_icons.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double progress = 0;

  @override
  void initState() {
    super.initState();
    // The dial measures itself out, then the app opens.
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => progress = 0.75);
    });
    Future<void>.delayed(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      final returning = MiqdarScope.of(context).onboarded;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => returning ? const MainShell() : const WelcomeScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiqdarColors.ink,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: MiqdarColors.ink,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Theme(
              data: Theme.of(context).copyWith(brightness: Brightness.dark),
              child: MeasureDial(
                size: 112,
                progress: progress,
                ticks: 0,
                child: const Text(
                  'م',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Plex',
                    fontWeight: FontWeight.w600,
                    fontSize: 62,
                    height: 1,
                    color: MiqdarColors.paper,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const MiqdarWordmark(size: 26, color: MiqdarColors.paper),
          ],
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
  int dish = 0;
  Timer? timer;

  static const _dishes = [
    (asset: 'assets/demo/kabsa.jpg', en: 'Chicken Kabsa', ar: 'كبسة دجاج', grams: 380, kcal: 692),
    (asset: 'assets/demo/jareesh.jpeg', en: 'Saudi Jareesh', ar: 'جريش سعودي', grams: 260, kcal: 364),
    (asset: 'assets/demo/shawarma.jpeg', en: 'Chicken Shawarma', ar: 'شاورما دجاج', grams: 190, kcal: 408),
  ];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => dish = (dish + 1) % _dishes.length);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final current = _dishes[dish];
    const cream = MiqdarColors.paper;
    const soft = Color(0xFFBFB1A0);

    return Scaffold(
      backgroundColor: MiqdarColors.ink,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: MiqdarColors.ink,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const MiqdarWordmark(size: 22, color: cream),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: cream),
                        onPressed: controller.toggleLocale,
                        child: Text(controller.isAr ? 'English' : 'العربية'),
                      ),
                      IconButton(
                        tooltip: s.tr('Dark or light', 'داكن أو فاتح'),
                        color: cream,
                        onPressed: controller.toggleThemeMode,
                        icon: Icon(
                          controller.isDark ? MiqIcons.sun : MiqIcons.moon,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final dial = (constraints.maxHeight - 44).clamp(170.0, constraints.maxWidth - 10);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Theme(
                              data: Theme.of(context).copyWith(brightness: Brightness.dark),
                              child: MeasureDial(
                                size: dial,
                                progress: current.grams / 500,
                                strokeWidth: 8,
                                child: Padding(
                                  padding: EdgeInsets.all(dial * 0.1),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 600),
                                    child: ClipOval(
                                      key: ValueKey(current.asset),
                                      child: Image.asset(
                                        current.asset,
                                        fit: BoxFit.cover,
                                        width: dial,
                                        height: dial,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: Text(
                                '${s.tr(current.en, current.ar)}  •  ${current.grams} ${s.unitG}  •  ${current.kcal} ${s.unitKcal}',
                                key: ValueKey(current.en),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: soft, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.tr(
                      'Know what’s on your plate, down to the gram.',
                      'اعرف ما في طبقك، بدقة الغرام.',
                    ),
                    style: MiqType.display(s.isAr ? 36 : 40, color: cream, height: s.isAr ? 1.35 : 1.05),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.tr(
                      'Put your food on the Miqdar scale. It weighs and photographs it, and Gemini estimates the calories and nutrients.',
                      'ضع طعامك على ميزان مقدار. يزنه ويصوّره، ويقدّر Gemini السعرات والعناصر الغذائية.',
                    ),
                    style: const TextStyle(fontSize: 14.5, height: 1.5, color: soft),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: () {
                      controller.signIn(email: '');
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainShell()),
                      );
                    },
                    child: Text(s.tr('Get Started', 'ابدأ الآن')),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: cream),
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
