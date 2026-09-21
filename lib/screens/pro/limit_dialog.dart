import 'package:flutter/material.dart';

/// Kullanıcının sınır penceresindeki seçimi.
enum LimitChoice {
  cancel,
  viewPro,

  /// Sınır içinde devam et (ör. "İlk 10 sayfayı işle").
  continueWithinLimit,
}

/// Sınır penceresi metinleri. Sayılar her zaman çağıranın verdiği plan
/// değerlerinden gelir; burada sabit sayı yazılmaz.
class LimitPrompt {
  const LimitPrompt({required this.title, required this.message, this.continueLabel});

  factory LimitPrompt.dailyOcr() => const LimitPrompt(
        title: 'Günlük OCR limitin doldu.',
        message: 'Pro ile sınırsız OCR kullanabilirsin. Free hakların yarın yenilenir.',
      );

  factory LimitPrompt.dailyPdf() => const LimitPrompt(
        title: 'Günlük PDF limitin doldu.',
        message: 'Pro ile sınırsız PDF işleyebilirsin. Free hakların yarın yenilenir.',
      );

  factory LimitPrompt.pdfPages({required int pageCount, required int maxPages}) => LimitPrompt(
        title: 'Bu PDF $pageCount sayfa.',
        message: "Free sürümde tek PDF'te en fazla $maxPages sayfa işlenir. "
            'Pro ile tüm sayfaları işleyebilirsin.',
        continueLabel: 'İlk $maxPages sayfayı işle',
      );

  factory LimitPrompt.batch({required int selectedCount, required int maxImages}) => LimitPrompt(
        title: '$selectedCount fotoğraf seçtin.',
        message: 'Free sürümde tek seferde en fazla $maxImages fotoğraf işlenir. '
            'Pro ile toplu OCR sınırsızdır.',
        continueLabel: 'İlk $maxImages fotoğrafı işle',
      );

  factory LimitPrompt.pdfFileSize({required int sizeBytes, required int maxBytes}) => LimitPrompt(
        title: 'Bu PDF çok büyük (${formatMegabytes(sizeBytes)}).',
        message: 'Free sürümde en fazla ${formatMegabytes(maxBytes)} boyutunda PDF işlenir. '
            'Pro ile daha büyük dosyaları işleyebilirsin.',
      );

  final String title;
  final String message;

  /// null ise yalnızca "İptal" ve "Pro'yu İncele" gösterilir.
  final String? continueLabel;

  /// 26214400 -> "25 MB", 1572864 -> "1,5 MB"
  static String formatMegabytes(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    final rounded = (megabytes * 10).round() / 10;
    final text = rounded == rounded.truncateToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1).replaceAll('.', ',');
    return '$text MB';
  }
}

Future<LimitChoice> showLimitDialog(BuildContext context, LimitPrompt prompt) async {
  final choice = await showDialog<LimitChoice>(
    context: context,
    builder: (dialogContext) {
      final navigator = Navigator.of(dialogContext);
      final continueLabel = prompt.continueLabel;
      return AlertDialog(
        icon: const Icon(Icons.workspace_premium_outlined),
        title: Text(prompt.title, textAlign: TextAlign.center),
        content: Text(prompt.message, textAlign: TextAlign.center),
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(
            onPressed: () => navigator.pop(LimitChoice.cancel),
            child: const Text('İptal'),
          ),
          if (continueLabel != null)
            TextButton(
              onPressed: () => navigator.pop(LimitChoice.continueWithinLimit),
              child: Text(continueLabel),
            ),
          FilledButton(
            onPressed: () => navigator.pop(LimitChoice.viewPro),
            child: const Text("Pro'yu İncele"),
          ),
        ],
      );
    },
  );
  // Dışarı dokunma veya geri tuşu = İptal.
  return choice ?? LimitChoice.cancel;
}
