import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/rich_description.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../gadgets_store.dart';

class GadgetDetailPage extends CompositionWidget {
  static const String path = '/gadgets/detail';

  final String gadgetId;

  const GadgetDetailPage({super.key, required this.gadgetId});

  @override
  Widget Function(BuildContext) setup() {
    final gadgetsStore = inject(gadgetsStoreKey);
    final authStore = inject(authStoreKey);
    final currentView = ref(CalendarView.week);
    final contextRef = useContext();

    onMounted(() {
      gadgetsStore.getGadget(gadgetId);
      gadgetsStore.getBookings(gadgetId);
    });

    Future<void> showAddBookingDialog() async {
      final context = contextRef.value;
      if (context == null) return;

      final titleController = TextEditingController();
      DateTime startDate = DateTime.now();
      DateTime endDate = DateTime.now().add(const Duration(hours: 1));

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Ny bokning'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titel (valfritt)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start'),
                    subtitle: Text(
                      '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')} ${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startDate),
                        );
                        if (time != null) {
                          setState(() {
                            startDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            if (endDate.isBefore(startDate)) {
                              endDate = startDate.add(const Duration(hours: 1));
                            }
                          });
                        }
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Slut'),
                    subtitle: Text(
                      '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')} ${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(endDate),
                        );
                        if (time != null) {
                          setState(() {
                            endDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Avbryt'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Boka'),
              ),
            ],
          ),
        ),
      );

      if (result == true) {
        await gadgetsStore.addBooking(
          gadgetId: gadgetId,
          startAt: startDate.toUtc().toIso8601String(),
          endAt: endDate.toUtc().toIso8601String(),
          title: titleController.text.trim(),
        );
      }

      titleController.dispose();
    }

    return (context) {
      final gadget = gadgetsStore.currentGadget.value;
      final bookings = gadgetsStore.bookings.value;
      final loading = gadgetsStore.loading.value;
      final canCreate = authStore.hasPermission(
        'gadget_bookings',
        CrudOperation.create,
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
            if (canDelete)
              EntityActionMenu.header(
                actions: [
                  EntityAction.delete(() async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Radera pryl',
                      message: 'Är du säker på att du vill radera denna pryl?',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: SegmentedButton<CalendarView>(
                            segments: const [
                              ButtonSegment(
                                value: CalendarView.day,
                                label: Text('Dag'),
                              ),
                              ButtonSegment(
                                value: CalendarView.week,
                                label: Text('Vecka'),
                              ),
                              ButtonSegment(
                                value: CalendarView.month,
                                label: Text('Månad'),
                              ),
                            ],
                            selected: {currentView.value},
                            onSelectionChanged: (views) {
                              currentView.value = views.first;
                            },
                          ),
                        ),
                        Expanded(
                          child: SfCalendar(
                            view: currentView.value,
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
                            timeSlotViewSettings: const TimeSlotViewSettings(
                              startHour: 6,
                              endHour: 23,
                              timeFormat: 'HH:mm',
                            ),
                            onTap: (details) {
                              if (details.appointments != null &&
                                  details.appointments!.isNotEmpty) {
                                final appointment =
                                    details.appointments!.first as Appointment;
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
