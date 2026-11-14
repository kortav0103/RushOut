import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

/// Root MaterialApp configured with dynamic WCAG AA themes and GoRouter.
class ReadZenApp extends ConsumerWidget {
  const ReadZenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'ReadZen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromMode(themeMode),
      routerConfig: router,
    );
  }
}
