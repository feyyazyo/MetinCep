import 'dart:math' as math;

import '../../models/ocr_table.dart';
import 'text_layout_formatter.dart';

/// OCR kelime koordinatlarından tablo yapısı çıkarır.
///
/// Algoritma:
/// 1. Kelimeler dikey merkezlerine göre satırlara gruplanır.
/// 2. Her satırdaki kelimeler yatay konuma göre sıralanır.
/// 3. Tüm kelimelerin sol kenarları kümelenerek kolon adayları bulunur.
/// 4. Kelimeler en yakın kolona yerleştirilir, aynı hücredekiler birleştirilir.
/// 5. Doluluk ve kolon tutarlılığından güven puanı hesaplanır.
/// 6. Güven [minConfidence] altındaysa **tablo döndürülmez** (null) ve uygulama
///    düz metne geri döner. Yanlış algılama veri kaybına yol açmamalıdır.
///
/// Tablo çizgileri (yatay/dikey çizgiler) bu sürümde kullanılmaz; ML Kit çizgi
/// bilgisi vermediği için sahte çizgi üretmek yerine hizalama esas alınır.
class TableDetector {
  TableDetector._();

  /// Bu değerin altındaki güvende tablo kabul edilmez.
  static const double minConfidence = 0.6;

  static const int minRows = 2;
  static const int minColumns = 2;

  /// Aynı satır sayılmak için dikey merkez farkı, ortalama yüksekliğin bu katından küçük olmalı.
  static const double rowToleranceFactor = 0.7;

  /// Kolon kümelemesinde iki sol kenarın aynı kolon sayılması için üst sınır çarpanı.
  static const double columnToleranceFactor = 1.6;

  /// Aynı hücre sayılmak için iki kelime arasındaki yatay boşluk üst sınırı çarpanı.
  /// ("2500" ve "TL" tek hücredir; kolonlar arası boşluk bundan büyüktür.)
  static const double wordGapFactor = 1.2;

  /// Tablo bulunamazsa null döner.
  static OcrTable? detect(List<OcrLine> lines) {
    final words = <OcrWord>[];
    for (final line in lines) {
      for (final word in line.words) {
        if (word.text.trim().isNotEmpty && word.width > 0) {
          words.add(word);
        }
      }
    }
    if (words.length < minRows * minColumns) {
      return null;
    }

    final medianHeight = _median(words.map((word) => word.height).toList());
    if (medianHeight <= 0) {
      return null;
    }

    final rowGroups = _groupIntoRows(words, medianHeight);
    if (rowGroups.length < minRows) {
      return null;
    }

    // Kolon kümelemesi hücre adayları üzerinden yapılır: "2500 TL" tek hücredir.
    final rowSegments =
        rowGroups.map((group) => _mergeIntoSegments(group, medianHeight)).toList();

    final columnStarts = _detectColumnStarts(
      rowSegments.expand((segments) => segments).toList(),
      medianHeight,
    );
    if (columnStarts.length < minColumns) {
      return null;
    }

    final rows = <OcrTableRow>[];
    for (final segments in rowSegments) {
      rows.add(_buildRow(segments, columnStarts));
    }

    final confidence = _score(rows, columnStarts.length);
    if (confidence < minConfidence) {
      return null;
    }

    return OcrTable(
      rows: rows,
      confidence: confidence,
      hasHeader: _looksLikeHeader(rows),
    );
  }

  static List<List<OcrWord>> _groupIntoRows(List<OcrWord> words, double medianHeight) {
    final sorted = List<OcrWord>.from(words)
      ..sort((a, b) => a.centerY.compareTo(b.centerY));
    final tolerance = medianHeight * rowToleranceFactor;

    final groups = <List<OcrWord>>[];
    var current = <OcrWord>[sorted.first];
    var reference = sorted.first.centerY;

    for (final word in sorted.skip(1)) {
      if ((word.centerY - reference).abs() <= tolerance) {
        current.add(word);
      } else {
        groups.add(current);
        current = <OcrWord>[word];
      }
      // Referans, gruptaki kelimelerin ortalaması: hafif kayan satırlar birlikte kalır.
      reference = current.map((w) => w.centerY).reduce((a, b) => a + b) / current.length;
    }
    groups.add(current);
    return groups;
  }

