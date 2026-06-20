import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/booking_time_slot_dialog.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/rich_description.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../gadgets_store.dart';
import 'create_gadget_page.dart';

class GadgetDetailPage extends CompositionWidget {
  static const String path = '/gadgets/detail';

  final String gadgetId;

  const GadgetDetailPage({super.key, required this.gadgetId});

  @override
  Widget Function(BuildContext) setup() {
    final gadgetsStore = inject(gadgetsStoreKey);
    final authStore = inject(authStoreKey);
    final viewMode = ref(_BookingViewMode.week);
    final contextRef = useContext();

    onMounted(() {
      gadgetsStore.getGadget(gadgetId);
      gadgetsStore.getBookings(gadgetId);
    });

    Future<void> showAddBookingDialog() async {
      final context = contextRef.value;
      if (context == null) return;

      final gadget = gadgetsStore.currentGadget.value;
      if (gadget == null) return;

      final result = await showBookingTimeSlotDialog(
        context: context,
        bookingStartTime: gadget.bookingStartTime,
        bookingEndTime: gadget.bookingEndTime,
        slotDurationLength: gadget.bookingSlotDurationLength,
        slotDurationType: gadget.bookingSlotDurationType,
        existingBookings: gadgetsStore.bookings.value
            .map(
              (b) => ExistingBooking(
                DateTime.parse(b.startAt),
                DateTime.parse(b.endAt),
              ),
            )
            .toList(),
        isAdmin: authStore.isAdmin.value,
      );

      if (result != null) {
        await gadgetsStore.addBooking(
          gadgetId: gadgetId,
          startAt: result.startAt.toUtc().toIso8601String(),
          endAt: result.endAt.toUtc().toIso8601String(),
          title: result.title,
          isAllDay: result.isAllDay,
          isBlock: result.isBlock,
        );
      }
    }

    return (context) {
      final gadget = gadgetsStore.currentGadget.value;
      final bookings = gadgetsStore.bookings.value;
      final loading = gadgetsStore.loading.value;
      final canCreate = authStore.hasPermission(
        'gadget_bookings',
        CrudOperation.create,
      );
      final canUpdate = authStore.hasPermission(
        'gadgets',
        CrudOperation.update,
      );
      final canDelete = authStore.hasPermission(
        'gadgets',
        CrudOperation.delete,
      );

      if (loading && gadget == null) {
        return const GradientScaffold(
          title: 'Pryl',
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (gadget == null) {
        return const GradientScaffold(
          title: 'Pryl',
          body: Center(child: Text('Pryl hittades inte.')),
        );
      }

      return DefaultTabController(
        length: 2,
        child: GradientScaffold(
          title: gadget.name,
          actions: [
            if (canUpdate || canDelete)
              EntityActionMenu.header(
                actions: [
                  if (canUpdate)
                    EntityAction.update(() {
                      context.push('${CreateGadgetPage.editPath}/${gadget.id}');
                    }),
                  if (canDelete)
                    EntityAction.delete(() async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Radera pryl',
                        message:
                            'Är du säker på att du vill radera denna pryl?',
                        okLabel: 'Radera',
                        okColor: Colors.red,
                      );
                      if (confirmed) {
                        await gadgetsStore.deleteGadget(gadget.id);
                        final ctx = contextRef.value;
                        if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
                      }
                    }),
                ],
              ),
          ],
          floatingActionButton: canCreate
              ? FloatingActionButton(
                  onPressed: showAddBookingDialog,
                  child: const Icon(Icons.add),
                )
              : null,
          body: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Information'),
                  Tab(text: 'Bokningar'),
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
                            gadget.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (gadget.description != null &&
                              gadget.description!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            RichDescription(html: gadget.description!),
                          ],
                          const SizedBox(height: 16),
                          const Divider(),
                          _infoRow(
                            Icons.location_on,
                            '${gadget.streetAddress}, ${gadget.zipCode} ${gadget.locality}',
                          ),
                          _infoRow(
                            Icons.schedule,
                            'Bokningsbar ${gadget.bookingStartTime} - ${gadget.bookingEndTime}',
                          ),
                          _infoRow(
                            Icons.timelapse,
                            '${gadget.bookingSlotDurationLength} ${gadget.bookingSlotDurationType}',
                          ),
                          if (gadget.pricePerSlot != null &&
                              gadget.pricePerSlot! > 0)
                            _infoRow(
                              Icons.payments,
                              '${gadget.pricePerSlot!.toStringAsFixed(0)} kr/slot',
                            ),
                        ],
                      ),
                    ),

                    // Bookings tab
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<_BookingViewMode>(
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: _BookingViewMode.day,
                                  label: Text('Dag'),
                                ),
                                ButtonSegment(
                                  value: _BookingViewMode.week,
                                  label: Text('Vecka'),
                                ),
                                ButtonSegment(
                                  value: _BookingViewMode.month,
                                  label: Text('Månad'),
                                ),
                                ButtonSegment(
                                  value: _BookingViewMode.list,
                                  label: Text('Lista'),
                                ),
                              ],
                              selected: {viewMode.value},
                              onSelectionChanged: (modes) {
                                viewMode.value = modes.first;
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: viewMode.value == _BookingViewMode.list
                              ? _BookingListView(
                                  bookings: bookings,
                                  gadgetsStore: gadgetsStore,
                                  gadgetId: gadgetId,
                                )
                              : SfCalendar(
                                  view:
                                      _toCalendarView(viewMode.value) ??
                                      CalendarView.week,
                                  dataSource: _BookingDataSource(
                                    bookings,
                                    gadget.bookingSlotDurationType == 'Dagar',
                                  ),
                                  firstDayOfWeek: 1,
                                  showNavigationArrow: true,
                                  monthViewSettings: const MonthViewSettings(
                                    appointmentDisplayMode:
                                        MonthAppointmentDisplayMode.appointment,
                                    showAgenda: true,
                                  ),
                                  timeSlotViewSettings:
                                      const TimeSlotViewSettings(
                                        startHour: 6,
                                        endHour: 23,
                                        timeFormat: 'HH:mm',
                                      ),
                                  onTap: (details) {
                                    if (details.appointments != null &&
                                        details.appointments!.isNotEmpty) {
                                      final appointment = details
                                          .appointments!
                                          .first as Appointment;
                                      final booking =
                                          appointment.id as GadgetBookingsRecord;
                                      _showBookingDetails(
                                        context,
                                        booking,
                                        gadgetsStore,
                                        gadgetId,
                                      );
                                    }
                                  },
                                ),
                        ),
                      ],
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

