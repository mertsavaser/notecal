import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:notecal/l10n/app_localizations.dart';
import 'core/auth_wrapper.dart';

class NotecalApp extends StatelessWidget {
  /// Optional override for the `home` widget.
  ///
  /// - In production, this is left `null` so the app uses the real
  ///   `AuthWrapper`, which handles onboarding, auth, and routing.
  /// - In tests, a simple widget (e.g. `SizedBox.shrink()`) can be
  ///   provided to avoid initializing Firebase or other async flows.
  final Widget home;

  const NotecalApp({
    super.key,
    Widget? home,
  }) : home = home ?? const AuthWrapper();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteCal',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('tr'),
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) {
          return const Locale('en');
        }
        // Check if device locale is Turkish
        if (locale.languageCode == 'tr') {
          return const Locale('tr');
        }
        // Fallback to English for all other locales
        return const Locale('en');
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.light,
        ),
      ),
      home: home,
    );
  }
}
