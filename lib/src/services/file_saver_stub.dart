import 'dart:typed_data';

const bool supportsDirectFileSave = false;

Future<String> saveBytesToFolder({
  required Uint8List bytes,
  required String folder,
  required String fileName,
}) async {
  throw UnsupportedError('当前平台不支持直接写入文件夹。');
}
