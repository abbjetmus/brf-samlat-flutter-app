import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class ResidenceDetailPage extends CompositionWidget {
  static const String path = '/residences/detail';

  final String residenceId;

  const ResidenceDetailPage({super.key, required this.residenceId});

  @override
  Widget Function(BuildContext) setup() {
    final residencesStore = inject(residencesStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    onMounted(() {
      residencesStore.getResidence(residenceId);
      residencesStore.getResidenceIssues(residenceId);
    });

    return (context) {
      final residence = residencesStore.currentResidence.value;
      final issues = residencesStore.residenceIssues.value;
      final loading = residencesStore.loading.value;
      final canDelete = authStore.hasPermission('residences', CrudOperation.delete);

      if (loading && residence == null) {
        return const GradientScaffold(
          title: 'Bostad',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (residence == null) {
        return const GradientScaffold(
          title: 'Bostad',
          body: Center(child: Text('Bostad hittades inte.')),
        );
      }

      return DefaultTabController(
        length: 2,
        child: GradientScaffold(
          title: residence.streetAddress,
          actions: [
            if (canDelete)
              HeaderIconButton(
                icon: Icons.delete_outline,
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Radera bostad',
                    message: 'Är du säker på att du vill radera denna bostad?',
                    okLabel: 'Radera',
                    okColor: Colors.red,
                  );
                  if (confirmed) {
                    await residencesStore.deleteResidence(residence.id);
                    final ctx = contextRef.value;
                    if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
                  }
                },
              ),
          ],
          body: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Information'),
                  Tab(text: 'Ärenden'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
              // Info tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      residence.streetAddress,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    _infoRow(Icons.location_on, '${residence.streetAddress}, ${residence.zipCode} ${residence.locality}'),
                    _infoRow(Icons.home, residence.residenceType),
                    if (residence.moveInDate != null && residence.moveInDate!.isNotEmpty)
                      _infoRow(Icons.calendar_today, 'Inflyttningsdatum: ${residence.moveInDate}'),
                  ],
                ),
              ),

              // Issues tab
              issues.isEmpty
                  ? const Center(child: Text('Inga ärenden för denna bostad.'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: issues.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final issue = issues[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: Icon(
                              issue.isResolved
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: issue.isResolved ? Colors.green : Colors.orange,
                            ),
                            title: Text(
                              issue.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              issue.isResolved ? 'Löst' : 'Olöst',
                              style: TextStyle(
                                color: issue.isResolved ? Colors.green : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
                ),
              ),
            ],
          ),
        ),
      );
    };
  }
}

Widget _infoRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
