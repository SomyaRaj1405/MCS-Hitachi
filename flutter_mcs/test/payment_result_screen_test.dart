import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mcs/screens/customer/payment_result_screen.dart';

void main() {
  testWidgets('successful payment renders the persisted receipt details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PaymentResultScreen(
          success: true,
          bill: {
            'amount': '1250.00',
            'description': 'Internet service',
            'merchantName': 'MCS Demo Merchant',
          },
          transactionId: 'TXN-1001',
          referenceNumber: 'SET-1001',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('The payment has been authorized and settled.'), findsOneWidget);
    expect(find.text('Internet service'), findsOneWidget);
    expect(find.text('MCS Demo Merchant'), findsOneWidget);
    expect(find.text('TXN-1001'), findsOneWidget);
    expect(find.text('SET-1001'), findsOneWidget);
    expect(find.text('PAID'), findsOneWidget);
  });

  testWidgets('declined payment exposes retry and does not show settlement reference', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PaymentResultScreen(
          success: false,
          bill: {
            'amount': '500.00',
            'description': 'Test bill',
            'merchantName': 'MCS Demo Merchant',
          },
          transactionId: 'TXN-FAILED',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Payment failed'), findsOneWidget);
    expect(find.text('Retry Payment'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('Reference No.'), findsNothing);
  });
}
