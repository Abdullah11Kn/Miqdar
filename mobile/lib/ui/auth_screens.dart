import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/miqdar_logo.dart';

/// The logo's mark width on the splash, and where Welcome takes it from.
double _lockupWidth(Size screen) => math.min(screen.width * 0.5, 240.0);

/// How small the logo ends up on Welcome, against its size on the splash.
const double _welcomeLockupScale = 0.5;

/// Real food photos for the Welcome wall, in three columns. Sources: assets/welcome/CREDITS.md.
const List<List<String>> _wallColumns = [
  [
    'assets/welcome/kabsa-eggs.jpg',
    'assets/welcome/fattoush-bowl.jpg',
    'assets/welcome/harees.jpg',
    'assets/demo/jareesh.jpeg',
    'assets/welcome/grilled-chicken.jpg',
  ],
  [
    'assets/welcome/hummus.jpg',
    'assets/welcome/mandi-plate.jpg',
    'assets/welcome/falafel-pita.jpg',
    'assets/demo/kabsa.jpg',
    'assets/welcome/mezze-plate.jpg',
  ],
  [
    'assets/welcome/kabsa-raisins.jpg',
    'assets/welcome/fattoush-plate.jpg',
    'assets/welcome/hummus-falafel.jpg',
    'assets/welcome/mandi-pot.jpg',
  ],
];

