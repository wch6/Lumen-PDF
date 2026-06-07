import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppDataPaths {
  const AppDataPaths._();

  static const appDirectoryName = 'LumenPDF';
  static const settingsFileName = 'settings.json';
  static const _oldPreferencesFileName = 'shared_preferences.json';

  static Future<Directory>? _appDirectoryFuture;

  static Future<Directory> appDirectory() {
    return _appDirectoryFuture ??= _prepareAppDirectory();
  }

  static Future<File> dataFile(String fileName) async {
    final directory = await appDirectory();
    return File(p.join(directory.path, fileName));
  }

  static Future<String?> readLegacyPreference(String key) async {
    for (final file in _legacyPreferenceFiles()) {
      try {
        if (!await file.exists()) {
          continue;
        }
        final raw = await file.readAsString();
        if (raw.isEmpty) {
          continue;
        }
        final data = jsonDecode(raw);
        if (data is Map && data[key] is String) {
          return data[key] as String;
        }
      } catch (error) {
        debugPrint('Unable to read legacy Lumen PDF preferences: $error');
      }
    }
    return null;
  }

  static Future<void> removeLegacyPreference(String key) async {
    for (final file in _legacyPreferenceFiles()) {
      try {
        if (!await file.exists()) {
          continue;
        }
        final raw = await file.readAsString();
        final data = raw.isEmpty ? <String, Object?>{} : jsonDecode(raw);
        if (data is! Map) {
          continue;
        }
        final next = Map<String, Object?>.from(data)..remove(key);
        if (next.isEmpty) {
          await file.delete();
        } else {
          await file.writeAsString(jsonEncode(next), flush: true);
        }
        await _deleteEmptyParents(file.parent, _rootForPath(file.path));
      } catch (error) {
        debugPrint('Unable to remove legacy Lumen PDF preferences: $error');
      }
    }
  }

  static Future<Directory> _prepareAppDirectory() async {
    final directory = await _resolveAppDirectory();
    await directory.create(recursive: true);
    await _migrateLegacyData(directory);
    return directory;
  }

  static Future<Directory> _resolveAppDirectory() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      return Directory(p.join(localAppData, appDirectoryName));
    }

    final cacheDirectory = await getApplicationCacheDirectory();
    return Directory(p.join(cacheDirectory.path, appDirectoryName));
  }

  static Future<void> _migrateLegacyData(Directory target) async {
    for (final source in _legacyDataDirectories()) {
      if (_samePath(source.path, target.path) || !await source.exists()) {
        continue;
      }
      final copied = await _copyDirectoryContents(source, target);
      if (!copied) {
        debugPrint(
          'Legacy Lumen PDF data was not fully migrated from ${source.path}',
        );
        continue;
      }
      try {
        await source.delete(recursive: true);
        await _deleteEmptyParents(source.parent, _rootForPath(source.path));
      } catch (error) {
        debugPrint('Unable to delete legacy Lumen PDF data: $error');
      }
    }
  }

  static List<Directory> _legacyDataDirectories() {
    final paths = <String>{};
    final appData = Platform.environment['APPDATA'];
    final localAppData = Platform.environment['LOCALAPPDATA'];

    if (appData != null && appData.isNotEmpty) {
      paths.add(p.join(appData, 'com.codex', 'pdf_reader', 'pdf_reader'));
      paths.add(p.join(appData, 'pdf_reader'));
    }
    if (localAppData != null && localAppData.isNotEmpty) {
      paths.add(p.join(localAppData, 'PDFReader'));
      paths.add(p.join(localAppData, 'com.codex', 'pdf_reader', 'pdf_reader'));
      paths.add(p.join(localAppData, 'pdf_reader'));
    }

    return paths.map(Directory.new).toList(growable: false);
  }

  static List<File> _legacyPreferenceFiles() {
    final paths = <String>{};
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      paths.add(
        p.join(appData, 'com.codex', 'pdf_reader', _oldPreferencesFileName),
      );
      paths.add(p.join(appData, 'pdf_reader', _oldPreferencesFileName));
    }
    return paths.map(File.new).toList(growable: false);
  }

  static Future<bool> _copyDirectoryContents(
    Directory source,
    Directory target,
  ) async {
    var copiedAll = true;
    await target.create(recursive: true);
    try {
      await for (final entity in source.list(followLinks: false)) {
        copiedAll = await _copyEntity(entity, target) && copiedAll;
      }
    } catch (error) {
      debugPrint('Unable to enumerate legacy Lumen PDF data: $error');
      copiedAll = false;
    }
    return copiedAll;
  }

  static Future<bool> _copyEntity(
    FileSystemEntity source,
    Directory targetDirectory,
  ) async {
    final destinationPath = p.join(
      targetDirectory.path,
      p.basename(source.path),
    );
    try {
      if (source is Directory) {
        final destination = Directory(destinationPath);
        await destination.create(recursive: true);
        return await _copyDirectoryContents(source, destination);
      }
      if (source is File) {
        await _copyFile(source, File(destinationPath));
      }
      return true;
    } catch (error) {
      debugPrint('Unable to migrate legacy Lumen PDF data: $error');
      return false;
    }
  }

  static Future<void> _copyFile(File source, File destination) async {
    await destination.parent.create(recursive: true);
    if (!await destination.exists()) {
      await source.copy(destination.path);
      return;
    }

    final sourceLength = await source.length();
    final destinationLength = await destination.length();
    if (sourceLength == destinationLength) {
      return;
    }

    final conflict = await _uniqueConflictFile(destination.path);
    await source.copy(conflict.path);
  }

  static Future<File> _uniqueConflictFile(String originalPath) async {
    var index = 1;
    while (true) {
      final candidate = File('$originalPath.legacy$index');
      if (!await candidate.exists()) {
        return candidate;
      }
      index += 1;
    }
  }

  static Future<void> _deleteEmptyParents(
    Directory start,
    Directory? stopRoot,
  ) async {
    if (stopRoot == null) {
      return;
    }
    var current = start;
    while (!_samePath(current.path, stopRoot.path)) {
      if (!await current.exists()) {
        current = current.parent;
        continue;
      }
      final entries = await current.list(followLinks: false).take(1).toList();
      if (entries.isNotEmpty) {
        return;
      }
      await current.delete();
      current = current.parent;
    }
  }

  static Directory? _rootForPath(String path) {
    final normalized = p.normalize(path).toLowerCase();
    for (final value in [
      Platform.environment['APPDATA'],
      Platform.environment['LOCALAPPDATA'],
    ]) {
      if (value == null || value.isEmpty) {
        continue;
      }
      final root = p.normalize(value);
      if (normalized.startsWith(root.toLowerCase())) {
        return Directory(root);
      }
    }
    return null;
  }

  static bool _samePath(String first, String second) {
    return p.normalize(first).toLowerCase() ==
        p.normalize(second).toLowerCase();
  }
}
