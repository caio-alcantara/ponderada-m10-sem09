// Smoke test do SkinLog.

import 'package:flutter_test/flutter_test.dart';

import 'package:skinlog/main.dart';

void main() {
  testWidgets('App inicializa exibindo o wordmark do SkinLog',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SkinLogApp());
    await tester.pump();

    expect(find.text('SkinLog'), findsWidgets);
  });
}
