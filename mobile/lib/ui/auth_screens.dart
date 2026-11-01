import 'package:flutter/material.dart';

import '../app.dart';
import '../models/nutrition.dart';
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
                                                    Icons.verified_rounded,
                                                    size: 16,
                                                    color: Color(0xFF059669),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                s.tr(
                                                  'Verified nutrition • ${dish.grams}g portion',
                                                  'بيانات غذائية موثقة • حصة ${dish.grams} غرام',
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
                      'Snap a photo or weigh your meal on the Miqdar scale for instant, verified macros and micronutrients.',
                      'التقط صورة لوجبتك أو زنها على ميزان مقدار للحصول على تحليل غذائي فوري وموثوق.',
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            minimumSize: const Size(0, 48),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : const Color(0xFFDCE3DF),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignInScreen()),
                          ),
                          child: Text(
                            s.signIn,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            minimumSize: const Size(0, 48),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : const Color(0xFFDCE3DF),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
                          ),
                          child: Text(
                            s.createAccount,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
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

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController(text: '');
  final password = TextEditingController(text: 'miqdar-secure-2026');
  bool obscure = true;
  String? errorText;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void _submit() {
    final s = S.of(context);
    final e = email.text.trim();
    final p = password.text;
    if (e.isEmpty || !e.contains('@')) {
      setState(() => errorText = s.tr(
            'Please enter a valid email address.',
            'يرجى إدخال بريد إلكتروني صحيح.',
          ));
      return;
    }
    if (p.length < 6) {
      setState(() => errorText = s.tr(
            'Please enter your account password.',
            'يرجى إدخال كلمة المرور الخاصة بحسابك.',
          ));
      return;
    }
    setState(() => errorText = null);
    final controller = MiqdarScope.of(context);
    controller.signIn(email: e, isDemo: false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final controller = MiqdarScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111815);
    final textSecondary = isDark ? const Color(0xFF9CA8A1) : const Color(0xFF5A655E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B110E) : const Color(0xFFF8F9F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(s.signIn),
        actions: [
          IconButton(
            tooltip: s.tr('Toggle theme', 'تبديل المظهر'),
            onPressed: controller.toggleThemeMode,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 19,
            ),
          ),
          TextButton(
            onPressed: controller.toggleLocale,
            child: Text(
              controller.isAr ? 'EN' : 'عربي',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              children: [
                Text(
                  s.tr('Welcome back', 'مرحباً بعودتك'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.tr(
                    'Sign in to access your meal diary, paired scale, and personal nutrition targets.',
                    'سجّل الدخول للوصول إلى سجل وجباتك، الميزان الذكي، وأهدافك الغذائية.',
                  ),
                  style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
                ),
                const SizedBox(height: 22),

                SurfaceCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (errorText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MiqdarColors.dangerBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: MiqdarColors.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: MiqdarColors.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorText!,
                                  style: const TextStyle(
                                    color: MiqdarColors.danger,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: s.emailLabel,
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: s.passwordLabel,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() => obscure = !obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () =>
                              _showPasswordRecoverySheet(context, email.text.trim()),
                          child: Text(s.forgotPassword),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              isDark ? const Color(0xFF10B981) : const Color(0xFF112A20),
                          foregroundColor: isDark ? const Color(0xFF062117) : Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _submit,
                        child: Text(
                          s.signIn,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Clean Instant Demo Card
                SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () {
                    controller.signIn(
                      email: 'demo@miqdar.health',
                      displayName: 'Demo Evaluator',
                      isDemo: true,
                    );
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainShell()),
                      (_) => false,
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: MiqdarColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: MiqdarColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.exploreDemo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.tr(
                                'Instant access with pre-loaded meals, scale & AI camera.',
                                'دخول فوري مع وجبات جاهزة وميزان ذكي وكاميرا الذكاء الاصطناعي.',
                              ),
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: MiqdarColors.muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.tr('New to Miqdar?', 'جديد في مقدار؟')),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
                      ),
                      child: Text(s.createAccount),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPasswordRecoverySheet(BuildContext context, String initialEmail) {
    final s = S.of(context);
    final recEmail = TextEditingController(text: initialEmail);
    var sent = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(ctx).bottom + 28,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.resetPasswordTitle,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  sent
                      ? s.tr(
                          'If an account matches ${recEmail.text.trim()}, a password reset link has been sent. Please check your inbox.',
                          'إذا كان هناك حساب مرتبط بالبريد ${recEmail.text.trim()}، فقد تم إرسال رابط إعادة التعيين.',
                        )
                      : s.resetPasswordDesc,
                ),
                const SizedBox(height: 18),
                if (!sent) ...[
                  TextField(
                    controller: recEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: s.emailLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => setSheetState(() => sent = true),
                    child: Text(s.sendResetLink),
                  ),
                ] else
                  FilledButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: Text(s.tr('Back to Sign In', 'العودة لتسجيل الدخول')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  String intention = 'balanced'; // 'track_only' | 'balanced' | 'clinician'
  bool acceptedTerms = true;
  bool optionalResearchConsent = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final controller = MiqdarScope.of(context);
    final intentions = [
      (
        'track_only',
        s.tr('Track without goals', 'تتبّع بدون أهداف محددة'),
        s.tr('Log meals & portions with zero threshold alerts.', 'تسجيل الوجبات والأوزان دون تنبيهات حدود يومية.'),
      ),
      (
        'balanced',
        s.tr('Balanced daily nutrition', 'تغذية يومية متوازنة'),
        s.tr('Standard configurable daily energy and macro targets.', 'أهداف يومية قابلة للتخصيص للسعرات والعناصر الكبرى.'),
      ),
      (
        'clinician',
        s.tr('Custom clinician-supplied targets', 'أهداف مخصصة من المختص الصحي'),
        s.tr('Enter custom sodium, sugar, or potassium thresholds.', 'إدخال حدود مخصصة للصوديوم أو السكر أو البوتاسيوم.'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.createAccount)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  s.tr(
                    'Create your personal Miqdar account. Health conditions and hardware pairing are completely optional.',
                    'أنشئ حسابك الشخصي في مقدار. الإفصاح عن الحالات الصحية أو ربط الميزان اختياري تماماً.',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: s.fullNameLabel,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: s.emailLabel,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: s.passwordLabel,
                    helperText: s.tr(
                      'Supports password managers & passphrases (15+ chars recommended).',
                      'يدعم مديري كلمات المرور والعبارات الطويلة (يُنصح بـ 15 حرفاً فأكثر).',
                    ),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  s.tr('How would you like to use Miqdar?', 'كيف ترغب في استخدام مقدار؟'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 10),
                ...intentions.map((item) {
                  final selected = intention == item.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(14),
                      borderColor: selected ? MiqdarColors.primary : null,
                      onTap: () => setState(() => intention = item.$1),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: selected ? MiqdarColors.primary : MiqdarColors.muted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                Text(item.$3, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: acceptedTerms,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    s.tr(
                      'I agree to the essential service terms & privacy policy.',
                      'أوافق على شروط الخدمة الأساسية وسياسة الخصوصية.',
                    ),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (v) => setState(() => acceptedTerms = v ?? false),
                ),
                CheckboxListTile(
                  value: optionalResearchConsent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    s.tr(
                      'Optional: Allow anonymized recognition diagnostics to improve regional food models.',
                      'اختياري: السماح بمشاركة بيانات تشخيصية مجهولة الهوية لتحسين نماذج الأطعمة المحلية.',
                    ),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  onChanged: (v) => setState(() => optionalResearchConsent = v ?? false),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: acceptedTerms
                      ? () {
                          controller.signIn(
                            email: emailCtrl.text.trim().isEmpty
                                ? ''
                                : emailCtrl.text.trim(),
                            displayName: nameCtrl.text.trim().isEmpty
                                ? UserAccount.defaultName
                                : nameCtrl.text.trim(),
                          );
                          controller.updateAccountProfile(trackingIntention: intention);
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const PairingScreen()),
                          );
                        }
                      : null,
                  child: Text(s.tr('Continue to Scale Setup (Optional)', 'المتابعة لإعداد الميزان (اختياري)')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: acceptedTerms
                      ? () {
                          controller.signIn(
                            email: emailCtrl.text.trim().isEmpty
                                ? ''
                                : emailCtrl.text.trim(),
                            displayName: nameCtrl.text.trim().isEmpty
                                ? UserAccount.defaultName
                                : nameCtrl.text.trim(),
                          );
                          controller.updateAccountProfile(trackingIntention: intention);
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const MainShell()),
                            (_) => false,
                          );
                        }
                      : null,
                  child: Text(s.tr('Skip scale setup & go to Home', 'تخطي إعداد الميزان والانتقال للرئيسية')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final claimCode = TextEditingController(text: 'MQD-015-8842');
  bool pairing = false;

  @override
  void dispose() {
    claimCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final controller = MiqdarScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.tr('Pair Miqdar Scale', 'ربط ميزان مقدار'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  s.tr(
                    'Link your physical Miqdar scale to your account using the pairing code shown on the scale display.',
                    'اربط ميزان مقدار الفعلي بحسابك باستخدام رمز الاقتران الظاهر على شاشة الميزان.',
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MiqdarColors.primary.withValues(alpha: 0.08),
                      border: Border.all(
                        color: MiqdarColors.primary.withValues(alpha: 0.22),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.scale_rounded,
                      size: 68,
                      color: MiqdarColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, color: MiqdarColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              pairing
                                  ? s.tr('Verifying device claim…', 'جارٍ التحقق من ملكية الجهاز…')
                                  : 'Miqdar-015 • Smart Scale Hub',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MiqdarColors.softGreen,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              s.tr('Ready', 'متاح'),
                              style: const TextStyle(
                                color: MiqdarColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: claimCode,
                        decoration: InputDecoration(
                          labelText: s.tr('Scale Pairing Code', 'رمز اقتران الميزان'),
                          prefixIcon: const Icon(Icons.qr_code_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: pairing
                      ? null
                      : () async {
                          setState(() => pairing = true);
                          await Future<void>.delayed(const Duration(milliseconds: 550));
                          controller.updateScaleSettings(
                            paired: true,
                            online: true,
                            wifiSsid: 'Home-5G',
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const MainShell()),
                            (_) => false,
                          );
                        },
                  icon: const Icon(Icons.link_rounded),
                  label: Text(s.tr('Pair Scale & Continue', 'ربط الميزان والمتابعة')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (_) => false,
                  ),
                  child: Text(s.continueWithoutScale),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
