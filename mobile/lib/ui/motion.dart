import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// How Miqdar moves. Everything in it has weight: it travels fast, then settles once, the way a
/// scale's reading comes to rest. No bounce and no overshoot.
class MiqdarMotion {
  MiqdarMotion._();

  /// Arriving: most of the distance early, then a long soft landing.
  static const Curve settle = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Moving across the screen: a visible journey that still lands softly. Screens, photos
  /// and Add Meal use it, the same both ways, so whatever moves together stays together.
  static const Curve travel = Cubic(0.4, 0.0, 0.0, 1.0);

  /// A tab cross-fade, or a pill sliding to its new place.
  static const Duration quick = Duration(milliseconds: 220);

  /// A screen pushed on top of another.
  static const Duration page = Duration(milliseconds: 400);
  static const Duration pageBack = Duration(milliseconds: 340);

  /// Add Meal growing out of the scale bar or the Add Meal button.
  static const Duration open = Duration(milliseconds: 440);
  static const Duration close = Duration(milliseconds: 360);

  /// True when the person asked the system for less motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Screens are set down from the trailing edge and settle; the screen beneath slides back
/// a little and dims. On iOS the edge swipe still takes a screen back, following the finger.
class MiqdarPageTransitionsBuilder extends PageTransitionsBuilder {
  const MiqdarPageTransitionsBuilder({this.backSwipe = true});

  /// Whether a swipe from the leading edge goes back, as on iOS.
  final bool backSwipe;

  @override
  Duration get transitionDuration => MiqdarMotion.page;

  @override
  Duration get reverseTransitionDuration => MiqdarMotion.pageBack;

  /// Lets a screen that was not opened this way, such as the main tabs, step back too.
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          _Recede(
              animation: secondaryAnimation,
              child: child ?? const SizedBox.shrink());

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MiqdarMotion.reduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    if (route.fullscreenDialog) {
      return _Recede(
        animation: secondaryAnimation,
        child: _RiseIn(animation: animation, child: child),
      );
    }
    return _Recede(
      animation: secondaryAnimation,
      child: _SetDown(
        animation: animation,
        child: backSwipe ? _BackSwipe(route: route, child: child) : child,
      ),
    );
  }
}

/// While the finger drives the page, it follows the finger exactly.
bool _following(BuildContext context) =>
    Navigator.maybeOf(context)?.userGestureInProgress ?? false;

