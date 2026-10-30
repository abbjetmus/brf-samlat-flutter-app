import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/status_chip.dart';
import '../residence_applications_store.dart';
import 'create_residence_application_page.dart';
import 'residence_application_detail_page.dart';

/// "Ansökningar": the member's own applications with their status. Users with
/// `residence_applications` update (the board) see every application in the
/// association instead, with status and type filters, and decide on them from
/// the detail page.
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

    final isBoard = computed(
      () =>
          authStore.currentUser.value != null &&
          authStore.hasPermission(
            'residence_applications',
            CrudOperation.update,
          ),
    );

    Future<void> reload() =>
        isBoard.value ? store.refreshAll() : store.refresh();

    watch(
      () => (
        authStore.currentUser.value?.id,
        isBoard.value,
        store.filter.value,
        store.typeFilter.value,
      ),
      (value, _) {
        final userId = value.$1;
        if (userId != null && userId.isNotEmpty) reload();
      },
      immediate: true,
    );

    return (context) {
      final board = isBoard.value;
      final items = board ? store.all.value : store.mine.value;
      final listLoading = board
          ? store.allLoading.value
          : store.loading.value;
      final canCreate = authStore.hasPermission(
        'residence_applications',
        CrudOperation.create,
      );

      Future<void> openCreate() async {
        final created = await context.push<bool>(
          CreateResidenceApplicationPage.path,
        );
        if (created == true) await reload();
      }

      final tip = board
          ? const HelpTip(
              id: 'residence-applications-admin',
              padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
              text:
                  'Här samlas medlemmarnas ansökningar. Tryck på en ansökan och '
                  'välj Fatta beslut i menyn. Den sökande får beskedet via push '
                  'och e-post. Beviljad andrahand som slutar inom 30 dagar visas '
                  'under Att hantera.',
            )
          : const HelpTip(
              id: 'residence-applications-member',
              padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
              text:
                  'Ansök om andrahandsuthyrning, överlåtelse, medlemskap eller '
                  'ombyggnad för din bostad. Du får besked via push och e-post, '
                  'och kan återkalla ansökan så länge den inte är avgjord.',
            );

      Widget chipRow(List<Widget> chips) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (final chip in chips)
              Padding(padding: const EdgeInsets.only(right: 6), child: chip),
          ],
        ),
      );

      final filters = board
          ? Column(
              children: [
                chipRow([
                  for (final f in ApplicationFilter.values)
                    FilterChip(
                      label: Text(f.label),
                      selected: store.filter.value == f,
                      showCheckmark: false,
                      onSelected: (_) => store.filter.value = f,
                    ),
                ]),
                const SizedBox(height: 4),
                chipRow([
                  FilterChip(
                    label: const Text('Alla typer'),
                    selected: store.typeFilter.value == null,
                    showCheckmark: false,
                    onSelected: (_) => store.typeFilter.value = null,
                  ),
                  for (final t in applicationTypes)
                    FilterChip(
                      label: Text(t.title),
                      selected: store.typeFilter.value == t.value,
                      showCheckmark: false,
                      onSelected: (_) => store.typeFilter.value = t.value,
                    ),
                ]),
              ],
            )
          : null;

      final Widget body;
      if (listLoading && items.isEmpty) {
        body = Column(
          children: [
            tip,
            ?filters,
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        );
      } else if (board && items.isEmpty) {
        body = RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              tip,
              ?filters,
              const SizedBox(height: 60),
              const Icon(Icons.assignment_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                store.filter.value == ApplicationFilter.active
                    ? 'Inga ansökningar att hantera just nu.'
                    : 'Inga ansökningar matchar filtret.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      } else if (items.isEmpty) {
        body = RefreshIndicator(
          onRefresh: store.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            children: const [
              HelpTip(
                id: 'residence-applications-member',
                padding: EdgeInsets.fromLTRB(0, 4, 0, 4),
                text:
                    'Ansök om andrahandsuthyrning, överlåtelse, medlemskap eller '
                    'ombyggnad för din bostad. Du får besked via push och e-post, '
                    'och kan återkalla ansökan så länge den inte är avgjord.',
              ),
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
          itemCount: items.length + 1,
          hasMore: board ? store.allHasMore.value : store.hasMore.value,
          loadingMore: board
              ? store.allLoadingMore.value
              : store.loadingMore.value,
          onLoadMore: board ? store.loadMoreAll : store.loadMore,
          onRefresh: reload,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(children: [tip, ?filters]);
            }
            final a = items[index - 1];
            final type = applicationTypeMeta(a.type);
            final subtitle = <String>[
              if (a.residenceAddress.isNotEmpty) a.residenceAddress,
              if (board && a.applicantName.isNotEmpty) a.applicantName,
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
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusChip(
                      label: applicationStatusLabels[a.status] ?? a.status,
                      tone: applicationStatusTone(a.status),
                    ),
                    if (board && a.endingSoon)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Slutar om ${a.daysLeft} d',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () async {
                  await context.push(
                    '${ResidenceApplicationDetailPage.path}/${a.id}',
                  );
                  await reload();
                },
              ),
            );
          },
        );
      }

      return GradientScaffold(
        title: 'Ansökningar',
        subtitle: board
            ? 'Medlemmarnas ansökningar till styrelsen'
            : 'Andrahand, överlåtelse, medlemskap, ombyggnad',
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
