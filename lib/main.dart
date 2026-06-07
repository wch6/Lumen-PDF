import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import 'src/app/pdf_reader_app.dart';

export 'src/app/pdf_reader_app.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  runApp(PdfReaderApp(initialFilePaths: args));
}
