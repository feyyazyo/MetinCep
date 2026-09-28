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
          // Sınırsız test derlemesi her ekranda işaretlenir: mağaza sürümüyle
          // karıştırılması imkânsız olsun. Normal derlemede bu kod ağaçtan atılır.
          builder: AppConstants.isTestBuild
              ? (context, child) => Banner(
                    message: 'TEST',
                    location: BannerLocation.topEnd,
                    color: const Color(0xFFD32F2F),
                    child: child ?? const SizedBox.shrink(),
                  )
              : null,
          home: const HomeShell(),
        );
      },
    );
  }
}
