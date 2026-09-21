import '../core/constants/app_constants.dart';

/// Metnin nereden geldiği (V2'de filtreleme / istatistik için hazır).
enum DocumentSource {
  camera,
  gallery,
  pdf,
  unknown;

  static DocumentSource fromName(Object? value) {
    for (final source in DocumentSource.values) {
      if (source.name == value) {
        return source;
      }
    }
    return DocumentSource.unknown;
  }
}

class DocumentModel {
  const DocumentModel({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.source = DocumentSource.unknown,
  });

  final String id;
  final String title;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DocumentSource source;

  DocumentModel copyWith({String? title, String? text, DateTime? updatedAt}) {
    return DocumentModel(
      id: id,
      title: title ?? this.title,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source,
    );
  }

  /// Listelerde gösterilen tek satırlık kısa önizleme.
  String get preview {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= AppConstants.previewMaxChars) {
      return singleLine;
    }
    return '${singleLine.substring(0, AppConstants.previewMaxChars).trimRight()}…';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'source': source.name,
      };

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Belge kimliği eksik.');
    }
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    return DocumentModel(
      id: id,
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt,
      source: DocumentSource.fromName(json['source']),
    );
  }
}
