/// OCR'dan çıkarılan tablonun yapısal modeli.
///
/// Tablo yalnızca güvenilir şekilde algılandığında oluşturulur; aksi halde
/// uygulama düz metne geri döner (bkz. TableDetector). Böylece yanlış algılama
/// veri kaybına yol açmaz.
class OcrTableCell {
  const OcrTableCell({
    required this.text,
    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,
  });

  final String text;
  final double left;
  final double right;
  final double top;
  final double bottom;

  bool get isEmpty => text.trim().isEmpty;

  OcrTableCell copyWith({String? text}) => OcrTableCell(
        text: text ?? this.text,
        left: left,
        right: right,
        top: top,
        bottom: bottom,
      );
}

class OcrTableRow {
  const OcrTableRow(this.cells);

  final List<OcrTableCell> cells;

  int get filledCellCount => cells.where((cell) => !cell.isEmpty).length;

  List<String> get values => cells.map((cell) => cell.text).toList();

  OcrTableRow copyWithCell(int columnIndex, String text) {
    if (columnIndex < 0 || columnIndex >= cells.length) {
      return this;
    }
    final updated = List<OcrTableCell>.from(cells);
    updated[columnIndex] = updated[columnIndex].copyWith(text: text);
    return OcrTableRow(updated);
  }
}

class OcrTable {
  const OcrTable({
    required this.rows,
    required this.confidence,
    this.hasHeader = false,
  });

  final List<OcrTableRow> rows;

  /// 0..1 arası algılama güveni. Eşiğin altındaki tablolar hiç oluşturulmaz.
  final double confidence;

  /// İlk satır başlık satırı mı? (PDF'te her sayfada tekrarlanır.)
  final bool hasHeader;

  int get rowCount => rows.length;

  int get columnCount => rows.isEmpty
      ? 0
      : rows.map((row) => row.cells.length).reduce((a, b) => a > b ? a : b);

  List<List<String>> get values => rows.map((row) => row.values).toList();

  List<String>? get headerValues => hasHeader && rows.isNotEmpty ? rows.first.values : null;

  List<List<String>> get bodyValues =>
      hasHeader && rows.isNotEmpty ? values.sublist(1) : values;

  OcrTable copyWithCell(int rowIndex, int columnIndex, String text) {
    if (rowIndex < 0 || rowIndex >= rows.length) {
      return this;
    }
    final updated = List<OcrTableRow>.from(rows);
    updated[rowIndex] = updated[rowIndex].copyWithCell(columnIndex, text);
    return OcrTable(rows: updated, confidence: confidence, hasHeader: hasHeader);
  }

  /// Tabloyu, kolonları boşlukla hizalanmış düz metne çevirir.
  /// Tablo PDF'i oluşturulamadığında ve "tabloyu metne dönüştür" seçeneğinde kullanılır.
  String toAlignedText({String columnSeparator = '  '}) {
    if (rows.isEmpty) {
      return '';
    }
    final widths = List<int>.filled(columnCount, 0);
    for (final row in rows) {
      for (var index = 0; index < row.cells.length; index++) {
        final length = row.cells[index].text.trim().length;
        if (length > widths[index]) {
          widths[index] = length;
        }
      }
    }

    final lines = <String>[];
    for (final row in rows) {
      final parts = <String>[];
      for (var index = 0; index < columnCount; index++) {
        final text = index < row.cells.length ? row.cells[index].text.trim() : '';
        // Son kolon doldurulmaz; satır sonunda gereksiz boşluk kalmasın.
        parts.add(index == columnCount - 1 ? text : text.padRight(widths[index]));
      }
      lines.add(parts.join(columnSeparator).trimRight());
    }
    return lines.join('\n');
  }
}
