import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/ocr_table.dart';
import '../pdf/pdf_export_flow.dart';

/// Tablo önizleme ekranından dönen sonuç.
class TablePreviewResult {
  const TablePreviewResult({required this.table, this.replaceTextWithTable = false});

  /// Kullanıcının düzenlemelerini içeren tablo.
  final OcrTable table;

  /// Kullanıcı "tabloyu metne dönüştür" dediyse true.
  final bool replaceTextWithTable;
}

/// Algılanan tabloyu gösterir ve hücrelerin düzenlenmesine izin verir.
///
/// Ana düzenleyici (sonuç ekranı) değişmez; tablo ayrı bir ekranda ele alınır.
/// Böylece tablo algılanmayan belgelerde arayüz aynen eskisi gibi kalır.
class TablePreviewScreen extends StatefulWidget {
  const TablePreviewScreen({super.key, required this.table, required this.title});

  final OcrTable table;
  final String title;

  @override
  State<TablePreviewScreen> createState() => _TablePreviewScreenState();
}

class _TablePreviewScreenState extends State<TablePreviewScreen> {
  late OcrTable _table;
  final List<List<TextEditingController>> _controllers = [];

  @override
  void initState() {
    super.initState();
    _table = widget.table;
    for (final row in _table.rows) {
      _controllers.add(
        row.cells.map((cell) => TextEditingController(text: cell.text)).toList(),
      );
    }
  }

  @override
  void dispose() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  /// Düzenlenen hücreleri tabloya yazar.
  OcrTable _collect() {
    var table = _table;
    for (var rowIndex = 0; rowIndex < _controllers.length; rowIndex++) {
      for (var columnIndex = 0;
          columnIndex < _controllers[rowIndex].length;
          columnIndex++) {
        table = table.copyWithCell(
          rowIndex,
          columnIndex,
          _controllers[rowIndex][columnIndex].text,
        );
      }
    }
    _table = table;
    return table;
  }

  void _close({bool replaceText = false}) {
    Navigator.of(context).pop(
      TablePreviewResult(table: _collect(), replaceTextWithTable: replaceText),
    );
  }

  Future<void> _exportPdf() async {
    final table = _collect();
    await PdfExportFlow.exportTable(context, title: widget.title, table: table);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columnCount = _table.columnCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Algılanan Tablo'),
        actions: [
          IconButton(
            tooltip: 'Tabloyu PDF yap',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_table.rowCount} satır × $columnCount kolon · '
                      'hücrelere dokunup düzeltebilirsin',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var rowIndex = 0; rowIndex < _controllers.length; rowIndex++)
                        Row(
                          children: [
                            for (var columnIndex = 0;
                                columnIndex < _controllers[rowIndex].length;
                                columnIndex++)
                              _Cell(
                                controller: _controllers[rowIndex][columnIndex],
                                isHeader: _table.hasHeader && rowIndex == 0,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _close(replaceText: true),
                      child: const Text('Metne dönüştür'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _close(),
                      child: const Text('Tamam'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.controller, required this.isHeader});

  final TextEditingController controller;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      decoration: ShapeDecoration(
        color: isHeader
            ? theme.colorScheme.secondaryContainer
            : AppTheme.cardColor(context),
        shape: AppTheme.cardShape(context, radius: 10),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        minLines: 1,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }
}
