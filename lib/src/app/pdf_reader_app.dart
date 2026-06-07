import 'package:flutter/material.dart';

import '../services/reader_repository.dart';
import '../services/reader_settings_store.dart';
import '../theme/app_colors.dart';
import 'reader_home.dart';

class PdfReaderApp extends StatelessWidget {
  const PdfReaderApp({this.repositoryFuture, this.settingsStore, super.key});

  final Future<ReaderRepository>? repositoryFuture;
  final ReaderSettingsStore? settingsStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lumen PDF',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Microsoft YaHei UI',
        fontFamilyFallback: const [
          'Microsoft YaHei',
          'SimHei',
          'Segoe UI',
          'Arial',
        ],
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
          surface: AppColors.surface,
        ),
        tooltipTheme: TooltipThemeData(
          waitDuration: const Duration(milliseconds: 450),
          showDuration: const Duration(milliseconds: 2600),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: TextStyle(color: AppColors.surface, fontSize: 12),
        ),
      ),
      home: ReaderHome(
        repositoryFuture: repositoryFuture,
        settingsStore: settingsStore ?? const FileReaderSettingsStore(),
      ),
    );
  }
}
