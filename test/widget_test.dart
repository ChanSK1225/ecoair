import 'package:flutter_test/flutter_test.dart';
import 'package:ecoair/main.dart';
import 'package:ecoair/screens/auth/login_screen.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that we start at the login screen (AuthWrapper initial state).
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
