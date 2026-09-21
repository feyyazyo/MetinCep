import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/document_model.dart';

/// Kaydedilen belgeleri cihazda tek bir JSON dosyasında tutar.
/// Hesap, sunucu veya bulut yoktur. İleride sqflite vb. ile değiştirilebilir.
class DocumentRepository extends ChangeNotifier {
  DocumentRepository({
    required Future<Directory> Function() directoryProvider,
    DateTime Function()? clock,
  })  : _directoryProvider = directoryProvider,
        _clock = clock ?? DateTime.now;

  factory DocumentRepository.appDefault() =>
      DocumentRepository(directoryProvider: getApplicationDocumentsDirectory);

  static const String fileName = 'metincep_documents.json';

  final Future<Directory> Function() _directoryProvider;
  final DateTime Function() _clock;
  final Random _random = Random();

  List<DocumentModel> _documents = const [];
  bool _isLoaded = false;
  Future<void> _pendingWrite = Future<void>.value();

  /// En son güncellenen belge en üstte.
  List<DocumentModel> get documents => List.unmodifiable(_documents);

  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final loaded = <DocumentModel>[];
    try {
      final file = await _file();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          final items = decoded is Map<String, dynamic> ? decoded['documents'] : decoded;
          if (items is List) {
            for (final item in items) {
              if (item is Map<String, dynamic>) {
                try {
                  loaded.add(DocumentModel.fromJson(item));
                } catch (error) {
                  debugPrint('Bozuk belge kaydı atlandı: $error');
                }
              }
            }
          }
        }
      }
    } catch (error) {
      debugPrint('Belgeler yüklenemedi, dosya yedeklenecek: $error');
      await _backupCorruptFile();
    }

    loaded.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _documents = loaded;
    _isLoaded = true;
    notifyListeners();
  }

  DocumentModel? findById(String id) {
    for (final document in _documents) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  /// [id] verilir ve belge varsa günceller; yoksa yeni belge oluşturur.
  Future<DocumentModel> save({
    String? id,
    required String title,
    required String text,
    DocumentSource source = DocumentSource.unknown,
  }) async {
    final now = _clock();
    final index = id == null ? -1 : _documents.indexWhere((d) => d.id == id);

    final DocumentModel saved;
    if (index >= 0) {
      saved = _documents[index].copyWith(title: title, text: text, updatedAt: now);
      _documents = [saved, ..._documents.where((d) => d.id != saved.id)];
    } else {
      saved = DocumentModel(
        id: _generateId(now),
        title: title,
        text: text,
        createdAt: now,
        updatedAt: now,
        source: source,
      );
      _documents = [saved, ..._documents];
    }

    notifyListeners();
    await _persist();
    return saved;
  }

  Future<void> delete(String id) async {
    _documents = _documents.where((document) => document.id != id).toList();
    notifyListeners();
    await _persist();
  }

  /// Ayarlar ekranındaki "Tüm belgeleri sil" için.
  Future<void> deleteAll() async {
    if (_documents.isEmpty) {
      return;
    }
    _documents = const [];
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      'version': 1,
      'documents': _documents.map((document) => document.toJson()).toList(),
    });
    // Yazmalar sıraya alınır; aynı anda iki yazma dosyayı bozamaz.
    final write = _pendingWrite.then((_) => _writeAtomically(snapshot));
    _pendingWrite = write.catchError((Object _) {});
    return write;
  }

  Future<void> _writeAtomically(String content) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(content, flush: true);
    await tempFile.rename(file.path);
  }

  Future<void> _backupCorruptFile() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        await file.rename('${file.path}.bozuk-${_clock().millisecondsSinceEpoch}');
      }
    } catch (error) {
      debugPrint('Bozuk dosya yedeklenemedi: $error');
    }
  }

  Future<File> _file() async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  String _generateId(DateTime now) {
    final timePart = now.microsecondsSinceEpoch.toRadixString(36);
    final randomPart = _random.nextInt(0x7fffffff).toRadixString(36);
    return '$timePart$randomPart';
  }
}
