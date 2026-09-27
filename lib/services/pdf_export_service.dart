import 'dart:io';
import 'dart:math' as math;

// Uint8List ve ByteData, flutter/foundation üzerinden gelir (dart:typed_data gereksiz).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/date_formatter.dart';
import '../core/utils/file_name_utils.dart';
import '../models/ocr_table.dart';

/// PDF için yazı tipini yükleyen fonksiyon. Testlerde dosyadan okunur.
typedef PdfFontLoader = Future<ByteData> Function();

/// Oluşturulmuş PDF'in baytları.
///
/// Takma ad olarak tanımlanır: böylece yalnızca `flutter/material.dart` içe
/// alan arayüz dosyaları (ör. akışlar) `Uint8List` adını kullanmak için ayrıca
/// `dart:typed_data` içe almak zorunda kalmaz.
typedef PdfBytes = Uint8List;

/// Metin, fotoğraf ve tabloları PDF'e dönüştürür. Tamamen çevrimdışıdır:
/// yazı tipi uygulamanın içinde gömülüdür, hiçbir ağ isteği yapılmaz.
///
/// Bu servis Free/Pro kurallarını bilmez; kota kontrolü çağıran akıştadır.
class PdfExportService {
  PdfExportService({
    PdfFontLoader? fontLoader,
    Future<Directory> Function()? temporaryDirectoryProvider,
  })  : _fontLoader = fontLoader ?? _assetFontLoader,
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory;

  final PdfFontLoader _fontLoader;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  pw.Font? _font;

  static Future<ByteData> _assetFontLoader() =>
      rootBundle.load(AppConstants.pdfFontAsset);

  /// Türkçe karakterleri içeren gömülü yazı tipi. Bir kez yüklenir.
  Future<pw.ThemeData> _theme() async {
    final font = _font ??= pw.Font.ttf(await _fontLoader());
    // Kalın varyant gömülmedi (APK boyutu); başlıklar arka planla ayrışır.
    return pw.ThemeData.withFont(base: font, bold: font, italic: font);
  }

