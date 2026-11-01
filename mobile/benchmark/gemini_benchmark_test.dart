// Measures the real Gemini pipeline on your own photos: food name, calories and speed.
//
//   flutter test benchmark/gemini_benchmark_test.dart \
//     --dart-define=GEMINI_API_KEY=<key> --dart-define=MANIFEST=<path to csv>
//
// Manifest columns: photo path, grams, accepted names (| separated), kcal per 100 g as
// weighed (blank if unknown). Use "not food" as the name for non-food photos.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

const _manifest = String.fromEnvironment('MANIFEST', defaultValue: 'benchmark/sample_manifest.csv');
const _runs = int.fromEnvironment('RUNS', defaultValue: 2);

void main() {
  test('Gemini benchmark', () async {
    final service = GeminiNutritionService();
    expect(service.configured, isTrue, reason: 'Pass --dart-define=GEMINI_API_KEY=<key>');
    final lines = File(_manifest).readAsLinesSync().skip(1).where((line) => line.trim().isNotEmpty);
    var total = 0, correct = 0, failed = 0;
    final latencies = <int>[], calorieErrors = <double>[], spreads = <double>[];

    for (final line in lines) {
      final fields = line.split(',');
      final grams = double.parse(fields[1]);
      final names = fields[2].split('|');
      final reference = fields.length > 3 ? double.tryParse(fields[3]) : null;
      final Uint8List photo = File(fields[0]).readAsBytesSync();
      final calories = <double>[];

      for (var run = 0; run < _runs; run++) {
        total++;
        final started = DateTime.now();
        String name;
        double? per100;
        try {
          final result = await service.analyze(imageBytes: photo, weightG: grams);
          name = result.nameEn;
          per100 = result.resolvedBasisPer100g.calories;
          calories.add(per100);
          if (reference != null && reference > 0) {
            calorieErrors.add((per100 - reference).abs() / reference * 100);
          }
        } on RecognitionException catch (error) {
          name = error.code == 'NOT_FOOD' ? 'not food' : error.code;
          if (error.code != 'NOT_FOOD') failed++;
        }
        final ms = DateTime.now().difference(started).inMilliseconds;
        latencies.add(ms);
        final hit = names.any((n) => name.toLowerCase().contains(n.toLowerCase()));
        if (hit) correct++;
        print('${hit ? 'ok ' : 'NO '} ${fields[0].split('/').last} -> $name '
            '${per100 == null ? '' : '${per100.toStringAsFixed(0)} kcal/100g (ref ${reference ?? '-'}) '}${ms}ms');
      }
      if (calories.length > 1) {
        calories.sort();
        if (calories.first > 0) spreads.add((calories.last - calories.first) / calories.first * 100);
      }
    }

    latencies.sort();
    double mean(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
    print('---');
    print('name correct: $correct/$total   failures: $failed');
    print('calorie error vs reference: ${mean(calorieErrors).toStringAsFixed(1)}% (${calorieErrors.length} answers)');
    print('calorie spread between repeats: ${mean(spreads).toStringAsFixed(1)}%');
    print('time: median ${latencies[latencies.length ~/ 2]} ms, slowest ${latencies.last} ms');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
