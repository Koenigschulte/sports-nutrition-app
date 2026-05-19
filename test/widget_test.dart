import 'package:flutter_test/flutter_test.dart';
import 'package:sports_nutrition_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App starts without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SportsNutritionApp()));
    expect(find.byType(SportsNutritionApp), findsOneWidget);
  });
}
