import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/data/error_reporter.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  ErrorReporter reporter = const NoopErrorReporter();
  if (AppEnv.isConfigured) {
    // The session is persisted by supabase_flutter in platform storage and refreshed automatically.
    // ignore: deprecated_member_use
    await Supabase.initialize(url: AppEnv.supabaseUrl, anonKey: AppEnv.supabaseAnonKey);
    final info = await PackageInfo.fromPlatform().catchError((Object _) => PackageInfo(appName: '', packageName: '', version: 'unknown', buildNumber: ''));
    reporter = RemoteErrorReporter(
      appVersion: info.version, buildNumber: info.buildNumber, platform: Platform.isIOS ? 'ios' : 'android',
      send: (body) => Supabase.instance.client.functions.invoke('report-error', body: body),
    );
  }
  _installErrorHandlers(reporter);
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs), errorReporterProvider.overrideWithValue(reporter)],
    child: AppEnv.isConfigured ? const BudgetPhoneApp() : const _MissingConfigApp(),
  ));
}

/// Every uncaught error is reported once (scrubbed, rate limited) and the app keeps running with a friendly state
/// instead of a red error screen. Nothing here ever throws.
void _installErrorHandlers(ErrorReporter reporter) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.report(details.exception, details.stack, operation: details.library ?? 'flutter', category: 'flutter');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report(error, stack, category: 'unhandled', fatal: true);
    return true; // handled: do not crash the process on a stray async error
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const Material(
          child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Something went wrong on this screen. Please go back and try again.', textAlign: TextAlign.center))),
        );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This build is missing its environment configuration.\n\n'
                'Run with --dart-define-from-file=env/dev.json (see env/dev.example.json).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
