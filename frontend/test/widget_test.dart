import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('MzaziCare app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MzaziCareApp());

    expect(find.text('MzaziCare'), findsOneWidget);
    expect(
      find.text('Continue with Google'),
      findsOneWidget,
    );
  });
}
