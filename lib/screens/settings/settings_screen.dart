import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/subscription_model.dart';
import '../pro/pro_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _deleteAll(BuildContext context) async {
    final repository = AppScope.of(context).documents;
    final count = repository.documents.length;
    if (count == 0) {
      showAppSnackBar(context, 'Silinecek belge yok.');
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Tüm belgeler silinsin mi?',
      message: 'Kayıtlı $count belge kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      confirmLabel: 'Tümünü sil',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await repository.deleteAll();
      if (context.mounted) {
        showAppSnackBar(context, 'Tüm belgeler silindi.');
      }
    } catch (error) {
      debugPrint('Toplu silme hatası: $error');
      if (context.mounted) {
        showAppSnackBar(context, ErrorMessages.deleteFailed);
      }
    }
  }

  void _showAbout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: 'Sürüm ${AppConstants.appVersion}',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.seedColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.document_scanner_outlined, color: colorScheme.onPrimary),
      ),
      applicationLegalese: 'Hesap, reklam ve abonelik içermez.',
      children: const [
        SizedBox(height: 16),
        Text(
          "Fotoğraf ve PDF'lerden cihaz üzerinde metin çıkarır. "
          'Metin tanıma: Google ML Kit (cihaz üzerinde). PDF: PDFium (pdfrx).',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final settings = services.settings;
    final documents = services.documents;
    final access = services.access;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const _SectionTitle('MetinCep Pro'),
            _SettingsCard(
              children: [
                ListenableBuilder(
                  listenable: access,
                  builder: (context, _) {
                    final entitlement = access.entitlement;
                    final String subtitle;
                    if (entitlement.source == EntitlementSource.debugMock) {
                      subtitle = 'Test Pro (yalnızca debug derleme)';
                    } else if (access.isPro) {
                      subtitle = 'Limitsiz belge işlemi, reklamsız';
                    } else {
                      subtitle = 'Bugün kalan: ${access.remainingOcrToday ?? 0} OCR · '
                          '${access.remainingPdfToday ?? 0} PDF';
                    }
                    return ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('Pro Durumu'),
                      subtitle: Text(subtitle),
                      trailing: _PlanBadge(tier: entitlement.tier),
                      onTap: () => ProScreen.open(context),
                    );
                  },
                ),
              ],
            ),
            const _SectionTitle('Görünüm'),
            _SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tema', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 10),
                      ListenableBuilder(
                        listenable: settings,
                        builder: (context, _) => SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto_outlined),
                                label: Text('Sistem'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_outlined),
                                label: Text('Açık'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_outlined),
                                label: Text('Koyu'),
                              ),
                            ],
                            selected: {settings.themeMode},
                            onSelectionChanged: (selection) =>
                                settings.setThemeMode(selection.first),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const _SectionTitle('Dil ve metin tanıma'),
            const _SettingsCard(
              children: [
                ListTile(
                  leading: Icon(Icons.language),
                  title: Text('Uygulama dili'),
                  subtitle: Text('Türkçe'),
                ),
                Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.translate),
                  title: Text('OCR dili'),
                  subtitle: Text(
                    'Latin alfabesi — Türkçe (ç, ğ, ı, İ, ö, ş, ü), İngilizce ve diğer '
                    'Latin alfabeli diller otomatik tanınır. Ayrı dil seçmeniz gerekmez.',
                  ),
                  isThreeLine: true,
                ),
              ],
            ),
            const _SectionTitle('Veriler'),
            _SettingsCard(
              children: [
                ListenableBuilder(
                  listenable: documents,
                  builder: (context, _) => ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Kayıtlı belgeler'),
                    subtitle: Text(
                      '${documents.documents.length} belge yalnızca bu cihazda saklanıyor',
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.delete_sweep_outlined,
                      color: Theme.of(context).colorScheme.error),
                  title: Text(
                    'Tüm belgeleri sil',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () => _deleteAll(context),
                ),
              ],
            ),
            const _SectionTitle('Hakkında'),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Gizlilik'),
                  subtitle: const Text('Belgeleriniz nasıl işlenir?'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Hakkında'),
                  subtitle: Text('${AppConstants.appName} ${AppConstants.appVersion}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardColor(context),
      shape: AppTheme.cardShape(context, radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.tier});

  final PlanTier tier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPro = tier == PlanTier.pro;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPro ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tier.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isPro ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
