import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

const bool supportsDirectFileSave = true;

Future<String> saveBytesToFolder({
  required Uint8List bytes,
  required String folder,
  required String fileName,
}) async {
  final directory = Directory(folder);
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final target = File(p.join(directory.path, fileName));
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}
