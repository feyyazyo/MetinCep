import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../services/feature_access_service.dart';
import 'limit_dialog.dart';
import 'pro_screen.dart';

/// Free sınırı dolduğunda pencereyi gösterir ve kullanıcının kararını uygular.
///
/// Erişim varsa hiçbir şey göstermez ve `true` döner. Sınır dolmuşsa pencere
/// açılır; kullanıcı Pro ekranından dönerse erişim yeniden kontrol edilir.
/// Uygulama hiçbir durumda çökmez, işlem sessizce iptal edilir.
Future<bool> ensureAccess(
  BuildContext context, {
  required bool Function(FeatureAccessService access) isAllowed,
  required LimitPrompt Function(FeatureAccessService access) prompt,
}) async {
  final access = AppScope.of(context).access;
  if (isAllowed(access)) {
    return true;
  }
  final choice = await showLimitDialog(context, prompt(access));
  if (choice != LimitChoice.viewPro || !context.mounted) {
    return false;
  }
  await ProScreen.open(context);
  return context.mounted && isAllowed(access);
}
