import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metincep/models/document_model.dart';
import 'package:metincep/repositories/document_repository.dart';

void main() {
  late Directory directory;
  late DateTime now;

  DocumentRepository createRepository() => DocumentRepository(
        directoryProvider: () async => directory,
        clock: () => now = now.add(const Duration(minutes: 1)),
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metincep_test_');
    now = DateTime(2026, 9, 11, 9);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('kaydedilen belgeler uygulama yeniden açılınca durur', () async {
    final repository = createRepository();
    await repository.load();
    await repository.save(
      title: 'Fatura 12',
      text: 'Çalışma Şirket İstanbul\n12.500 TL',
      source: DocumentSource.camera,
    );

    final reopened = createRepository();
    await reopened.load();

    expect(reopened.documents, hasLength(1));
    final document = reopened.documents.single;
    expect(document.title, 'Fatura 12');
    expect(document.text, 'Çalışma Şirket İstanbul\n12.500 TL');
    expect(document.source, DocumentSource.camera);
  });

  test('düzenlenen belge aynı kimlikle güncellenir ve en üste çıkar', () async {
    final repository = createRepository();
    await repository.load();
    final first = await repository.save(title: 'Birinci', text: 'A');
    await repository.save(title: 'İkinci', text: 'B');

    final updated = await repository.save(id: first.id, title: 'Birinci', text: 'A düzenlendi');

    expect(repository.documents, hasLength(2));
    expect(repository.documents.first.id, first.id);
    expect(updated.text, 'A düzenlendi');
    expect(updated.createdAt, first.createdAt);
    expect(updated.updatedAt.isAfter(first.updatedAt), isTrue);
  });

  test('silme ve toplu silme kalıcıdır', () async {
    final repository = createRepository();
    await repository.load();
    final first = await repository.save(title: 'Birinci', text: 'A');
    await repository.save(title: 'İkinci', text: 'B');
    await repository.save(title: 'Üçüncü', text: 'C');

    await repository.delete(first.id);
    expect(repository.findById(first.id), isNull);

    var reopened = createRepository();
    await reopened.load();
    expect(reopened.documents.map((d) => d.title), ['Üçüncü', 'İkinci']);

    await reopened.deleteAll();
    reopened = createRepository();
    await reopened.load();
    expect(reopened.documents, isEmpty);
  });

  test('bozuk kayıt dosyası uygulamayı çökertmez ve yedeklenir', () async {
    await File('${directory.path}/${DocumentRepository.fileName}').writeAsString('{bozuk json');

    final repository = createRepository();
    await repository.load();

    expect(repository.isLoaded, isTrue);
    expect(repository.documents, isEmpty);
    final backups = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('.bozuk-'));
    expect(backups, hasLength(1));
  });
}
