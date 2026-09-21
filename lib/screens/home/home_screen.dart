import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../services/ad_service.dart';
import '../../widgets/action_card.dart';
import '../../widgets/ad_banner_slot.dart';
import '../../widgets/document_item.dart';
import '../../widgets/empty_state.dart';
import '../pro/pro_screen.dart';
import '../processing/extraction_flow.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onShowHistory});

  final VoidCallback onShowHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final services = AppScope.of(context);
    final documents = services.documents;
    final access = services.access;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([documents, access]),
          builder: (_, _) {
            final recent =
                documents.documents.take(AppConstants.recentDocumentsLimit).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              children: [
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConstants.appTagline,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                ActionCard(
                  icon: Icons.photo_camera_outlined,
                  title: 'Fotoğraf Çek',
                  subtitle: 'Belgeyi kamerayla çekin',
                  onTap: () => ExtractionFlow.startCamera(context),
                ),
                ActionCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Galeriden Seç',
                  subtitle: 'Bir veya birkaç fotoğraf seçin',
                  onTap: () => ExtractionFlow.startGallery(context),
                ),
                ActionCard(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'PDF Aç',
                  subtitle: "Telefondaki PDF'den metni çıkarın",
                  onTap: () => ExtractionFlow.startPdf(context),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Son Belgeler',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (recent.isNotEmpty)
                      TextButton(onPressed: onShowHistory, child: const Text('Tümünü gör')),
                  ],
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const EmptyState(
                    compact: true,
                    icon: Icons.text_snippet_outlined,
                    title: 'Henüz kayıtlı belge yok',
                    message: 'Çıkardığınız metni kaydettiğinizde burada görünür.',
                  )
                else
                  for (final document in recent)
                    DocumentItem(
                      document: document,
                      onTap: () => ExtractionFlow.openDocument(context, document),
                    ),
                // Free kullanıcıya küçük, sade Pro kartı: eylem kartlarının ve
                // son belgelerin ALTINDA; OCR / PDF düğmelerinin önüne geçmez.
                if (!access.isPro) ...[
                  const SizedBox(height: 8),
                  const _ProTeaserCard(),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Belgeleriniz cihazınızda işlenir, sunucuya gönderilmez.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                // Reklam yeri (Pro'da ve bu sürümde boş, yer kaplamaz).
                const AdBannerSlot(placement: AdPlacement.homeBottomBanner),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProTeaserCard extends StatelessWidget {
  const _ProTeaserCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ProScreen.open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MetinCep Pro',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text('Limitsiz belge işlemi', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => ProScreen.open(context),
                child: const Text("Pro'yu İncele"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
