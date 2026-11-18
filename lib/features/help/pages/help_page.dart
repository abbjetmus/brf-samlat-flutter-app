import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_description.dart';
import '../../../shared/widgets/search_field.dart';

/// Kategoriernas ikoner. Kategorierna (faq.tags) heter som menyposterna, så
/// ikonerna motsvarar webbens meny. Ordningen kommer från faq.position.
const Map<String, IconData> _categoryIcons = {
  'Kom igång': Icons.rocket_launch_outlined,
  'Inlägg': Icons.newspaper_outlined,
  'Meddelanden': Icons.chat_bubble_outline,
  'Kalender': Icons.calendar_today_outlined,
  'Enkäter': Icons.assignment_outlined,
  'Felanmälan': Icons.report_problem_outlined,
  'Lokaler': Icons.meeting_room_outlined,
  'Prylar': Icons.inventory_2_outlined,
  'Parkeringar': Icons.directions_car_outlined,
  'Bostäder': Icons.home_outlined,
  'Ansökningar': Icons.description_outlined,
  'Underhållsplan': Icons.construction_outlined,
  'Dokument': Icons.folder_outlined,
  'Fakturor': Icons.receipt_long_outlined,
  'Styrelsen': Icons.groups_outlined,
  'Årshjul': Icons.donut_large_outlined,
  'Föreningsstämma': Icons.gavel_outlined,
  'Signering': Icons.draw_outlined,
  'Användare': Icons.people_outline,
  'Rättigheter': Icons.admin_panel_settings_outlined,
  'Föreningen': Icons.apartment_outlined,
  'Konto & inställningar': Icons.manage_accounts_outlined,
  'Appen': Icons.smartphone_outlined,
};

IconData _iconFor(String category) =>
    _categoryIcons[category] ?? Icons.help_outline;

/// Vem som ser vilken kategori — samma tabell som webbens HELP_CATEGORY_ACCESS
/// (brf-samlat-nuxt-app/app/utils/helpContent.ts). Värdet är funktionerna
/// (feature- och läsbehörighetstoken) varav minst en måste vara påslagen och
/// läsbar; [_adminOnly] betyder bara administratörer. Kategorier som saknas här
/// (Kom igång, Konto & inställningar, Appen, Signering, nya) syns för alla.
const _adminOnly = <String>['__admin__'];
const Map<String, List<String>> _categoryAccess = {
  'Inlägg': ['posts'],
  'Meddelanden': ['chat'],
  'Kalender': ['calendar_events'],
  'Enkäter': ['forms'],
  'Felanmälan': ['issues'],
  'Lokaler': ['places'],
  'Prylar': ['gadgets'],
  'Parkeringar': ['parking_lots'],
  'Bostäder': ['residences'],
  'Ansökningar': ['residence_applications'],
  'Underhållsplan': ['maintenance_plan'],
  'Dokument': ['folders_and_files'],
  'Fakturor': ['invoices'],
  'Styrelsen': ['board', 'board_meetings'],
  'Årshjul': ['annual_wheel'],
  'Föreningsstämma': ['general_meetings'],
  'Användare': _adminOnly,
  'Rättigheter': _adminOnly,
  'Föreningen': _adminOnly,
};

/// Hjälp: vanliga frågor ur PocketBase-samlingen `faq` — samma innehåll som
/// webbens /portal/help, så texterna sköts på ett ställe (i databasen).
class HelpPage extends CompositionWidget {
  static const String path = '/help';

  const HelpPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final pb = inject(pocketBaseKey);
    final theme = useTheme();

    final faqs = ref<List<FaqRecord>>([]);
    final loading = ref(true);
    final failed = ref(false);
    final query = ref('');

    Future<void> load() async {
      try {
        final records = await pb
            .collection(Collections.faq)
            .getFullList(sort: 'position,title');
        faqs.value =
            records.map((r) => FaqRecord.fromJson(r.toJson())).toList();
        failed.value = false;
      } catch (e) {
        debugPrint('Kunde inte hämta hjälptexterna: $e');
        failed.value = true;
      } finally {
        loading.value = false;
      }
    }

