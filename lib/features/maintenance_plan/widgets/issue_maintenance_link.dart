import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/pb_error.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../maintenance_plan_store.dart';
import '../pages/maintenance_plan_page.dart';

/// "Kopplad till underhållsplan" on an issue: the plan actions the issue is
/// linked to, with "Koppla" and "Ta bort kopplingen" for those with
/// `maintenance_plan` update. Hidden without read access or when the feature is
/// switched off. Mirrors the web's IssueMaintenanceLink.
class IssueMaintenanceLink extends CompositionWidget {
  final String issueId;

  const IssueMaintenanceLink({super.key, required this.issueId});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final authStore = inject(authStoreKey);
    final store = MaintenancePlanStore(inject(pocketBaseKey), authStore);
    final theme = useTheme();
    final contextRef = useContext();

    final canRead = computed(
      () =>
          authStore.isFeatureEnabled('maintenance_plan') &&
          authStore.hasPermission('maintenance_plan', CrudOperation.read),
    );
    final linked = ref<List<MaintenancePlanItemsRecord>>([]);
    final loading = ref(false);
    final error = ref<String?>(null);

    Future<void> load() async {
      if (!canRead.value) return;
      loading.value = true;
      try {
        linked.value = await store.forIssue(props.value.issueId);
        error.value = null;
      } catch (e) {
        error.value = pbErrorMessage(e, 'Kunde inte hämta kopplingarna.');
      } finally {
        loading.value = false;
      }
    }

    watch(
      () => (props.value.issueId, canRead.value),
      (_, _) => load(),
      immediate: true,
    );

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> setLink(String itemId, bool link) async {
      final message = await store.linkIssue(itemId, props.value.issueId, link);
      if (message != null) {
        snack(message);
        return;
      }
      snack(
        link ? 'Ärendet kopplat till underhållsplanen' : 'Kopplingen borttagen',
      );
      await load();
    }

    Future<void> openPicker() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final linkedIds = linked.value.map((i) => i.id).toSet();
      final selected = await showAppBottomSheet<String>(
        context: ctx,
        builder: (_) => _PickItemSheet(
          load: () async => (await store.allItems())
              .where((i) => !linkedIds.contains(i.id))
              .toList(),
          canCreate: authStore.hasPermission(
            'maintenance_plan',
            CrudOperation.create,
          ),
        ),
      );
      if (selected != null) await setLink(selected, true);
    }

    return (context) {
      if (!canRead.value) return const SizedBox.shrink();
      final scheme = theme.value.colorScheme;
      final canUpdate = authStore.hasPermission(
        'maintenance_plan',
        CrudOperation.update,
      );
      final items = linked.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Kopplad till underhållsplan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (canUpdate)
                      TextButton.icon(
                        onPressed: openPicker,
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text('Koppla'),
                      ),
                  ],
                ),
                if (loading.value && items.isEmpty)
                  const LinearProgressIndicator()
                else if (error.value != null)
                  Text(error.value!, style: TextStyle(color: scheme.error))
                else if (items.isEmpty)
                  Text(
                    'Inte kopplad till någon åtgärd.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(maintenanceComponentMeta(item.component).icon),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item.plannedYear} · '
                        '${maintenanceStatusLabels[item.status] ?? item.status} · '
                        '${formatSek(item.estimatedCost)}',
                      ),
                      onTap: () => context.push(MaintenancePlanPage.path),
                      trailing: canUpdate
                          ? IconButton(
                              icon: const Icon(Icons.link_off),
                              tooltip: 'Ta bort kopplingen',
                              onPressed: () => setLink(item.id, false),
                            )
                          : null,
                    ),
              ],
            ),
          ),
        ],
      );
    };
  }
}

/// Picks one plan action to link; pops its id.
class _PickItemSheet extends CompositionWidget {
  final Future<List<MaintenancePlanItemsRecord>> Function() load;
  final bool canCreate;

  const _PickItemSheet({required this.load, required this.canCreate});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final contextRef = useContext();
    final items = ref<List<MaintenancePlanItemsRecord>>([]);
    final loading = ref(true);
    final error = ref<String?>(null);

    onMounted(() async {
      try {
        items.value = await props.value.load();
      } catch (e) {
        error.value = pbErrorMessage(e, 'Kunde inte hämta underhållsplanen.');
      } finally {
        loading.value = false;
      }
    });

    void pick(String id) {
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) Navigator.of(ctx).pop(id);
    }

    return (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Koppla till underhållsplan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Koppla ärendet till en åtgärd i underhållsplanen, t.ex. när en '
            'felanmälan visar att taket behöver bytas.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          if (loading.value)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error.value != null)
            Text(error.value!, style: const TextStyle(color: Colors.red))
          else if (items.value.isEmpty)
            Text(
              props.value.canCreate
                  ? 'Inga åtgärder att koppla. Lägg till en åtgärd under '
                        'Underhållsplan först.'
                  : 'Inga åtgärder i underhållsplanen.',
            )
          else
            for (final item in items.value)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(maintenanceComponentMeta(item.component).icon),
                title: Text(item.title),
                subtitle: Text(
                  '${item.plannedYear} · '
                  '${maintenanceStatusLabels[item.status] ?? item.status}',
                ),
                onTap: () => pick(item.id),
              ),
        ],
      );
    };
  }
}
