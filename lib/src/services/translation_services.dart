import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart' as pc;

import '../models/reader_models.dart';

enum Pdf2zhAction {
  translate('translate', '翻译全文'),
  crop('crop', '裁剪全文'),
  compare('compare', '对照全文'),
  cropCompare('crop-compare', '裁剪对照'),
  checkService('check-service', '本地服务');

  const Pdf2zhAction(this.endpoint, this.label);

  final String endpoint;
  final String label;
}

enum PronunciationAccent { uk, us }

extension PronunciationAccentLabel on PronunciationAccent {
  String get label {
    return switch (this) {
      PronunciationAccent.uk => '英式',
      PronunciationAccent.us => '美式',
    };
  }
}

class PronunciationAudio {
  const PronunciationAudio({
    required this.accent,
    required this.url,
    this.phonetic = '',
  });

  final PronunciationAccent accent;
  final String url;
  final String phonetic;

  String get text => phonetic.trim().isEmpty
      ? accent.label
      : '${accent.label} ${phonetic.trim()}';
}

class SelectionTranslationResult {
  const SelectionTranslationResult({
    required this.translation,
    this.dictionary = '',
    this.audio = const [],
    this.translationService = '',
    this.dictionaryService = '',
  });

  final String translation;
  final String dictionary;
  final List<PronunciationAudio> audio;
  final String translationService;
  final String dictionaryService;

  bool get hasDictionary => dictionary.trim().isNotEmpty;
  bool get hasTranslation => translation.trim().isNotEmpty;

  String get summary {
    if (hasDictionary && hasTranslation) {
      return '$dictionary\n\n$translation';
    }
    return hasDictionary ? dictionary : translation;
  }
}

HttpClient _newHttpClient({required Duration connectionTimeout}) {
  final client = HttpClient()..connectionTimeout = connectionTimeout;
  client.findProxy = _WindowsSystemProxy.findProxy;
  return client;
}

class _WindowsSystemProxy {
  const _WindowsSystemProxy._({
    required this.enabled,
    required this.proxyServer,
    required this.proxyOverride,
  });

  final bool enabled;
  final String proxyServer;
  final List<String> proxyOverride;

  static final _WindowsSystemProxy _current = _load();

  static String findProxy(Uri uri) => _current._findProxy(uri);

  static _WindowsSystemProxy _load() {
    if (!Platform.isWindows) {
      return const _WindowsSystemProxy._(
        enabled: false,
        proxyServer: '',
        proxyOverride: [],
      );
    }
    final enabledRaw = _readRegistryValue('ProxyEnable');
    final proxyServer = _readRegistryValue('ProxyServer').trim();
    final proxyOverride = _readRegistryValue('ProxyOverride')
        .split(';')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final enabled =
        enabledRaw == '1' ||
        enabledRaw.toLowerCase() == '0x1' ||
        enabledRaw.toLowerCase().endsWith(' 0x1');
    return _WindowsSystemProxy._(
      enabled: enabled && proxyServer.isNotEmpty,
      proxyServer: proxyServer,
      proxyOverride: proxyOverride,
    );
  }

  static String _readRegistryValue(String name) {
    try {
      final result = Process.runSync('reg', [
        'query',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        name,
      ], runInShell: true);
      if (result.exitCode != 0) {
        return '';
      }
      final output = result.stdout?.toString() ?? '';
      for (final line in output.split(RegExp(r'\r?\n'))) {
        if (!line.contains(name)) {
          continue;
        }
        final match = RegExp(
          r'REG_\w+\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(line.trim());
        if (match != null) {
          return match.group(1)?.trim() ?? '';
        }
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  String _findProxy(Uri uri) {
    if (!enabled || _shouldBypass(uri.host)) {
      return 'DIRECT';
    }
    final server = _proxyForScheme(uri.scheme);
    if (server == null || server.isEmpty) {
      return 'DIRECT';
    }
    return '${_proxyDirective(server)}; DIRECT';
  }

  bool _shouldBypass(String host) {
    final lower = host.toLowerCase();
    if (lower == 'localhost' ||
        lower == '::1' ||
        lower.startsWith('127.') ||
        lower.startsWith('10.') ||
        lower.startsWith('192.168.')) {
      return true;
    }
    for (final pattern in proxyOverride) {
      final lowerPattern = pattern.toLowerCase();
      if (lowerPattern == '<local>' && !lower.contains('.')) {
        return true;
      }
      if (_wildcardMatches(lowerPattern, lower)) {
        return true;
      }
    }
    return false;
  }

  bool _wildcardMatches(String pattern, String value) {
    if (pattern == value) {
      return true;
    }
    final regex = RegExp(
      '^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}\$',
      caseSensitive: false,
    );
    return regex.hasMatch(value);
  }

  String? _proxyForScheme(String scheme) {
    final raw = proxyServer.trim();
    if (raw.isEmpty) {
      return null;
    }
    final parts = raw.split(';').map((item) => item.trim()).toList();
    final values = <String, String>{};
    for (final part in parts) {
      final index = part.indexOf('=');
      if (index <= 0) {
        continue;
      }
      values[part.substring(0, index).toLowerCase()] = part.substring(
        index + 1,
      );
    }
    if (values.isNotEmpty) {
      return values[scheme] ??
          values['https'] ??
          values['http'] ??
          values.values.first;
    }
    return raw;
  }

  String _proxyDirective(String server) {
    final trimmed = server.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('socks=')) {
      return 'SOCKS ${trimmed.substring(6)}';
    }
    if (lower.startsWith('socks://')) {
      return 'SOCKS ${trimmed.substring(8)}';
    }
    if (lower.startsWith('http://')) {
      return 'PROXY ${trimmed.substring(7)}';
    }
    if (lower.startsWith('https://')) {
      return 'PROXY ${trimmed.substring(8)}';
    }
    return 'PROXY $trimmed';
  }
}

class Pdf2zhLocalService {
  const Pdf2zhLocalService();

  Future<bool> isRunning(String rawUrl) async {
    final uri = _baseUri(rawUrl);
    final client = _newHttpClient(
      connectionTimeout: const Duration(seconds: 2),
    );
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 2));
      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<String>> run({
    required PdfSource source,
    required ReaderSettings settings,
    required Pdf2zhAction action,
  }) async {
    final path = source.path;
    if (path == null || path.isEmpty) {
      throw StateError('pdf2zh 需要可访问的本地 PDF 文件路径。');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('文件不存在：$path');
    }
    if (!await isRunning(settings.pdf2zhServiceUrl)) {
      throw StateError('未检测到 pdf2zh 本地服务，请先在终端运行 pdf2zh。');
    }
    if (action == Pdf2zhAction.checkService) {
      return const [];
    }

    final uri = _baseUri(settings.pdf2zhServiceUrl).replace(
      pathSegments: [
        ..._baseUri(
          settings.pdf2zhServiceUrl,
        ).pathSegments.where((item) => item.isNotEmpty),
        action.endpoint,
      ],
    );
    final bytes = await file.readAsBytes();
    final body = jsonEncode({
      'fileName': p.basename(path),
      'fileContent': 'data:application/pdf;base64,${base64Encode(bytes)}',
      ..._configFromSettings(settings),
      ..._configFromAction(action),
    });
    final responseBody = await _postJson(uri, body);
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    if (data['status'] == 'error') {
      throw StateError(data['message']?.toString() ?? 'pdf2zh 服务返回错误。');
    }
    final files = (data['fileList'] as List? ?? const [])
        .whereType<String>()
        .toList();
    if (files.isEmpty) {
      return const [];
    }

    final outputDir = Directory(
      p.join(p.dirname(path), '${p.basenameWithoutExtension(path)}_pdf2zh'),
    );
    await outputDir.create(recursive: true);
    final saved = <String>[];
    for (final item in files) {
      final bytes = await _downloadTranslatedFile(
        settings.pdf2zhServiceUrl,
        item,
      );
      final outPath = p.join(outputDir.path, p.basename(item));
      await File(outPath).writeAsBytes(bytes, flush: true);
      saved.add(outPath);
    }
    return saved;
  }

  Map<String, String> _configFromAction(Pdf2zhAction action) {
    return switch (action) {
      Pdf2zhAction.translate => const {
        'mono': 'true',
        'dual': 'false',
        'mono_cut': 'false',
        'dual_cut': 'false',
        'crop_compare': 'false',
        'compare': 'false',
      },
      Pdf2zhAction.crop => const {
        'mono': 'false',
        'dual': 'false',
        'mono_cut': 'true',
        'dual_cut': 'false',
        'crop_compare': 'false',
        'compare': 'false',
      },
      Pdf2zhAction.compare => const {
        'mono': 'false',
        'dual': 'true',
        'mono_cut': 'false',
        'dual_cut': 'false',
        'crop_compare': 'false',
        'compare': 'true',
      },
      Pdf2zhAction.cropCompare => const {
        'mono': 'false',
        'dual': 'false',
        'mono_cut': 'false',
        'dual_cut': 'true',
        'crop_compare': 'true',
        'compare': 'false',
      },
      Pdf2zhAction.checkService => const {},
    };
  }

  Map<String, String> _configFromSettings(ReaderSettings settings) {
    return {
      'serverUrl': settings.pdf2zhServiceUrl,
      'threadNum': '${settings.pdf2zhThreadCount}',
      'qps': '${settings.pdf2zhQps}',
      'poolSize': '${settings.pdf2zhPoolSize}',
      'engine': settings.pdf2zhEngine,
      'service': settings.pdf2zhService,
      'next_service': settings.pdf2zhNextService,
      'skipLastPages': '${settings.pdf2zhSkipLastPages}',
      'sourceLang': settings.pdf2zhSourceLanguage,
      'targetLang': settings.pdf2zhTargetLanguage,
      'rename': '${settings.pdf2zhRename}',
      'skipSubsetFonts': '${settings.pdf2zhSkipSubsetFonts}',
      'babeldoc': '${settings.pdf2zhBabeldoc}',
      'fontFile': '',
      'fontFamily': settings.pdf2zhFontFamily,
      'dualMode': settings.pdf2zhDualMode,
      'transFirst': '${settings.pdf2zhTransFirst}',
      'ocr': '${settings.pdf2zhOcr}',
      'autoOcr': '${settings.pdf2zhAutoOcr}',
      'noWatermark': '${settings.pdf2zhNoWatermark}',
      'saveGlossary': 'false',
      'disableGlossary': 'false',
      'noDual': 'false',
      'noMono': 'false',
      'skipClean': 'false',
      'disableRichTextTranslate': 'false',
      'enhanceCompatibility': '${settings.pdf2zhEnhanceCompatibility}',
      'translateTableText': '${settings.pdf2zhTranslateTableText}',
      'onlyIncludeTranslatedPage': 'false',
    };
  }

  Future<String> _postJson(Uri uri, String body) async {
    final client = _newHttpClient(
      connectionTimeout: const Duration(seconds: 5),
    );
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(body);
      final response = await request.close().timeout(
        const Duration(minutes: 10),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('pdf2zh 服务响应失败：HTTP ${response.statusCode}');
      }
      return responseBody;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<int>> _downloadTranslatedFile(String baseUrl, String name) async {
    final uri = _baseUri(baseUrl).replace(
      pathSegments: [
        ..._baseUri(baseUrl).pathSegments.where((item) => item.isNotEmpty),
        'translatedFile',
        ...name.split('/').where((item) => item.isNotEmpty),
      ],
    );
    final client = _newHttpClient(
      connectionTimeout: const Duration(seconds: 5),
    );
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(minutes: 6),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('无法下载翻译文件：$name');
      }
      return await response.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );
    } finally {
      client.close(force: true);
    }
  }

