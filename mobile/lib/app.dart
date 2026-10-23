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
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final isAr = controller.isAr;
            final isDark = controller.isDark;
            return MaterialApp(
              title: isAr ? 'مقدار • Miqdar' : 'Miqdar • مقدار',
              debugShowCheckedModeBanner: false,
              locale: controller.locale,
              themeMode: controller.themeMode,
              theme: miqdarTheme(isDark: false),
              darkTheme: miqdarTheme(isDark: true),
              builder: (context, child) {
                final directionalChild = Directionality(
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  child: child ?? const SizedBox.shrink(),
                );
                if (!controller.forceMobileFrameOnDesktop) {
                  return directionalChild;
                }
                return ColoredBox(
                  color: isDark ? const Color(0xFF050A08) : const Color(0xFFE2EAE5),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Material(
                            elevation: 14,
                            child: directionalChild,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              home: const SplashScreen(),
            );
          },
        ),
      );
}
