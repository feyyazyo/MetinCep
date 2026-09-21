/// intl paketine gerek kalmadan Türkçe tarih biçimlendirme.
class DateFormatter {
  DateFormatter._();

  static const List<String> _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  /// 11 Eylül 2026
  static String long(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  /// 11 Eylül 2026, 14:05
  static String longWithTime(DateTime date) =>
      '${long(date)}, ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';

  /// 11.09.2026
  static String short(DateTime date) =>
      '${_twoDigits(date.day)}.${_twoDigits(date.month)}.${date.year}';

  /// 20260911_1405 (dosya adları için)
  static String fileStamp(DateTime date) =>
      '${date.year}${_twoDigits(date.month)}${_twoDigits(date.day)}_'
      '${_twoDigits(date.hour)}${_twoDigits(date.minute)}';

  /// Belge - 11.09.2026
  static String defaultDocumentTitle(DateTime date) => 'Belge - ${short(date)}';

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
