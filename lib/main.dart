import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (AppEnv.isConfigured) {
    // The session is persisted by supabase_flutter in platform storage and refreshed automatically.
    // ignore: deprecated_member_use
    await Supabase.initialize(url: AppEnv.supabaseUrl, anonKey: AppEnv.supabaseAnonKey);
  }
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: AppEnv.isConfigured ? const BudgetPhoneApp() : const _MissingConfigApp(),
  ));
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
