import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/theme.dart';

/// The app's own page transition replaces iOS's, so it has to keep the edge swipe that
/// takes a screen back, from the left in English and from the right in Arabic.
void main() {
  Future<void> openSecondScreen(WidgetTester tester, TextDirection direction) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: miqdarTheme().copyWith(platform: TargetPlatform.iOS),
        builder: (context, child) => Directionality(textDirection: direction, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Text('Second')))),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
  }

  Future<void> swipe(WidgetTester tester, {required double fromX, required double by}) async {
    final gesture = await tester.startGesture(Offset(fromX, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(by / 10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a swipe from the left edge goes back in English', (tester) async {
    await openSecondScreen(tester, TextDirection.ltr);
    await swipe(tester, fromX: 5, by: 500);
    expect(find.text('Second'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('a swipe from the right edge goes back in Arabic', (tester) async {
    await openSecondScreen(tester, TextDirection.rtl);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    await swipe(tester, fromX: width - 5, by: -500);
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('a short slow swipe stays on the screen', (tester) async {
    await openSecondScreen(tester, TextDirection.ltr);
    final gesture = await tester.startGesture(const Offset(5, 300));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('a swipe that starts away from the edge does nothing', (tester) async {
    await openSecondScreen(tester, TextDirection.ltr);
    await swipe(tester, fromX: 200, by: 500);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('the screen underneath keeps its state while another opens and closes over it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: miqdarTheme().copyWith(platform: TargetPlatform.iOS),
        home: const _Counter(),
      ),
    );
    await tester.tap(find.text('Count 0'));
    await tester.pump();
    final state = tester.state(find.byType(_Counter));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Count 1'), findsOneWidget);
    expect(tester.state(find.byType(_Counter)), same(state));
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Column(
          children: [
            TextButton(onPressed: () => setState(() => count++), child: Text('Count $count')),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(), body: const Text('Second'))),
              ),
              child: const Text('Open'),
            ),
          ],
        ),
      );
}
