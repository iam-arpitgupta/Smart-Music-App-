import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('MusicApp renders HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MusicApp());
    // Verify the search hint text appears on the home screen.
    expect(find.text('Search for your favorite music'), findsOneWidget);
  });
}
