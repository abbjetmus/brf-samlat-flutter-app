import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

class HelpPage extends CompositionWidget {
  static const String path = '/help';

  const HelpPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);

    const faqs = [
      _Faq(
        'Hur gör jag en felanmälan?',
        'Gå till "Felanmälan & ärenden" från startsidan och tryck på plusknappen. '
            'Beskriv felet, lägg gärna till en bild, och skicka in. Styrelsen får då en '
            'notis och kan följa upp ärendet.',
      ),
      _Faq(
        'Var hittar jag föreningens dokument?',
        'Under "Dokument" på startsidan finns föreningens filer och mappar, '
            'till exempel stadgar, årsredovisningar och protokoll.',
      ),
      _Faq(
        'Hur bokar jag en lokal eller pryl?',
        'Öppna "Lokaler" eller "Prylar", välj objektet och följ instruktionerna '
            'för bokning. Du ser där vilka tider som är lediga.',
      ),
      _Faq(
        'Varför ser jag inte alla menyval?',
        'Vilka delar du ser styrs av din roll i föreningen. Styrelsen kan ge dig '
            'utökad behörighet vid behov.',
      ),
      _Faq(
        'Hur ändrar jag mina uppgifter eller lösenord?',
        'Gå till "Mitt konto" via menyn. Där kan du uppdatera namn, e-post och lösenord.',
      ),
    ];

    Future<void> sendEmail(String email) async {
      final uri = Uri(scheme: 'mailto', path: email);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }

    return (context) {
      final theme = Theme.of(context);
      final association = authStore.association.value;
      final associationEmail = association?.email;

      return GradientScaffold(
        title: 'Hjälp',
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Text(
                'Vanliga frågor',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < faqs.length; i++) ...[
                    ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Icon(
                        Icons.help_outline,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(faqs[i].question),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(faqs[i].answer)],
                    ),
                    if (i < faqs.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Text(
                'Kontakt',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              child: Column(
                children: [
                  if (associationEmail != null && associationEmail.isNotEmpty)
                    ListTile(
                      leading: Icon(
                        Icons.email_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Kontakta styrelsen'),
                      subtitle: Text(associationEmail),
                      onTap: () => sendEmail(associationEmail),
                    ),
                  ListTile(
                    leading: Icon(
                      Icons.support_agent_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Teknisk support'),
                    subtitle: const Text('support@brfsamlat.se'),
                    onTap: () => sendEmail('support@brfsamlat.se'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'BRF Samlat',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    };
  }
}
