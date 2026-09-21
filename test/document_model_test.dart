import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/models/document_model.dart';

void main() {
  final created = DateTime(2026, 9, 11, 10, 30);
  final updated = DateTime(2026, 9, 11, 11, 0);

  DocumentModel sample({String text = 'ABC Mermer Ltd.\nToplam: 12.500 TL'}) => DocumentModel(
        id: 'abc123',
        title: 'Fatura 12',
        text: text,
        createdAt: created,
        updatedAt: updated,
        source: DocumentSource.pdf,
      );

  test('JSON gidiş-dönüşünde tüm alanlar korunur', () {
    final restored = DocumentModel.fromJson(sample().toJson());

    expect(restored.id, 'abc123');
    expect(restored.title, 'Fatura 12');
    expect(restored.text, 'ABC Mermer Ltd.\nToplam: 12.500 TL');
    expect(restored.createdAt, created);
    expect(restored.updatedAt, updated);
    expect(restored.source, DocumentSource.pdf);
  });

  test('kimliği olmayan kayıt reddedilir', () {
    expect(() => DocumentModel.fromJson({'title': 'x'}), throwsFormatException);
  });

  test('bilinmeyen kaynak ve eksik tarih güvenle okunur', () {
    final restored = DocumentModel.fromJson({
      'id': 'x1',
      'createdAt': '2026-09-11T10:30:00.000',
      'source': 'tarayici',
    });

    expect(restored.source, DocumentSource.unknown);
    expect(restored.title, '');
    expect(restored.updatedAt, restored.createdAt);
  });

  test('önizleme tek satırdır ve uzun metni kısaltır', () {
    expect(sample().preview, 'ABC Mermer Ltd. Toplam: 12.500 TL');

    final preview = sample(text: 'x' * 300).preview;
    expect(preview.length, 121);
    expect(preview.endsWith('…'), isTrue);
  });

  test('copyWith kimliği, oluşturma tarihini ve kaynağı korur', () {
    final changed = sample().copyWith(title: 'Yeni', text: 'Yeni metin', updatedAt: DateTime(2027));

    expect(changed.id, 'abc123');
    expect(changed.createdAt, created);
    expect(changed.source, DocumentSource.pdf);
    expect(changed.title, 'Yeni');
    expect(changed.text, 'Yeni metin');
  });
}
