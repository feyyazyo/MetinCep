import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/date_formatter.dart';
import '../models/document_model.dart';

/// Geçmiş listesindeki belge satırı: başlık, tarih, kısa önizleme.
class DocumentItem extends StatelessWidget {
  const DocumentItem({
    super.key,
    required this.document,
    required this.onTap,
    this.onDelete,
  });

  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  static IconData iconFor(DocumentSource source) {
    switch (source) {
      case DocumentSource.camera:
        return Icons.photo_camera_outlined;
      case DocumentSource.gallery:
        return Icons.photo_library_outlined;
      case DocumentSource.pdf:
        return Icons.picture_as_pdf_outlined;
      case DocumentSource.unknown:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preview = document.preview;
    final title = document.title.trim().isEmpty ? 'Adsız belge' : document.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.cardColor(context),
        shape: AppTheme.cardShape(context, radius: 16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 14, onDelete == null ? 14 : 4, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    iconFor(document.source),
                    size: 22,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatter.long(document.updatedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
