import 'package:flutter/material.dart';

import 'data/local_database.dart';
import 'showcase/showcase_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final launcher = ShowcaseLauncher(LocalDatabase());
  final controller = await launcher.openAtLaunch();
  runApp(MiqdarRoot(launcher: launcher, initial: controller));
}