    onMounted(load);

    /// Bara kategorier för påslagna funktioner som användaren får läsa, och
    /// administratörskategorierna bara för administratörer.
    bool categoryVisible(String? category) {
      final access = _categoryAccess[category ?? ''];
      if (access == null) return true;
      if (identical(access, _adminOnly)) return authStore.isAdmin.value;
      return access.any(
        (token) =>
            authStore.isFeatureEnabled(token) &&
            authStore.hasPermission(token, CrudOperation.read),
      );
    }

    final allowed = computed(
      () => faqs.value.where((faq) => categoryVisible(faq.tags)).toList(),
    );

    /// Sökningen tittar på frågan, kategorin och svaret (utan HTML), bland de
    /// frågor användaren får se.
    final visible = computed(() {
      final term = query.value.trim().toLowerCase();
      if (term.isEmpty) return allowed.value;
      return allowed.value.where((faq) {
        final answer = faq.description.replaceAll(RegExp(r'<[^>]+>'), ' ');
        return [faq.title, faq.tags ?? '', answer]
            .any((v) => v.toLowerCase().contains(term));
      }).toList();
    });

    /// Grupperat per kategori, i den ordning kategorierna först förekommer.
    final groups = computed(() {
      final map = <String, List<FaqRecord>>{};
      for (final faq in visible.value) {
        final category =
            (faq.tags?.isNotEmpty ?? false) ? faq.tags! : 'Övrigt';
        map.putIfAbsent(category, () => []).add(faq);
      }
      return map.entries.toList();
    });

    Future<void> sendEmail(String email) async {
      final uri = Uri(scheme: 'mailto', path: email);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }

    return (context) {
      final t = theme.value;
      final associationEmail = authStore.association.value?.email;
      final searching = query.value.trim().isNotEmpty;
      // En sökning med få träffar visar svaren direkt.
      final expandAll = searching && visible.value.length <= 3;

      Widget sectionTitle(String text, {IconData? icon}) => Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: t.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(
                  text.toUpperCase(),
                  style: t.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );

      Widget faqContent() {
        if (loading.value) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (failed.value || allowed.value.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              failed.value
                  ? 'Hjälptexterna kunde inte hämtas. Dra nedåt för att försöka igen.'
                  : 'Inga hjälptexter än.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
            ),
          );
        }
        if (searching && visible.value.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Inga träffar. Prova ett annat ord, eller kontakta oss nedan.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in groups.value) ...[
              sectionTitle(group.key, icon: _iconFor(group.key)),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < group.value.length; i++) ...[
                      ExpansionTile(
                        // Ny nyckel när sökningen ändras, så att
                        // initiallyExpanded gäller för de nya träffarna.
                        key: ValueKey(
                            '${group.value[i].id}-$expandAll-${query.value}'),
                        initiallyExpanded: expandAll,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(
                          group.value[i].title,
                          style: t.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichDescription(
                            html: group.value[i].description,
                            fontSize: 15,
                          ),
                        ],
                      ),
                      if (i < group.value.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      }

      return GradientScaffold(
        title: 'Hjälp',
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              SearchField(
                hintText: 'Sök i hjälpen',
                onChanged: (value) => query.value = value,
              ),
              if (searching && !loading.value)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(
                    visible.value.length == 1
                        ? '1 träff'
                        : '${visible.value.length} träffar',
                    style: t.textTheme.bodySmall
                        ?.copyWith(color: t.hintColor),
                  ),
                ),
              faqContent(),
              sectionTitle('Kontakt', icon: Icons.mail_outline),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (associationEmail != null &&
                        associationEmail.isNotEmpty)
                      ListTile(
                        leading: Icon(
                          Icons.email_outlined,
                          color: t.colorScheme.primary,
                        ),
                        title: const Text('Kontakta styrelsen'),
                        subtitle: Text(associationEmail),
                        onTap: () => sendEmail(associationEmail),
                      ),
                    ListTile(
                      leading: Icon(
                        Icons.support_agent_outlined,
                        color: t.colorScheme.primary,
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
                  style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    };
  }
}
