
import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ThemeModeSelector(),
        ],
      ),
    );
  }
}

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, child) {
        final selectedMode = ThemeController.instance.themeMode;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Choose how MzaziCare looks on your device.'),
                const SizedBox(height: 16),
                RadioGroup<ThemeMode>(
                  groupValue: selectedMode,
                  onChanged: (mode) {
                    if (mode != null) {
                      ThemeController.instance.setThemeMode(mode);
                    }
                  },
                  child: const Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: Text('Light mode'),
                        secondary: Icon(Icons.light_mode_outlined),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: Text('Dark mode'),
                        secondary: Icon(Icons.dark_mode_outlined),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        title: Text('System default'),
                        secondary: Icon(Icons.settings_brightness),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
