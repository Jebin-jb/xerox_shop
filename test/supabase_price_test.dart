// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:campus_xerox/services/supabase_config.dart';

void main() {
  test('Test Supabase Price Change and Verification', () async {
    final client = SupabaseClient(
      SupabaseConfig.supabaseUrl,
      SupabaseConfig.supabasePublishableKey,
    );

    print('\n============================================================');
    print('SUPABASE PRICE SYNC LIVE TEST');
    print('Project URL: ${SupabaseConfig.supabaseUrl}');
    print('============================================================');

    try {
      // Step 1: Read initial price
      print('\n[Step 1] Fetching current price from table `shop_prices`...');
      final initialRes = await client
          .from('shop_prices')
          .select()
          .eq('id', 'campus-xerox');
      if (initialRes.isEmpty) {
        print('No row found with id="campus-xerox". Fetching all rows...');
        final all = await client.from('shop_prices').select();
        print('Found rows: $all');
      } else {
        final currentBwSingle = initialRes.first['bw_single'];
        print('-> Current B&W Single Price in Supabase: Rs $currentBwSingle');

        // Step 2: Change price to a new test value (e.g. 2.75)
        final newTestPrice = 2.75;
        print('\n[Step 2] Updating B&W Single Price to Rs $newTestPrice...');
        final updateRes = await client
            .from('shop_prices')
            .update({
              'bw_single': newTestPrice,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', 'campus-xerox')
            .select();
        print('-> Update response: $updateRes');

        // Step 3: Fetch again and verify price changed
        print('\n[Step 3] Fetching updated price to verify change...');
        final verifiedRes = await client
            .from('shop_prices')
            .select()
            .eq('id', 'campus-xerox');
        final updatedBwSingle = verifiedRes.first['bw_single'];
        print('-> Verified Price in Supabase: Rs $updatedBwSingle');

        expect(
          double.parse(updatedBwSingle.toString()),
          equals(newTestPrice),
          reason: 'Price in Supabase did not match expected updated price',
        );
        print(
          '\n[SUCCESS] Price change was successfully verified in Supabase!',
        );

        // Optional: Revert back to original price
        print('\n[Step 4] Reverting price back to Rs $currentBwSingle...');
        await client
            .from('shop_prices')
            .update({
              'bw_single': currentBwSingle,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', 'campus-xerox');
        print('-> Successfully reverted to Rs $currentBwSingle.');
      }
    } on PostgrestException catch (e) {
      print('\n[POSTGRES ERROR] Code: ${e.code}');
      print('Message: ${e.message}');
      print('Hint: ${e.hint}');
      if (e.code == '42501') {
        print('\n*** ACTION REQUIRED IN SUPABASE DASHBOARD ***');
        print(
          'The table exists, but PostgreSQL role "anon" has not been granted access.',
        );
        print(
          'Please open Supabase Dashboard -> SQL Editor and run the GRANT snippet in supabase_schema.sql:',
        );
        print('GRANT USAGE ON SCHEMA public TO anon, authenticated;');
        print(
          'GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;',
        );
      }
    } catch (e) {
      print('\n[UNEXPECTED ERROR]: $e');
    }
  });
}
