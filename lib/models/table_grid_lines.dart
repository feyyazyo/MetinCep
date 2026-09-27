/// Fotoğrafta bulunan tablo çizgileri (özgün görüntü piksel koordinatlarında).
///
/// Çizgiler yalnızca **ipucu**dur: kolon sınırlarını doğrular ve güven puanına
/// katkı verir. Çizgiler kelime geometrisiyle çelişirse yok sayılır — yanlış
/// çizgi yüzünden tablo bozulmaz.
class TableGridLines {
  const TableGridLines({
    this.horizontal = const [],
    this.vertical = const [],
  });

  static const TableGridLines none = TableGridLines();

  /// Yatay çizgilerin y konumları (satır ayırıcılar).
  final List<double> horizontal;

  /// Dikey çizgilerin x konumları (kolon ayırıcılar).
  final List<double> vertical;

  bool get isEmpty => horizontal.isEmpty && vertical.isEmpty;

  bool get hasGrid => horizontal.length >= 2 && vertical.length >= 2;

  @override
  String toString() =>
      'TableGridLines(yatay: ${horizontal.length}, dikey: ${vertical.length})';
}
