import 'dart:math' as math;

import '../../models/ocr_table.dart';
import '../../models/table_grid_lines.dart';
import 'text_layout_formatter.dart';

/// Tablo algılanamadığında nedeni (kullanıcıya doğru mesajı göstermek için).
enum TableRejectionReason {
  /// Tablo bulundu.
  none,

  /// Koordinatlı kelime sayısı yetersiz.
  tooFewWords,

  /// En az iki satır oluşmadı.
  tooFewRows,

  /// En az iki kolon oluşmadı (ör. düz paragraf).
  tooFewColumns,

  /// Anlamsız derecede çok kolon çıktı (gürültü).
  tooManyColumns,

  /// Yapı bulundu ama güven eşiğin altında kaldı.
  lowConfidence,
}

/// Tablo algılama sonucu. Tablo yoksa da neden ve puan taşınır; böylece
/// kullanıcıya "tablo algılanamadı, metin olarak gösteriliyor" denebilir.
class TableDetectionResult {
  const TableDetectionResult({
    this.table,
    this.confidence = 0,
    this.reason = TableRejectionReason.none,
  });

  static const TableDetectionResult empty =
      TableDetectionResult(reason: TableRejectionReason.tooFewWords);

  final OcrTable? table;
  final double confidence;
  final TableRejectionReason reason;

  bool get isTable => table != null;

  /// Tabloya benziyordu ama eşiği geçemedi: kullanıcıyı bilgilendirmeye değer.
  bool get isNearMiss =>
      table == null &&
      reason == TableRejectionReason.lowConfidence &&
      confidence >= TableDetector.nearMissConfidence;
}

/// OCR kelime koordinatlarından (ve varsa tablo çizgilerinden) tablo çıkarır.
///
/// Boru hattı:
/// 1. KELİMELER — koordinatı olan tüm kelimeler toplanır, medyan yükseklik ölçülür.
/// 2. EĞİM — satırların eğimi (dy/dx) tahmin edilir. Telefonla eğik çekilmiş
///    fotoğrafta satırlar bu düzeltme olmadan parçalanır.
/// 3. SATIRLAR — kelimeler eğim düzeltilmiş dikey konuma göre gruplanır.
/// 4. KOLONLAR — **tüm satırlarda boş kalan dikey şeritler** kolon ayırıcı
///    sayılır. Bir hücrenin içindeki kelime boşluğu ("2500 TL") başka
///    satırlarda metinle kaplı olduğu için ayırıcı sayılmaz. Çizgi ipucu
///    varsa ve kelime geometrisiyle uyumluysa sınırlar çizgilerden alınır.
/// 5. HÜCRELER — satır önce segmentlere bölünür, segmentler kolona atanır.
///    Böylece tam genişlikteki başlık satırı parçalanmaz.
/// 6. GÜVEN — doluluk, tutarlılık, hizalama, kolon kullanımı, satır derinliği
///    ve (varsa) çizgi kanıtı birleştirilir.
/// 7. Eşiğin altındaysa **tablo döndürülmez**; metin akışı korunur.
class TableDetector {
  TableDetector._();

  /// Bu değerin altındaki güvende tablo kabul edilmez.
  static const double minConfidence = 0.6;

  /// Bu değerin üstündeki reddedilen yapılar kullanıcıya bildirilir
  /// ("tablo algılanamadı"), altındakiler sessizce yok sayılır (düz metin).
  static const double nearMissConfidence = 0.35;

  static const int minRows = 2;
  static const int minColumns = 2;

  /// Bundan fazla kolon gerçek tablo değil, gürültüdür.
  static const int maxColumns = 12;

  /// Aynı satır sayılmak için (eğim düzeltilmiş) dikey fark üst sınırı çarpanı.
  static const double rowToleranceFactor = 0.6;

  /// Kolon ayırıcı sayılmak için boşluğun asgari genişliği (medyan yükseklik çarpanı).
  /// Kelime arası boşluk ~0.3h, kolon arası boşluk ~1.5h olduğu için ayrışır.
  static const double separatorMinFactor = 0.7;

  /// Kelime aralıklarını köprülemek için her kelimeye eklenen dolgu.
  static const double separatorPadFactor = 0.10;

  /// Bir şeridi "boş" saymak için onu kaplayabilecek satır oranı.
  /// Tablonun üstündeki tek satırlık başlık kolonları yok etmesin.
  static const double coverageTolerance = 0.25;

