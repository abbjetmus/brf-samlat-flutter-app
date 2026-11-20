import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../dashboard/widgets/dashboard_tasks.dart';
import '../../gadgets/pages/create_gadget_page.dart';
import '../../gadgets/pages/gadget_detail_page.dart';
import '../../places/pages/create_place_page.dart';
import '../../places/pages/place_detail_page.dart';

/// The Boka tab: the association's rooms (Lokaler) and things (Prylar) to
/// book, plus your own upcoming bookings. Booking itself happens on the
/// place/gadget page (tab Bokningar), as before.
class BookPage extends CompositionWidget {
  static const String path = '/book';

  /// 'places' or 'gadgets' (?tab=…); defaults to the first one available.
  final String? tab;

  const BookPage({super.key, this.tab});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final authStore = inject(authStoreKey);
    final placesStore = inject(placesStoreKey);
    final gadgetsStore = inject(gadgetsStoreKey);
    final dashboardStore = inject(dashboardStoreKey);
    final theme = useTheme();

    bool can(String feature) =>
        authStore.isFeatureEnabled(feature) &&
        authStore.hasPermission(feature, CrudOperation.read);

    final selected = ref<String>(props.value.tab ?? 'places');

    onMounted(() {
      if (can('places')) placesStore.getAllPlaces();
      if (can('gadgets')) gadgetsStore.getAllGadgets();
      dashboardStore.loadTasks();
    });

    return (context) {
      final textTheme = theme.value.textTheme;
      final colors = theme.value.colorScheme;
      final showPlaces = can('places');
      final showGadgets = can('gadgets');
      final current = !showGadgets
          ? 'places'
          : !showPlaces
          ? 'gadgets'
          : selected.value;
      final isPlaces = current == 'places';

      final myBookings = dashboardStore.tasks.value.personal
          .where((t) => t.kind == 'booking')
          .toList();

      final loading = isPlaces
          ? placesStore.listLoading.value
          : gadgetsStore.listLoading.value;
      final hasMore = isPlaces
          ? placesStore.hasMore.value
          : gadgetsStore.hasMore.value;
      final loadingMore = isPlaces
          ? placesStore.loadingMore.value
          : gadgetsStore.loadingMore.value;

      final items = isPlaces
          ? [
              for (final p in placesStore.placesList.value)
                _Bookable(
                  name: p.name,
                  facts: [
                    if (placesStore.isSharedWithUs(p))
                      p.associationName ?? 'Delad lokal',
                    _slotText(
                      p.bookingSlotDurationLength,
                      p.bookingSlotDurationType,
                    ),
                    if ((p.maxRoomCapacity ?? 0) > 0)
                      'Max ${p.maxRoomCapacity} personer',
                    if ((p.pricePerSlot ?? 0) > 0) _price(p.pricePerSlot!),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  hours: _hours(p.bookingStartTime, p.bookingEndTime),
                  needsApproval: p.requiresApproval,
                  path: '${PlaceDetailPage.path}/${p.id}',
                ),
            ]
          : [
              for (final g in gadgetsStore.gadgetsList.value)
                _Bookable(
                  name: g.name,
                  facts: [
                    _slotText(
                      g.bookingSlotDurationLength,
                      g.bookingSlotDurationType,
                    ),
                    if ((g.pricePerSlot ?? 0) > 0) _price(g.pricePerSlot!),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  hours: _hours(g.bookingStartTime, g.bookingEndTime),
                  needsApproval: false,
                  path: '${GadgetDetailPage.path}/${g.id}',
                ),
            ];

      final canCreate = authStore.hasPermission(
        isPlaces ? 'places' : 'gadgets',
        CrudOperation.create,
      );

      return GradientScaffold(
        title: 'Boka',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                tooltip: isPlaces ? 'Ny lokal' : 'Ny pryl',
                onPressed: () => context.push(
                  isPlaces ? CreatePlacePage.path : CreateGadgetPage.path,
                ),
                child: const Icon(Icons.add),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: () => Future.wait([
            if (showPlaces) placesStore.getAllPlaces(),
            if (showGadgets) gadgetsStore.getAllGadgets(),
            dashboardStore.loadTasks(),
          ]),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
            children: [
              if (showPlaces && showGadgets) ...[
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'places', label: Text('Lokaler')),
                    ButtonSegment(value: 'gadgets', label: Text('Prylar')),
                  ],
                  selected: {current},
                  onSelectionChanged: (s) => selected.value = s.first,
                ),
                const SizedBox(height: 22),
              ],

              if (myBookings.isNotEmpty) ...[
                DashboardTaskSection(
                  title: 'Dina bokningar',
                  tasks: myBookings,
                  onTap: (t) => context.push(t.path),
                ),
                const SizedBox(height: 24),
              ],

              Text(
                isPlaces ? 'LOKALER' : 'PRYLAR',
                style: textTheme.labelSmall,
              ),
              const SizedBox(height: 10),
              if (loading && items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    isPlaces
                        ? 'Föreningen har inga lokaler att boka än.'
                        : 'Föreningen har inga prylar att låna än.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                for (final item in items) ...[
                  _BookableCard(
                    item: item,
                    onTap: () => context.push(item.path),
                  ),
                  const SizedBox(height: 10),
                ],
                if (hasMore)
                  Center(
                    child: TextButton(
                      onPressed: loadingMore
                          ? null
                          : (isPlaces
                                ? placesStore.fetchNextPlaces
                                : gadgetsStore.fetchNextGadgets),
                      child: Text(loadingMore ? 'Hämtar…' : 'Visa fler'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    };
  }

  static String _slotText(int length, String type) {
    if (length <= 0 || type.isEmpty) return '';
    final unit = type.toLowerCase();
    if (length == 1) {
      const singular = {'timmar': 'timme', 'dagar': 'dag', 'minuter': 'minut'};
      return 'Pass om 1 ${singular[unit] ?? unit}';
    }
    return 'Pass om $length $unit';
  }

  static String _price(double price) =>
      '${price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2)} kr';

  static String _hours(String start, String end) {
    String hm(String v) {
      final t = DateTime.tryParse(v)?.toLocal();
      if (t != null) {
        return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }
      return v.length >= 5 ? v.substring(0, 5) : v;
    }

    if (start.isEmpty || end.isEmpty) return '';
    return 'Bokningsbar ${hm(start)}–${hm(end)}';
  }
}

class _Bookable {
  final String name;
  final String facts;
  final String hours;
  final bool needsApproval;
  final String path;

  const _Bookable({
    required this.name,
    required this.facts,
    required this.hours,
    required this.needsApproval,
    required this.path,
  });
}

class _BookableCard extends StatelessWidget {
  final _Bookable item;
  final VoidCallback onTap;

  const _BookableCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (item.facts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(item.facts, style: theme.textTheme.bodySmall),
                    ],
                    if (item.hours.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(item.hours, style: theme.textTheme.bodySmall),
                    ],
                    if (item.needsApproval) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Godkänns av styrelsen',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Boka'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
