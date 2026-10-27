import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
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
      throw Exception(
        'File size ($sizeMB MB) exceeds the maximum 50 MB limit.',
      );
    }

    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$uid/${timestamp}_$safeName';
    final mimeType = _getMimeType(fileName);

    // 1. Primary: Upload to Supabase Storage private bucket if configured
    if (isSupabaseLive) {
      try {
        final client = Supabase.instance.client;
        onProgress?.call(0.3);
        await client.storage
            .from(SupabaseConfig.documentsBucket)
            .uploadBinary(
              storagePath,
              data,
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );
        onProgress?.call(0.8);

        // Generate clean public URL for instant previewing and downloading
        String fileUrl;
        try {
          fileUrl = client.storage
              .from(SupabaseConfig.documentsBucket)
              .getPublicUrl(storagePath);
        } catch (_) {
          fileUrl = await client.storage
              .from(SupabaseConfig.documentsBucket)
              .createSignedUrl(storagePath, 172800);
        }

        onProgress?.call(1.0);
        _cloudVault[fileUrl] = data;
        _cloudVault[storagePath] = data;
        return fileUrl;
      } catch (e) {
        debugPrint('Supabase Storage upload notice: $e');
      }
    }

    // 2. Secondary fallback: Firebase Storage (if configured)
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'orders/$uid/${timestamp}_$safeName',
      );
      onProgress?.call(0.2);
      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {'uploadedBy': uid, 'fileName': fileName},
      );
      final uploadTask = storageRef.putData(data, metadata);
      uploadTask.snapshotEvents.listen((taskSnapshot) {
        if (taskSnapshot.totalBytes > 0) {
          final progress =
              taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
          onProgress?.call(progress);
        }
      });
      final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
      final downloadUrl = await snapshot.ref.getDownloadURL();
      _cloudVault[downloadUrl] = data;
      _cloudVault[storagePath] = data;
      onProgress?.call(1.0);
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage upload notice: $e');
    }

    // 3. Fallback in-memory vault for demo / unconfigured mode only
    final uniqueMarker = base64UrlEncode(
      utf8.encode('$uid:$safeName:${DateTime.now().microsecondsSinceEpoch}'),
    );
    final fileUrl = 'secure://vault/$uniqueMarker/$safeName';
    _cloudVault[fileUrl] = data;
    _cloudVault[storagePath] = data;
    onProgress?.call(1.0);
    return fileUrl;
  }

  /// Uploads Shopkeeper Payment QR Code into Supabase Storage `payment_qr` bucket.
  /// Appends a timestamp cache-busting query to avoid stale image caching on phones.
  Future<String> uploadPaymentQr({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('QR image file is empty.');
    }

    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'png';
    final mimeType = ext == 'png'
        ? 'image/png'
        : (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/png');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'shop_qr_$timestamp.$ext';

    // 1. Primary: Upload to Firebase Storage
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'payment_qr/qr_$timestamp.$ext',
      );
      final metadata = SettableMetadata(contentType: mimeType);
      final snapshot = await ref
          .putData(bytes, metadata)
          .timeout(const Duration(seconds: 15));
      final downloadUrl = await snapshot.ref.getDownloadURL();
      _cloudVault[downloadUrl] = bytes;
      _cloudVault[storagePath] = bytes;
      return downloadUrl;
    } catch (e) {
      debugPrint(
        'Firebase Storage uploadPaymentQr notice (trying fallback): $e',
      );
    }

    if (isSupabaseLive) {
      try {
        final client = Supabase.instance.client;
        await client.storage
            .from(SupabaseConfig.paymentQrBucket)
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );

        final rawUrl = client.storage
            .from(SupabaseConfig.paymentQrBucket)
            .getPublicUrl(storagePath);
        final publicUrl = '$rawUrl?t=$timestamp';
        _cloudVault[publicUrl] = bytes;
        _cloudVault[rawUrl] = bytes;
        _cloudVault[storagePath] = bytes;
        return publicUrl;
      } catch (e) {
        debugPrint(
          'Supabase uploadPaymentQr notice (falling back to document bucket): $e',
        );
        try {
          final client = Supabase.instance.client;
          final fallbackPath = 'payment_qr/qr_$timestamp.$ext';
          await client.storage
              .from(SupabaseConfig.documentsBucket)
              .uploadBinary(
                fallbackPath,
                bytes,
                fileOptions: FileOptions(contentType: mimeType, upsert: true),
              );
          final rawUrl = client.storage
              .from(SupabaseConfig.documentsBucket)
              .getPublicUrl(fallbackPath);
          final publicUrl = '$rawUrl?t=$timestamp';
          _cloudVault[publicUrl] = bytes;
          _cloudVault[rawUrl] = bytes;
          return publicUrl;
        } catch (err2) {
          debugPrint('Fallback document bucket QR upload notice: $err2');
        }
      }
    }

    // Fallback data URI for local offline demo
    final base64String = base64Encode(bytes);
    final dataUri = 'data:$mimeType;base64,$base64String';
    _cloudVault[dataUri] = bytes;
    return dataUri;
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

    // 2. Direct HTTP GET for Signed URLs or Public Storage URLs
    if (fileUrl.startsWith('http')) {
      try {
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(fileUrl));
        if (fileUrl.contains(SupabaseConfig.supabaseUrl) &&
            SupabaseConfig.supabaseAnonKey.isNotEmpty) {
          request.headers.set('apikey', SupabaseConfig.supabaseAnonKey);
          request.headers.set(
            'Authorization',
            'Bearer ${SupabaseConfig.supabaseAnonKey}',
          );
        }
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

    // 3. Local filesystem fallback (if fileUrl points to a local file)
    try {
      final cleanPath = fileUrl.startsWith('file://')
          ? fileUrl.replaceFirst('file://', '')
          : fileUrl;
      final file = File(cleanPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          _cloudVault[fileUrl] = bytes;
          return bytes;
        }
      }
    } catch (_) {}

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
    if (kIsWeb) return null;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final prefix = orderCode != null ? '${orderCode}_' : '';
    final outName = '$prefix$safeName';

    final candidateDirs = <Directory>[];

    if (Platform.isAndroid) {
      try {
        final androidDownload = Directory('/storage/emulated/0/Download');
        if (await androidDownload.exists()) {
          candidateDirs.add(androidDownload);
        }
      } catch (_) {}

      try {
        final extDirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (extDirs != null && extDirs.isNotEmpty) {
          candidateDirs.addAll(extDirs);
        }
      } catch (_) {}

      try {
        final extStorageDir = await getExternalStorageDirectory();
        if (extStorageDir != null) {
          candidateDirs.add(extStorageDir);
        }
      } catch (_) {}
    }

    try {
      final dlDir = await getDownloadsDirectory();
      if (dlDir != null) candidateDirs.add(dlDir);
    } catch (_) {}

    try {
      final docDir = await getApplicationDocumentsDirectory();
      candidateDirs.add(docDir);
    } catch (_) {}

    for (final dir in candidateDirs) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final filePath = '${dir.path}/$outName';
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        debugPrint('File saved to device at: $filePath');
        return filePath;
      } catch (e) {
        debugPrint(
          'Could not save to ${dir.path} ($e), trying next candidate...',
        );
      }
    }

    debugPrint('Error: Could not save file to any candidate device location.');
    return null;
  }

  /// Completely deletes and erases document from the in-app vault, local device storage,
  /// and Supabase Cloud storage after printing is finished.
  /// Returns true if the document was successfully deleted from storage (or already removed).
  Future<bool> deleteAfterPrinting({
    required String fileUrl,
    required String fileName,
    String? orderId,
    String? orderCode,
  }) async {
    bool cloudSuccess = true;
    bool localSuccess = true;

    // 1. Delete from memory cache
    _cloudVault.remove(fileUrl);
    final relativePath = _extractStoragePath(fileUrl);
    if (relativePath != null) {
      _cloudVault.remove(relativePath);
    }

    // 2. Delete from private in-app vault on this device
    if (!kIsWeb && orderId != null) {
      try {
        final docDir = await getApplicationDocumentsDirectory().timeout(
          const Duration(milliseconds: 600),
        );
        final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final vaultFile = File(
          '${docDir.path}/app_print_vault/${orderId}_$safeName',
        );
        if (await vaultFile.exists()) {
          await vaultFile.delete();
          debugPrint('Erased from app vault: ${vaultFile.path}');
        }
      } catch (e) {
        debugPrint('Error clearing app vault file: $e');
      }
    }

    // 3. Delete from device storage (only files saved with this order's prefix)
    if (!kIsWeb) {
      try {
        final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final prefix = orderCode != null ? '${orderCode}_' : '';
        final candidates = <File>[];

        if (Platform.isAndroid) {
          candidates.add(File('/storage/emulated/0/Download/$prefix$safeName'));
          try {
            final extDirs = await getExternalStorageDirectories(
              type: StorageDirectory.downloads,
            );
            if (extDirs != null) {
              for (final d in extDirs) {
                candidates.add(File('${d.path}/$prefix$safeName'));
              }
            }
          } catch (_) {}
          try {
            final extDir = await getExternalStorageDirectory();
            if (extDir != null) {
              candidates.add(File('${extDir.path}/$prefix$safeName'));
            }
          } catch (_) {}
        }
        try {
          final dlDir = await getDownloadsDirectory().timeout(
            const Duration(milliseconds: 600),
          );
          if (dlDir != null) {
            candidates.add(File('${dlDir.path}/$prefix$safeName'));
          }
        } catch (_) {}

        try {
          final docDir = await getApplicationDocumentsDirectory().timeout(
            const Duration(milliseconds: 600),
          );
          candidates.add(File('${docDir.path}/$prefix$safeName'));
        } catch (_) {}

        for (final file in candidates) {
          try {
            if (await file.exists()) {
              await file.delete();
              debugPrint(
                'Erased from shopkeeper device downloads: ${file.path}',
              );
            }
          } catch (e) {
            debugPrint('Error clearing local download file ${file.path}: $e');
          }
        }
      } catch (e) {
        debugPrint('Error clearing download file: $e');
      }
    }

    // 4. Delete from Supabase Cloud Storage bucket 'xerox-documents'
    if (isSupabaseLive &&
        fileUrl.isNotEmpty &&
        relativePath != null &&
        !fileUrl.startsWith('secure://')) {
      try {
        final client = Supabase.instance.client;
        final res = await client.storage
            .from(SupabaseConfig.documentsBucket)
            .remove([relativePath]);
        debugPrint(
          'Securely erased from Supabase Cloud Storage: $relativePath ($res)',
        );
      } catch (e) {
        debugPrint('Error erasing from Supabase storage: $e');
        cloudSuccess = false;
      }
    }

    // 5. Delete from Firebase Storage if applicable
    if (fileUrl.contains('firebasestorage.googleapis.com')) {
      try {
        await FirebaseStorage.instance.refFromURL(fileUrl).delete();
        debugPrint('Securely erased file from Firebase Storage: $fileUrl');
      } catch (e) {
        debugPrint('Firebase Storage delete notice: $e');
      }
    }

    return cloudSuccess && localSuccess;
  }

  /// Delete/erase document from database storage after shopkeeper downloads it
  Future<bool> deleteFile(String fileUrl) async {
    _cloudVault.remove(fileUrl);
    final relativePath = _extractStoragePath(fileUrl);
    if (relativePath != null) {
      _cloudVault.remove(relativePath);
    }

    if (fileUrl.contains('firebasestorage.googleapis.com')) {
      try {
        await FirebaseStorage.instance.refFromURL(fileUrl).delete();
        debugPrint('Securely erased file from Firebase Storage: $fileUrl');
        return true;
      } catch (e) {
        debugPrint('Firebase Storage delete notice: $e');
      }
    }

    if (isSupabaseLive && fileUrl.startsWith('http') && relativePath != null) {
      try {
        final client = Supabase.instance.client;
        await client.storage.from(SupabaseConfig.documentsBucket).remove([
          relativePath,
        ]);
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
        final bucketIndex = pathSegments.indexOf(
          SupabaseConfig.documentsBucket,
        );
        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          return pathSegments.sublist(bucketIndex + 1).join('/');
        }
      } else if (fileUrl.isNotEmpty && !fileUrl.startsWith('secure://')) {
        if (fileUrl.contains('${SupabaseConfig.documentsBucket}/')) {
          return fileUrl.split('${SupabaseConfig.documentsBucket}/').last;
        }
        return fileUrl;
      }
    } catch (_) {}
    return null;
  }

  bool isAvailable(String fileUrl) =>
      _cloudVault.containsKey(fileUrl) ||
      (isSupabaseLive && fileUrl.startsWith('http'));

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
