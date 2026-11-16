import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

/// "Om föreningen": the association's details for every member, plus a link to
/// its own website (`associations.website_url`, set by an admin on the web).
class AssociationInfoPage extends CompositionWidget {
  static const String path = '/association';

  const AssociationInfoPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final contextRef = useContext();
    final theme = useTheme();

    // Pick up changes an admin made on the web since the app started.
    onMounted(() {
      authStore.loadAssociation();
    });

    Future<void> open(Uri uri, String failMessage) async {
      var opened = false;
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('AssociationInfoPage: could not open $uri: $e');
      }
      final context = contextRef.value;
      if (!opened && context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failMessage)));
      }
    }

    return (context) {
      final association = authStore.association.value;
      final colors = theme.value.colorScheme;

      if (association == null) {
        return const GradientScaffold(
          title: 'Om föreningen',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final websiteUri = _websiteUri(association.websiteUrl);
      final email = (association.email ?? '').trim();
      final address = [
        association.streetAddress.trim(),
        [
          association.zipCode.trim(),
          association.locality.trim(),
        ].where((s) => s.isNotEmpty).join(' '),
      ].where((s) => s.isNotEmpty).join('\n');

      return GradientScaffold(
        title: 'Om föreningen',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.apartment_outlined,
                    color: AppTheme.primaryDarken1,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    association.name,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (websiteUri != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () =>
                    open(websiteUri, 'Kunde inte öppna hemsidan.'),
                icon: const Icon(Icons.language),
                label: const Text('Besök hemsidan'),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: colors.outline),
              ),
              child: Column(
                children: _withDividers([
                  if (association.organizationNumber.trim().isNotEmpty)
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Organisationsnummer',
                      value: association.organizationNumber.trim(),
                    ),
                  if (address.isNotEmpty)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Adress',
                      value: address,
                    ),
                  if (email.isNotEmpty)
                    _InfoRow(
                      icon: Icons.mail_outline,
                      label: 'E-post',
                      value: email,
                      onTap: () => open(
                        Uri(scheme: 'mailto', path: email),
                        'Kunde inte öppna e-post.',
                      ),
                    ),
                  if (websiteUri != null)
                    _InfoRow(
                      icon: Icons.language,
                      label: 'Hemsida',
                      value: websiteUri.host,
                      onTap: () =>
                          open(websiteUri, 'Kunde inte öppna hemsidan.'),
                    ),
                ]),
              ),
            ),
          ],
        ),
      );
    };
  }
}

/// The website as an absolute http(s) URI, or null when unset/invalid.
Uri? _websiteUri(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final withScheme = RegExp(r'^https?://', caseSensitive: false).hasMatch(value)
      ? value
      : 'https://$value';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  return uri;
}

List<Widget> _withDividers(List<Widget> rows) => [
  for (var i = 0; i < rows.length; i++) ...[
    if (i > 0) const Divider(height: 1),
    rows[i],
  ],
];

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppTheme.primaryDarken1),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: onTap != null
              ? AppTheme.primaryDarken1
              : theme.colorScheme.onSurface,
        ),
      ),
      trailing: onTap != null
          ? Icon(Icons.open_in_new, size: 18, color: theme.colorScheme.outline)
          : null,
    );
  }
}
