import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/status_chip.dart';
import '../residence_applications_store.dart';
import 'create_residence_application_page.dart';
import 'residence_application_detail_page.dart';

/// "Ansökningar": the member's own applications with their status.
class ResidenceApplicationsPage extends CompositionWidget {
  static const String path = '/residence-applications';

  const ResidenceApplicationsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final store = ResidenceApplicationsStore(
      inject(pocketBaseKey),
      authStore,
    );

    watch(() => authStore.currentUser.value?.id, (userId, _) {
      if (userId != null && userId.isNotEmpty) store.refresh();
    }, immediate: true);

    return (context) {
      final items = store.mine.value;
      final canCreate = authStore.hasPermission(
        'residence_applications',
        CrudOperation.create,
      );

      Future<void> openCreate() async {
        final created = await context.push<bool>(
          CreateResidenceApplicationPage.path,
        );
        if (created == true) await store.refresh();
      }

      final Widget body;
      if (store.loading.value && items.isEmpty) {
        body = const Center(child: CircularProgressIndicator());
      } else if (items.isEmpty) {
        body = RefreshIndicator(
          onRefresh: store.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(32),
            children: const [
              SizedBox(height: 80),
              Icon(Icons.assignment_outlined, size: 48),
              SizedBox(height: 12),
              Text(
                'Du har inga ansökningar.\nHär ansöker du om andrahandsuthyrning, '
                'överlåtelse, medlemskap eller ombyggnad för din bostad.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      } else {
        body = PaginatedListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          itemCount: items.length,
          hasMore: store.hasMore.value,
          loadingMore: store.loadingMore.value,
          onLoadMore: store.loadMore,
          onRefresh: store.refresh,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final a = items[index];
            final type = applicationTypeMeta(a.type);
            final subtitle = <String>[
              if (a.residenceAddress.isNotEmpty) a.residenceAddress,
              'Inskickad ${AppDateUtils.formatDate(a.created)}',
              if (a.type == 'andrahand' && a.periodFrom != null)
                '${AppDateUtils.formatDate(a.periodFrom)} – ${AppDateUtils.formatDate(a.periodTo)}',
            ];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(type.icon),
                title: Text(type.title),
                subtitle: Text(subtitle.join(' · ')),
                trailing: StatusChip(
                  label: applicationStatusLabels[a.status] ?? a.status,
                  tone: applicationStatusTone(a.status),
                ),
                onTap: () async {
                  await context.push(
                    '${ResidenceApplicationDetailPage.path}/${a.id}',
                  );
                  await store.refresh();
                },
              ),
            );
          },
        );
      }

      return GradientScaffold(
        title: 'Ansökningar',
        subtitle: 'Andrahand, överlåtelse, medlemskap, ombyggnad',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: openCreate,
                child: const Icon(Icons.add),
              )
            : null,
        body: body,
      );
    };
  }
}
