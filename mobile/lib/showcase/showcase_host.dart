import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../data/local_database.dart';
import '../services/alert_service.dart';
import '../services/api_service.dart';
import 'showcase.dart';

/// Opens the real diary or a showcase scenario. The diary's database stays open the whole time;
/// a scenario's file is deleted and seeded afresh each time it is started.
class ShowcaseLauncher {
  ShowcaseLauncher(this.diary);

  final LocalDatabase diary;
  LocalDatabase? _scenarioDb;

  static const _activeKey = 'showcase_active';

  /// On launch: the scenario that was open when the app closed, else the diary.
  Future<MiqdarController> openAtLaunch() async {
    await diary.initialize();
    final active = Showcase.byName(await diary.getSetting(_activeKey));
    if (active != null && await LocalDatabase.filesExist(active.fileName)) {
      return _controllerFor(active);
    }
    return _controllerFor(null);
  }

  /// Starts [showcase] from scratch, or goes back to the diary for null.
  Future<MiqdarController> open(Showcase? showcase, ShowcaseCarryOver carry) async {
    await _scenarioDb?.close();
    _scenarioDb = null;
    await diary.saveSetting(_activeKey, showcase?.name ?? '');
    if (showcase == null) {
      // A capture made during the scenario must not reopen in the diary as a new meal.
      if (carry.lastCaptureEvent != null) await diary.saveSetting('last_capture_event', carry.lastCaptureEvent!);
      return _controllerFor(null);
    }
    await LocalDatabase.deleteFiles(showcase.fileName);
    final db = LocalDatabase(fileName: showcase.fileName);
    await db.initialize();
    await ShowcaseSeeder(db).seed(showcase, carry);
    return _controllerFor(showcase, db: db);
  }

  Future<MiqdarController> _controllerFor(Showcase? showcase, {LocalDatabase? db}) async {
    final database = showcase == null ? diary : (db ?? LocalDatabase(fileName: showcase.fileName));
    if (showcase != null) _scenarioDb = database;
    final controller = MiqdarController(
      localDatabase: database,
      apiService: ApiService(),
      alertService: AlertService(),
    )..showcase = showcase;
    await controller.initialize();
    return controller;
  }
}

/// Holds the app and swaps it for a fresh one, from the splash, when a scenario starts or ends.
class MiqdarRoot extends StatefulWidget {
  const MiqdarRoot({super.key, required this.launcher, required this.initial});

  final ShowcaseLauncher launcher;
  final MiqdarController initial;

  @override
  State<MiqdarRoot> createState() => _MiqdarRootState();
}

class _MiqdarRootState extends State<MiqdarRoot> {
  late MiqdarController _controller = _wire(widget.initial);
  int _generation = 0;
  bool _switching = false;

  MiqdarController _wire(MiqdarController controller) => controller..switchShowcase = _switch;

  Future<void> _switch(Showcase? showcase) async {
    if (_switching) return;
    _switching = true;
    final old = _controller;
    old.suspend();
    try {
      final next = await widget.launcher.open(showcase, old.showcaseCarryOver);
      if (!mounted) return;
      setState(() {
        _controller = _wire(next);
        _generation++;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    } finally {
      _switching = false;
    }
  }

  @override
  Widget build(BuildContext context) => MiqdarApp(key: ValueKey(_generation), controller: _controller);
}
