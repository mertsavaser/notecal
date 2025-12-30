import 'package:flutter/material.dart';
import 'core/root_wrapper.dart';

class NotecalApp extends StatelessWidget {
  /// Optional override for the `home` widget.
  ///
  /// - In production, this is left `null` so the app uses the real
  ///   `RootWrapper`, which wires up onboarding and Firebase auth.
  /// - In tests, a simple widget (e.g. `SizedBox.shrink()`) can be
  ///   provided to avoid initializing Firebase or other async flows.
  final Widget home;

  const NotecalApp({
    super.key,
    Widget? home,
  }) : home = home ?? const RootWrapper();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteCal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: home,
    );
  }
}

