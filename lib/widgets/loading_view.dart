import 'dart:io';

import 'package:flutter/material.dart';

import '../models/extraction_models.dart';

/// OCR / PDF işlemi sürerken gösterilen ekran: ilerleme, yüzde, sayfa sayısı, iptal.
class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    required this.title,
    this.progress,
    this.previewImagePath,
    this.onCancel,
  });

  final String title;
  final ExtractionProgress? progress;
  final String? previewImagePath;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = progress;
    final double? progressValue =
        (current != null && current.isDeterminate) ? current.fraction : null;
    final detail = current?.detail;
    final previewPath = previewImagePath;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (previewPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(previewPath),
                    height: 200,
                    fit: BoxFit.contain,
                    cacheWidth: 600,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.image_outlined,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                  ),
                )
              else
                Icon(Icons.document_scanner_outlined, size: 64, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progressValue, minHeight: 10),
              ),
              const SizedBox(height: 12),
              if (current != null && current.isDeterminate) ...[
                Text(
                  '%${current.percent}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${current.completed} / ${current.total} ${current.unit.label} işlendi'),
              ],
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Lütfen bekleyin.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('İptal'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