  /// Kapsama histogramı kutu genişliği (medyan yükseklik çarpanı).
  static const double coverageBinFactor = 0.10;

  /// Taranan en büyük eğim (dy/dx). 0.12 ≈ 6.8°.
  static const double maxSlope = 0.12;
  static const int slopeSteps = 24;

  /// Eski çağrılar için kısa yol: tablo yoksa null döner.
  static OcrTable? detect(List<OcrLine> lines, {TableGridLines? gridLines}) =>
      analyze(lines, gridLines: gridLines).table;

  /// Tam sonuç: tablo + güven + reddetme nedeni.
  static TableDetectionResult analyze(
    List<OcrLine> lines, {
    TableGridLines? gridLines,
  }) {
    final words = <OcrWord>[];
    for (final line in lines) {
      for (final word in line.words) {
        if (word.text.trim().isNotEmpty && word.width > 0 && word.height > 0) {
          words.add(word);
        }
      }
    }
    if (words.length < minRows * minColumns) {
      return TableDetectionResult.empty;
    }

    final medianHeight = _median(words.map((word) => word.height).toList());
    if (medianHeight <= 0) {
      return TableDetectionResult.empty;
    }

    final slope = estimateSlope(words, medianHeight);
    final rowGroups = _groupIntoRows(words, medianHeight, slope);
    if (rowGroups.length < minRows) {
      return const TableDetectionResult(reason: TableRejectionReason.tooFewRows);
    }

    final xMin = words.map((word) => word.left).reduce(math.min);
    final xMax = words.map((word) => word.right).reduce(math.max);
    final coverage = _CoverageHistogram.build(rowGroups, medianHeight, xMin, xMax);

    var boundaries = const <double>[];
    double? lineScore;
    if (gridLines != null) {
      final fromLines = _boundariesFromLines(gridLines, coverage);
      if (fromLines.length >= minColumns - 1) {
        boundaries = fromLines;
        lineScore = _lineScore(gridLines, fromLines.length, rowGroups.length);
      }
    }
    if (boundaries.isEmpty) {
      boundaries = coverage.separatorCenters();
    }

    final columns = _columnsFromBoundaries(boundaries, xMin, xMax);
    if (columns.length < minColumns) {
      return const TableDetectionResult(reason: TableRejectionReason.tooFewColumns);
    }
    if (columns.length > maxColumns) {
      return const TableDetectionResult(reason: TableRejectionReason.tooManyColumns);
    }

    final rows = <OcrTableRow>[];
    for (final group in rowGroups) {
      rows.add(_buildRow(group, columns, medianHeight));
    }

    final confidence = _score(
      rows: rows,
      columnCount: columns.length,
      medianHeight: medianHeight,
      words: words,
      lineScore: lineScore,
    );

    if (confidence < minConfidence) {
      return TableDetectionResult(
        reason: TableRejectionReason.lowConfidence,
        confidence: confidence,
      );
    }

    return TableDetectionResult(
      table: OcrTable(
        rows: rows,
        confidence: confidence,
        hasHeader: _looksLikeHeader(rows),
      ),
      confidence: confidence,
    );
  }

  /// Satırların eğimini (dy/dx) tahmin eder.
  ///
  /// Kelime merkezleri farklı eğimler için yatay kovalara dağıtılır; satırlar
  /// düzeldiğinde kovalar yoğunlaşır ve kare toplamı büyür. Görüntü
  /// döndürülmez, yalnızca koordinatlar yeniden yorumlanır: bu yüzden hem
  /// hızlıdır hem de basılı OCR davranışını hiç etkilemez.
  static double estimateSlope(List<OcrWord> words, double medianHeight) {
    if (words.length < 6) {
      return 0;
    }
    final bucket = math.max(medianHeight * rowToleranceFactor, 0.001);
    var bestSlope = 0.0;
    var bestScore = -1.0;
    for (var step = -slopeSteps; step <= slopeSteps; step++) {
      final slope = maxSlope * step / slopeSteps;
      final counts = <int, int>{};
      for (final word in words) {
        final key = ((word.centerY - slope * word.centerX) / bucket).round();
        counts[key] = (counts[key] ?? 0) + 1;
      }
      var score = 0.0;
      for (final count in counts.values) {
        score += count * count;
      }
      if (score > bestScore) {
        bestScore = score;
        bestSlope = slope;
      }
    }
    return bestSlope;
  }

