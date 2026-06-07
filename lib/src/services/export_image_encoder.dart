import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;

import '../models/reader_models.dart';

const int kMinExportImageDpi = 72;
const int kMaxExportImageDpi = 600;

Uint8List encodeExportImage({
  required image_lib.Image image,
  required ExportImageFormat format,
  required int resolution,
}) {
  final dpi = normalizeExportImageDpi(resolution);
  return switch (format) {
    ExportImageFormat.png => image_lib.PngEncoder(
      pixelDimensions: image_lib.PngPhysicalPixelDimensions.dpi(dpi),
    ).encode(image),
    ExportImageFormat.jpg => applyJpegDpiMetadata(
      image_lib.JpegEncoder(quality: 95).encode(image),
      dpi,
    ),
  };
}

int normalizeExportImageDpi(int resolution) {
  return resolution.clamp(kMinExportImageDpi, kMaxExportImageDpi);
}

Uint8List applyJpegDpiMetadata(Uint8List jpegBytes, int resolution) {
  final dpi = resolution.clamp(1, 65535);
  final data = Uint8List.fromList(jpegBytes);
  if (data.length < 20 || data[0] != 0xff || data[1] != 0xd8) {
    return data;
  }

  var offset = 2;
  while (offset + 4 <= data.length) {
    if (data[offset] != 0xff) {
      return data;
    }
    while (offset < data.length && data[offset] == 0xff) {
      offset++;
    }
    if (offset >= data.length) {
      return data;
    }

    final marker = data[offset++];
    if (marker == 0xda || marker == 0xd9) {
      return data;
    }
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    if (offset + 2 > data.length) {
      return data;
    }

    final length = (data[offset] << 8) | data[offset + 1];
    if (length < 2 || offset + length > data.length) {
      return data;
    }

    final payloadOffset = offset + 2;
    final payloadLength = length - 2;
    if (marker == 0xe0 &&
        payloadLength >= 14 &&
        data[payloadOffset] == 0x4a &&
        data[payloadOffset + 1] == 0x46 &&
        data[payloadOffset + 2] == 0x49 &&
        data[payloadOffset + 3] == 0x46 &&
        data[payloadOffset + 4] == 0x00) {
      data[payloadOffset + 7] = 1;
      data[payloadOffset + 8] = dpi >> 8;
      data[payloadOffset + 9] = dpi & 0xff;
      data[payloadOffset + 10] = dpi >> 8;
      data[payloadOffset + 11] = dpi & 0xff;
      return data;
    }

    offset += length;
  }

  return data;
}
