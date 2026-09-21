import 'dart:math' as math;

import '../constants/app_constants.dart';

/// PDF sayfasının OCR için hangi piksel boyutunda çizileceğini hesaplar.
/// Hem OCR doğruluğunu (yeterli çözünürlük) hem RAM'i (üst sınır) gözetir.
class PdfRenderSizing {
  PdfRenderSizing._();

  static ({int width, int height}) forPage(double pageWidth, double pageHeight) {
    // PDF birimi: 1/72 inç. Geçersiz boyutta A4 varsayılır.
    final width = pageWidth > 0 ? pageWidth : 595.0;
    final height = pageHeight > 0 ? pageHeight : 842.0;
    final longestSide = math.max(width, height);

    var scale = AppConstants.pdfRenderDpi / 72.0;
    final scaledLongest = longestSide * scale;
    if (scaledLongest > AppConstants.pdfRenderMaxDimension) {
      scale = AppConstants.pdfRenderMaxDimension / longestSide;
    } else if (scaledLongest < AppConstants.pdfRenderMinDimension) {
      scale = AppConstants.pdfRenderMinDimension / longestSide;
    }

    return (
      width: math.max(1, (width * scale).round()),
      height: math.max(1, (height * scale).round()),
    );
  }
}
