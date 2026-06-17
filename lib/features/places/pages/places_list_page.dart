import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import 'place_detail_page.dart';
import 'create_place_page.dart';

class PlacesListPage extends CompositionWidget {
  static const String path = '/places';

  const PlacesListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final placesStore = inject(placesStoreKey);
    final authStore = inject(authStoreKey);

    onMounted(() {
      placesStore.getAllPlaces();
    });

    return (context) {
      final places = placesStore.placesList.value;
      final loading = placesStore.loading.value;
      final canCreate = authStore.hasPermission('places', CrudOperation.create);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Lokaler'),
        ),
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
                : RefreshIndicator(
                    onRefresh: () => placesStore.getAllPlaces(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: places.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: const Icon(Icons.meeting_room_outlined),
                            title: Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              place.streetAddress,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('${PlaceDetailPage.path}/${place.id}'),
                          ),
                        );
                      },
                    ),
                  ),
      );
    };
  }
}
