/// OCR tanıma modu.
///
/// [printed] mevcut (V1) davranıştır: görüntüye dokunulmaz, doğrudan ML Kit'e
/// verilir. Basılı metinde ön işleme sonucu genellikle iyileştirmez.
///
/// [handwriting] el yazısı profilidir: gri tonlama, kontrast ve eğiklik
/// düzeltmesi uygulanır. Tanıma yine cihaz üzerindeki ML Kit ile yapılır;
/// el yazısı desteği bu yüzden kısmidir (README: HANDWRITING = PARTIAL).
enum OcrMode {
  printed('Basılı metin'),
  handwriting('El yazısı');

  const OcrMode(this.label);

  final String label;

  static OcrMode fromName(Object? value) {
    for (final mode in OcrMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return OcrMode.printed;
  }
}
