import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/search_field.dart';
import 'residence_detail_page.dart';
import 'create_residence_page.dart';

class ResidencesListPage extends CompositionWidget {
  static const String path = '/residences';

  const ResidencesListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final residencesStore = inject(residencesStoreKey);
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');

    onMounted(() {
      residencesStore.getAllResidences();
    });

    return (context) {
      final residences = residencesStore.residencesList.value;
      final loading = residencesStore.listLoading.value;
      final loadingMore = residencesStore.loadingMore.value;
      final hasMore = residencesStore.hasMore.value;
      final canCreate = authStore.hasPermission(
        'residences',
        CrudOperation.create,
      );

      final query = searchQuery.value.trim().toLowerCase();
      final filteredResidences = query.isEmpty
          ? residences
          : residences
                .where(
                  (r) =>
                      r.streetAddress.toLowerCase().contains(query) ||
                      r.locality.toLowerCase().contains(query) ||
                      r.zipCode.toLowerCase().contains(query) ||
                      r.residenceType.toLowerCase().contains(query),
                )
                .toList();

      return GradientScaffold(
        title: 'Bostäder',
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
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SearchField(
                      hintText: 'Sök bostad...',
                      onChanged: (v) => searchQuery.value = v,
                    ),
                  ),
                  Expanded(
                    child: filteredResidences.isEmpty
                        ? const Center(child: Text('Inga träffar.'))
                        : PaginatedListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredResidences.length,
                            hasMore: hasMore,
                            loadingMore: loadingMore,
                            onLoadMore: residencesStore.fetchNextResidences,
                            onRefresh: residencesStore.getAllResidences,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final residence = filteredResidences[index];
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
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(
                                    '${ResidenceDetailPage.path}/${residence.id}',
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      );
    };
  }
}
