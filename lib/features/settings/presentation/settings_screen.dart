import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';

/// Tab 4: Settings screen with global Theme Switcher, Voice Packs, and Storage info.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: AppThemeMode.values.map((mode) {
                final selected = activeTheme == mode;
                return ListTile(
                  key: Key('theme_option_${mode.storageKey}'),
                  title: Text(mode.label),
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onTap: () =>
                      ref.read(themeControllerProvider.notifier).setTheme(mode),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'AI Voice Packs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.record_voice_over_outlined),
              title: Text('Kokoro-82M & Piper Voice Manager'),
              subtitle: Text('Download & preview manager completes in Milestone 6.'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Storage & Cache',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.cleaning_services_outlined),
              title: Text('Cache & Offline Storage'),
              subtitle: Text('Safe Cache Cleaner completes in Milestone 6.'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'About App',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('ReadZen v1.0.0'),
              subtitle: Text('100% Free · Offline-First · No Account Required'),
            ),
          ),
        ],
      ),
    );
  }
}
