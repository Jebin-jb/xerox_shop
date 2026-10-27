// ignore_for_file: avoid_print

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:campus_xerox/models/app_models.dart';
import 'package:campus_xerox/services/data_service.dart';
import 'package:campus_xerox/services/storage_service.dart';
import 'package:campus_xerox/services/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('Verification of 3 Core Campus Xerox Features', () {
    late SupabaseClient client;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      try {
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          publishableKey: SupabaseConfig.supabasePublishableKey,
        );
      } catch (_) {}
      client = Supabase.instance.client;
    });

    test(
      'Feature 1: Order Status Synchronization in Supabase',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final dataService = DataService();
        final testOrderId =
            'test_sync_${DateTime.now().millisecondsSinceEpoch}';
        final testCode = dataService.newCode();

        // 1. Insert order with pending status
        await client.from('print_orders').insert({
          'id': testOrderId,
          'code': testCode,
          'student_id': 'student_verify_1',
          'student_name': 'Sync Test Student',
          'file_name': 'test_sync.pdf',
          'file_url':
              'https://oywophlrrxibdqszdooq.supabase.co/storage/v1/object/public/xerox-documents/test_sync.pdf',
          'pages': 5,
          'copies': 1,
          'total': 12.50,
          'payment_mode': 'online',
          'payment_status': 'paid',
          'status': 'pending',
          'is_downloaded': false,
          'is_purged': false,
        });

        // 2. Verify Accept transition
        await client
            .from('print_orders')
            .update({'status': 'accepted'})
            .eq('id', testOrderId);
        var res = await client
            .from('print_orders')
            .select('status')
            .eq('id', testOrderId)
            .single();
        expect(res['status'], equals('accepted'));

        // 3. Verify Start Printing transition
        await client
            .from('print_orders')
            .update({'status': 'printing'})
            .eq('id', testOrderId);
        res = await client
            .from('print_orders')
            .select('status')
            .eq('id', testOrderId)
            .single();
        expect(res['status'], equals('printing'));

        // 4. Verify Mark Ready transition
        await client
            .from('print_orders')
            .update({'status': 'ready'})
            .eq('id', testOrderId);
        res = await client
            .from('print_orders')
            .select('status')
            .eq('id', testOrderId)
            .single();
        expect(res['status'], equals('ready'));

        // 5. Verify Complete Order transition
        await client
            .from('print_orders')
            .update({
              'status': 'completed',
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', testOrderId);
        res = await client
            .from('print_orders')
            .select('status')
            .eq('id', testOrderId)
            .single();
        expect(res['status'], equals('completed'));

        // Clean up
        await client.from('print_orders').delete().eq('id', testOrderId);
      },
    );

    test(
      'Feature 2: Four-Digit Numerical Collection Code & Pay at Counter',
      () async {
        final dataService = DataService();

        // Test code format: exactly 4 numeric digits
        for (int i = 0; i < 20; i++) {
          final code = dataService.newCode();
          expect(
            code.length,
            equals(4),
            reason: 'Collection code must be exactly 4 digits',
          );
          expect(
            RegExp(r'^[0-9]{4}$').hasMatch(code),
            isTrue,
            reason: 'Code must be purely numeric',
          );
        }

        // Test Pay at Counter order creation with 4-digit code
        final counterOrderId = await dataService.createOrder(
          studentId: 'student_counter_1',
          studentName: 'Counter Student',
          fileName: 'counter_notes.pdf',
          fileUrl: 'https://test/counter_notes.pdf',
          pages: 10,
          copies: 2,
          color: false,
          doubleSided: true,
          lamination: false,
          binding: false,
          total: 15.0,
          paymentMode: PaymentMode.counter,
          paymentStatus: PaymentStatus.unpaid,
        );

        final order = dataService.allOrdersDirect.firstWhere(
          (o) => o.id == counterOrderId,
        );
        expect(order.code.length, equals(4));
        expect(RegExp(r'^[0-9]{4}$').hasMatch(order.code), isTrue);
        expect(order.paymentMode, equals(PaymentMode.counter));
        expect(order.paymentStatus, equals(PaymentStatus.unpaid));

        // Test search / lookup by 4-digit code
        final found = await dataService.findByCode(
          order.code,
          isShopkeeper: true,
        );
        expect(found, isNotNull);
        expect(found!.id, equals(counterOrderId));
        expect(found.code, equals(order.code));
      },
    );

    test(
      'Feature 3: Automatic PDF Deletion After Printing & Preserved History',
      () async {
        final storage = StorageService();
        final testFileName =
            'auto_purge_test_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final testPath = 'test_student/$testFileName';
        final testBytes = Uint8List.fromList(
          'PDF-MOCK-CONTENT-FOR-DELETION-VERIFICATION'.codeUnits,
        );

        // 1. Upload file to Supabase Storage
        await client.storage
            .from(SupabaseConfig.documentsBucket)
            .uploadBinary(
              testPath,
              testBytes,
              fileOptions: const FileOptions(
                contentType: 'application/pdf',
                upsert: true,
              ),
            );

        final publicUrl = client.storage
            .from(SupabaseConfig.documentsBucket)
            .getPublicUrl(testPath);

        // 2. Insert order in Supabase with file details
        final testOrderId =
            'test_purge_${DateTime.now().millisecondsSinceEpoch}';
        final testCode = DataService().newCode();

        await client.from('print_orders').insert({
          'id': testOrderId,
          'code': testCode,
          'student_id': 'student_purge_test',
          'student_name': 'Purge Test Student',
          'file_name': testFileName,
          'file_url': publicUrl,
          'pages': 3,
          'copies': 1,
          'total': 7.50,
          'payment_mode': 'counter',
          'payment_status': 'paid',
          'status': 'ready',
          'is_downloaded': true,
          'is_purged': false,
        });

        // Confirm file is in storage prior to print completion
        final listBefore = await client.storage
            .from(SupabaseConfig.documentsBucket)
            .list(path: 'test_student');
        expect(
          listBefore.any((f) => f.name == testFileName),
          isTrue,
          reason: 'File must exist before print completion',
        );

        // 3. Complete order and purge file
        final purgeSuccess = await storage.deleteAfterPrinting(
          fileUrl: publicUrl,
          fileName: testFileName,
          orderId: testOrderId,
          orderCode: testCode,
        );
        expect(purgeSuccess, isTrue, reason: 'Purge operation must succeed');

        // Update order in Supabase
        await client
            .from('print_orders')
            .update({
              'status': 'completed',
              'is_purged': true,
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', testOrderId);

        // 4. Verify file is deleted from Supabase Storage
        final listAfter = await client.storage
            .from(SupabaseConfig.documentsBucket)
            .list(path: 'test_student');
        expect(
          listAfter.any((f) => f.name == testFileName),
          isFalse,
          reason: 'File must be purged from storage bucket',
        );

        // 5. Verify order record, financial totals, and collection code remain intact
        final finishedOrder = await client
            .from('print_orders')
            .select()
            .eq('id', testOrderId)
            .single();
        expect(finishedOrder['status'], equals('completed'));
        expect(finishedOrder['is_purged'], equals(true));
        expect(finishedOrder['code'], equals(testCode));
        expect(finishedOrder['student_name'], equals('Purge Test Student'));
        expect(double.parse('${finishedOrder['total']}'), equals(7.50));
        expect(finishedOrder['payment_status'], equals('paid'));

        // Clean up test order
        await client.from('print_orders').delete().eq('id', testOrderId);
      },
    );
  });
}
