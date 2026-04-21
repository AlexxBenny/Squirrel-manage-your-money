import 'package:flutter_test/flutter_test.dart';
import 'package:squirrel/app.dart';

void main() {
  testWidgets('app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanceApp());
    expect(find.byType(FinanceApp), findsOneWidget);
  });
}