  static List<List<OcrWord>> _groupIntoRows(
    List<OcrWord> words,
    double medianHeight,
    double slope,
  ) {
    double key(OcrWord word) => word.centerY - slope * word.centerX;

    final sorted = List<OcrWord>.from(words)
      ..sort((a, b) => key(a).compareTo(key(b)));
    final tolerance = medianHeight * rowToleranceFactor;

    final groups = <List<OcrWord>>[];
    var current = <OcrWord>[sorted.first];
    var reference = key(sorted.first);

    for (final word in sorted.skip(1)) {
      if ((key(word) - reference).abs() <= tolerance) {
        current.add(word);
      } else {
        groups.add(current);
        current = <OcrWord>[word];
      }
      reference =
          current.map(key).reduce((a, b) => a + b) / current.length;
    }
    groups.add(current);
    return groups;
  }

  /// Çizgi ipuçlarından kolon sınırları. Yalnızca kelime geometrisinin de boş
  /// bıraktığı x konumları kabul edilir; uyumsuz çizgiler atılır.
  static List<double> _boundariesFromLines(
    TableGridLines? lines,
    _CoverageHistogram coverage,
  ) {
    if (lines == null || lines.vertical.length < 2) {
      return const [];
    }
    final accepted = <double>[];
    for (final x in lines.vertical) {
      if (x <= coverage.xMin || x >= coverage.xMax) {
        continue; // Tablonun dış kenarı: sınır değil.
      }
      if (coverage.isFreeAt(x)) {
        accepted.add(x);
      }
    }
    accepted.sort();
    return accepted;
  }

  static List<_Column> _columnsFromBoundaries(
    List<double> boundaries,
    double xMin,
    double xMax,
  ) {
    final edges = <double>[xMin - 1, ...boundaries, xMax + 1];
    final columns = <_Column>[];
    for (var index = 0; index < edges.length - 1; index++) {
      columns.add(_Column(edges[index], edges[index + 1]));
    }
    return columns;
  }

  /// Satırı segmentlere böler (boşluk >= eşik ise yeni segment) ve segmentleri
  /// en çok örtüştüğü kolona atar.
  static OcrTableRow _buildRow(
    List<OcrWord> rowWords,
    List<_Column> columns,
    double medianHeight,
  ) {
    final segments = _rowSegments(rowWords, medianHeight);
    final buckets = List<List<_Segment>>.generate(
      columns.length,
      (_) => <_Segment>[],
    );

    for (final segment in segments) {
      var bestIndex = 0;
      var bestOverlap = -double.infinity;
      for (var index = 0; index < columns.length; index++) {
        final overlap = math.min(segment.right, columns[index].end) -
            math.max(segment.left, columns[index].start);
        if (overlap > bestOverlap) {
          bestOverlap = overlap;
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
          text: bucket.map((segment) => segment.text).join(' ').trim(),
          left: bucket.map((segment) => segment.left).reduce(math.min),
          right: bucket.map((segment) => segment.right).reduce(math.max),
          top: bucket.map((segment) => segment.top).reduce(math.min),
          bottom: bucket.map((segment) => segment.bottom).reduce(math.max),
        ),
      );
    }
    return OcrTableRow(cells);
  }

  static List<_Segment> _rowSegments(List<OcrWord> rowWords, double medianHeight) {
    final sorted = List<OcrWord>.from(rowWords)
      ..sort((a, b) => a.left.compareTo(b.left));
    final limit = medianHeight * separatorMinFactor;

    final segments = <_Segment>[];
    var parts = <OcrWord>[sorted.first];

    void flush() => segments.add(_Segment.fromWords(parts));

    for (final word in sorted.skip(1)) {
      if (word.left - parts.last.right >= limit) {
        flush();
        parts = <OcrWord>[word];
      } else {
        parts.add(word);
      }
    }
    flush();
    return segments;
  }

