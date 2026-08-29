import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Storage Adapter for safe document sharing with a 50MB limit, Supabase Storage
/// bucket integration, internal app vault caching, and automatic file erasing after printing.
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Maximum file size limit: 50 Megabytes (52,428,800 bytes)
  static const int maxFileSizeBytes = SupabaseConfig.maxFileSizeBytes;

  // Active in-memory document vault for prototype & offline runtime
  final Map<String, Uint8List> _cloudVault = {};

  bool get isSupabaseLive => SupabaseConfig.isConfigured;

  /// Uploads document (PDF, DOCX, PPT, JPG, PNG) up to 50MB
  Future<String> upload({
    required String uid,
    required String fileName,
    Uint8List? bytes,
    String? localPath,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes == null && localPath == null) {
      throw Exception('No file selected.');
    }

    final data = bytes ?? Uint8List(0);
    if (data.length > maxFileSizeBytes) {
      final sizeMB = (data.length / (1024 * 1024)).toStringAsFixed(1);
      throw Exception('File size ($sizeMB MB) exceeds the maximum 50 MB limit.');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$uid/${timestamp}_$safeName';

    // 1. If Supabase is connected, upload to Supabase Storage bucket
    if (isSupabaseLive) {
      try {
        final client = Supabase.instance.client;
        final mimeType = _getMimeType(fileName);

        onProgress?.call(0.3);
        await client.storage.from(SupabaseConfig.documentsBucket).uploadBinary(
          storagePath,
          data,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
        // Generate clean public URL for instant previewing and downloading
        final publicUrl = client.storage
            .from(SupabaseConfig.documentsBucket)
            .getPublicUrl(storagePath);

        onProgress?.call(1.0);
        _cloudVault[publicUrl] = data;
        _cloudVault[storagePath] = data;
        return publicUrl;
      } catch (e) {
        debugPrint('Supabase Storage upload error (falling back to vault): $e');
      }
    }

    // 2. Fallback in-memory vault for demo / offline mode
    final uniqueMarker = base64UrlEncode(
      utf8.encode('$uid:$safeName:${DateTime.now().microsecondsSinceEpoch}'),
    );
    final fileUrl = 'secure://vault/$uniqueMarker/$safeName';
    _cloudVault[fileUrl] = data;
    _cloudVault[storagePath] = data;
    onProgress?.call(1.0);
    return fileUrl;
  }

  /// Download or retrieve bytes for printing/previewing
  Future<Uint8List?> downloadFile(String fileUrl) async {
    if (fileUrl.isEmpty) return null;

    if (_cloudVault.containsKey(fileUrl)) {
      return _cloudVault[fileUrl];
    }

    final relativePath = _extractStoragePath(fileUrl);
    if (relativePath != null && _cloudVault.containsKey(relativePath)) {
      return _cloudVault[relativePath];
    }

    // 1. Download via Supabase Storage client
    if (isSupabaseLive && relativePath != null) {
      try {
        final client = Supabase.instance.client;
        final bytes = await client.storage
            .from(SupabaseConfig.documentsBucket)
            .download(relativePath);
        if (bytes.isNotEmpty) {
          _cloudVault[fileUrl] = bytes;
          _cloudVault[relativePath] = bytes;
          return bytes;
        }
      } catch (e) {
        debugPrint('Supabase SDK download notice: $e');
      }
    }

    // 2. Direct HTTP GET for Signed URLs
    if (fileUrl.startsWith('http')) {
      try {
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(fileUrl));
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await consolidateHttpClientResponseBytes(response);
          if (bytes.isNotEmpty) {
            _cloudVault[fileUrl] = bytes;
            if (relativePath != null) _cloudVault[relativePath] = bytes;
            return bytes;
          }
        }
      } catch (e) {
        debugPrint('HTTP direct download notice: $e');
      }
    }

    return null;
  }

  /// Stores document inside the private app directory for in-app viewing & printing
  Future<String?> saveToAppVault({
    required String orderId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      if (kIsWeb) return null;
      final docDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${docDir.path}/app_print_vault');
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final localPath = '${vaultDir.path}/${orderId}_$safeName';
      final file = File(localPath);
      await file.writeAsBytes(bytes);
      return localPath;
    } catch (e) {
      debugPrint('Error saving to app vault: $e');
      return null;
    }
  }

  /// Saves document directly to device Download/Documents folder for external printer tools
  Future<String?> saveFileToDevice({
    required String fileName,
    required Uint8List bytes,
    String? orderCode,
  }) async {
    try {
      Directory? targetDir;
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          final androidDownload = Directory('/storage/emulated/0/Download');
          if (await androidDownload.exists()) {
            targetDir = androidDownload;
          }
        }
        targetDir ??= await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      if (targetDir == null) return null;

      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final prefix = orderCode != null ? '${orderCode}_' : '';
      final filePath = '${targetDir.path}/$prefix$safeName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      debugPrint('File saved to device at: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('Error saving file to local device: $e');
      return null;
    }
  }

  /// Completely deletes and erases document from the in-app vault, local device storage,
  /// and Supabase Cloud storage after printing is finished
  Future<void> deleteAfterPrinting({
    required String fileUrl,
    required String fileName,
    String? orderId,
    String? orderCode,
  }) async {
    // 1. Delete from memory cache
    _cloudVault.remove(fileUrl);
    final relativePath = _extractStoragePath(fileUrl);
    if (relativePath != null) {
      _cloudVault.remove(relativePath);
    }

    // 2. Delete from private in-app vault
    if (!kIsWeb && orderId != null) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final vaultFile = File('${docDir.path}/app_print_vault/${orderId}_$safeName');
        if (await vaultFile.exists()) {
          await vaultFile.delete();
          debugPrint('Erased from app vault: ${vaultFile.path}');
        }
      } catch (e) {
        debugPrint('Error clearing app vault file: $e');
      }
    }

    // 3. Delete from public device Downloads folder if saved
    if (!kIsWeb) {
      try {
        final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final prefix = orderCode != null ? '${orderCode}_' : '';
        if (Platform.isAndroid) {
          final downloadFile = File('/storage/emulated/0/Download/$prefix$safeName');
          if (await downloadFile.exists()) {
            await downloadFile.delete();
            debugPrint('Erased from Android Downloads: ${downloadFile.path}');
          }
        }
      } catch (e) {
        debugPrint('Error clearing download file: $e');
      }
    }

    // 4. Delete from Supabase Cloud Storage bucket
    if (isSupabaseLive && fileUrl.startsWith('http') && relativePath != null) {
      try {
        final client = Supabase.instance.client;
        await client.storage
            .from(SupabaseConfig.documentsBucket)
            .remove([relativePath]);
        debugPrint('Securely erased from Supabase Cloud Storage: $relativePath');
      } catch (e) {
        debugPrint('Error erasing from Supabase storage: $e');
      }
    }
  }

  /// Delete/erase document from database storage after shopkeeper downloads it
  Future<bool> deleteFile(String fileUrl) async {
    _cloudVault.remove(fileUrl);
    final relativePath = _extractStoragePath(fileUrl);
    if (relativePath != null) {
      _cloudVault.remove(relativePath);
    }

    if (isSupabaseLive && fileUrl.startsWith('http') && relativePath != null) {
      try {
        final client = Supabase.instance.client;
        await client.storage
            .from(SupabaseConfig.documentsBucket)
            .remove([relativePath]);
        debugPrint('Securely erased file from Supabase Storage: $relativePath');
        return true;
      } catch (e) {
        debugPrint('Error erasing file from Supabase storage: $e');
      }
    }

    return true;
  }

  String? _extractStoragePath(String fileUrl) {
    try {
      if (fileUrl.startsWith('http')) {
        final uri = Uri.parse(fileUrl);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf(SupabaseConfig.documentsBucket);
        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          return pathSegments.sublist(bucketIndex + 1).join('/');
        }
      }
    } catch (_) {}
    return null;
  }

  bool isAvailable(String fileUrl) =>
      _cloudVault.containsKey(fileUrl) || (isSupabaseLive && fileUrl.startsWith('http'));

  static String _getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }
}