  Uri _baseUri(String raw) {
    final value = raw.trim().isEmpty ? 'http://localhost:8890' : raw.trim();
    return Uri.parse(
      value.endsWith('/') ? value.substring(0, value.length - 1) : value,
    );
  }
}

class SelectionTranslationService {
  const SelectionTranslationService();

  static const _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36 Edg/113.0.1774.42';
  static const _deepLXUserAgent =
      'DeepLBrowserExtension/1.28.0 Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36';
  static const _tencentTransmartUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36';
  static const _tencentTransmartClientKey =
      'browser-chrome-110.0.0-Mac OS-df4bd4c5-a65d-44b2-a40f-42f34f3535f2-1677486696487';
  static const _keylessTranslateFallbackOrder = [
    'bing',
    'tencenttransmart',
    'huoshanweb',
    'google',
  ];
  static String? _bingAuthToken;
  static DateTime? _bingAuthTokenExpiresAt;

  static String normalizeSelectionText(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ');
    if (normalized.isEmpty) {
      return '';
    }
    return dictionaryLookupTerm(normalized) ?? normalized;
  }

  static String? dictionaryLookupTerm(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'[ \t\r\f\v]+'), ' ');
    if (normalized.isEmpty ||
        normalized.length > 64 ||
        normalized.contains('\n')) {
      return null;
    }

    final stripped = _stripSelectionEdgePunctuation(normalized);
    if (stripped.isEmpty) {
      return null;
    }

    final words = stripped
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty || words.length > 4) {
      return null;
    }

    for (final word in words) {
      if (!_containsWordCore(word) ||
          word.codeUnits.any((unit) => !_isDictionaryTermCodeUnit(unit))) {
        return null;
      }
    }
    return stripped;
  }

  static String _stripSelectionEdgePunctuation(String text) {
    var start = 0;
    var end = text.length;
    while (start < end && !_isDictionaryTermCodeUnit(text.codeUnitAt(start))) {
      start++;
    }
    while (end > start &&
        !_isDictionaryTermCodeUnit(text.codeUnitAt(end - 1))) {
      end--;
    }
    while (start < end && !_isWordCoreCodeUnit(text.codeUnitAt(start))) {
      start++;
    }
    while (end > start && !_isWordCoreCodeUnit(text.codeUnitAt(end - 1))) {
      end--;
    }
    return start < end ? text.substring(start, end).trim() : '';
  }

  static bool _containsWordCore(String text) {
    return text.codeUnits.any(_isWordCoreCodeUnit);
  }

  static bool _isDictionaryTermCodeUnit(int codeUnit) {
    return _isWordCoreCodeUnit(codeUnit) ||
        (codeUnit >= 0x30 && codeUnit <= 0x39) ||
        codeUnit == 0x20 ||
        codeUnit == 0x27 ||
        codeUnit == 0x2019 ||
        codeUnit == 0x2d ||
        codeUnit == 0x2010 ||
        codeUnit == 0x2011 ||
        codeUnit == 0x2012 ||
        codeUnit == 0x2013;
  }

  static bool _isWordCoreCodeUnit(int codeUnit) {
    return (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a) ||
        (codeUnit >= 0x4e00 && codeUnit <= 0x9fff);
  }

  Future<SelectionTranslationResult> translate({
    required String text,
    required ReaderSettings settings,
  }) async {
    final trimmed = normalizeSelectionText(text);
    if (trimmed.isEmpty) {
      return const SelectionTranslationResult(translation: '');
    }

    String translation = '';
    String dictionary = '';
    List<PronunciationAudio> audio = const [];
    Object? translationError;
    Object? dictionaryError;

    try {
      translation = await _translateSentence(trimmed, settings);
    } catch (error) {
      translationError = error;
    }

    final dictionaryTerm = dictionaryLookupTerm(trimmed);
    if (settings.selectionDictionaryEnabled && dictionaryTerm != null) {
      try {
        final result = await _translateWord(dictionaryTerm, settings);
        dictionary = result.text;
        audio = settings.selectionShowPronunciation ? result.audio : const [];
      } catch (error) {
        dictionaryError = error;
      }
    }

    if (translation.isEmpty && dictionary.isEmpty) {
      final pieces = [
        if (translationError != null) '翻译服务暂不可用：$translationError',
        if (dictionaryError != null) '字典服务暂不可用：$dictionaryError',
      ];
      translation = pieces.isEmpty ? '未返回翻译结果。' : pieces.join('\n');
    }

    return SelectionTranslationResult(
      translation: translation,
      dictionary: dictionary,
      audio: audio,
      translationService: settings.selectionTranslateService,
      dictionaryService: settings.selectionDictionaryService,
    );
  }

  Future<String> _translateSentence(
    String text,
    ReaderSettings settings,
  ) async {
    return switch (settings.selectionTranslateService) {
      'baidu' => _baidu(text, settings),
      'aliyun' => _aliyun(text, settings),
      'tencent' => _tencent(text, settings),
      'youdao' ||
      'google' ||
      'bing' ||
      'cnki' ||
      'deeplx' ||
      'haici' ||
      'huoshanweb' ||
      'tencenttransmart' => _translateKeylessWithFallback(
        settings.selectionTranslateService,
        text,
        settings,
      ),
      _ => _translateKeylessWithFallback('bing', text, settings),
    };
  }

  Future<String> _translateKeylessWithFallback(
    String primaryService,
    String text,
    ReaderSettings settings,
  ) async {
    final errors = <String, Object>{};
    final services = <String>[
      primaryService,
      for (final service in _keylessTranslateFallbackOrder)
        if (service != primaryService) service,
    ];

    for (final service in services) {
      try {
        final result = (await _translateKeylessByService(
          service,
          text,
          settings,
        )).trim();
        if (result.isNotEmpty) {
          return result;
        }
        errors[service] = StateError(
          '$service returned an empty translation result',
        );
      } catch (error) {
        errors[service] = error;
      }
    }
    throw StateError(_formatTranslationErrors(errors));
  }

  Future<String> _translateKeylessByService(
    String service,
    String text,
    ReaderSettings settings,
  ) {
    return switch (service) {
      'youdao' => _youdao(text, settings),
      'bing' => _bing(text, settings),
      'google' => _google(text, settings),
      'cnki' => _cnki(text, settings),
      'deeplx' => _deeplx(text, settings),
      'haici' => _haici(text, settings),
      'huoshanweb' => _huoshanWeb(text, settings),
      'tencenttransmart' => _tencentTransmart(text, settings),
      _ => _bing(text, settings),
    };
  }

  String _formatTranslationErrors(Map<String, Object> errors) {
    if (errors.isEmpty) {
      return 'translation failed';
    }
    return [
      '无密钥翻译服务全部不可用。',
      for (final entry in errors.entries)
        '${_translationServiceName(entry.key)}：${_compactError(entry.value)}',
    ].join('\n');
  }

  String _translationServiceName(String service) {
    return const {
          'youdao': '有道',
          'bing': '必应',
          'cnki': 'CNKI',
          'google': 'Google',
          'haici': '海词',
          'huoshanweb': '火山网页翻译',
          'tencenttransmart': '腾讯 TranSmart',
          'deeplx': 'DeepLX',
        }[service] ??
        service;
  }

  String _compactError(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 220) {
      return normalized;
    }
    return '${normalized.substring(0, 220)}...';
  }

  Future<_DictionaryResult> _translateWord(
    String text,
    ReaderSettings settings,
  ) async {
    final term = text.trim().toLowerCase();
    return switch (settings.selectionDictionaryService) {
      'bingdict' => _bingDict(term),
      'cambridgedict' => _cambridgeDict(term, settings),
      'freedictionaryapi' => _freeDictionaryApi(term),
      'haicidict' => _haiciDict(term),
      'youdaodict' => _youdaoDict(term),
      _ => _haiciDict(term),
    };
  }

  String _sourceLang(ReaderSettings settings, {String auto = 'auto'}) {
    return settings.selectionTranslateAutoDetectLanguage
        ? auto
        : settings.selectionTranslateSourceLanguage.trim();
  }

  String _targetLang(ReaderSettings settings) {
    final target = settings.selectionTranslateTargetLanguage.trim();
    return target.isEmpty ? 'zh-CN' : target;
  }

  Future<String> _youdao(String text, ReaderSettings settings) async {
    final from = _sourceLang(
      settings,
      auto: 'AUTO',
    ).toUpperCase().replaceAll('-', '_');
    final to = _targetLang(settings).toUpperCase().replaceAll('-', '_');
    try {
      final uri = Uri.http('fanyi.youdao.com', '/translate', {
        'doctype': 'json',
        'type': '${from}2$to',
        'i': text,
      });
      final data = await _getJson(uri);
      final rows = data['translateResult'] as List? ?? const [];
      final result = rows
          .expand((row) => row is List ? row : const [])
          .map((item) => item is Map ? item['tgt']?.toString() : null)
          .whereType<String>()
          .join('\n')
          .trim();
      if (result.isNotEmpty) {
        return result;
      }
    } catch (error) {
      throw StateError('有道旧接口不可用：$error');
    }
    throw StateError('有道未返回翻译结果。');
  }

  Future<String> _google(String text, ReaderSettings settings) async {
    final uri = Uri.https('translate.google.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': _googleLang(_sourceLang(settings)),
      'tl': _googleLang(_targetLang(settings)),
      'hl': 'en',
      'dt': ['at', 'bd', 'ex', 'ld', 'md', 'qca', 'rw', 'rm', 'ss', 't'],
      'source': 'bh',
      'ssel': '0',
      'tsel': '0',
      'kc': '1',
      'tk': _googleToken(text),
      'q': text,
    });
    final data = await _getJson(uri);
    final rows = data is List && data.isNotEmpty && data.first is List
        ? data.first as List
        : const [];
    return rows
        .map((item) => item is List && item.isNotEmpty ? item.first : null)
        .whereType<String>()
        .join()
        .trim();
  }

  Future<String> _bing(String text, ReaderSettings settings) async {
    final token = await _bingToken();
    final query = <String, String>{
      'to': _targetLang(settings),
      'api-version': '3.0',
      'includeSentenceLength': 'true',
    };
    if (!settings.selectionTranslateAutoDetectLanguage) {
      query['from'] = settings.selectionTranslateSourceLanguage;
    }
    final data = await _postJson(
      Uri.https(
        'api-edge.cognitive.microsofttranslator.com',
        '/translate',
        query,
      ),
      jsonEncode([
        {'text': text},
      ]),
      headers: {
        'accept': '*/*',
        'accept-language':
            'zh-TW,zh;q=0.9,ja;q=0.8,zh-CN;q=0.7,en-US;q=0.6,en;q=0.5',
        'authorization': 'Bearer $token',
        'cache-control': 'no-cache',
        'content-type': 'application/json',
        'pragma': 'no-cache',
        'referer': 'https://appsumo.com/',
        'user-agent': _browserUserAgent,
      },
    );
    final rows = data is List ? data : const [];
    if (rows.isEmpty || rows.first is! Map) {
      return '';
    }
    final translations =
        (rows.first as Map)['translations'] as List? ?? const [];
    return translations.isNotEmpty && translations.first is Map
        ? ((translations.first as Map)['text']?.toString() ?? '')
        : '';
  }

  Future<String> _bingToken() async {
    final cachedToken = _bingAuthToken;
    final expiresAt = _bingAuthTokenExpiresAt;
    if (cachedToken != null &&
        cachedToken.isNotEmpty &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt)) {
      return cachedToken;
    }
    final token = (await _getText(
      Uri.https('edge.microsoft.com', '/translate/auth'),
      headers: {'user-agent': _browserUserAgent},
    )).trim();
    if (token.isEmpty) {
      throw StateError('Bing 未返回授权 token。');
    }
    _bingAuthToken = token;
    _bingAuthTokenExpiresAt = DateTime.now().add(const Duration(minutes: 4));
    return token;
  }

  Future<String> _baidu(String text, ReaderSettings settings) async {
    final parts = settings.selectionTranslateSecretFor('baidu').split('#');
    if (parts.length < 2) {
      throw StateError('百度翻译密钥格式：appid#key#action(可选)。');
    }
    final appid = parts[0];
    final key = parts[1];
    final action = parts.length >= 3 && parts[2].isNotEmpty ? parts[2] : '0';
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final sign = crypto.md5.convert(utf8.encode(appid + text + salt + key));
    final data = await _getJson(
      Uri.http('api.fanyi.baidu.com', '/api/trans/vip/translate', {
        'q': text,
        'appid': appid,
        'from': _baiduLang(_sourceLang(settings, auto: 'auto')),
        'to': _baiduLang(_targetLang(settings)),
        'salt': salt,
        'sign': '$sign',
        'action': action,
        'needIntervene': '1',
      }),
    );
    if (data['error_code'] != null) {
      throw StateError('${data['error_code']}:${data['error_msg']}');
    }
    return (data['trans_result'] as List? ?? const [])
        .map((item) => item is Map ? item['dst']?.toString() : null)
        .whereType<String>()
        .join('\n');
  }

  Future<String> _aliyun(String text, ReaderSettings settings) async {
    final parts = settings.selectionTranslateSecretFor('aliyun').split('#');
    if (parts.length < 2) {
      throw StateError('阿里翻译密钥格式：accessKeyId#accessKeySecret#endpoint(可选)。');
    }
    final accessKeyId = parts[0];
    final accessKeySecret = parts[1];
    final endpoint = parts.length >= 3 && parts[2].isNotEmpty
        ? parts[2]
        : 'https://mt.aliyuncs.com/';
    final params = <String, String>{
      'AccessKeyId': accessKeyId,
      'Action': 'TranslateGeneral',
      'Format': 'JSON',
      'FormatType': 'text',
      'Scene': 'general',
      'SignatureMethod': 'HMAC-SHA1',
      'SignatureNonce': _randomString(12),
      'SignatureVersion': '1.0',
      'SourceLanguage': _aliyunLang(_sourceLang(settings, auto: 'auto')),
      'SourceText': text,
      'TargetLanguage': _aliyunLang(_targetLang(settings)),
      'Timestamp': _iso8601Milliseconds(DateTime.now().toUtc()),
      'Version': '2018-10-12',
    };
    final encodedBody = _canonicalQuery(params);
    final signature = _hmacSha1Base64(
      'POST&%2F&${Uri.encodeComponent(encodedBody)}',
      '$accessKeySecret&',
    );
    final data = await _postJsonCompatible(
      Uri.parse(endpoint),
      '$encodedBody&Signature=${_encodeRfc3986(signature)}',
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      allowErrorStatus: true,
    );
    if (data['Code']?.toString() != '200') {
      throw StateError('${data['Code']}:${data['Message']}');
    }
    return data['Data']?['Translated']?.toString() ?? '';
  }

  Future<String> _tencent(String text, ReaderSettings settings) async {
    final parts = settings.selectionTranslateSecretFor('tencent').split('#');
    if (parts.length < 2) {
      throw StateError('腾讯翻译密钥格式：SecretId#SecretKey#Region(可选)#ProjectId(可选)。');
    }
    final secretId = parts[0];
    final secretKey = parts[1];
    final region = parts.length >= 3 && parts[2].isNotEmpty
        ? parts[2]
        : 'ap-shanghai';
    final projectId = parts.length >= 4 && parts[3].isNotEmpty ? parts[3] : '0';
    final termRepoIds = parts.length >= 5 ? _splitIdList(parts[4]) : const [];
    final sentRepoIds = parts.length >= 6 ? _splitIdList(parts[5]) : const [];
    final params = <String, String>{
      'Action': 'TextTranslate',
      'Language': 'zh-CN',
      'Nonce': '9744',
      'ProjectId': projectId,
      'Region': region,
      'SecretId': secretId,
      'Source': _baseLang(_sourceLang(settings, auto: 'auto')),
      'SourceText': '#\$#',
      'Target': _baseLang(_targetLang(settings)),
      'Timestamp': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      'Version': '2018-03-21',
    };
    for (var i = 0; i < termRepoIds.length; i++) {
      params['TermRepoIDList.$i'] = termRepoIds[i];
    }
    for (var i = 0; i < sentRepoIds.length; i++) {
      params['SentRepoIDList.$i'] = sentRepoIds[i];
    }
    final rawStr = _canonicalTencentRawQuery(params);
    final signature = _hmacSha1Base64(
      'POSTtmt.tencentcloudapi.com/?${rawStr.replaceAll('#\$#', text)}',
      secretKey,
    );
    final response = await _postText(
      Uri.https('tmt.tencentcloudapi.com'),
      '${rawStr.replaceAll('#\$#', _encodeTencent(text))}&Signature=${_encodeTencent(signature)}',
      headers: {'content-type': 'application/json'},
    );
    final data = jsonDecode(response) as Map<String, dynamic>;
    final responseData = data['Response'] as Map? ?? const {};
    if (responseData['Error'] != null) {
      final error = responseData['Error'] as Map;
      throw StateError('${error['Code']}:${error['Message']}');
    }
    return responseData['TargetText']?.toString() ?? '';
  }

  Future<String> _cnki(String text, ReaderSettings settings) async {
    final tokenData = await _getJson(
      Uri.https('dict.cnki.net', '/fyzs-front-api/getToken'),
      headers: {
        'accept': 'application/json, text/plain, */*',
        'referer': 'https://dict.cnki.net/',
        'user-agent': _browserUserAgent,
      },
    );
    final token =
        tokenData['data']?.toString() ?? tokenData['token']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('CNKI 未返回 token。');
    }
    final content = text.length > 800 ? text.substring(0, 800) : text;
    final data = await _postJson(
      Uri.https(
        'dict.cnki.net',
        '/fyzs-front-api/translate/literaltranslation',
      ),
      jsonEncode({'words': _cnkiEncryptWord(content), 'translateType': null}),
      headers: {
        'accept': 'application/json, text/plain, */*',
        'content-type': 'application/json;charset=UTF-8',
        'referer': 'https://dict.cnki.net/',
        'Token': token,
        'user-agent': _browserUserAgent,
      },
    );
    if (data['data'] is Map &&
        data['data']['isInputVerificationCode'] == true) {
      throw StateError('CNKI 要求人机验证，请稍后重试。');
    }
    return data['data']?['mResult']?.toString() ?? '';
  }

  Future<String> _deeplx(String text, ReaderSettings settings) async {
    final endpoint = settings.selectionTranslateEndpoint.trim();
    if (endpoint.isNotEmpty && !endpoint.contains('/jsonrpc')) {
      final data = await _postJson(
        Uri.parse(endpoint),
        jsonEncode({
          'text': text,
          'source_lang': _sourceLang(settings, auto: 'auto'),
          'target_lang': _targetLang(settings),
        }),
      );
      return data['data']?.toString() ??
          data['translation']?.toString() ??
          data['result']?.toString() ??
          '';
    }
    final url = endpoint.isEmpty ? 'https://www2.deepl.com/jsonrpc' : endpoint;
    final id = 1000 * (Random.secure().nextInt(99999) + 8300000) + 1;
    final iCounts = RegExp('i').allMatches(text).length + 1;
    final ts = DateTime.now().millisecondsSinceEpoch;
    var body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'LMT_handle_texts',
      'id': id,
      'params': {
        'texts': [
          {'text': text, 'requestAlternatives': 3},
        ],
        'splitting': 'newlines',
        'lang': {
          'source_lang_user_selected': _mapDeepLXLang(
            _sourceLang(settings, auto: 'auto'),
          ),
          'target_lang': _mapDeepLXLang(_targetLang(settings)),
        },
        'timestamp': ts - (ts % iCounts) + iCounts,
        'commonJobParams': {'wasSpoken': false, 'transcribe_as': ''},
      },
    });
    if ((id + 5) % 29 == 0 || (id + 3) % 13 == 0) {
      body = body.replaceFirst('"method":"', '"method" : "');
    } else {
      body = body.replaceFirst('"method":"', '"method": "');
    }
    final data = await _postJson(
      Uri.parse('$url?client=chrome-extension,1.28.0&method=LMT_handle_jobs'),
      body,
      headers: {
        'accept': '*/*',
        'accept-language':
            'en-US,en;q=0.9,zh-CN;q=0.8,zh-TW;q=0.7,zh-HK;q=0.6,zh;q=0.5',
        'authorization': 'None',
        'cache-control': 'no-cache',
        'content-type': 'application/json',
        'dnt': '1',
        'origin': 'chrome-extension://cofdbpoegempjloogbagkncekinflcnj',
        'pragma': 'no-cache',
        'priority': 'u=1, i',
        'referer': 'https://www.deepl.com/',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'none',
        'sec-gpc': '1',
        'user-agent': _deepLXUserAgent,
      },
    );
    return data['result']?['texts']?[0]?['text']?.toString() ?? '';
  }

  Future<String> _haici(String text, ReaderSettings settings) async {
    final appIdPage = await _getText(
      Uri.http('capi.dict.cn', '/fanyi.php'),
      headers: {'Referer': 'http://fanyi.dict.cn/'},
    );
    final appId = RegExp(r'"([^"]+)"').firstMatch(appIdPage)?.group(1);
    if (appId == null) {
      throw StateError('海词未返回 appId。');
    }
    final data = await _getJson(
      Uri.http('api.microsofttranslator.com', '/V2/Ajax.svc/TranslateArray', {
        'appId': appId,
        'from': _baseLang(_sourceLang(settings, auto: 'en')),
        'to': _baseLang(_targetLang(settings)),
        'texts': jsonEncode([text]),
      }),
    );
    return (data as List? ?? const [])
        .map((item) => item is Map ? item['TranslatedText']?.toString() : null)
        .whereType<String>()
        .join('\n');
  }

  Future<String> _huoshanWeb(String text, ReaderSettings settings) async {
    final data = await _postJson(
      Uri.https('translate.volcengine.com', '/crx/translate/v1'),
      jsonEncode({
        'source_language': _baseLang(_sourceLang(settings, auto: 'auto')),
        'target_language': _baseLang(_targetLang(settings)),
        'text': text,
      }),
      headers: {
        'accept': 'application/json, text/plain, */*',
        'content-type': 'application/json',
        'user-agent': _browserUserAgent,
      },
    );
    return data['translation']?.toString() ?? '';
  }

  Future<String> _tencentTransmart(String text, ReaderSettings settings) async {
    final data = await _postJson(
      Uri.https('transmart.qq.com', '/api/imt'),
      jsonEncode({
        'header': {
          'fn': 'auto_translation',
          'client_key': _tencentTransmartClientKey,
        },
        'type': 'plain',
        'model_category': 'normal',
        'source': {
          'lang': _baseLang(_sourceLang(settings, auto: 'auto')),
          'text_list': [text],
        },
        'target': {'lang': _baseLang(_targetLang(settings))},
      }),
      headers: {
        'content-type': 'application/json',
        'referer': 'https://transmart.qq.com/zh-CN/index',
        'user-agent': _tencentTransmartUserAgent,
      },
    );
    final result = data['auto_translation'];
    return result is List ? result.join('\n').trim() : '';
  }

  List<PronunciationAudio> _accentAudio(Iterable<PronunciationAudio> items) {
    PronunciationAudio? uk;
    PronunciationAudio? us;
    for (final item in items) {
      if (item.url.trim().isEmpty) {
        continue;
      }
      switch (item.accent) {
        case PronunciationAccent.uk:
          uk ??= item;
        case PronunciationAccent.us:
          us ??= item;
      }
    }
    return [?uk, ?us];
  }

  PronunciationAccent? _accentFromText(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('英') ||
        RegExp(r'(^|[^a-z])(uk|br)([^a-z]|$)').hasMatch(lower) ||
        lower.contains('uk_pron') ||
        lower.contains('uk-pron') ||
        lower.contains('british')) {
      return PronunciationAccent.uk;
    }
    if (lower.contains('美') ||
        RegExp(r'(^|[^a-z])us([^a-z]|$)').hasMatch(lower) ||
        lower.contains('us_pron') ||
        lower.contains('us-pron') ||
        lower.contains('american')) {
      return PronunciationAccent.us;
    }
    return null;
  }

  String _cleanPhonetic(String value) {
    return _compactDictionaryLine(
      value
          .replaceAll(
            RegExp(r'^(英式|美式|英|美|uk|us|uk:|us:)\s*', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(r'^(br|british|american)\s*', caseSensitive: false),
            '',
          ),
    );
  }

  String _formatDictionaryText(
    String head,
    Iterable<String> lines, {
    String? ukPhonetic,
    String? usPhonetic,
  }) {
    final bodyLines = <String>[];
    for (final raw in lines) {
      for (final part in raw.split('\n')) {
        final line = _compactDictionaryLine(part);
        if (line.isEmpty || _isDictionaryNoiseLine(line, head)) {
          continue;
        }
        bodyLines.add(line);
      }
    }

    final pieces = <String>[
      if (head.trim().isNotEmpty) head.trim(),
      if (ukPhonetic != null && ukPhonetic.trim().isNotEmpty)
        '英式 ${_cleanPhonetic(ukPhonetic)}',
      if (usPhonetic != null && usPhonetic.trim().isNotEmpty)
        '美式 ${_cleanPhonetic(usPhonetic)}',
      ...bodyLines.map(_decorateDictionaryLine),
    ];
    return _limitLines(pieces.join('\n'), 36);
  }

  String _decorateDictionaryLine(String line) {
    if (line.startsWith('[') ||
        line.startsWith('【') ||
        RegExp(r'^\d+\.').hasMatch(line) ||
        line.startsWith('例句：') ||
        line.startsWith('Example:')) {
      return line;
    }
    return '• $line';
  }

  bool _isDictionaryNoiseLine(String line, String head) {
    final lower = line.toLowerCase();
    final normalizedHead = head.trim().toLowerCase();
    if (normalizedHead.isNotEmpty && lower == normalizedHead) {
      return true;
    }
    return lower.contains('javascript') ||
        lower.contains('google_ad_') ||
        lower.contains('add to word list') ||
        lower.contains('learn more') ||
        line.contains('必应词典为您提供') ||
        line.contains('海词词典') ||
        line.contains('在线翻译') ||
        line.contains('返回顶部') ||
        line.contains('暂无') ||
        line.contains('未返回');
  }

  Future<_DictionaryResult> _freeDictionaryApi(String word) async {
    final data = await _getJson(
      Uri.https('api.dictionaryapi.dev', '/api/v2/entries/en/$word'),
    );
    final entry = data is List && data.isNotEmpty && data.first is Map
        ? data.first as Map
        : const {};
    final audio = <PronunciationAudio>[];
    String? ukPhonetic;
    String? usPhonetic;
    for (final item in entry['phonetics'] as List? ?? const []) {
      if (item is! Map) {
        continue;
      }
      final phonetic = item['text']?.toString().trim() ?? '';
      final url = item['audio']?.toString().trim() ?? '';
      final accent = _accentFromText('$phonetic $url');
      if (accent == PronunciationAccent.uk && ukPhonetic == null) {
        ukPhonetic = phonetic;
      } else if (accent == PronunciationAccent.us && usPhonetic == null) {
        usPhonetic = phonetic;
      }
      if (accent != null && url.isNotEmpty) {
        audio.add(
          PronunciationAudio(accent: accent, phonetic: phonetic, url: url),
        );
      }
    }
    final meanings = <String>[];
    for (final meaning in entry['meanings'] as List? ?? const []) {
      if (meaning is! Map) {
        continue;
      }
      final part = meaning['partOfSpeech']?.toString() ?? '';
      final defs = (meaning['definitions'] as List? ?? const [])
          .whereType<Map>()
          .take(4)
          .indexed
          .map((def) {
            final index = def.$1 + 1;
            final item = def.$2;
            final definition = item['definition']?.toString() ?? '';
            final example = item['example']?.toString();
            if (definition.trim().isEmpty) {
              return '';
            }
            final suffix = example == null || example.trim().isEmpty
                ? ''
                : '\n例句：${example.trim()}';
            return '$index. $definition$suffix';
          })
          .where((item) => item.trim().isNotEmpty);
      if (part.isNotEmpty && defs.isNotEmpty) {
        meanings.add('[$part]\n${defs.join('\n')}');
      }
    }
    return _DictionaryResult(
      text: _formatDictionaryText(
        entry['word']?.toString() ?? word,
        meanings,
        ukPhonetic: ukPhonetic,
        usPhonetic: usPhonetic,
      ),
      audio: _accentAudio(audio),
    );
  }

  Future<_DictionaryResult> _youdaoDict(String word) async {
    final term = word.trim().toLowerCase();
    final html = await _getText(
      Uri.parse('https://www.youdao.com/w/${Uri.encodeComponent(term)}/'),
    );
    final head = _cleanHtml(
      RegExp(
            r'<span class="keyword">([\s\S]*?)</span>',
            caseSensitive: false,
          ).firstMatch(html)?.group(1) ??
          term,
    );
    final phonetics =
        RegExp(
              r'<span class="pronounce">([\s\S]*?)</span>',
              caseSensitive: false,
            )
            .allMatches(html)
            .map((match) => _cleanHtml(match.group(1) ?? ''))
            .where((line) => line.isNotEmpty)
            .take(2)
            .toList(growable: false);

    String? ukPhonetic;
    String? usPhonetic;
    for (final phonetic in phonetics) {
      final accent = _accentFromText(phonetic);
      if (accent == PronunciationAccent.uk) {
        ukPhonetic ??= phonetic;
      } else if (accent == PronunciationAccent.us) {
        usPhonetic ??= phonetic;
      }
    }

    final phrsBlock = _firstElementByClass(html, 'div', 'trans-wrapper');
    final transBlock = _firstElementByClass(
      phrsBlock.isEmpty ? html : phrsBlock,
      'div',
      'trans-container',
    );
    final definitions =
        RegExp(r'<li>([\s\S]*?)</li>', caseSensitive: false, dotAll: true)
            .allMatches(transBlock)
            .map((match) => _cleanHtml(match.group(1) ?? ''))
            .where((line) => line.isNotEmpty);
    final additional = _compactDictionaryLine(
      _cleanHtml(
        RegExp(
              r'<p class="additional">([\s\S]*?)</p>',
              caseSensitive: false,
            ).firstMatch(html)?.group(1) ??
            '',
      ),
    );
    final lines = [...definitions, if (additional.isNotEmpty) additional];
    if (lines.isEmpty) {
      throw StateError('有道词典未返回词条释义。');
    }
    final text = _formatDictionaryText(
      head.isNotEmpty ? head : term,
      lines,
      ukPhonetic: ukPhonetic,
      usPhonetic: usPhonetic,
    );
    final encoded = Uri.encodeComponent(term);
    return _DictionaryResult(
      text: text,
      audio: _accentAudio([
        PronunciationAudio(
          accent: PronunciationAccent.uk,
          phonetic: ukPhonetic ?? '',
          url: 'https://dict.youdao.com/dictvoice?audio=$encoded&type=1',
        ),
        PronunciationAudio(
          accent: PronunciationAccent.us,
          phonetic: usPhonetic ?? '',
          url: 'https://dict.youdao.com/dictvoice?audio=$encoded&type=2',
        ),
      ]),
    );
  }

  Future<_DictionaryResult> _bingDict(String word) async {
    final html = await _getText(
      Uri.https('cn.bing.com', '/dict/search', {'q': word}),
    );
    final audio = <PronunciationAudio>[];
    String? ukPhonetic;
    String? usPhonetic;
    for (final match in RegExp(
      r'<div[^>]*class="([^"]*\bhd_pr(?:US)?\b[^"]*\bb_primtxt\b[^"]*)"[^>]*>([\s\S]*?)</div>\s*<div[^>]*class="[^"]*\bhd_tf\b[^"]*"[^>]*>\s*<a[^>]*data-mp3link="([^"]+)"',
      caseSensitive: false,
    ).allMatches(html)) {
      final className = match.group(1)?.toLowerCase() ?? '';
      final phonetic = _cleanHtml(match.group(2) ?? '');
      final path = match.group(3) ?? '';
      final accent = className.contains('hd_prus')
          ? PronunciationAccent.us
          : PronunciationAccent.uk;
      if (accent == PronunciationAccent.uk) {
        ukPhonetic ??= phonetic;
      } else {
        usPhonetic ??= phonetic;
      }
      if (path.isNotEmpty) {
        audio.add(
          PronunciationAudio(
            accent: accent,
            phonetic: phonetic,
            url: _absoluteUrl(path, 'https://cn.bing.com'),
          ),
        );
      }
    }
    final qdef = _firstElementByClass(html, 'div', 'qdef');
    final definitions = <String>[];
    for (final match in RegExp(
      r'<li\b[^>]*>([\s\S]*?)</li>',
      caseSensitive: false,
    ).allMatches(qdef)) {
      final item = match.group(1) ?? '';
      final pos = _cleanHtml(_firstElementByClass(item, 'span', 'pos'));
      final def = _cleanHtml(_firstElementByClass(item, 'span', 'def'));
      final line = [
        pos,
        def,
      ].where((part) => part.trim().isNotEmpty).join(' ').trim();
      if (line.isNotEmpty) {
        definitions.add(line);
      }
    }
    if (definitions.isEmpty) {
      final meta = RegExp(
        r'<meta name="description" content="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(html)?.group(1);
      definitions.addAll(
        _decodeHtml(meta ?? '')
            .replaceFirst(RegExp(r'^必应词典为您提供[^，]*的释义，?'), '')
            .split(RegExp(r'[；;]'))
            .map(_compactDictionaryLine)
            .where(
              (line) =>
                  line.isNotEmpty &&
                  !line.contains('必应词典') &&
                  !line.contains('网络释义'),
            ),
      );
    }
    return _DictionaryResult(
      text: _formatDictionaryText(
        word,
        definitions,
        ukPhonetic: ukPhonetic,
        usPhonetic: usPhonetic,
      ),
      audio: _accentAudio(audio),
    );
  }

  Future<_DictionaryResult> _haiciDict(String word) async {
    final html = await _getText(Uri.https('dict.cn', '/$word'));
    final audio = <PronunciationAudio>[];
    String? ukPhonetic;
    String? usPhonetic;
    final phoneticBlock = _firstMatch(
      html,
      RegExp(r'<div class="phonetic">([\s\S]*?)</div>', caseSensitive: false),
    );
    for (final span in RegExp(
      r'<span[^>]*>([\s\S]*?)</span>',
      caseSensitive: false,
    ).allMatches(phoneticBlock)) {
      final chunk = span.group(1) ?? '';
      final phonetic = _cleanHtml(chunk);
      final accent = _accentFromText(phonetic);
      if (accent == PronunciationAccent.uk) {
        ukPhonetic ??= phonetic;
      } else if (accent == PronunciationAccent.us) {
        usPhonetic ??= phonetic;
      }
      if (accent == null) {
        continue;
      }
      for (final match in RegExp(r'naudio="([^"]+)"').allMatches(chunk)) {
        final path = match.group(1);
        if (path != null && path.isNotEmpty) {
          audio.add(
            PronunciationAudio(
              accent: accent,
              phonetic: phonetic,
              url: 'https://audio.dict.cn/$path',
            ),
          );
        }
      }
    }
    final items = <String>[];
    final basicBlock = _firstElementByClass(html, 'ul', 'dict-basic-ul');
    for (final match in RegExp(
      r'<li\b[^>]*>([\s\S]*?)</li>',
      caseSensitive: false,
    ).allMatches(basicBlock)) {
      final raw = match.group(1) ?? '';
      if (raw.contains('<script')) {
        continue;
      }
      final line = _cleanHtml(raw);
      if (line.isNotEmpty) {
        items.add(line);
      }
    }

    final defBlock = _firstElementByClass(html, 'div', 'section def');
    for (final titleMatch in RegExp(
      r'<h3\b[^>]*>([\s\S]*?)</h3>\s*<div\b[^>]*class="[^"]*layout[^"]*"[^>]*>([\s\S]*?)(?=<h3\b|</div>\s*</div>)',
      caseSensitive: false,
    ).allMatches(defBlock)) {
      final title = _cleanHtml(titleMatch.group(1) ?? '');
      final chunk = titleMatch.group(2) ?? '';
      if (title.isNotEmpty) {
        items.add('【$title】');
      }
      final posLabels = RegExp(
        r'<span\b[^>]*>([\s\S]*?)</span>\s*<ol\b[^>]*>([\s\S]*?)</ol>',
        caseSensitive: false,
      ).allMatches(chunk);
      var matchedPos = false;
      for (final posMatch in posLabels) {
        matchedPos = true;
        final pos = _cleanHtml(posMatch.group(1) ?? '');
        if (pos.isNotEmpty) {
          items.add('[$pos]');
        }
        for (final li in RegExp(
          r'<li\b[^>]*>([\s\S]*?)</li>',
          caseSensitive: false,
        ).allMatches(posMatch.group(2) ?? '')) {
          final line = _cleanHtml(li.group(1) ?? '');
          if (line.isNotEmpty) {
            items.add(line);
          }
        }
      }
      if (!matchedPos) {
        for (final li in RegExp(
          r'<li\b[^>]*>([\s\S]*?)</li>',
          caseSensitive: false,
        ).allMatches(chunk)) {
          final line = _cleanHtml(li.group(1) ?? '');
          if (line.isNotEmpty) {
            items.add(line);
          }
        }
      }
    }
    return _DictionaryResult(
      text: _formatDictionaryText(
        word,
        items,
        ukPhonetic: ukPhonetic,
        usPhonetic: usPhonetic,
      ),
      audio: _accentAudio(audio),
    );
  }

  Future<_DictionaryResult> _cambridgeDict(
    String word,
    ReaderSettings settings,
  ) async {
    final target = _targetLang(settings).toLowerCase().startsWith('zh')
        ? 'english-chinese-simplified'
        : 'english-${_baseLang(_targetLang(settings))}';
    final html = await _getText(
      Uri.https('dictionary.cambridge.org', '/dictionary/$target/$word'),
    );
    final audio = <PronunciationAudio>[];
    String? ukPhonetic;
    String? usPhonetic;
    for (final block in RegExp(
      r'<span[^>]*class="[^"]*dpron-[^"]*"[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final chunk =
          _balancedElement(html, 'span', block.start, block.end) ?? '';
      final region = _cleanHtml(
        _firstMatch(
          chunk,
          RegExp(
            r'<span[^>]*class="region[^"]*"[^>]*>([\s\S]*?)</span>',
            caseSensitive: false,
          ),
        ),
      );
      final phonetic = _cleanHtml(
        _firstMatch(
          chunk,
          RegExp(
            r'<span[^>]*class="dpron[^"]*"[^>]*>([\s\S]*?)</span>',
            caseSensitive: false,
          ),
        ),
      );
      final url = _firstMatch(
        chunk,
        RegExp(r'<source[^>]+src="([^"]+)"', caseSensitive: false),
      );
      final accent = _accentFromText('$region $url');
      if (accent == PronunciationAccent.uk) {
        ukPhonetic ??= phonetic;
      } else if (accent == PronunciationAccent.us) {
        usPhonetic ??= phonetic;
      }
      if (accent != null && url.isNotEmpty) {
        audio.add(
          PronunciationAudio(
            accent: accent,
            phonetic: phonetic,
            url: _absoluteUrl(url, 'https://dictionary.cambridge.org'),
          ),
        );
      }
    }
    final definitions = <String>[];
    for (final entry in _elementsByClass(html, 'div', 'entry-body__el')) {
      final pos = _cleanHtml(_firstElementByClass(entry, 'div', 'posgram'));
      if (pos.isNotEmpty) {
        definitions.add('[$pos]');
      }
      for (final sense in _elementsByClass(entry, 'div', 'dsense')) {
        final guide = _cleanHtml(
          _firstElementByClass(sense, 'span', 'guideword'),
        );
        final def = _cleanHtml(_firstElementByClass(sense, 'div', 'def'));
        final trans = _cleanHtml(_firstElementByClass(sense, 'span', 'trans'));
        final line = [
          guide,
          def,
          if (trans.isNotEmpty) '=> $trans',
        ].where((item) => item.trim().isNotEmpty).join(' ');
        if (line.isNotEmpty) {
          definitions.add(line);
        }
      }
    }
    if (definitions.isEmpty) {
      throw StateError('剑桥词典未返回词条释义。');
    }
    return _DictionaryResult(
      text: _formatDictionaryText(
        word,
        definitions,
        ukPhonetic: ukPhonetic,
        usPhonetic: usPhonetic,
      ),
      audio: _accentAudio(audio),
    );
  }

  Future<dynamic> _getJson(Uri uri, {Map<String, String>? headers}) async {
    final body = await _getText(uri, headers: headers);
    return jsonDecode(body);
  }

  Future<String> _getText(
    Uri uri, {
    Map<String, String>? headers,
    int redirects = 0,
  }) async {
    final client = _newHttpClient(
      connectionTimeout: const Duration(seconds: 5),
    );
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, _browserUserAgent);
      headers?.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await response.transform(utf8.decoder).join();
      if (_isRedirect(response.statusCode) && redirects < 5) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location != null && location.isNotEmpty) {
          return await _getText(
            uri.resolve(location),
            headers: headers,
            redirects: redirects + 1,
          );
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('HTTP ${response.statusCode}');
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> _postJson(
    Uri uri,
    String body, {
    Map<String, String>? headers,
  }) async {
    final text = await _postText(
      uri,
      body,
      headers: {'content-type': 'application/json', ...?headers},
    );
    return jsonDecode(text);
  }

  Future<String> _postText(
    Uri uri,
    String body, {
    Map<String, String>? headers,
    int redirects = 0,
    bool allowErrorStatus = false,
  }) async {
    final client = _newHttpClient(
      connectionTimeout: const Duration(seconds: 5),
    );
    try {
      final request = await client.postUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, _browserUserAgent);
      headers?.forEach(request.headers.set);
      request.write(body);
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      if (_isRedirect(response.statusCode) && redirects < 5) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location != null && location.isNotEmpty) {
          return await _postText(
            uri.resolve(location),
            body,
            headers: headers,
            redirects: redirects + 1,
            allowErrorStatus: allowErrorStatus,
          );
        }
      }
      if (!allowErrorStatus &&
          (response.statusCode < 200 || response.statusCode >= 300)) {
        throw StateError(
          'HTTP ${response.statusCode}: ${_truncateForError(responseBody)}',
        );
      }
      return responseBody;
    } finally {
      client.close(force: true);
    }
  }

  bool _isRedirect(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }

  String _truncateForError(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= 300) {
      return trimmed;
    }
    return '${trimmed.substring(0, 300)}...';
  }

  Future<dynamic> _postJsonCompatible(
    Uri uri,
    String body, {
    required Map<String, String> headers,
    bool allowErrorStatus = false,
  }) async {
    final text = await _postText(
      uri,
      body,
      headers: headers,
      allowErrorStatus: allowErrorStatus,
    );
    return jsonDecode(text);
  }

  String _cnkiEncryptWord(String text) {
    final key = Uint8List.fromList(utf8.encode('4e87183cfd3a45fe'));
    final cipher = pc.PaddedBlockCipherImpl(
      pc.PKCS7Padding(),
      pc.ECBBlockCipher(pc.AESEngine()),
    )..init(true, pc.PaddedBlockCipherParameters(pc.KeyParameter(key), null));
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(text)));
    return base64Encode(encrypted).replaceAll('/', '_').replaceAll('+', '-');
  }

  String _hmacSha1Base64(String text, String key) {
    final hmac = crypto.Hmac(crypto.sha1, utf8.encode(key));
    return base64Encode(hmac.convert(utf8.encode(text)).bytes);
  }

  String _canonicalQuery(Map<String, String> params) {
    final keys = params.keys.toList()..sort();
    return keys
        .map(
          (key) =>
              '${_encodeRfc3986(key)}=${_encodeRfc3986(params[key] ?? '')}',
        )
        .join('&');
  }

  String _canonicalTencentRawQuery(Map<String, String> params) {
    final keys = params.keys.toList()..sort();
    return keys.map((key) => '$key=${params[key] ?? ''}').join('&');
  }

  String _encodeRfc3986(String value) {
    return Uri.encodeComponent(value).replaceAllMapped(
      RegExp(r"[!'()*]"),
      (match) =>
          '%${match.group(0)!.codeUnitAt(0).toRadixString(16).toUpperCase()}',
    );
  }

  String _encodeTencent(String value) {
    return Uri.encodeComponent(value)
        .replaceAll('%20', '+')
        .replaceAll("'", '%27')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29')
        .replaceAll('*', '%2A');
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  List<String> _splitIdList(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _iso8601Milliseconds(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    String three(int number) => number.toString().padLeft(3, '0');
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${two(utc.month)}-${two(utc.day)}T'
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}.'
        '${three(utc.millisecond)}Z';
  }

  String _googleLang(String value) {
    return switch (value) {
      'pt-BR' => 'pt',
      _ => value,
    };
  }

  String _googleToken(String text) {
    const seed = 406644;
    const seed2 = 3293161072;
    var value = seed;
    for (final byte in _googleTokenBytes(text)) {
      value += byte;
      value = _googleRotate(value, '+-a^+6');
    }
    value = _googleRotate(value, '+-3^+b+-f');
    value = (value ^ seed2) & 0xffffffff;
    value %= 1000000;
    return '$value.${value ^ seed}';
  }

  List<int> _googleTokenBytes(String text) {
    final bytes = <int>[];
    for (var i = 0; i < text.length; i++) {
      var code = text.codeUnitAt(i);
      if (code < 128) {
        bytes.add(code);
      } else if (code < 2048) {
        bytes
          ..add((code >> 6) | 192)
          ..add((code & 63) | 128);
      } else if ((code & 0xfc00) == 0xd800 &&
          i + 1 < text.length &&
          (text.codeUnitAt(i + 1) & 0xfc00) == 0xdc00) {
        code =
            0x10000 + ((code & 0x03ff) << 10) + (text.codeUnitAt(++i) & 0x03ff);
        bytes
          ..add((code >> 18) | 240)
          ..add(((code >> 12) & 63) | 128)
          ..add(((code >> 6) & 63) | 128)
          ..add((code & 63) | 128);
      } else {
        bytes
          ..add((code >> 12) | 224)
          ..add(((code >> 6) & 63) | 128)
          ..add((code & 63) | 128);
      }
    }
    return bytes;
  }

  int _googleRotate(int value, String salt) {
    var result = value;
    for (var i = 0; i < salt.length - 2; i += 3) {
      final char = salt.codeUnitAt(i + 2);
      final shift = char >= 0x61 ? char - 87 : int.parse(salt[i + 2]);
      final shifted = salt[i + 1] == '+' ? result >>> shift : result << shift;
      result = salt[i] == '+'
          ? (result + shifted) & 0xffffffff
          : result ^ shifted;
    }
    return result;
  }

  String _baseLang(String value) {
    final lower = value.toLowerCase();
    if (lower == 'auto') {
      return 'auto';
    }
    if (lower.startsWith('zh')) {
      return 'zh';
    }
    return lower.split('-').first;
  }

  String _baiduLang(String value) {
    final base = _baseLang(value);
    return base == 'zh' ? 'zh' : base;
  }

  String _aliyunLang(String value) {
    final base = _baseLang(value);
    return base == 'auto' ? 'auto' : base;
  }

  String _mapDeepLXLang(String raw) {
    final lower = raw.toLowerCase();
    if (lower == 'auto') {
      return 'AUTO';
    }
    if (lower.startsWith('zh')) {
      // DeepL's browser JSON-RPC endpoint currently rejects ZH-HANS/ZH-HANT
      // and accepts the generic ZH target instead.
      return 'ZH';
    }
    return switch (raw) {
      'pt-BR' => 'PT-BR',
      'pt-PT' => 'PT-PT',
      _ => raw.split('-').first.toUpperCase(),
    };
  }

  String _firstMatch(String text, RegExp regex) {
    return regex.firstMatch(text)?.group(1) ?? '';
  }

  String _firstElementByClass(String html, String tag, String classPart) {
    return _elementsByClass(html, tag, classPart).firstOrNull ?? '';
  }

  List<String> _elementsByClass(String html, String tag, String classPart) {
    final escapedTag = RegExp.escape(tag);
    final escapedClass = RegExp.escape(classPart);
    final startTag = RegExp(
      '<$escapedTag\\b[^>]*class\\s*=\\s*["\'][^"\']*$escapedClass[^"\']*["\'][^>]*>',
      caseSensitive: false,
    );
    final items = <String>[];
    for (final match in startTag.allMatches(html)) {
      final element = _balancedElement(html, tag, match.start, match.end);
      if (element != null && element.trim().isNotEmpty) {
        items.add(element);
      }
    }
    return items;
  }

  String? _balancedElement(
    String html,
    String tag,
    int start,
    int contentStart,
  ) {
    final escapedTag = RegExp.escape(tag);
    final token = RegExp('</?$escapedTag\\b[^>]*>', caseSensitive: false);
    var depth = 1;
    for (final match in token.allMatches(html, contentStart)) {
      final raw = match.group(0) ?? '';
      if (raw.startsWith('</')) {
        depth--;
        if (depth == 0) {
          return html.substring(contentStart, match.start);
        }
      } else if (!raw.endsWith('/>')) {
        depth++;
      }
    }
    return null;
  }

  String _absoluteUrl(String value, String base) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }
    if (value.startsWith('/')) {
      return '$base$value';
    }
    return '$base/$value';
  }

  String _cleanHtml(String html) {
    return _decodeHtml(
      html
          .replaceAll(RegExp(r'<script.*?</script>', dotAll: true), ' ')
          .replaceAll(RegExp(r'<style.*?</style>', dotAll: true), ' ')
          .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ')
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(
            RegExp(r'</(p|div|li|tr|h\d)>', caseSensitive: false),
            '\n',
          )
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+\n'), '\n')
          .replaceAll(RegExp(r'\n\s+'), '\n')
          .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
          .trim(),
    );
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
          final code = int.tryParse(match.group(1) ?? '', radix: 16);
          return code == null ? match.group(0)! : String.fromCharCode(code);
        })
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          final code = int.tryParse(match.group(1) ?? '');
          return code == null ? match.group(0)! : String.fromCharCode(code);
        });
  }

  String _limitLines(String text, int maxLines) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.take(maxLines).join('\n');
  }

  String _compactDictionaryLine(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ')
        .replaceAll('[ ', '[')
        .replaceAll(' ]', ']')
        .trim();
  }
}

class _DictionaryResult {
  const _DictionaryResult({required this.text, this.audio = const []});

  final String text;
  final List<PronunciationAudio> audio;
}
