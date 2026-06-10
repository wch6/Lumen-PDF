import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:pdfrx/pdfrx.dart';

import '../models/reader_models.dart';

class PdfFirstPagePreviewRenderer {
  const PdfFirstPagePreviewRenderer._();

  static const int defaultMaxRenderPixels = 420;

  static Future<PdfFirstPagePreviewData?> render(
    PdfSource source, {
    int maxRenderPixels = defaultMaxRenderPixels,
  }) async {
    PdfDocument? document;
    PdfImage? rendered;
    try {
      final path = source.path;
      final bytes = source.bytes;
      if (path != null && path.isNotEmpty) {
        document = await PdfDocument.openFile(
          path,
          useProgressiveLoading: true,
        );
      } else if (bytes != null) {
        document = await PdfDocument.openData(
          bytes,
          sourceName: source.name,
          useProgressiveLoading: true,
        );
      } else {
        return null;
      }
      if (document.pages.isEmpty) {
        return null;
      }

      final page = await document.pages.first.ensureLoaded();
      final longestSide = math.max(page.width, page.height);
      if (longestSide <= 0) {
        return null;
      }
      final scale = maxRenderPixels / longestSide;
      final width = math.max(1, (page.width * scale).round());
      final height = math.max(1, (page.height * scale).round());
      rendered = await page.render(
        fullWidth: width.toDouble(),
        fullHeight: height.toDouble(),
        backgroundColor: 0xffffffff,
      );
      if (rendered == null) {
        return null;
      }

      final image = image_lib.Image.fromBytes(
        width: rendered.width,
        height: rendered.height,
        bytes: rendered.pixels.buffer,
        bytesOffset: rendered.pixels.offsetInBytes,
        numChannels: 4,
        order: image_lib.ChannelOrder.bgra,
      );
      return PdfFirstPagePreviewData(
        pngBytes: Uint8List.fromList(image_lib.encodePng(image)),
        width: rendered.width,
        height: rendered.height,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    } finally {
      rendered?.dispose();
      await document?.dispose();
    }
  }
}
