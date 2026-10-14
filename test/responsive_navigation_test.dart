import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/screens/shopkeeper/shopkeeper_shell.dart';
import 'package:campus_xerox/screens/shopkeeper/price_management.dart';
import 'package:campus_xerox/screens/shopkeeper/bank_payment_account_screen.dart';
import 'package:campus_xerox/services/auth_service.dart';
import 'package:campus_xerox/services/data_service.dart';

void main() {
  testWidgets(
    'ShopkeeperShell: 5 bottom items, Bank & Payment Account only on Dashboard, no global FAB',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final auth = AuthService();
      final data = DataService();

      await tester.pumpWidget(
        MaterialApp(
          home: ShopkeeperShell(
            auth: auth,
            dataService: data,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify 5 items in bottom bar
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Auto Detect'), findsOneWidget);
      expect(find.text('Prices'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);

      // 2. Verify Bank & Payment Account card is visible on Dashboard
      final paymentCardFinder = find.text('Bank & Payment Account');
      expect(paymentCardFinder, findsOneWidget);

      // 3. Tap Bank & Payment Account card -> navigates to BankPaymentAccountScreen
      await tester.tap(paymentCardFinder);
      await tester.pumpAndSettle();
      expect(find.byType(BankPaymentAccountScreen), findsOneWidget);

      // 4. Tap Back arrow -> returns to Dashboard
      final backButton = find.byTooltip('Back to Dashboard');
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(find.text('Shop Dashboard'), findsOneWidget);

      // 5. Navigate to 'Prices' (tab 3)
      await tester.tap(find.text('Prices'));
      await tester.pumpAndSettle();

      // Bank & Payment Account must NOT appear on Prices
      expect(find.text('Bank & Payment Account'), findsNothing);
      // Add Paper Type FAB must be visible
      expect(find.text('Add Paper Type'), findsOneWidget);

      // 6. Navigate to 'Auto Detect' (tab 2)
      await tester.tap(find.text('Auto Detect'));
      await tester.pump(const Duration(milliseconds: 300));

      // Bank & Payment Account must NOT appear on Auto Detect
      expect(find.text('Bank & Payment Account'), findsNothing);
    },
  );

  testWidgets(
    'PriceManagement screen renders on 320px narrow mobile without RenderFlex overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final data = DataService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceManagement(
              dataService: data,
              onToggleTheme: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header renders properly
      expect(find.text('Live Price Control'), findsOneWidget);
      expect(find.text('LIVE SYNC'), findsOneWidget);

      // Verify Paper Types tab renders
      expect(find.text('Paper Types'), findsOneWidget);

      // Verify no RenderFlex overflow error was triggered
      expect(tester.takeException(), isNull);
    },
  );
}