  /// Bir satırdaki kelimeleri, aralarındaki boşluk küçükse tek hücre adayında birleştirir.
  static List<OcrTableCell> _mergeIntoSegments(
    List<OcrWord> rowWords,
    double medianHeight,
  ) {
    final sorted = List<OcrWord>.from(rowWords)
      ..sort((a, b) => a.left.compareTo(b.left));
    final maxGap = medianHeight * wordGapFactor;

    final segments = <OcrTableCell>[];
    var parts = <OcrWord>[sorted.first];

    void flush() {
      segments.add(
        OcrTableCell(
          text: parts.map((word) => word.text.trim()).join(' ').trim(),
          left: parts.map((word) => word.left).reduce(math.min),
          right: parts.map((word) => word.right).reduce(math.max),
          top: parts.map((word) => word.top).reduce(math.min),
          bottom: parts.map((word) => word.bottom).reduce(math.max),
        ),
      );
    }

    for (final word in sorted.skip(1)) {
      final gap = word.left - parts.last.right;
      if (gap <= maxGap) {
        parts.add(word);
      } else {
        flush();
        parts = <OcrWord>[word];
      }
    }
    flush();
    return segments;
  }

  static List<double> _detectColumnStarts(
    List<OcrTableCell> segments,
    double medianHeight,
  ) {
    final lefts = segments.map((segment) => segment.left).toList()..sort();
    final tolerance = medianHeight * columnToleranceFactor;

    final starts = <double>[];
    var clusterStart = lefts.first;
    var clusterSum = lefts.first;
    var clusterCount = 1;

    for (final left in lefts.skip(1)) {
      if (left - clusterStart <= tolerance) {
        clusterSum += left;
        clusterCount++;
      } else {
        starts.add(clusterSum / clusterCount);
        clusterStart = left;
        clusterSum = left;
        clusterCount = 1;
      }
    }
    starts.add(clusterSum / clusterCount);
    return starts;
  }

  static OcrTableRow _buildRow(
    List<OcrTableCell> segments,
    List<double> columnStarts,
  ) {
    final buckets =
        List<List<OcrTableCell>>.generate(columnStarts.length, (_) => <OcrTableCell>[]);
    for (final segment in segments) {
      var bestIndex = 0;
      var bestDistance = double.infinity;
      for (var index = 0; index < columnStarts.length; index++) {
        final distance = (segment.left - columnStarts[index]).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = index;
        }
      }
      buckets[bestIndex].add(segment);
    }

    final cells = <OcrTableCell>[];
    for (final bucket in buckets) {
      if (bucket.isEmpty) {
        cells.add(const OcrTableCell(text: ''));
        continue;
      }
      bucket.sort((a, b) => a.left.compareTo(b.left));
      cells.add(
        OcrTableCell(
          text: bucket.map((cell) => cell.text.trim()).join(' ').trim(),
          left: bucket.map((cell) => cell.left).reduce(math.min),
          right: bucket.map((cell) => cell.right).reduce(math.max),
          top: bucket.map((cell) => cell.top).reduce(math.min),
          bottom: bucket.map((cell) => cell.bottom).reduce(math.max),
        ),
      );
    }
    return OcrTableRow(cells);
  }

  /// Doluluk + satır tutarlılığı + kolon kullanımı.
  static double _score(List<OcrTableRow> rows, int columnCount) {
    if (rows.isEmpty || columnCount < minColumns) {
      return 0;
    }

    final totalCells = rows.length * columnCount;
    var filled = 0;
    var rowsWithEnoughCells = 0;
    final columnUsage = List<int>.filled(columnCount, 0);

    for (final row in rows) {
      var rowFilled = 0;
      for (var index = 0; index < row.cells.length; index++) {
        if (!row.cells[index].isEmpty) {
          filled++;
          rowFilled++;
          columnUsage[index]++;
        }
      }
      if (rowFilled >= minColumns) {
        rowsWithEnoughCells++;
      }
    }

    final fillRatio = filled / totalCells;
    final consistency = rowsWithEnoughCells / rows.length;
    final usedColumns =
        columnUsage.where((count) => count >= (rows.length * 0.6)).length;
    final columnRatio = usedColumns / columnCount;

    return (fillRatio * 0.4) + (consistency * 0.3) + (columnRatio * 0.3);
  }

  /// İlk satır tamamen doluysa ve gövdedeki sayısal hücreleri içermiyorsa başlık sayılır.
  static bool _looksLikeHeader(List<OcrTableRow> rows) {
    if (rows.length < 2) {
      return false;
    }
    final first = rows.first;
    if (first.filledCellCount != first.cells.length) {
      return false;
    }
    final headerHasDigits = first.cells.any((cell) => _containsDigit(cell.text));
    if (headerHasDigits) {
      return false;
    }
    final bodyHasDigits = rows
        .skip(1)
        .any((row) => row.cells.any((cell) => _containsDigit(cell.text)));
    return bodyHasDigits;
  }

  static bool _containsDigit(String text) =>
      text.codeUnits.any((unit) => unit >= 0x30 && unit <= 0x39);

  static double _median(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
