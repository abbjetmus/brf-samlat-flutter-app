import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../calendar_store.dart';

class CalendarPage extends CompositionWidget {
  static const String path = '/calendar';

  const CalendarPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final calendarStore = inject(calendarStoreKey);
    final authStore = inject(authStoreKey);
    final currentView = ref(CalendarView.month);
    final contextRef = useContext();

    onMounted(() {
      calendarStore.getAllEvents();
    });

    Future<void> showCreateEventDialog() async {
      final context = contextRef.value;
      if (context == null) return;

      final titleController = TextEditingController();
      final descriptionController = TextEditingController();
      DateTime startDate = DateTime.now();
      DateTime endDate = DateTime.now().add(const Duration(hours: 1));
      String selectedColor = '#2196F3';

      final colors = {
        '#2196F3': 'Blå',
        '#4CAF50': 'Grön',
        '#F44336': 'Röd',
        '#FF9800': 'Orange',
        '#9C27B0': 'Lila',
        '#009688': 'Teal',
      };

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Skapa händelse'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titel',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Beskrivning',
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
                            startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
                            endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: colors.entries.map((entry) {
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: selectedColor == entry.key,
                        selectedColor: CalendarStore.parseColor(entry.key).withValues(alpha: 0.3),
                        onSelected: (selected) {
                          if (selected) setState(() => selectedColor = entry.key);
                        },
                      );
                    }).toList(),
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
                child: const Text('Skapa'),
              ),
            ],
          ),
        ),
      );

      if (result == true && titleController.text.trim().isNotEmpty) {
        await calendarStore.createEvent(
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          startAt: startDate.toUtc().toIso8601String(),
          endAt: endDate.toUtc().toIso8601String(),
          color: selectedColor,
        );
      }

      titleController.dispose();
      descriptionController.dispose();
    }

    return (context) {
      final events = calendarStore.events.value;
      final loading = calendarStore.loading.value;
      final canCreate = authStore.hasPermission('calendar_events', CrudOperation.create);
      final canDelete = authStore.hasPermission('calendar_events', CrudOperation.delete);

      return GradientScaffold(
        title: 'Kalender',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: showCreateEventDialog,
                child: const Icon(Icons.add),
              )
            : null,
        body: Column(
          children: [
            // View selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<CalendarView>(
                segments: const [
                  ButtonSegment(value: CalendarView.day, label: Text('Dag')),
                  ButtonSegment(value: CalendarView.week, label: Text('Vecka')),
                  ButtonSegment(value: CalendarView.month, label: Text('Månad')),
                ],
                selected: {currentView.value},
                onSelectionChanged: (views) {
                  currentView.value = views.first;
                },
              ),
            ),

            // Calendar
            Expanded(
              child: loading && events.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SfCalendar(
                      view: currentView.value,
                      dataSource: _EventDataSource(events),
                      firstDayOfWeek: 1,
                      showNavigationArrow: true,
                      monthViewSettings: const MonthViewSettings(
                        appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
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
                          final appointment = details.appointments!.first as Appointment;
                          final event = appointment.id as CalendarEventsRecord;
                          _showEventDetails(context, event, calendarStore, canDelete);
                        }
                      },
                    ),
            ),
          ],
        ),
      );
    };
  }
}

void _showEventDetails(
  BuildContext context,
  CalendarEventsRecord event,
  CalendarStore calendarStore,
  bool canDelete,
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
                  color: CalendarStore.parseColor(event.color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    await calendarStore.deleteEvent(event.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
            ],
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(event.description!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _formatEventTime(event),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

String _formatEventTime(CalendarEventsRecord event) {
  try {
    final start = DateTime.parse(event.startAt).toLocal();
    final end = DateTime.parse(event.endAt).toLocal();
    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$startStr - $endStr';
  } catch (_) {
    return '${event.startAt} - ${event.endAt}';
  }
}

class _EventDataSource extends CalendarDataSource {
  _EventDataSource(List<CalendarEventsRecord> events) {
    appointments = events.map((e) {
      DateTime startTime;
      DateTime endTime;
      try {
        startTime = DateTime.parse(e.startAt).toLocal();
        endTime = DateTime.parse(e.endAt).toLocal();
      } catch (_) {
        startTime = DateTime.now();
        endTime = DateTime.now().add(const Duration(hours: 1));
      }

      return Appointment(
        startTime: startTime,
        endTime: endTime,
        subject: e.title,
        color: CalendarStore.parseColor(e.color),
        notes: e.description,
        id: e,
      );
    }).toList();
  }
}
