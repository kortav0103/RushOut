import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app/app_dependencies.dart';
import 'app/rush_out_app.dart';
import 'core/services/error_reporting_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReportingService.instance.recordError(
      details.exception,
      details.stack ?? StackTrace.current,
      fatal: true,
      context: details.context?.toDescription() ?? 'FlutterError',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReportingService.instance.recordError(
      error,
      stack,
      fatal: true,
      context: 'PlatformDispatcher',
    );
    return true;
  };

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  } catch (_) {}

  await _loadEnv();

  try {
    final deps = await AppDependencies.init();
    runApp(RushOutApp.fromDependencies(deps));
  } catch (e, stack) {
    ErrorReportingService.instance.recordError(
      e,
      stack,
      fatal: true,
      context: 'AppDependencies.init',
    );
    runApp(const _BootstrapErrorApp());
  }
}

Future<void> _loadEnv() async {
  // Compile-time --dart-define / --dart-define-from-file=.env takes precedence in
  // SupabaseRemoteDataSource. Only fall back to .env.example if available.
  try {
    await dotenv.load(fileName: '.env.example');
  } catch (_) {
    // Graceful fallback when no dotenv asset is used.
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Unable to start RushOut',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please restart the app. If the problem persists, try reinstalling.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final deps = await AppDependencies.init();
                      runApp(RushOutApp.fromDependencies(deps));
                    } catch (e, stack) {
                      ErrorReportingService.instance.recordError(
                        e,
                        stack,
                        fatal: false,
                        context: 'BootstrapRetry',
                      );
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
