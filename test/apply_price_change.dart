// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:campus_xerox/services/supabase_config.dart';

void main() {
  test('Update Supabase Prices Now', () async {
    final client = SupabaseClient(
      SupabaseConfig.supabaseUrl,
      SupabaseConfig.supabasePublishableKey,
    );

    print('\n============================================================');
    print('UPDATING SUPABASE PRICING LIVE ACROSS ALL TABLES');
    print('============================================================');

    const testPrice = 2.50;

    // 1. Update shop_prices table
    print('\n[1] Updating `shop_prices` table to Rs $testPrice...');
    final resPrices = await client
        .from('shop_prices')
        .update({
          'bw_single': testPrice,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', 'campus-xerox')
        .select();
    print('-> shop_prices result: $resPrices');

    // 2. Update services table
    print(
      '\n[2] Updating `services` table for B&W Single Side to Rs $testPrice...',
    );
    final resServices = await client
        .from('services')
        .update({
          'price': testPrice,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .ilike('service_name', '%B&W Single%')
        .select();
    print('-> services result: $resServices');

    // 3. Verify latest prices from Supabase
    print('\n[3] Verifying live values from Supabase:');
    final checkPrices = await client
        .from('shop_prices')
        .select('bw_single')
        .eq('id', 'campus-xerox');
    final checkServices = await client
        .from('services')
        .select('service_name, price')
        .ilike('service_name', '%B&W Single%');

    print(
      '-> Verified shop_prices bw_single: ${checkPrices.first['bw_single']}',
    );
    print('-> Verified services rows: $checkServices');

    expect(
      double.parse('${checkPrices.first['bw_single']}'),
      equals(testPrice),
    );
    print('\n[SUCCESS] Supabase is now updated with Rs $testPrice!');
  });
}