void _showBookingDetails(
  BuildContext context,
  GadgetBookingsRecord booking,
  GadgetsStore gadgetsStore,
  String gadgetId,
) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: GadgetsStore.parseBookingColor(booking.isBlock),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.isBlock
                      ? 'Inte bokningsbar'
                      : (booking.title ?? 'Bokning'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              EntityActionMenu(
                actions: [
                  EntityAction.delete(() async {
                    await gadgetsStore.deleteBooking(booking.id, gadgetId);
                    if (context.mounted) Navigator.of(context).pop();
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (_) {
              try {
                final start = DateTime.parse(booking.startAt).toLocal();
                final end = DateTime.parse(booking.endAt).toLocal();
                return Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
                      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - '
                      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                );
              } catch (_) {
                return const SizedBox.shrink();
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

/// Booking views. The first three map to Syncfusion calendar views; [list]
/// renders a plain scrollable list of bookings instead of a calendar.
enum _BookingViewMode { day, week, month, list }

CalendarView? _toCalendarView(_BookingViewMode mode) {
  switch (mode) {
    case _BookingViewMode.day:
      return CalendarView.day;
    case _BookingViewMode.week:
      return CalendarView.week;
    case _BookingViewMode.month:
      return CalendarView.month;
    case _BookingViewMode.list:
      return null;
  }
}

String _formatBookingTime(GadgetBookingsRecord booking) {
  try {
    final start = DateTime.parse(booking.startAt).toLocal();
    final end = DateTime.parse(booking.endAt).toLocal();
    return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} '
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - '
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '${booking.startAt} - ${booking.endAt}';
  }
}

/// A chronological list of bookings, used by the "Lista" view mode.
class _BookingListView extends StatelessWidget {
  const _BookingListView({
    required this.bookings,
    required this.gadgetsStore,
    required this.gadgetId,
  });

  final List<GadgetBookingsRecord> bookings;
  final GadgetsStore gadgetsStore;
  final String gadgetId;

  DateTime _start(GadgetBookingsRecord b) {
    try {
      return DateTime.parse(b.startAt).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(child: Text('Inga bokningar.'));
    }

    final sorted = [...bookings]..sort((a, b) => _start(a).compareTo(_start(b)));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final booking = sorted[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: GadgetsStore.parseBookingColor(booking.isBlock),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              booking.isBlock
                  ? 'Inte bokningsbar'
                  : (booking.title ?? 'Bokning'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_formatBookingTime(booking)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _showBookingDetails(context, booking, gadgetsStore, gadgetId),
          ),
        );
      },
    );
  }
}

class _BookingDataSource extends CalendarDataSource {
  _BookingDataSource(List<GadgetBookingsRecord> bookings, bool isAllDay) {
    appointments = bookings.map((b) {
      DateTime startTime;
      DateTime endTime;
      try {
        startTime = DateTime.parse(b.startAt).toLocal();
        endTime = DateTime.parse(b.endAt).toLocal();
      } catch (_) {
        startTime = DateTime.now();
        endTime = DateTime.now().add(const Duration(hours: 1));
      }

      return Appointment(
        startTime: startTime,
        endTime: endTime,
        subject: b.isBlock ? 'Inte bokningsbar' : (b.title ?? 'Bokning'),
        color: GadgetsStore.parseBookingColor(b.isBlock),
        isAllDay: isAllDay,
        id: b,
      );
    }).toList();
  }
}