  /// Çizgi kanıtı puanı: çizgi sayısı beklenen ızgaraya ne kadar uyuyor.
  static double _lineScore(
    TableGridLines lines,
    int acceptedBoundaries,
    int rowCount,
  ) {
    final columnFit = lines.vertical.isEmpty
        ? 0.0
        : (acceptedBoundaries / lines.vertical.length).clamp(0.0, 1.0);
    // Izgara tablosunda yatay çizgi sayısı satır sayısı civarındadır.
    final rowFit = lines.horizontal.isEmpty
        ? 0.0
        : (lines.horizontal.length / (rowCount + 1)).clamp(0.0, 1.0);
    return (columnFit * 0.6) + (rowFit * 0.4);
  }

  /// Güven puanı. Ağırlıklar: doluluk, satır tutarlılığı, hizalama,
  /// kolon kullanımı, satır derinliği. Çizgi kanıtı varsa puana katılır.
  static double _score({
    required List<OcrTableRow> rows,
    required int columnCount,
    required double medianHeight,
    required List<OcrWord> words,
    double? lineScore,
  }) {
    if (rows.isEmpty || columnCount < minColumns) {
      return 0;
    }

    final rowCount = rows.length;
    final totalCells = rowCount * columnCount;
    var filled = 0;
    var consistentRows = 0;
    final columnUsage = List<int>.filled(columnCount, 0);

    for (final row in rows) {
      var rowFilled = 0;
      for (var index = 0; index < row.cells.length && index < columnCount; index++) {
        if (!row.cells[index].isEmpty) {
          filled++;
          rowFilled++;
          columnUsage[index]++;
        }
      }
      if (rowFilled >= minColumns) {
        consistentRows++;
      }
    }

    final fillRatio = filled / totalCells;
    final consistency = consistentRows / rowCount;
    final requiredUsage = math.max(2, (rowCount * 0.6).ceil());
    final usedColumns =
        columnUsage.where((count) => count >= requiredUsage).length;
    final columnRatio = usedColumns / columnCount;
    final rowDepth = math.min(1.0, (rowCount - 1) / 3.0);
    final alignment = _alignmentScore(rows, columnCount, medianHeight);

    var score = (fillRatio * 0.30) +
        (consistency * 0.25) +
        (alignment * 0.20) +
        (columnRatio * 0.15) +
        (rowDepth * 0.10);

    if (lineScore != null) {
      // Çizgi kanıtı puanı YALNIZCA yukarı çeker. Kenarlıklı bir tabloda
      // çizgiler sınırları doğruladığı için güven artar; çizgi bulunmuş olması
      // hiçbir durumda geometriden gelen puanı düşürmez.
      score = score + (1 - score) * lineScore * 0.5;
    }

    final ocrConfidence = _averageConfidence(words);
    if (ocrConfidence != null) {
      // OCR güveni puanı en fazla %15 aşağı çeker; tek başına baskın olmaz.
      score *= 0.85 + 0.15 * ocrConfidence.clamp(0.0, 1.0);
    }
    return score.clamp(0.0, 1.0);
  }

