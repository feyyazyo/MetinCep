import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/text_stats.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/document_model.dart';
import '../../models/extraction_models.dart';
import '../../services/share_service.dart';

/// OCR / PDF sonucunu veya kayıtlı bir belgeyi düzenleme ekranı.
class ResultScreen extends StatefulWidget {
  const ResultScreen._({
    super.key,
    required this.initialText,
    required this.source,
    this.suggestedTitle,
    this.extraction,
    this.document,
  });

  /// Yeni çıkarılmış (henüz kaydedilmemiş) metin.
  factory ResultScreen.fromExtraction({Key? key, required ExtractionResult result}) {
    return ResultScreen._(
      key: key,
      initialText: result.text,
      source: result.source,
      suggestedTitle: result.suggestedTitle,
      extraction: result,
    );
  }

  /// Geçmişten açılan kayıtlı belge.
  factory ResultScreen.fromDocument({Key? key, required DocumentModel document}) {
    return ResultScreen._(
      key: key,
      initialText: document.text,
      source: document.source,
      suggestedTitle: document.title,
      document: document,
    );
  }

  final String initialText;
  final DocumentSource source;
  final String? suggestedTitle;
  final ExtractionResult? extraction;
  final DocumentModel? document;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final TextEditingController _controller;
  final FocusNode _editorFocus = FocusNode();

  String? _documentId;
  String? _savedTitle;
  String _savedText = '';
  DateTime? _updatedAt;
  bool _busy = false;
  bool _saving = false;

  bool get _isSaved => _documentId != null;

  bool get _hasUnsavedChanges {
    final text = _controller.text;
    return _isSaved ? text != _savedText : text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    final document = widget.document;
    if (document != null) {
      _documentId = document.id;
      _savedTitle = document.title;
      _savedText = document.text;
      _updatedAt = document.updatedAt;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Eylemler
  // ---------------------------------------------------------------------------

  Future<void> _copy() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      showAppSnackBar(context, 'Kopyalanacak metin yok.');
      return;
    }
    try {
      await AppScope.of(context).share.copyToClipboard(text);
      if (mounted) {
        showAppSnackBar(context, 'Metin panoya kopyalandı.');
      }
    } catch (error) {
      debugPrint('Kopyalama hatası: $error');
      if (mounted) {
        showAppSnackBar(context, 'Metin kopyalanamadı.');
      }
    }
  }

