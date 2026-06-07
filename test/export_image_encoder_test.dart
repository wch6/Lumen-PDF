import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:pdf_reader/src/models/reader_models.dart';
import 'package:pdf_reader/src/services/export_image_encoder.dart';

void main() {
  test('PNG export writes matching physical DPI metadata', () {
    final image = image_lib.Image(width: 4, height: 3);

    final bytes = encodeExportImage(
      image: image,
      format: ExportImageFormat.png,
      resolution: 300,
    );

    final decoder = image_lib.PngDecoder()..decode(bytes);
    expect(decoder.info.width, 4);
    expect(decoder.info.height, 3);
    expect(
      decoder.info.pixelDimensions,
      image_lib.PngPhysicalPixelDimensions.dpi(300),
    );
  });

  test('JPG export writes matching JFIF DPI metadata', () {
    final image = image_lib.Image(width: 4, height: 3);

    final bytes = encodeExportImage(
      image: image,
      format: ExportImageFormat.jpg,
      resolution: 240,
    );

    final density = _readJfifDensity(bytes);
    expect(density, isNotNull);
    expect(density!.unit, 1);
    expect(density.x, 240);
    expect(density.y, 240);
  });

  test('export DPI is clamped to the supported UI range', () {
    expect(normalizeExportImageDpi(12), 72);
    expect(normalizeExportImageDpi(192), 192);
    expect(normalizeExportImageDpi(900), 600);
  });
}

_JfifDensity? _readJfifDensity(Uint8List bytes) {
  if (bytes.length < 20 || bytes[0] != 0xff || bytes[1] != 0xd8) {
    return null;
  }

  var offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xff) {
      return null;
    }
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset++;
    }
    if (offset >= bytes.length) {
      return null;
    }

    final marker = bytes[offset++];
    if (marker == 0xda || marker == 0xd9) {
      return null;
    }
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    if (offset + 2 > bytes.length) {
      return null;
    }

    final length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) {
      return null;
    }

    final payloadOffset = offset + 2;
    final payloadLength = length - 2;
    if (marker == 0xe0 &&
        payloadLength >= 14 &&
        bytes[payloadOffset] == 0x4a &&
        bytes[payloadOffset + 1] == 0x46 &&
        bytes[payloadOffset + 2] == 0x49 &&
        bytes[payloadOffset + 3] == 0x46 &&
        bytes[payloadOffset + 4] == 0x00) {
      return _JfifDensity(
        unit: bytes[payloadOffset + 7],
        x: (bytes[payloadOffset + 8] << 8) | bytes[payloadOffset + 9],
        y: (bytes[payloadOffset + 10] << 8) | bytes[payloadOffset + 11],
      );
    }

    offset += length;
  }

  return null;
}

class _JfifDensity {
  const _JfifDensity({required this.unit, required this.x, required this.y});

  final int unit;
  final int x;
  final int y;
}
