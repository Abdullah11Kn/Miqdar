import 'package:flutter/material.dart';

import 'app.dart';
import 'app_controller.dart';
import 'data/local_database.dart';
import 'services/alert_service.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = MiqdarController(
    localDatabase: LocalDatabase(),
    apiService: ApiService(),
    alertService: AlertService(),
  );
  await controller.initialize();
  runApp(MiqdarApp(controller: controller));
}
