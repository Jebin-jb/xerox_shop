import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/main.dart';
import 'package:campus_xerox/services/auth_service.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Campus Xerox App launches and shows portal selection', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    await auth.isReady;
    final data = DataService();

    await tester.pumpWidget(CampusXeroxApp(
      initialDarkMode: false,
      auth: auth,
      data: data,
    ));

    await tester.pump(const Duration(milliseconds: 200));

    // Verify Portal Selection Screen is shown when no session exists
    expect(find.text('Welcome to Campus Xerox'), findsOneWidget);
    expect(find.text('Student Portal'), findsOneWidget);
    expect(find.text('Shopkeeper Admin'), findsOneWidget);
  });
}
