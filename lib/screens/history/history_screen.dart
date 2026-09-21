import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/search_utils.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/document_model.dart';
import '../../services/ad_service.dart';
import '../../widgets/ad_banner_slot.dart';
import '../../widgets/document_item.dart';
import '../../widgets/empty_state.dart';
import '../processing/extraction_flow.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// Belge nesneleri değişmez olduğu için katlanmış arama metni nesne başına bir kez hesaplanır.
  static final Expando<String> _foldedCache = Expando<String>('metincepSearch');

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _foldedFor(DocumentModel document) {
    return _foldedCache[document] ??=
        SearchUtils.fold('${document.title}\n${document.text}');
  }

  void _updateQuery(String value) {
    if (value == _query) {
      return;
    }
    setState(() => _query = value);
  }

  void _clearQuery() {
    _searchController.clear();
    _updateQuery('');
  }

  Future<void> _confirmDelete(DocumentModel document) async {
    final title = document.title.trim().isEmpty ? 'Adsız belge' : document.title;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Belge silinsin mi?',
      message: '"$title" kalıcı olarak silinecek.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await AppScope.of(context).documents.delete(document.id);
      if (mounted) {
        showAppSnackBar(context, 'Belge silindi.');
      }
    } catch (error) {
      debugPrint('Silme hatası: $error');
      if (mounted) {
        showAppSnackBar(context, ErrorMessages.deleteFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = AppScope.of(context).documents;

    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: documents,
          builder: (context, _) {
            final all = documents.documents;
            if (all.isEmpty) {
              return const Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.history,
                    title: 'Henüz kayıtlı belge yok',
                    message:
                        'Metin çıkardıktan sonra "Kaydet"e dokunduğunuzda belgeleriniz burada listelenir.',
                  ),
                ),
              );
            }

            final query = _query.trim();
            final visible = query.isEmpty
                ? all
                : all
                    .where((document) =>
                        SearchUtils.matchesFolded(query, _foldedFor(document)))
                    .toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _SearchField(
                    controller: _searchController,
                    onChanged: _updateQuery,
                    onClear: _clearQuery,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      query.isEmpty
                          ? '${all.length} belge'
                          : '${visible.length} / ${all.length} belge',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? SingleChildScrollView(
                          child: EmptyState(
                            icon: Icons.search_off,
                            title: 'Sonuç bulunamadı',
                            message: '"$query" için eşleşen belge yok.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final document = visible[index];
                            return DocumentItem(
                              key: ValueKey(document.id),
                              document: document,
                              onTap: () => ExtractionFlow.openDocument(context, document),
                              onDelete: () => _confirmDelete(document),
                            );
                          },
                        ),
                ),
                // Reklam yeri (Pro'da ve bu sürümde boş, yer kaplamaz).
                const AdBannerSlot(placement: AdPlacement.historyBottomBanner),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Belgelerde ara',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Aramayı temizle',
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
