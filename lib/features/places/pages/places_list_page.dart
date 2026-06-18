import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/search_field.dart';
import 'place_detail_page.dart';
import 'create_place_page.dart';

class PlacesListPage extends CompositionWidget {
  static const String path = '/places';

  const PlacesListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final placesStore = inject(placesStoreKey);
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');

    onMounted(() {
      placesStore.getAllPlaces();
    });

    return (context) {
      final places = placesStore.placesList.value;
      final loading = placesStore.listLoading.value;
      final loadingMore = placesStore.loadingMore.value;
      final hasMore = placesStore.hasMore.value;
      final canCreate = authStore.hasPermission('places', CrudOperation.create);

      final query = searchQuery.value.trim().toLowerCase();
      final filteredPlaces = query.isEmpty
          ? places
          : places
                .where(
                  (p) =>
                      p.name.toLowerCase().contains(query) ||
                      p.streetAddress.toLowerCase().contains(query) ||
                      (p.placeType ?? '').toLowerCase().contains(query) ||
                      p.locality.toLowerCase().contains(query),
                )
                .toList();

      return GradientScaffold(
        title: 'Lokaler',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => context.push(CreatePlacePage.path),
                child: const Icon(Icons.add),
              )
            : null,
        body: loading && places.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : places.isEmpty
            ? const Center(child: Text('Inga lokaler ännu.'))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SearchField(
                      hintText: 'Sök lokal...',
                      onChanged: (v) => searchQuery.value = v,
                    ),
                  ),
                  Expanded(
                    child: filteredPlaces.isEmpty
                        ? const Center(child: Text('Inga träffar.'))
                        : PaginatedListView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredPlaces.length,
                            hasMore: hasMore,
                            loadingMore: loadingMore,
                            onLoadMore: placesStore.fetchNextPlaces,
                            onRefresh: placesStore.getAllPlaces,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final place = filteredPlaces[index];
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.meeting_room_outlined,
                                  ),
                                  title: Text(
                                    place.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    place.streetAddress,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(
                                    '${PlaceDetailPage.path}/${place.id}',
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
