import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/constants/plan_limits.dart';
import '../../core/constants/purchase_products.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/subscription_model.dart';
import '../../services/purchase_service.dart';
import 'limit_dialog.dart';

/// "Pro'ya Geç" ekranı.
///
/// Google Play Billing bu sürümde bağlı değildir: satın alma düğmesi "Yakında"
/// olarak pasif görünür ve hiçbir ödeme alınmaz. Mock Pro anahtarı yalnızca
/// debug derlemede görünür.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final access = services.access;
    final entitlement = services.entitlement;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('MetinCep Pro')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: access,
          builder: (context, _) {
            final isPro = access.isPro;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Icon(Icons.workspace_premium_outlined, size: 56, color: colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  'MetinCep Pro',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Daha fazla belge işle.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                if (isPro) _ActiveProCard(entitlement: access.entitlement),
                const _FeatureList(),
                if (!isPro) ...[
                  const SizedBox(height: 12),
                  _UsageCard(
                    remainingOcr: access.remainingOcrToday ?? 0,
                    remainingPdf: access.remainingPdfToday ?? 0,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      // Satın alma sağlayıcısı yokken düğme pasiftir; sahte satın alma yapılmaz.
                      onPressed: entitlement.canPurchase ? () => _purchase(context) : null,
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: Text(entitlement.canPurchase ? "Pro'ya Geç" : "Pro'ya Geç · Yakında"),
                    ),
                  ),
                  if (!entitlement.canPurchase) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Google Play üzerinden satın alma bir sonraki sürümde eklenecek. '
                      'Şu anda hiçbir ödeme alınmaz.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Free ve Pro, internet olmadan da çalışır. OCR her zaman cihazda yapılır.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                // Release ve profile derlemelerde kDebugMode derleme zamanında false olur;
                // bu bölüm ve içindeki Mock Pro anahtarı uygulamaya hiç girmez.
                if (kDebugMode && entitlement.isMockProAvailable) ...[
                  const SizedBox(height: 24),
                  const _DebugToolsCard(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _purchase(BuildContext context) async {
    final entitlement = AppScope.of(context).entitlement;
    // Gerçek Billing bağlandığında burada aylık/yıllık/ömür boyu plan seçimi gösterilecek.
    final result = await entitlement.purchase(PurchaseProducts.proYearly);
    if (!context.mounted) {
      return;
    }
    switch (result) {
      case PurchaseResult.purchased:
        showAppSnackBar(context, 'MetinCep Pro etkin. Teşekkürler!');
      case PurchaseResult.pending:
        showAppSnackBar(context, 'Ödeme onayı bekleniyor.');
      case PurchaseResult.cancelled:
        break;
      case PurchaseResult.unavailable:
        showAppSnackBar(context, 'Satın alma şu anda kullanılamıyor.');
      case PurchaseResult.failed:
        showAppSnackBar(context, 'Satın alma tamamlanamadı.');
    }
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    final features = <(String, String)>[
      ('Limitsiz OCR', 'Free: günde ${FreeLimits.dailyOcrOperations} fotoğraf işlemi'),
      ('Limitsiz PDF', 'Free: günde ${FreeLimits.dailyPdfOperations} PDF'),
      ('Çok sayfalı PDF', 'Free: PDF başına en fazla ${FreeLimits.maxPdfPages} sayfa'),
      ('Toplu OCR', 'Free: tek seferde en fazla ${FreeLimits.maxImagesPerBatch} fotoğraf'),
      ('Reklamsız kullanım', "Pro'da hiçbir zaman reklam gösterilmez"),
      (
        'Daha yüksek dosya limitleri',
        'Free: en fazla ${LimitPrompt.formatMegabytes(FreeLimits.plan.maxPdfFileSizeBytes!)} PDF',
      ),
    ];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: AppTheme.cardColor(context),
      shape: AppTheme.cardShape(context, radius: 18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final (title, detail) in features)
              ListTile(
                dense: true,
                leading: Icon(Icons.check_circle, color: colorScheme.primary),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(detail),
              ),
          ],
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.remainingOcr, required this.remainingPdf});

  final int remainingOcr;
  final int remainingPdf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Free kullanım',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _UsageRow(
              label: 'Bugün kalan OCR',
              remaining: remainingOcr,
              limit: FreeLimits.dailyOcrOperations,
            ),
            const SizedBox(height: 10),
            _UsageRow(
              label: 'Bugün kalan PDF',
              remaining: remainingPdf,
              limit: FreeLimits.dailyPdfOperations,
            ),
            const SizedBox(height: 10),
            Text(
              'Haklar her gün yenilenir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.remaining, required this.limit});

  final String label;
  final int remaining;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text(
              '$remaining / $limit',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: limit <= 0 ? 0 : remaining / limit,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _ActiveProCard extends StatelessWidget {
  const _ActiveProCard({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sourceText = switch (entitlement.source) {
      EntitlementSource.debugMock => 'Test Pro (yalnızca debug derleme)',
      EntitlementSource.googlePlay => 'Google Play aboneliği',
      EntitlementSource.none => '',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          leading: Icon(Icons.verified, color: colorScheme.onPrimaryContainer),
          title: Text(
            'MetinCep Pro etkin',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: sourceText.isEmpty
              ? null
              : Text(sourceText, style: TextStyle(color: colorScheme.onPrimaryContainer)),
        ),
      ),
    );
  }
}

/// Yalnızca debug derlemede oluşturulur.
class _DebugToolsCard extends StatelessWidget {
  const _DebugToolsCard();

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final entitlement = services.entitlement;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.bug_report_outlined, color: colorScheme.error),
            title: const Text('Geliştirici araçları'),
            subtitle: const Text('Bu bölüm release APK’da bulunmaz.'),
          ),
          SwitchListTile(
            title: const Text('Mock Pro'),
            subtitle: const Text('Pro özelliklerini ödeme olmadan test et (kalıcı değil)'),
            value: entitlement.isMockProEnabled,
            onChanged: entitlement.setMockPro,
          ),
          ListTile(
            leading: const Icon(Icons.speed_outlined),
            title: const Text('Free sayaçlarını limite doldur'),
            subtitle: const Text('Limit pencerelerini hemen test et'),
            onTap: () async {
              await services.usage.setCountsForDebug(
                ocrCount: FreeLimits.dailyOcrOperations,
                pdfCount: FreeLimits.dailyPdfOperations,
              );
              if (context.mounted) {
                showAppSnackBar(context, 'Günlük haklar doldu.');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Bugünkü Free sayaçlarını sıfırla'),
            onTap: () async {
              await services.usage.resetTodayForDebug();
              if (context.mounted) {
                showAppSnackBar(context, 'Sayaçlar sıfırlandı.');
              }
            },
          ),
        ],
      ),
    );
  }
}
