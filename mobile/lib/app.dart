import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'theme.dart';
import 'ui/screens.dart';

class MiqdarScope extends InheritedNotifier<MiqdarController> {
  const MiqdarScope({
    super.key,
    required MiqdarController controller,
    required super.child,
  }) : super(notifier: controller);

  static MiqdarController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MiqdarScope>();
    if (scope == null) throw StateError('MiqdarScope is missing');
    return scope.notifier!;
  }
}

class MiqdarApp extends StatelessWidget {
  const MiqdarApp({super.key, required this.controller});
  final MiqdarController controller;

  @override
  Widget build(BuildContext context) => MiqdarScope(
        controller: controller,
        child: MaterialApp(
          title: 'Miqdar',
          debugShowCheckedModeBanner: false,
          theme: miqdarTheme(),
          home: const SplashScreen(),
        ),
      );
}
