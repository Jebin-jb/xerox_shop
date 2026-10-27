import 'package:flutter_test/flutter_test.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/data_service.dart';

void main() {
  group('Comprehensive Verification of Tasks 1-14', () {
    test(
      'Task 2 & 3: Colour and B&W exact page lists & display text formatting',
      () {
        final pageSettings = [
          const PagePrintSetting(
            pageNumber: 1,
            printType: PrintType.bw,
            orientation: 'Portrait',
          ),
          const PagePrintSetting(
            pageNumber: 2,
            printType: PrintType.color,
            orientation: 'Landscape',
          ),
          const PagePrintSetting(
            pageNumber: 3,
            printType: PrintType.color,
            orientation: 'Portrait',
          ),
          const PagePrintSetting(
            pageNumber: 4,
            printType: PrintType.bw,
            orientation: 'Portrait',
          ),
          const PagePrintSetting(
            pageNumber: 5,
            printType: PrintType.bw,
            orientation: 'Portrait',
          ),
        ];

        final order = PrintOrder(
          id: 'test_order_paged',
          code: '5727',
          studentId: 'STU101',
          studentName: 'Alice',
          studentEmail: 'alice@campus.edu',
          fileName: 'assignment.pdf',
          fileSizeBytes: 20480,
          fileUrl: 'https://example.com/doc.pdf',
          pages: 5,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          paperType: PaperType.standard75Gsm,
          total: 25.0,
          status: OrderStatus.pending,
          paymentStatus: PaymentStatus.unpaid,
          paymentMode: PaymentMode.counter,
          createdAt: DateTime.now(),
          pageSettings: pageSettings,
        );

        // Verify exact page numbers and display text
        expect(order.resolvedColorPages, equals([2, 3]));
        expect(order.resolvedBwPages, equals([1, 4, 5]));
        expect(order.colorPagesDisplayText, equals('2, 3'));
        expect(order.bwPagesDisplayText, equals('1, 4, 5'));
        expect(order.calculatedColorPages, equals(2));
        expect(order.calculatedBwPages, equals(3));
      },
    );

    test(
      'Task 4: Student can cancel while Pending, but cannot cancel after Acceptance',
      () {
        final pendingOrder = PrintOrder(
          id: 'ord_pending',
          code: '1234',
          studentId: 'STU01',
          studentName: 'Bob',
          studentEmail: 'bob@campus.edu',
          fileName: 'test.pdf',
          fileSizeBytes: 1024,
          fileUrl: 'https://example.com/test.pdf',
          pages: 2,
          copies: 1,
          color: false,
          doubleSided: false,
          lamination: false,
          binding: false,
          paperType: PaperType.standard75Gsm,
          total: 10.0,
          status: OrderStatus.pending,
          paymentStatus: PaymentStatus.unpaid,
          paymentMode: PaymentMode.counter,
          createdAt: DateTime.now(),
        );

        expect(pendingOrder.studentCanCancel, isTrue);

        final acceptedOrder = pendingOrder.copyWith(
          status: OrderStatus.accepted,
        );
        expect(acceptedOrder.studentCanCancel, isFalse);

        final printingOrder = pendingOrder.copyWith(
          status: OrderStatus.printing,
        );
        expect(printingOrder.studentCanCancel, isFalse);

        final readyOrder = pendingOrder.copyWith(status: OrderStatus.ready);
        expect(readyOrder.studentCanCancel, isFalse);

        final completedOrder = pendingOrder.copyWith(
          status: OrderStatus.completed,
        );
        expect(completedOrder.studentCanCancel, isFalse);
      },
    );

    test(
      'Task 8: Page orientation preservation in PagePrintSetting and serialization',
      () {
        const setting = PagePrintSetting(
          pageNumber: 1,
          printType: PrintType.color,
          orientation: 'Landscape',
        );

        final map = setting.toMap();
        expect(map['orientation'], equals('Landscape'));

        final reconstructed = PagePrintSetting.fromMap(map);
        expect(reconstructed.orientation, equals('Landscape'));
        expect(reconstructed.isColor, isTrue);
        expect(reconstructed.isLandscape, isTrue);
      },
    );

    test('Task 9: Order queue deletion synchronization logic', () {
      final order1 = PrintOrder(
        id: 'ord_1',
        code: '1111',
        studentId: 'STU01',
        studentName: 'Bob',
        studentEmail: 'bob@campus.edu',
        fileName: 'test1.pdf',
        fileSizeBytes: 1024,
        fileUrl: 'https://example.com/1.pdf',
        pages: 1,
        copies: 1,
        color: false,
        doubleSided: false,
        lamination: false,
        binding: false,
        paperType: PaperType.standard75Gsm,
        total: 5.0,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.paid,
        paymentMode: PaymentMode.online,
        createdAt: DateTime.now(),
        isDeletedFromQueue: false,
      );

      final order2 = order1.copyWith(
        id: 'ord_2',
        code: '2222',
        isDeletedFromQueue: true,
      );

      final allOrders = [order1, order2];
      final activeOrders = allOrders
          .where((o) => !o.isDeletedFromQueue)
          .toList();

      expect(activeOrders.length, equals(1));
      expect(activeOrders.first.id, equals('ord_1'));
    });

    test('Task 13: 4-digit numeric collection code format verification', () {
      final dataService = DataService();
      for (int i = 0; i < 50; i++) {
        final code = dataService.newCode();
        expect(code.length, equals(4));
        expect(RegExp(r'^\d{4}$').hasMatch(code), isTrue);
      }
    });
  });
}
