import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/models/nutrition.dart';

void main() {
  test('nutrition totals add without losing alert nutrients', () {
    const first = NutritionValues(
      calories: 100,
      protein: 10,
      carbohydrates: 12,
      fat: 3,
      sugar: 2,
      fiber: 1,
      sodium: 100,
      potassium: 200,
    );
    final total = first + first;
    expect(total.calories, 200);
    expect(total.sugar, 4);
    expect(total.sodium, 200);
    expect(total.potassium, 400);
  });
}
