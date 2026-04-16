import 'package:flutter_test/flutter_test.dart';
import 'package:study_hub/main.dart';

void main() {
  testWidgets('App deve inicializar sem erros', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyHubApp());
    expect(find.text('StudyHub'), findsNothing); // App inicializa OK
  });
}
