import 'dart:math' as math;

/// Toplam alan tablosu (integral image): dikdörtgen bir bölgenin ortalamasını
/// pencere boyutundan bağımsız olarak O(1) hesaplar.
///
/// Uyarlamalı eşikleme ve aydınlatma normalizasyonu bunun üzerine kurulur:
/// Gauss bulanıklığı yarıçapla pahalılaşır, bu yapı pahalılaşmaz.
class IntegralImage {
  IntegralImage(List<double> values, this.width, this.height)
      : _sum = List<double>.filled((width + 1) * (height + 1), 0) {
    final stride = width + 1;
    for (var y = 0; y < height; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < width; x++) {
        rowSum += values[y * width + x];
        _sum[(y + 1) * stride + (x + 1)] = _sum[y * stride + (x + 1)] + rowSum;
      }
    }
  }

  final int width;
  final int height;
  final List<double> _sum;

  /// (x, y) merkezli, [radius] yarıçaplı karenin ortalaması.
  double average(int x, int y, int radius) {
    final x0 = math.max(0, x - radius);
    final y0 = math.max(0, y - radius);
    final x1 = math.min(width - 1, x + radius);
    final y1 = math.min(height - 1, y + radius);
    final area = (x1 - x0 + 1) * (y1 - y0 + 1);
    final stride = width + 1;
    final total = _sum[(y1 + 1) * stride + (x1 + 1)] -
        _sum[y0 * stride + (x1 + 1)] -
        _sum[(y1 + 1) * stride + x0] +
        _sum[y0 * stride + x0];
    return total / area;
  }
}
