import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ocr_mode.dart';

/// Basit ayarlar (tema ve OCR modu). Cihazda küçük bir JSON dosyasında saklanır.
class SettingsController extends ChangeNotifier {
  SettingsController({required Future<Directory> Function() directoryProvider})
      : _directoryProvider = directoryProvider;

  factory SettingsController.appDefault() =>
      SettingsController(directoryProvider: getApplicationSupportDirectory);

  static const String fileName = 'metincep_settings.json';

  final Future<Directory> Function() _directoryProvider;
  ThemeMode _themeMode = ThemeMode.system;
  OcrMode _ocrMode = OcrMode.printed;

  ThemeMode get themeMode => _themeMode;

  /// Tanıma modu. Varsayılan basılı metindir (V1 davranışı).
  OcrMode get ocrMode => _ocrMode;

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        _themeMode = _parseThemeMode(decoded['themeMode']);
        _ocrMode = OcrMode.fromName(decoded['ocrMode']);
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Ayarlar okunamadı, varsayılanlar kullanılacak: $error');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    await _persist();
  }

  Future<void> setOcrMode(OcrMode mode) async {
    if (mode == _ocrMode) {
      return;
    }
    _ocrMode = mode;
    notifyListeners();
    await _persist();
  }

  /// Tüm ayarlar birlikte yazılır; tek alan güncellenirken diğeri kaybolmaz.
  Future<void> _persist() async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({'themeMode': _themeMode.name, 'ocrMode': _ocrMode.name}),
      );
    } catch (error) {
      debugPrint('Ayarlar kaydedilemedi: $error');
    }
  }

  Future<File> _file() async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  static ThemeMode _parseThemeMode(Object? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return ThemeMode.system;
  }
}
