import '../models/reader_models.dart';
import 'app_data_paths.dart';

abstract class ReaderSettingsStore {
  const ReaderSettingsStore();

  Future<String?> read();
  Future<void> write(String encoded);
  Future<void> clear();
}

class FileReaderSettingsStore extends ReaderSettingsStore {
  const FileReaderSettingsStore();

  @override
  Future<String?> read() async {
    final file = await AppDataPaths.dataFile(AppDataPaths.settingsFileName);
    if (await file.exists()) {
      return file.readAsString();
    }

    final legacy = await AppDataPaths.readLegacyPreference(
      StorageKeys.settings,
    );
    if (legacy == null || legacy.isEmpty) {
      return null;
    }
    await write(legacy);
    await AppDataPaths.removeLegacyPreference(StorageKeys.settings);
    return legacy;
  }

  @override
  Future<void> write(String encoded) async {
    final file = await AppDataPaths.dataFile(AppDataPaths.settingsFileName);
    await file.parent.create(recursive: true);
    await file.writeAsString(encoded, flush: true);
  }

  @override
  Future<void> clear() async {
    final file = await AppDataPaths.dataFile(AppDataPaths.settingsFileName);
    if (await file.exists()) {
      await file.delete();
    }
    await AppDataPaths.removeLegacyPreference(StorageKeys.settings);
  }
}

class InMemoryReaderSettingsStore extends ReaderSettingsStore {
  InMemoryReaderSettingsStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String encoded) async {
    value = encoded;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}
