import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../account/pages/account_page.dart';
import '../../auth/pages/login_page.dart';
import '../notification_settings_store.dart';

class SettingsPage extends CompositionWidget {
  static const String path = '/settings';

  const SettingsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final themeStore = inject(themeStoreKey);
    final pocketBase = inject(pocketBaseKey);
    final contextRef = useContext();

    final notificationSettings =
        NotificationSettingsStore(pocketBase, authStore);
    onMounted(notificationSettings.load);

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

    return (context) => GradientScaffold(
      title: 'Inställningar',
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Notiser', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              notificationSettings.hasPushToken.value
                  ? 'Välj push-notis och/eller e-post för varje område. '
                        'Notiserna finns alltid kvar i notislistan.'
                  : 'Du har inga push-notiser registrerade, så e-post är på '
                        'som standard. Notiserna finns alltid kvar i notislistan.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (notificationSettings.loading.value)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (notificationSettings.loadFailed.value)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Kunde inte hämta dina notisinställningar.'),
            )
          else ...[
            const HelpTip(
              id: 'notification-preferences',
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              text:
                  'Slå av det du inte vill bli meddelad om. Viktiga '
                  'e-postmeddelanden, som engångskoder för signering och '
                  'lösenordsåterställning, skickas alltid.',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: SizedBox.shrink()),
                  SizedBox(
                    width: 64,
                    child: Text(
                      'Push',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      'E-post',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            for (final category in notificationSettings.categories.value)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.label),
                          Text(
                            category.description,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Switch(
                        value: notificationSettings
                                .preferences.value[category.key]?.push ??
                            true,
                        onChanged: notificationSettings.saving.value ==
                                '${category.key}:push'
                            ? null
                            : (v) => notificationSettings.setPush(category.key, v),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Switch(
                        value: notificationSettings
                                .preferences.value[category.key]?.email ??
                            false,
                        onChanged: notificationSettings.saving.value ==
                                '${category.key}:email'
                            ? null
                            : (v) => notificationSettings.setEmail(category.key, v),
                      ),
                    ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Signeringsförfrågningar, inbjudningar, lösenordsåterställning '
                'och fakturor skickas alltid.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
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
