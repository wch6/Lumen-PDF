import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/reader_models.dart';

class PdfHashService {
  const PdfHashService();

  Future<String> hashSource(PdfSource source) {
    final path = source.path;
    if (path != null && path.isNotEmpty) {
      return hashFile(path);
    }
    final bytes = source.bytes;
    if (bytes != null) {
      return Future.value(hashBytes(bytes));
    }
    throw FileSystemException('PDF source has no readable file or bytes');
  }

  Future<String> hashFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('PDF file does not exist', path);
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String hashBytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }
}
