import '../errors/app_exception.dart';

/// Uzun süren işlemleri (çok sayfalı PDF gibi) adımlar arasında iptal etmeye yarar.
class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const OperationCancelledException();
    }
  }
}
