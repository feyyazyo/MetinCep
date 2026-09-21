import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Basit ayarlar (şimdilik tema). Cihazda küçük bir JSON dosyasında saklanır.
class SettingsController extends ChangeNotifier {
  SettingsController({required Future<Directory> Function() directoryProvider})
      : _directoryProvider = directoryProvider;

  factory SettingsController.appDefault() =>
      SettingsController(directoryProvider: getApplicationSupportDirectory);

  static const String fileName = 'metincep_settings.json';

  final Future<Directory> Function() _directoryProvider;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        _themeMode = _parseThemeMode(decoded['themeMode']);
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
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'themeMode': mode.name}));
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