/// The page coming in: from the trailing edge, with a soft shadow on the edge that leads.
class _SetDown extends StatelessWidget {
  const _SetDown({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final c = context.mq;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final raw = animation.value;
        final t = _following(context) || raw == 0 || raw == 1
            ? raw
            : (animation.status == AnimationStatus.reverse
                    ? MiqdarMotion.travel.flipped
                    : MiqdarMotion.travel)
                .transform(raw);
        final width = MediaQuery.sizeOf(context).width;
        final dx = (1 - t) * width * (rtl ? -1 : 1);
        // The shadow exists only in motion, so a still page has none.
        final shadow =
            math.sin(math.pi * t).clamp(0.0, 1.0) * (c.isDark ? 0.6 : 0.16);
        // The same widgets at rest and in motion, so the page never loses its state.
        return Transform.translate(
          offset: Offset(dx, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                if (shadow > 0)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: shadow),
                    blurRadius: 28,
                    offset: Offset(rtl ? 6 : -6, 0),
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// A full-screen sheet coming up from below.
class _RiseIn extends StatelessWidget {
  const _RiseIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: CurvedAnimation(
              parent: animation,
              curve: MiqdarMotion.travel,
              reverseCurve: MiqdarMotion.travel.flipped)
          .drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
      child: child,
    );
  }
}

/// The page underneath: slides a quarter of the way back and dims, as if covered.
class _Recede extends StatelessWidget {
  const _Recede({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final c = context.mq;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final raw = animation.value;
        final t =
            _following(context)
                ? raw
                : (animation.status == AnimationStatus.reverse
                        ? MiqdarMotion.travel.flipped
                        : MiqdarMotion.travel)
                    .transform(raw);
        final width = MediaQuery.sizeOf(context).width;
        return Transform.translate(
          offset: Offset(-0.25 * width * t * (rtl ? -1 : 1), 0),
          // The same widgets at rest and in motion, so the page never loses its state.
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: t * (c.isDark ? 0.5 : 0.14)),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// The iOS edge swipe, for screens that use [MiqdarPageTransitionsBuilder]. A swipe from the
/// leading edge drags the screen away; let go past halfway, or flick, and it goes back.
class _BackSwipe extends StatefulWidget {
  const _BackSwipe({required this.route, required this.child});

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_BackSwipe> createState() => _BackSwipeState();
}

class _BackSwipeState extends State<_BackSwipe> {
  HorizontalDragGestureRecognizer? _drag;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _drag = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _start
      ..onUpdate = _update
      ..onEnd = _end
      ..onCancel = _cancel;
  }

  @override
  void dispose() {
    _drag?.dispose();
    final navigator = widget.route.navigator;
    if (_active && navigator != null) {
      // Not while the tree is being torn down.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted) navigator.didStopUserGesture();
      });
    }
    super.dispose();
  }

  bool get _enabled => widget.route.isCurrent && widget.route.popGestureEnabled;

  double get _sign => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  void _start(DragStartDetails _) {
    if (!_enabled) return;
    _active = true;
    widget.route.handleStartBackGesture(progress: 1);
  }

  void _update(DragUpdateDetails details) {
    if (!_active) return;
    final width = context.size?.width ?? 1;
    final value =
        widget.route.animation!.value - _sign * details.primaryDelta! / width;
    widget.route
        .handleUpdateBackGestureProgress(progress: value.clamp(0.0, 1.0));
  }

  void _end(DragEndDetails details) {
    if (!_active) return;
    _active = false;
    final width = context.size?.width ?? 1;
    final velocity = _sign * details.velocity.pixelsPerSecond.dx / width;
    final value = widget.route.animation!.value;
    final goBack = velocity.abs() >= 1 ? velocity > 0 : value < 0.5;
    final navigator = widget.route.navigator!;
    if (goBack) {
      // Popping reverses from where the finger left it, still following the finger's line.
      navigator.pop();
      final animation = widget.route.animation!;
      if (animation.isAnimating) {
        late final AnimationStatusListener done;
        done = (status) {
          if (!status.isAnimating) {
            navigator.didStopUserGesture();
            animation.removeStatusListener(done);
          }
        };
        animation.addStatusListener(done);
      } else {
        navigator.didStopUserGesture();
      }
    } else {
      widget.route.handleCancelBackGesture();
    }
  }

  void _cancel() {
    if (!_active) return;
    _active = false;
    widget.route.handleCancelBackGesture();
  }

  void _pointerDown(PointerDownEvent event) {
    if (_enabled) _drag!.addPointer(event);
  }

  @override
  Widget build(BuildContext context) {
    final edge = math.max(20.0, MediaQuery.paddingOf(context).left);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        PositionedDirectional(
          start: 0,
          width: edge,
          top: 0,
          bottom: 0,
          child: Listener(
              onPointerDown: _pointerDown,
              behavior: HitTestBehavior.translucent),
        ),
      ],
    );
  }
}

/// A meal's photo that flies between the meal list and Meal Detail, rounding its corners
/// from one size to the other on the way.
class MealPhotoHero extends StatelessWidget {
  const MealPhotoHero({
    super.key,
    required this.mealId,
    required this.bytes,
    required this.radius,
    this.cacheWidth,
  });

  final String mealId;
  final Uint8List bytes;
  final double radius;
  final int? cacheWidth;

  static Object tagFor(String mealId) => 'meal-photo-$mealId';

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tagFor(mealId),
      curve: MiqdarMotion.travel,
      reverseCurve: MiqdarMotion.travel.flipped,
      flightShuttleBuilder:
          (flightContext, animation, direction, fromContext, toContext) {
        final from = (fromContext.widget as Hero).child as _RoundedPhoto;
        final to = (toContext.widget as Hero).child as _RoundedPhoto;
        // [animation] is already on the Hero's curve, with 1 at Meal Detail.
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            // The animation always runs from the list's photo to the detail's photo.
            final (start, end) =
                direction == HeroFlightDirection.push ? (from, to) : (to, from);
            return _RoundedPhoto(
              bytes: bytes,
              radius: lerpDouble(start.radius, end.radius, animation.value)!,
            );
          },
        );
      },
      child:
          _RoundedPhoto(bytes: bytes, radius: radius, cacheWidth: cacheWidth),
    );
  }
}

class _RoundedPhoto extends StatelessWidget {
  const _RoundedPhoto(
      {required this.bytes, required this.radius, this.cacheWidth});

  final Uint8List bytes;
  final double radius;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(bytes,
            fit: BoxFit.cover, cacheWidth: cacheWidth, gaplessPlayback: true),
      );
}