  Future<void> _share() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      showAppSnackBar(context, 'Paylaşılacak metin yok.');
      return;
    }
    await _runBusy(() async {
      try {
        await AppScope.of(context).share.shareText(text, title: _titleForFiles());
      } catch (error) {
        debugPrint('Paylaşım hatası: $error');
        if (mounted) {
          showAppSnackBar(context, ErrorMessages.shareFailed);
        }
      }
    });
  }

  Future<void> _saveAsTxt() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      showAppSnackBar(context, 'Kaydedilecek metin yok.');
      return;
    }
    await _runBusy(() async {
      try {
        final outcome = await AppScope.of(context)
            .share
            .saveAsTxt(text, fileName: _titleForFiles());
        if (mounted && outcome == TxtSaveOutcome.saved) {
          showAppSnackBar(context, 'TXT dosyası kaydedildi.');
        }
      } catch (error) {
        debugPrint('TXT kaydetme hatası: $error');
        if (mounted) {
          showAppSnackBar(context, ErrorMessages.fileSaveFailed);
        }
      }
    });
  }

  void _clear() {
    final previous = _controller.value;
    if (previous.text.isEmpty) {
      return;
    }
    _controller.clear();
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Metin temizlendi.'),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () {
              if (mounted) {
                _controller.value = previous;
              }
            },
          ),
        ),
      );
  }

  Future<void> _save() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      showAppSnackBar(context, 'Kaydedilecek metin yok.');
      return;
    }

    var title = _savedTitle;
    if (!_isSaved) {
      title = await _askTitle(initialTitle: widget.suggestedTitle ?? '');
      if (title == null || !mounted) {
        return; // Kullanıcı vazgeçti.
      }
    }

    await _persist(
      title: title!,
      text: text,
      successMessage: _isSaved ? 'Değişiklikler kaydedildi.' : 'Belge kaydedildi.',
    );
  }

  Future<void> _rename() async {
    final currentTitle = _savedTitle;
    if (!_isSaved || currentTitle == null) {
      return;
    }
    final newTitle = await _askTitle(initialTitle: currentTitle, isRename: true);
    if (newTitle == null || newTitle == currentTitle || !mounted) {
      return;
    }
    // Yalnızca başlık değişir; kaydedilmemiş metin düzenlemeleri kaydedilmez.
    await _persist(
      title: newTitle,
      text: _savedText,
      successMessage: 'Belge adı değiştirildi.',
    );
  }

  Future<void> _persist({
    required String title,
    required String text,
    required String successMessage,
  }) async {
    await _runBusy(saving: true, () async {
      try {
        final saved = await AppScope.of(context).documents.save(
              id: _documentId,
              title: title,
              text: text,
              source: widget.source,
            );
        if (!mounted) {
          return;
        }
        setState(() {
          _documentId = saved.id;
          _savedTitle = saved.title;
          _savedText = saved.text;
          _updatedAt = saved.updatedAt;
        });
        showAppSnackBar(context, successMessage);
      } catch (error) {
        debugPrint('Kayıt hatası: $error');
        if (mounted) {
          showAppSnackBar(context, ErrorMessages.saveFailed);
        }
      }
    });
  }

  Future<void> _runBusy(Future<void> Function() action, {bool saving = false}) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _saving = saving;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  Future<String?> _askTitle({required String initialTitle, bool isRename = false}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _TitleDialog(initialTitle: initialTitle, isRename: isRename),
    );
  }

  String _titleForFiles() {
    final candidates = [_savedTitle, widget.suggestedTitle];
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'MetinCep_${DateFormatter.fileStamp(DateTime.now())}';
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop) {
      return;
    }
    final navigator = Navigator.of(context);
    if (!_hasUnsavedChanges) {
      navigator.pop();
      return;
    }
    final leave = await showConfirmDialog(
      context,
      title: 'Kaydedilmemiş değişiklikler',
      message: _isSaved
          ? 'Yaptığınız değişiklikler kaydedilmedi. Çıkmak istiyor musunuz?'
          : 'Bu metin henüz kaydedilmedi. Çıkarsanız metin kaybolur.',
      confirmLabel: 'Kaydetmeden çık',
      destructive: true,
    );
    if (leave && mounted) {
      navigator.pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Arayüz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final savedTitle = _savedTitle;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            savedTitle == null || savedTitle.trim().isEmpty
                ? 'Çıkarılan Metin'
                : savedTitle,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (keyboardVisible)
              TextButton(
                onPressed: () => _editorFocus.unfocus(),
                child: const Text('Bitti'),
              )
            else if (_isSaved)
              IconButton(
                tooltip: 'Adını değiştir',
                icon: const Icon(Icons.drive_file_rename_outline),
                onPressed: _busy ? null : _rename,
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _InfoLine(text: _infoText()),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Editor(controller: _controller, focusNode: _editorFocus),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                child: _StatsLine(controller: _controller),
              ),
              if (!keyboardVisible) _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  String _infoText() {
    final updatedAt = _updatedAt;
    final extraction = widget.extraction;

    if (extraction == null) {
      return updatedAt == null
          ? 'Metni düzenleyebilirsiniz.'
          : 'Son kayıt: ${DateFormatter.longWithTime(updatedAt)}';
    }

    final String origin;
    if (extraction.source == DocumentSource.pdf) {
      final pages = extraction.unitCount;
      final ocrPages = extraction.ocrUnitCount;
      final pageLabel = extraction.isPartial
          ? 'ilk $pages / ${extraction.sourcePageCount} sayfa'
          : '$pages sayfa';
      if (ocrPages == 0) {
        origin = 'PDF · $pageLabel · metin doğrudan okundu';
      } else if (ocrPages >= pages) {
        origin = 'PDF · $pageLabel · OCR ile okundu';
      } else {
        origin = 'PDF · $pageLabel · $ocrPages sayfa OCR ile okundu';
      }
    } else {
      origin = extraction.unitCount > 1
          ? '${extraction.unitCount} fotoğraf · OCR ile okundu'
          : 'Fotoğraftan OCR ile okundu';
    }

    if (updatedAt != null) {
      return '$origin · Kaydedildi';
    }
    return '$origin · Hataları düzeltebilirsiniz';
  }

  Widget _buildActions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _ToolButton(
                  icon: Icons.copy_rounded,
                  label: 'Kopyala',
                  onPressed: _copy,
                ),
              ),
              Expanded(
                child: _ToolButton(
                  icon: Icons.share_outlined,
                  label: 'Paylaş',
                  onPressed: _busy ? null : _share,
                ),
              ),
              Expanded(
                child: _ToolButton(
                  icon: Icons.file_download_outlined,
                  label: 'TXT kaydet',
                  onPressed: _busy ? null : _saveAsTxt,
                ),
              ),
              Expanded(
                child: _ToolButton(
                  icon: Icons.backspace_outlined,
                  label: 'Temizle',
                  onPressed: _clear,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final dirty = _hasUnsavedChanges;
                final String label;
                final IconData icon;
                if (!_isSaved) {
                  label = 'Kaydet';
                  icon = Icons.bookmark_add_outlined;
                } else if (dirty) {
                  label = 'Değişiklikleri kaydet';
                  icon = Icons.save_outlined;
                } else {
                  label = 'Kaydedildi';
                  icon = Icons.check_rounded;
                }
                return FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _busy || (_isSaved && !dirty) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(icon),
                  label: Text(label),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppTheme.cardColor(context),
        shape: AppTheme.cardShape(context, radius: 18),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        expands: true,
        maxLines: null,
        minLines: null,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        autocorrect: false,
        enableSuggestions: false,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        decoration: const InputDecoration(
          hintText: 'Metin burada görünecek…',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _StatsLine extends StatelessWidget {
  const _StatsLine({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final stats = TextStats.of(value.text);
          return Text(
            '${TextStats.formatCount(stats.characters)} karakter · '
            '${TextStats.formatCount(stats.words)} kelime',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// "Belge adı" penceresi. Boş bırakılırsa "Belge - 11.09.2026" kullanılır.
class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.initialTitle, required this.isRename});

  final String initialTitle;
  final bool isRename;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final TextEditingController _titleController;
  late final String _defaultTitle;

  @override
  void initState() {
    super.initState();
    _defaultTitle = DateFormatter.defaultDocumentTitle(DateTime.now());
    final initial = widget.initialTitle.trim();
    final clipped = initial.length > AppConstants.titleMaxLength
        ? initial.substring(0, AppConstants.titleMaxLength)
        : initial;
    _titleController = TextEditingController(text: clipped)
      ..selection = TextSelection(baseOffset: 0, extentOffset: clipped.length);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    Navigator.of(context).pop(title.isEmpty ? _defaultTitle : title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isRename ? 'Belge adını değiştir' : 'Belgeyi kaydet'),
      content: TextField(
        controller: _titleController,
        autofocus: true,
        maxLength: AppConstants.titleMaxLength,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Belge adı',
          hintText: _defaultTitle,
          helperText: 'Boş bırakırsanız "$_defaultTitle" olur.',
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isRename ? 'Değiştir' : 'Kaydet'),
        ),
      ],
    );
  }
}
