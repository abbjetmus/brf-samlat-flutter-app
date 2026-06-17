import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import 'residence_detail_page.dart';
import 'create_residence_page.dart';

class ResidencesListPage extends CompositionWidget {
  static const String path = '/residences';

  const ResidencesListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final residencesStore = inject(residencesStoreKey);
    final authStore = inject(authStoreKey);

    onMounted(() {
      residencesStore.getAllResidences();
    });

    return (context) {
      final residences = residencesStore.residencesList.value;
      final loading = residencesStore.loading.value;
      final canCreate = authStore.hasPermission('residences', CrudOperation.create);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Bostäder'),
        ),
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => context.push(CreateResidencePage.path),
                child: const Icon(Icons.add),
              )
            : null,
        body: loading && residences.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : residences.isEmpty
                ? const Center(child: Text('Inga bostäder ännu.'))
                : RefreshIndicator(
                    onRefresh: () => residencesStore.getAllResidences(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: residences.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final residence = residences[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: const Icon(Icons.home_outlined),
                            title: Text(
                              residence.streetAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              residence.residenceType,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('${ResidenceDetailPage.path}/${residence.id}'),
                          ),
                        );
                      },
                    ),
                  ),
      );
    };
  }
}