  /// Düzenlenmiş metni A4 PDF'e aktarır. Uzun metin otomatik sayfalanır.
  Future<PdfBytes> buildTextPdf({required String title, required String text}) async {
    final content = text.trim();
    if (content.isEmpty) {
      throw const AppException(ErrorMessages.pdfEmptyContent);
    }

    final theme = await _theme();
    final document = pw.Document(theme: theme, title: _documentTitle(title));

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        maxPages: AppConstants.pdfMaxPages,
        header: (context) => _header(context, title),
        footer: _footer,
        build: (context) => _textWidgets(content),
      ),
    );

    return document.save();
  }

  /// Algılanan tabloyu gerçek PDF tablosu olarak aktarır.
  /// Geniş tablolar yatay sayfaya, uzun tablolar birden fazla sayfaya basılır;
  /// başlık satırı her yeni sayfada tekrarlanır.
  Future<PdfBytes> buildTablePdf({
    required String title,
    required OcrTable table,
    String? trailingText,
  }) async {
    if (table.rowCount == 0 || table.columnCount == 0) {
      throw const AppException(ErrorMessages.pdfEmptyContent);
    }

    final theme = await _theme();
    final document = pw.Document(theme: theme, title: _documentTitle(title));
    final landscape = table.columnCount >= AppConstants.pdfTableLandscapeColumnCount;

    document.addPage(
      pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        theme: theme,
        maxPages: AppConstants.pdfMaxPages,
        header: (context) => _header(context, title),
        footer: _footer,
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: table.headerValues,
            data: table.bodyValues,
            headerCount: table.hasHeader ? 1 : 0,
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: const pw.TextStyle(fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.topLeft,
            cellPadding: const pw.EdgeInsets.all(4),
          ),
          if (trailingText != null && trailingText.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            ..._textWidgets(trailingText.trim()),
          ],
        ],
      ),
    );

    return document.save();
  }

  /// Bir veya birden fazla fotoğrafı tek PDF'e aktarır: her fotoğraf bir sayfa.
  /// Sıra, en boy oranı ve EXIF yönü korunur; dikey/yatay sayfa otomatik seçilir.
  Future<PdfBytes> buildImagesPdf({
    required List<String> imagePaths,
    String title = AppConstants.appName,
  }) async {
    if (imagePaths.isEmpty) {
      throw const AppException(ErrorMessages.pdfEmptyContent);
    }

    final document = pw.Document(title: _documentTitle(title));
    var added = 0;

    for (final path in imagePaths) {
      // Fotoğraflar tek tek işlenir: hepsi aynı anda RAM'e alınmaz.
      final prepared = await compute(prepareImageForPdf, path);
      if (prepared == null) {
        debugPrint('PDF için fotoğraf hazırlanamadı: $path');
        continue;
      }
      final provider = pw.MemoryImage(prepared.bytes);
      final isLandscape = prepared.width > prepared.height;
      document.addPage(
        pw.Page(
          pageFormat: isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Image(provider, fit: pw.BoxFit.contain),
          ),
        ),
      );
      added++;
    }

    if (added == 0) {
      throw const AppException(ErrorMessages.pdfImageReadFailed);
    }
    return document.save();
  }

  /// PDF'i geçici klasöre yazar (paylaşım için). Yarım dosya bırakmaz.
  Future<File> writeTemporaryFile(PdfBytes bytes, {required String fileName}) async {
    final directory = await _temporaryDirectoryProvider();
    final safeName = FileNameUtils.sanitize(fileName);
    final file = File('${directory.path}${Platform.pathSeparator}$safeName.pdf');
    try {
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (error) {
      debugPrint('Geçici PDF yazılamadı: $error');
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Temizlik hatası yutulur; asıl hata aşağıda bildirilir.
      }
      throw const AppException(ErrorMessages.pdfCreateFailed);
    }
  }

  /// Varsayılan dosya adı: "Fatura 12 - 11.09.2026"
  static String suggestedFileName(String title) {
    final base = title.trim().isEmpty ? AppConstants.appName : title.trim();
    return FileNameUtils.sanitize('$base ${DateFormatter.short(DateTime.now())}');
  }

  String _documentTitle(String title) =>
      title.trim().isEmpty ? AppConstants.appName : title.trim();

  pw.Widget _header(pw.Context context, String title) {
    final trimmed = title.trim();
    if (context.pageNumber > 1 || trimmed.isEmpty) {
      return pw.SizedBox(height: 0);
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Text(
        trimmed,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _footer(pw.Context context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      );

  /// Metni satır satır widget'lara çevirir.
  /// Her satır ayrı widget olduğu için sayfalama doğaldır: taşma ve boş sayfa oluşmaz.
  List<pw.Widget> _textWidgets(String text) {
    final widgets = <pw.Widget>[];
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            line,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
          ),
        ),
      );
    }
    return widgets;
  }
}

/// Isolate'e gönderilen/dönen hazır görüntü (yalnızca ilkel alanlar taşır).
class PreparedPdfImage {
  const PreparedPdfImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Fotoğrafı PDF'e uygun hale getirir: EXIF yönü uygulanır, boyut küçültülür.
/// Üst düzey fonksiyondur; `compute` ile arka planda çalışır.
PreparedPdfImage? prepareImageForPdf(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    return null;
  }

  var image = img.bakeOrientation(decoded);
  final longest = math.max(image.width, image.height);
  if (longest > AppConstants.pdfImageMaxDimension) {
    final scale = AppConstants.pdfImageMaxDimension / longest;
    image = img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  return PreparedPdfImage(
    bytes: img.encodeJpg(image, quality: AppConstants.pdfImageQuality),
    width: image.width,
    height: image.height,
  );
}
