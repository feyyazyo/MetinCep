import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_scope.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_shell.dart';

class MetinCepApp extends StatelessWidget {
  const MetinCepApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const HomeShell(),
        );
      },
    );
  }
}
