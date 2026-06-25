import 'package:flutter_test/flutter_test.dart';
import 'package:raja_rani/main.dart';

void main() {
  testWidgets('Setup screen renders successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RajaRaniApp());

    // Verify that the title text is rendered.
    expect(find.text('ராஜா ராணி'), findsOneWidget);
    expect(find.text('RAJA RANI MULTIPLAYER'), findsOneWidget);
  });
}