/// Both first screens are black whatever the theme, like the launch screen before them.
Widget _onBlack(Widget child) => Theme(
      data: miqdarTheme(isDark: true),
      child: AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light, child: child),
    );

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// The logo draws itself: the bowl's outline is traced, food fills it from the foot, the star
/// lands and the bowl presses down once like a weighed plate, then the name arrives letter by
/// letter. A first-time user then goes on to Welcome with the logo where it is; everyone else
/// fades to the app. A tap skips it. With reduced motion the finished logo shows at once.
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _length = Duration(milliseconds: 2500);
  static const _hold = Duration(milliseconds: 400);

  late final AnimationController _anim = AnimationController(vsync: this, duration: _length);
  Timer? _leaveTimer;
  bool _left = false;
  bool _buzzed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_anim.isAnimating || _anim.isCompleted || _leaveTimer != null) return;
    // Welcome's photos load while the logo draws, so its wall never appears half empty.
    if (!MiqdarScope.of(context).onboarded) {
      for (final asset in _wallColumns.expand((c) => c)) {
        precacheImage(AssetImage(asset), context);
      }
    }
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
    if (!controller.onboarded) {
      // No transition: Welcome's first frame is this screen's last, and it moves the logo on.
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => const WelcomeScreen(),
        ),
      );
      return;
    }
    final needsProfile = controller.needsBodyProfile;
    final firstRun = controller.bodyProfileIsFirstRun;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => needsProfile ? BodyProfileScreen(firstRun: firstRun) : const MainShell(),
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
  static const _starLands = 0.62;

  static double _part(double t, double from, double to, [Curve curve = Curves.linear]) =>
      curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  static MiqdarMarkFrame _markAt(double t) {
    // After the star lands the bowl presses down once and eases back, like a plate set on a
    // scale. One movement, no bounce.
    final since = (t - _starLands) * _length.inMilliseconds / 1000;
    final press = (since / 0.45).clamp(0.0, 1.0);
    final dip = 9 * math.sin(math.pi * Curves.easeOut.transform(press));
    return MiqdarMarkFrame(
      outline: _part(t, 0.00, 0.42, Curves.easeInOutCubic),
      fill: _part(t, 0.25, 0.56, Curves.easeInOutSine),
      outlineFade: _part(t, 0.48, 0.62),
      star: _part(t, 0.48, _starLands + 0.06, Curves.easeOutBack),
      burst: _part(t, _starLands - 0.02, 0.92),
      dip: dip,
    );
  }

  @override
  Widget build(BuildContext context) {
    const c = MiqdarTokens.dark;
    final markWidth = _lockupWidth(MediaQuery.sizeOf(context));
    return _onBlack(
      Scaffold(
        backgroundColor: c.bg,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _leave,
          // Dead center of the whole screen, the same spot Welcome starts from.
          child: Center(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final t = _anim.value;
                return MiqdarLockup(
                  markWidth: markWidth,
                  ink: c.ink,
                  green: c.logoGreen,
                  frame: _markAt(t),
                  letters: [
                    for (var i = 0; i < 6; i++) _part(t, 0.60 + i * 0.04, 0.84 + i * 0.03, Curves.easeOutCubic),
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

/// The first screen for someone new, and where the app returns after Delete All My Data.
/// The logo rises from where the splash left it, a slow wall of real food fades in behind,
/// and the actions come up from the bottom.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late final AnimationController _reveal =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 80));
  final _stackKey = GlobalKey();
  final _slotKey = GlobalKey();
  Rect? _slot;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _reveal.value = 1;
    } else {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _drift.dispose();
    super.dispose();
  }

  /// Finds where the logo settles, which depends on the headline's height in each language.
  void _measureSlot() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final slot = _slotKey.currentContext?.findRenderObject() as RenderBox?;
    if (!mounted || stack == null || slot == null || !stack.hasSize || !slot.hasSize) return;
    final rect = slot.localToGlobal(Offset.zero, ancestor: stack) & slot.size;
    if (rect != _slot) setState(() => _slot = rect);
    if (!_reveal.isAnimating && !_reveal.isCompleted) _reveal.forward();
  }

  void _getStarted() {
    final controller = MiqdarScope.of(context);
    controller.signIn(email: '');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => controller.needsBodyProfile
            ? BodyProfileScreen(firstRun: controller.bodyProfileIsFirstRun)
            : const MainShell(),
      ),
    );
  }

  void _tryDemo() {
    MiqdarScope.of(context).signIn(email: '', displayName: 'Demo', isDemo: true);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  /// Sign Up and Log In are in place for accounts that do not exist yet, so they say so.
  void _accountsComingSoon() {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: MiqdarTokens.dark.surface,
      // Sheets take the app's theme, so this one is told it sits on the black Welcome.
      builder: (_) => _onBlack(Builder(builder: (sheet) {
        final c = sheet.mq;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.tr('Accounts are coming soon', 'الحسابات قادمة قريبًا'),
                  style: MiqdarType.titleSection.copyWith(color: c.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  s.tr(
                    'Signing up and logging in are not ready yet. Until then, Miqdar works without an account and keeps your diary on this phone.',
                    'إنشاء الحساب وتسجيل الدخول غير متاحين بعد. حتى ذلك الحين يعمل مقدار دون حساب، ويحفظ مذكرتك على هذا الهاتف.',
                  ),
                  style: MiqdarType.body.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    _getStarted();
                  },
                  child: Text(s.tr('Get Started', 'ابدأ الآن')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(sheet).pop(),
                  child: Text(s.tr('Not Now', 'ليس الآن')),
                ),
              ],
            ),
          ),
        );
      })),
    );
  }

  static double _part(double t, double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  /// Fades and lifts a piece in over its own part of the reveal.
  Widget _rise(double from, double to, Widget child) {
    final t = _part(_reveal.value, from, to);
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    const c = MiqdarTokens.dark;
    final screen = MediaQuery.sizeOf(context);
    final markWidth = _lockupWidth(screen);
    final full = MiqdarLockup.sizeFor(markWidth);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSlot());

    final pill = TextButton.styleFrom(
      foregroundColor: c.ink,
      backgroundColor: c.surfaceFloat,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: const StadiumBorder(),
      textStyle: MiqdarType.label,
    );

    return _onBlack(
      Scaffold(
        backgroundColor: c.bg,
        body: AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) {
            final move = _part(_reveal.value, 0.0, 0.55, Curves.easeInOutCubic);
            final from = screen.center(Offset.zero);
            final to = _slot?.center ?? from;
            final at = Offset.lerp(from, to, move)!;
            final scale = 1 + (_welcomeLockupScale - 1) * move;

            return Stack(
              key: _stackKey,
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: _part(_reveal.value, 0.15, 0.75, Curves.easeOut),
                  child: _FoodWall(drift: _drift),
                ),
                // A dark scrim, so the photos give way to plain black under the actions.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0x99000000), Color(0xFF000000)],
                      stops: [0.0, 0.32, 0.6],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _rise(
                          0.5,
                          0.9,
                          Row(
                            children: [
                              TextButton(
                                style: pill,
                                onPressed: controller.toggleLocale,
                                child: Text(controller.isAr ? 'English' : 'العربية'),
                              ),
                              const Spacer(),
                              TextButton(style: pill, onPressed: _tryDemo, child: Text(s.exploreDemo)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Center(
                          child: SizedBox(
                            key: _slotKey,
                            width: full.width * _welcomeLockupScale,
                            height: full.height * _welcomeLockupScale,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _rise(
                          0.42,
                          0.78,
                          Text(
                            s.tr('Weigh it. Snap it.\nKnow what you ate.', 'زِن طعامك وصوّره،\nواعرف ما تأكله.'),
                            textAlign: TextAlign.center,
                            style: MiqdarType.titleScreen.copyWith(color: c.ink, fontSize: 34, height: 42 / 34),
                          ),
                        ),
                        const SizedBox(height: 36),
                        _rise(
                          0.55,
                          0.88,
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                            onPressed: _getStarted,
                            child: Text(s.tr('Get Started', 'ابدأ الآن'), style: MiqdarType.button.copyWith(fontSize: 17)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _rise(
                          0.62,
                          0.94,
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              foregroundColor: c.ink,
                              side: BorderSide(color: c.inkMuted, width: 1),
                            ),
                            onPressed: _accountsComingSoon,
                            child: Text(s.tr('Sign Up', 'إنشاء حساب'), style: MiqdarType.button.copyWith(fontSize: 17)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _rise(
                          0.68,
                          1.0,
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: c.ink,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: _accountsComingSoon,
                            child: Text(s.tr('Log In', 'تسجيل الدخول'), style: MiqdarType.button.copyWith(fontSize: 17)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // The logo itself, flying from the splash's spot to its place above the headline.
                Positioned(
                  left: at.dx - full.width / 2,
                  top: at.dy - full.height / 2,
                  width: full.width,
                  height: full.height,
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: scale,
                      child: MiqdarLockup(markWidth: markWidth, ink: c.ink, green: c.logoGreen),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Three columns of food photos drifting slowly, the middle one against the others.
class _FoodWall extends StatelessWidget {
  const _FoodWall({required this.drift});

  final Animation<double> drift;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final tileW = (box.maxWidth + 2 * 18 - 2 * _gap) / 3;
        final tileH = tileW * 1.25;
        return ClipRect(
          child: AnimatedBuilder(
            animation: drift,
            builder: (context, _) => Stack(
              children: [
                for (var col = 0; col < 3; col++)
                  _column(col, _wallColumns[col], tileW, tileH, dpr, left: -18 + col * (tileW + _gap)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _column(int col, List<String> photos, double w, double h, double dpr, {required double left}) {
    final cycle = photos.length * (h + _gap);
    // The middle column starts half a tile lower and drifts down; the outer two drift up.
    final travel = drift.value * cycle;
    final offset = col == 1 ? (travel % cycle) - cycle - h / 2 : -(travel % cycle);
    return Positioned(
      left: left,
      top: offset,
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final photo in [...photos, ...photos, ...photos])
            Padding(
              padding: const EdgeInsets.only(bottom: _gap),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  photo,
                  width: w,
                  height: h,
                  fit: BoxFit.cover,
                  cacheWidth: (w * dpr).round(),
                  excludeFromSemantics: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
