import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/cancellation_token.dart';
import '../../models/extraction_models.dart';
import '../../services/ad_service.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../pro/limit_dialog.dart';
import '../pro/pro_screen.dart';
import '../result/result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.request});

  final ExtractionRequest request;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final CancellationToken _cancellationToken = CancellationToken();
  AppServices? _services;
  ExtractionProgress? _progress;
  String? _errorMessage;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _run();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // dispose içinde context kullanılamadığı için servisler burada alınır.
    _services ??= AppScope.of(context);
  }

  @override
  void dispose() {
    // Geri tuşu veya İptal: kalan sayfalar işlenmez.
    _cancellationToken.cancel();
    // Fotoğraf / PDF'in önbellekteki kopyası artık gerekmez (sonuç metin olarak taşındı).
    _services?.picker.discardTemporaryCopies(_temporaryPaths());
    super.dispose();
  }

  List<String> _temporaryPaths() {
    final request = widget.request;
    if (request is ImageExtractionRequest) {
      return request.imagePaths;
    }
    if (request is PdfExtractionRequest) {
      return [request.pdfPath];
    }
    return const [];
  }

  Future<void> _run() async {
    if (_running) {
      return;
    }
    final services = _services ??= AppScope.of(context);
    final extraction = services.extraction;
    setState(() {
      _running = true;
      _errorMessage = null;
      _progress = null;
    });

    try {
      final result = await extraction.run(
        widget.request,
        cancellationToken: _cancellationToken,
        onProgress: _handleProgress,
        onPageLimitExceeded: _resolvePageLimit,
      );
      if (!mounted || _cancellationToken.isCancelled) {
        return;
      }
      // Hak yalnızca başarıyla biten işlemde harcanır (hata / iptal sayılmaz).
      // Sayaç bellekte hemen artar; dosyaya yazma arka planda sürer.
      unawaited(services.access.recordCompletedExtraction(result.source));
      final resultRoute = MaterialPageRoute<void>(
        builder: (_) => ResultScreen.fromExtraction(result: result),
      );
      // Reklam geçiş noktası: kullanıcı sonuç ekranını kapatıp ana ekrana döndükten SONRA.
      // İşlem sırasında veya metin düzenlenirken asla. Pro'da ve bu sürümde (SDK yok) hiçbir şey olmaz.
      final ads = services.ads;
      unawaited(
        resultRoute.popped.then((_) => ads.showInterstitial(AdPlacement.afterResultClosed)),
      );
      Navigator.of(context).pushReplacement(resultRoute);
    } on OperationCancelledException {
      // Kullanıcı iptal etti; ekran zaten kapandı.
    } on AppException catch (error) {
      _showError(error.message);
    } catch (error, stackTrace) {
      debugPrint('Beklenmeyen işlem hatası: $error\n$stackTrace');
      _showError(
        widget.request is PdfExtractionRequest
            ? ErrorMessages.pdfOpenFailed
            : ErrorMessages.noTextInImage,
      );
    } finally {
      _running = false;
    }
  }

  /// PDF, geçerli planın sayfa sınırını aşıyorsa kullanıcıya sorar.
  Future<PageLimitDecision> _resolvePageLimit(int pageCount, int maxPages) async {
    while (mounted) {
      final choice = await showLimitDialog(
        context,
        LimitPrompt.pdfPages(pageCount: pageCount, maxPages: maxPages),
      );
      if (!mounted) {
        return PageLimitDecision.cancel;
      }
      switch (choice) {
        case LimitChoice.continueWithinLimit:
          return PageLimitDecision.processFirstPages;
        case LimitChoice.viewPro:
          await ProScreen.open(context);
          if (mounted && (_services?.access.canUseLargePdf(pageCount) ?? false)) {
            return PageLimitDecision.processAll;
          }
        case LimitChoice.cancel:
          _cancel();
          return PageLimitDecision.cancel;
      }
    }
    return PageLimitDecision.cancel;
  }

  void _handleProgress(ExtractionProgress progress) {
    if (!mounted) {
      return;
    }
    setState(() => _progress = progress);
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _errorMessage = message);
  }

  void _cancel() {
    _cancellationToken.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final isPdf = request is PdfExtractionRequest;
    final errorMessage = _errorMessage;
    String? previewPath;
    if (request is ImageExtractionRequest && request.imagePaths.isNotEmpty) {
      previewPath = request.imagePaths.first;
    }

    return Scaffold(
      appBar: AppBar(title: Text(isPdf ? 'PDF' : 'Metin okuma')),
      body: SafeArea(
        child: errorMessage != null
            ? ErrorView(
                message: errorMessage,
                onBack: () => Navigator.of(context).pop(),
                onRetry: _run,
              )
            : LoadingView(
                title: isPdf ? 'PDF analiz ediliyor…' : 'Metin okunuyor…',
                progress: _progress,
                previewImagePath: previewPath,
                onCancel: _cancel,
              ),
      ),
    );
  }
}
