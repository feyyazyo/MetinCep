import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/file_name_utils.dart';

enum TxtSaveOutcome { saved, cancelled }

/// Kopyalama, paylaşma ve TXT dosyası kaydetme.
class ShareService {
  Future<void> copyToClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  /// Android paylaşım menüsünü açar (WhatsApp, Telegram, E-posta vb.).
  Future<void> shareText(String text, {String? title}) async {
    if (text.length > AppConstants.shareAsFileThreshold) {
      await shareTextFile(text, fileName: title ?? AppConstants.appName);
      return;
    }
    await SharePlus.instance.share(ShareParams(text: text, subject: title));
  }

  Future<void> shareTextFile(String text, {required String fileName}) async {
    final safeName = FileNameUtils.sanitize(fileName);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$safeName.txt');
    await file.writeAsString(text, encoding: utf8, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain')],
        subject: safeName,
      ),
    );
  }

  /// Android "Farklı kaydet" ekranını açar; kullanıcı konumu seçer (ör. İndirilenler).
  /// Depolama izni gerekmez.
  Future<TxtSaveOutcome> saveAsTxt(String text, {required String fileName}) async {
    final safeName = FileNameUtils.sanitize(fileName);
    final bytes = Uint8List.fromList(utf8.encode(text));
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'TXT olarak kaydet',
      fileName: '$safeName.txt',
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      bytes: bytes,
    );
    return savedPath == null ? TxtSaveOutcome.cancelled : TxtSaveOutcome.saved;
  }
}