  /// Her kolonda hücre sol kenarlarının ne kadar dar dağıldığı (0..1).
  static double _alignmentScore(
    List<OcrTableRow> rows,
    int columnCount,
    double medianHeight,
  ) {
    final scores = <double>[];
    for (var column = 0; column < columnCount; column++) {
      final lefts = <double>[];
      for (final row in rows) {
        if (column < row.cells.length && !row.cells[column].isEmpty) {
          lefts.add(row.cells[column].left);
        }
      }
      if (lefts.length < 2) {
        continue;
      }
      final spread =
          (lefts.reduce(math.max) - lefts.reduce(math.min)) / medianHeight;
      scores.add(math.max(0.0, 1.0 - spread / 3.0));
    }
    if (scores.isEmpty) {
      return 0;
    }
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  static double? _averageConfidence(List<OcrWord> words) {
    final values = words
        .map((word) => word.confidence)
        .whereType<double>()
        .toList(growable: false);
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((a, b) => a + b) / values.length;
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
    if (first.cells.any((cell) => _containsDigit(cell.text))) {
      return false;
    }
    return rows
        .skip(1)
        .any((row) => row.cells.any((cell) => _containsDigit(cell.text)));
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

/// Kolon aralığı (x başlangıç/bitiş).
class _Column {
  const _Column(this.start, this.end);

  final double start;
  final double end;
}

/// Bir satır içindeki hücre adayı (bitişik kelimeler).
class _Segment {
  const _Segment({
    required this.text,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  factory _Segment.fromWords(List<OcrWord> words) {
    final sorted = List<OcrWord>.from(words)
      ..sort((a, b) => a.left.compareTo(b.left));
    return _Segment(
      text: sorted.map((word) => word.text.trim()).join(' ').trim(),
      left: sorted.map((word) => word.left).reduce(math.min),
      right: sorted.map((word) => word.right).reduce(math.max),
      top: sorted.map((word) => word.top).reduce(math.min),
      bottom: sorted.map((word) => word.bottom).reduce(math.max),
    );
  }

  final String text;
  final double left;
  final double right;
  final double top;
  final double bottom;
}

/// "Her x konumunu kaç satırın metni kaplıyor" histogramı.
/// Kolon ayırıcılar bu histogramın boş şeritleridir.
class _CoverageHistogram {
  _CoverageHistogram._({
    required this.counts,
    required this.binWidth,
    required this.xMin,
    required this.xMax,
    required this.maxFreeCount,
    required this.minSeparatorWidth,
    required this.pad,
  });

  factory _CoverageHistogram.build(
    List<List<OcrWord>> rows,
    double medianHeight,
    double xMin,
    double xMax,
  ) {
    final pad = medianHeight * TableDetector.separatorPadFactor;
    // Kutu genişliği hem medyan yüksekliğe hem de tablo genişliğine bağlıdır:
    // bozuk (çok küçük) yükseklikte bile kutu sayısı 4000'i geçmez.
    final binWidth = math.max(
      medianHeight * TableDetector.coverageBinFactor,
      math.max((xMax - xMin) / 4000, 0.001),
    );
    final binCount = math.max(1, ((xMax - xMin) / binWidth).floor() + 1);
    final counts = List<int>.filled(binCount, 0);

    for (final row in rows) {
      final intervals = _mergedIntervals(row, pad);
      for (final interval in intervals) {
        final from = math.max(0, ((interval[0] - xMin) / binWidth).floor());
        final to = math.min(binCount - 1, ((interval[1] - xMin) / binWidth).floor());
        for (var index = from; index <= to; index++) {
          counts[index]++;
        }
      }
    }

    return _CoverageHistogram._(
      counts: counts,
      binWidth: binWidth,
      xMin: xMin,
      xMax: xMax,
      maxFreeCount: (rows.length * TableDetector.coverageTolerance).floor(),
      minSeparatorWidth: medianHeight * TableDetector.separatorMinFactor,
      pad: pad,
    );
  }

  final List<int> counts;
  final double binWidth;
  final double xMin;
  final double xMax;
  final int maxFreeCount;
  final double minSeparatorWidth;
  final double pad;

  static List<List<double>> _mergedIntervals(List<OcrWord> row, double pad) {
    final intervals = row
        .map((word) => <double>[word.left - pad, word.right + pad])
        .toList()
      ..sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<double>>[];
    for (final interval in intervals) {
      if (merged.isNotEmpty && interval[0] <= merged.last[1]) {
        merged.last[1] = math.max(merged.last[1], interval[1]);
      } else {
        merged.add(<double>[interval[0], interval[1]]);
      }
    }
    return merged;
  }

  /// Verilen x konumu boş şeritte mi (çizgi ipucu doğrulaması için).
  bool isFreeAt(double x) {
    final index = ((x - xMin) / binWidth).floor();
    if (index < 0 || index >= counts.length) {
      return false;
    }
    return counts[index] <= maxFreeCount;
  }

  /// Yeterince geniş boş şeritlerin orta noktaları = kolon sınırları.
  List<double> separatorCenters() {
    final centers = <double>[];
    int? start;
    for (var index = 0; index < counts.length; index++) {
      if (counts[index] <= maxFreeCount) {
        start ??= index;
        continue;
      }
      if (start != null) {
        _addSeparator(centers, start, index - 1);
        start = null;
      }
    }
    if (start != null) {
      _addSeparator(centers, start, counts.length - 1);
    }
    return centers;
  }

  void _addSeparator(List<double> centers, int from, int to) {
    if (from == 0 || to == counts.length - 1) {
      return; // Tablonun solu/sağı: ayırıcı değil.
    }
    final left = xMin + from * binWidth;
    final right = xMin + (to + 1) * binWidth;
    // Dolgu geri eklenir: gerçek boşluk genişliği.
    if ((right - left) + 2 * pad >= minSeparatorWidth) {
      centers.add((left + right) / 2);
    }
  }
}
