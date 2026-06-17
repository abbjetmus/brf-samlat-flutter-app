import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../account/pages/account_page.dart';
import '../../auth/pages/login_page.dart';

class SettingsPage extends CompositionWidget {
  static const String path = '/settings';

  const SettingsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final themeStore = inject(themeStoreKey);
    final contextRef = useContext();

    void handleSignOut() {
      showDialog(
        context: contextRef.value!,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Logga ut'),
          content: const Text('Är du säker på att du vill logga ut?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                authStore.signOut();
                contextRef.value?.go(LoginPage.path);
              },
              child: const Text('Logga ut'),
            ),
          ],
        ),
      );
    }

    return (context) => Scaffold(
      appBar: AppBar(
        title: const Text('Inställningar'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Utseende', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Ljust'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Mörkt'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {themeStore.themeMode.value},
              onSelectionChanged: (selection) =>
                  themeStore.setThemeMode(selection.first),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.person_outlined),
            title: const Text('Mitt konto'),
            subtitle: const Text('Namn, e-post, lösenord'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AccountPage.path),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logga ut',
              style: TextStyle(color: Colors.red),
            ),
            onTap: handleSignOut,
          ),
        ],
      ),
    );
  }
}
