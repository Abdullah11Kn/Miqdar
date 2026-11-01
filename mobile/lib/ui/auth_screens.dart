import 'package:flutter/material.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'screens.dart';

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
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B110E) : const Color(0xFFF8F9F7),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18241E) : const Color(0xFF112A20),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.scale_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Miqdar • مقدار',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111815),
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? MiqdarColors.darkMuted : const Color(0xFF5A655E),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dish = _previews[_selectedPreview];

    final bgColor = isDark ? const Color(0xFF0B110E) : const Color(0xFFF8F9F7);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111815);
    final textSecondary = isDark ? const Color(0xFF9CA8A1) : const Color(0xFF5A655E);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Minimal Editorial Top Bar
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18241E) : const Color(0xFF112A20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.scale_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Miqdar  مقدار',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(0, 34),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        onPressed: controller.toggleLocale,
                        child: Text(
                          controller.isAr ? 'EN' : 'العربية',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.05),
                          minimumSize: const Size(34, 34),
                          padding: const EdgeInsets.all(7),
                        ),
                        tooltip: s.tr('Toggle theme', 'تبديل المظهر'),
                        onPressed: controller.toggleThemeMode,
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          size: 17,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Natural Editorial Food Showcase (Cal AI / Lifesum inspired)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Crisp natural dish photography
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
                            // Subtle top and bottom vignette for legibility (never heavy green)
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

                            // Top-left floating scale pill + Top-right dish switcher
                            Positioned(
                              top: 14,
                              left: 14,
                              right: 14,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(99),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.12),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          '${dish.grams} ${s.unitG} • ${s.tr("Smart Scale", "الميزان الذكي")}',
                                          style: const TextStyle(
                                            color: Color(0xFF111815),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Interactive dish dots / pills
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(99),
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
                                            padding: EdgeInsets.symmetric(
                                              horizontal: active ? 10 : 7,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: active
                                                  ? Colors.white
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(99),
                                            ),
                                            child: Text(
                                              s.tr(
                                                _previews[idx].nameEn.split(' ').last,
                                                _previews[idx].nameAr.split(' ').first,
                                              ),
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: active
                                                    ? const Color(0xFF111815)
                                                    : Colors.white.withValues(alpha: 0.85),
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

                            // Subtle center camera focus brackets
                            Center(
                              child: IgnorePointer(
                                child: SizedBox(
                                  width: 140,
                                  height: 100,
                                  child: CustomPaint(
                                    painter: _MinimalFocusPainter(),
                                  ),
                                ),
                              ),
                            ),

                            // Floating Native Nutrition Summary Card at Bottom of Photo
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 14,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF141D19).withValues(alpha: 0.95)
                                      : Colors.white.withValues(alpha: 0.96),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.16),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
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
                                                      style: TextStyle(
                                                        fontSize: 16.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: textPrimary,
                                                        letterSpacing: -0.3,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Icon(
                                                    Icons.auto_awesome_rounded,
                                                    size: 16,
                                                    color: Color(0xFF059669),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                s.tr(
                                                  'Sample meal • ${dish.grams} g',
                                                  'وجبة نموذجية • ${dish.grams} غ',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF059669).withValues(alpha: 0.20)
                                                : const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${dish.kcal} ${s.unitKcal}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? const Color(0xFF34D399)
                                                  : const Color(0xFF047857),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _NaturalMacroPill(
                                            dotColor: const Color(0xFF0EA5E9),
                                            label: s.protein,
                                            value: '${dish.protein}g',
                                            isDark: isDark,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _NaturalMacroPill(
                                            dotColor: const Color(0xFFF59E0B),
                                            label: s.carbs,
                                            value: '${dish.carbs}g',
                                            isDark: isDark,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _NaturalMacroPill(
                                            dotColor: const Color(0xFFEC4899),
                                            label: s.fat,
                                            value: '${dish.fat}g',
                                            isDark: isDark,
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
                  ),
                  const SizedBox(height: 22),

                  // Editorial Human Typography
                  Text(
                    s.tr(
                      'Know what’s on your plate, down to the gram.',
                      'اعرف القيمة الغذائية لطبقك، بدقة الغرام.',
                    ),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      height: 1.18,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.tr(
                      'Put your food on the Miqdar scale. It weighs and photographs it, and Gemini estimates the calories and nutrients.',
                      'ضع طعامك على ميزان مقدار. يزنه ويصوّره، ويقدّر Gemini السعرات والعناصر الغذائية.',
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                      height: 1.42,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Clean Primary CTA + Secondary Auth Row
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF10B981) : const Color(0xFF112A20),
                      foregroundColor: isDark ? const Color(0xFF062117) : Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      controller.signIn(email: '');
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainShell()),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          s.tr('Get Started', 'ابدأ الآن'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : const Color(0xFFDCE3DF),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      controller.signIn(email: '', displayName: 'Demo', isDemo: true);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainShell()),
                      );
                    },
                    child: Text(
                      s.exploreDemo,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
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
    required this.isDark,
  });

  final Color dotColor;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F5F3),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value $label',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2924),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
