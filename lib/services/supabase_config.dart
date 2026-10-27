/// Supabase Configuration & Credentials for Campus Xerox.
///
/// HOW TO SET UP SUPABASE:
/// 1. Create a free project at https://supabase.com
/// 2. Go to Project Settings -> API to find your Project URL & Anon Key.
/// 3. Replace the placeholder values below with your credentials.
/// 4. Go to SQL Editor in Supabase and run the provided `supabase_schema.sql` file.
/// 5. Go to Storage in Supabase and ensure the bucket `xerox-documents` is created.
///
/// Note: If you leave the placeholders, the application automatically falls back
/// to local persistent storage mode so you can demo and test the app immediately.
class SupabaseConfig {
  /// Your Supabase Project URL (e.g., 'https://xyzcompany.supabase.co')
  static const String supabaseUrl = 'https://oywophlrrxibdqszdooq.supabase.co';

  /// Your Supabase Publishable API Key
  static const String supabasePublishableKey =
      'sb_publishable_JC1fypujiBSvrqE-WXnKqg_kEagzL5J';

  /// Backwards-compatible alias for supabaseAnonKey
  static const String supabaseAnonKey = supabasePublishableKey;

  /// Supabase Storage Bucket for print documents (PDF, DOCX, PPT, JPG, PNG up to 50MB)
  static const String documentsBucket = 'xerox-documents';

  /// Supabase Storage Bucket for active shopkeeper payment QR codes
  static const String paymentQrBucket = 'payment_qr';

  /// Maximum file size supported for student uploads (50 MB in bytes)
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 52,428,800 bytes

  /// Returns true if valid custom Supabase credentials have been configured
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE_PROJECT_URL') &&
      supabasePublishableKey.isNotEmpty &&
      !supabasePublishableKey.contains('YOUR_SUPABASE_ANON_KEY') &&
      !supabasePublishableKey.contains('YOUR_SUPABASE_PUBLISHABLE_KEY') &&
      !supabasePublishableKey.contains('PASTE_YOUR_PUBLISHABLE_KEY_HERE');
}
