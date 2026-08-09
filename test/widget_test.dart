import 'package:flutter_test/flutter_test.dart';

import 'package:inventory_app/main.dart';

void main() {
  testWidgets('App boots to the startup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const InventoryApp());
    await tester.pump();
    expect(find.text('庫存管理系統'), findsOneWidget);
  });
}
