import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const List<_PrivacyItem> _items = [
    _PrivacyItem(
      icon: Icons.photo_camera_outlined,
      title: 'Fotoğraflar',
      body: 'Çektiğiniz veya seçtiğiniz fotoğraflar metin tanıma için yalnızca '
          'telefonunuzda işlenir ve hiçbir sunucuya gönderilmez. İşlem bitince '
          'uygulamanın geçici kopyası silinir; galerinizdeki orijinal fotoğrafa dokunulmaz.',
    ),
    _PrivacyItem(
      icon: Icons.picture_as_pdf_outlined,
      title: "Belgeler ve PDF'ler",
      body: "PDF'ler telefonunuzda açılır ve okunur. Dosyalarınız internete yüklenmez.",
    ),
    _PrivacyItem(
      icon: Icons.text_snippet_outlined,
      title: 'OCR sonuçları',
      body: 'Çıkarılan metin, siz "Kaydet"e dokunmadıkça hiçbir yere kaydedilmez. '
          'Kaydettiğiniz belgeler yalnızca bu cihazda, uygulamanın kendi klasöründe saklanır. '
          'Uygulamayı kaldırdığınızda bu kayıtlar da silinir.',
    ),
    _PrivacyItem(
      icon: Icons.data_usage_outlined,
      title: 'Free kullanım sayacı',
      body: 'Free sürüm sınırları için yalnızca bugünün tarihi ve günlük işlem sayıları '
          'cihazınızda tutulur. Bu bilgi belge içeriği içermez ve hiçbir yere gönderilmez.',
    ),
    _PrivacyItem(
      icon: Icons.no_accounts_outlined,
      title: 'Hesap, reklam, analiz yok',
      body: 'Bu sürümde kullanıcı hesabı, reklam SDK’sı, analiz servisi veya bulut '
          'senkronizasyonu yoktur. Verileriniz satılmaz ve kimseyle paylaşılmaz.',
    ),
    _PrivacyItem(
      icon: Icons.memory_outlined,
      title: 'Metin tanıma bileşeni',
      body: 'Metin tanıma, cihaz üzerinde çalışan Google ML Kit ile yapılır. '
          "Görüntüleriniz ve metinleriniz Google'a gönderilmez. ML Kit, Google'ın "
          'açıklamasına göre bileşenin çalışmasıyla ilgili teknik ölçümleri '
          '(ör. performans ve hata bilgisi) iletebilir; bu ölçümler belge içeriği içermez.',
    ),
    _PrivacyItem(
      icon: Icons.share_outlined,
      title: 'Paylaşım sizin kontrolünüzde',
      body: 'Metin yalnızca siz "Paylaş" veya "TXT kaydet"i seçtiğinizde, sizin seçtiğiniz '
          'uygulamaya ya da konuma aktarılır.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 32, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Belgeleriniz cihazınızdan çıkmadan işlenir.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: AppTheme.cardColor(context),
                  shape: AppTheme.cardShape(context, radius: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon, color: colorScheme.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(item.body, style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyItem {
  const _PrivacyItem({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}
