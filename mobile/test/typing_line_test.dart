import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/theme.dart';
import 'package:miqdar_mobile/ui/widgets/typing_line.dart';

String shown(WidgetTester tester) {
  final rich = tester.widget<RichText>(find.byType(RichText).first);
  return rich.text.toPlainText(includePlaceholders: false).replaceAll('​', '');
}

/// Waits for the line to empty, then for it to rest, and returns what it rests on.
Future<String> nextLine(WidgetTester tester) async {
  for (var i = 0; i < 400 && shown(tester).isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  String last = '';
  for (var i = 0; i < 400; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    final now = shown(tester);
    if (now.isNotEmpty && now == last) return now;
    last = now;
  }
  return last;
}

Widget host({bool reduce = false}) => MaterialApp(
      theme: miqdarTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: const Scaffold(
          body: TypingLine(
            lines: ['صباح الخير', 'يوم صحي', 'عِش بصحة'],
            typeStep: Duration(milliseconds: 10),
            eraseStep: Duration(milliseconds: 10),
            firstHold: Duration(seconds: 1),
            hold: Duration(seconds: 1),
            gap: Duration(milliseconds: 10),
          ),
        ),
      ),
    );

void main() {
  testWidgets('types the greeting letter by letter, then a health line, then the greeting again', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 25));
    final partial = shown(tester);
    expect(partial, isNotEmpty);
    expect('صباح الخير'.startsWith(partial), isTrue);
    expect(partial, isNot('صباح الخير'));

    await tester.pump(const Duration(milliseconds: 200));
    expect(shown(tester), 'صباح الخير');

    // Rest, erase, then the first health line; then the greeting returns before the next one.
    expect(await nextLine(tester), 'يوم صحي');
    expect(await nextLine(tester), 'صباح الخير');
    expect(await nextLine(tester), 'عِش بصحة');
  });

  testWidgets('with Reduce Motion the greeting stands still', (tester) async {
    await tester.pumpWidget(host(reduce: true));
    expect(find.text('صباح الخير'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('صباح الخير'), findsOneWidget);
  });
}
