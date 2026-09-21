import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

class PickedPdf {
  const PickedPdf({required this.path, required this.name, required this.sizeBytes});

  final String path;
  final String name;

  /// Dosya boyutu (bayt). Bilinmiyorsa 0.
  final int sizeBytes;
}

/// Kamera, galeri ve dosya seçici erişimi.
/// Sistem arayüzleri kullanıldığı için uygulama ek izin istemez.
class SourcePickerService {
  SourcePickerService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  /// Kullanıcı vazgeçerse null döner.
  Future<String?> captureFromCamera() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: AppConstants.imageMaxDimension,
        maxHeight: AppConstants.imageMaxDimension,
        imageQuality: AppConstants.imageQuality,
      );
      return file?.path;
    } catch (error) {
      debugPrint('Kamera hatası: $error');
      throw const AppException(ErrorMessages.cameraFailed);
    }
  }

  /// Bir veya birden fazla fotoğraf. Vazgeçilirse boş liste.
  Future<List<String>> pickFromGallery() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        maxWidth: AppConstants.imageMaxDimension,
        maxHeight: AppConstants.imageMaxDimension,
        imageQuality: AppConstants.imageQuality,
      );
      return files.map((file) => file.path).toList();
    } catch (error) {
      debugPrint('Galeri hatası: $error');
      throw const AppException(ErrorMessages.galleryFailed);
    }
  }

  /// Kullanıcı vazgeçerse null döner.
  Future<PickedPdf?> pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      final file = result.files.first;
      final path = file.path;
      if (path == null || path.isEmpty) {
        throw const AppException(ErrorMessages.filePickFailed);
      }
      return PickedPdf(path: path, name: file.name, sizeBytes: file.size);
    } on AppException {
      rethrow;
    } catch (error) {
      debugPrint('Dosya seçici hatası: $error');
      throw const AppException(ErrorMessages.filePickFailed);
    }
  }

  /// Seçici/kamera eklentilerinin uygulama önbelleğine kopyaladığı dosyaları siler.
  /// Yalnızca uygulamanın geçici klasöründeki dosyalara dokunur; kullanıcının
  /// galerideki veya indirilenlerdeki orijinal dosyaları asla silinmez.
  Future<void> discardTemporaryCopies(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    try {
      final tempRoot = (await getTemporaryDirectory()).absolute.path;
      for (final path in paths) {
        final file = File(path).absolute;
        if (!file.path.startsWith(tempRoot)) {
          continue;
        }
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (error) {
          debugPrint('Geçici kopya silinemedi: $error');
        }
      }
    } catch (error) {
      debugPrint('Geçici klasör bulunamadı: $error');
    }
  }

  /// Düşük RAM'li telefonlarda Android, kamera açıkken uygulamayı kapatabilir.
  /// Uygulama yeniden açıldığında çekilen fotoğrafı kurtarır.
  Future<List<String>> retrieveLostImages() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty) {
        return const [];
      }
      final files = response.files;
      if (files == null) {
        return const [];
      }
      return files.map((file) => file.path).toList();
    } catch (error) {
      debugPrint('Kayıp fotoğraf verisi alınamadı: $error');
      return const [];
    }
  }
}
