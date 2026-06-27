import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/rich_description.dart';
import '../calendar_store.dart';

class CalendarPage extends CompositionWidget {
  static const String path = '/calendar';

  const CalendarPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final calendarStore = inject(calendarStoreKey);
    final authStore = inject(authStoreKey);
    final viewMode = ref(_CalendarViewMode.month);
    // Drive view changes through a controller so SfCalendar reliably switches
    // between Dag/Vecka/Månad (changing only the `view` property is flaky).
    final calendarController = CalendarController()..view = CalendarView.month;
    final contextRef = useContext();

    onMounted(() {
      calendarStore.getAllEvents();
    });

    onUnmounted(calendarController.dispose);

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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: colors.entries.map((entry) {
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: selectedColor == entry.key,
                        selectedColor: CalendarStore.parseColor(
                          entry.key,
                        ).withValues(alpha: 0.3),
                        onSelected: (selected) {
                          if (selected)
                            setState(() => selectedColor = entry.key);
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
      final items = calendarStore.items.value;
      final loading = calendarStore.loading.value;
      final canCreate = authStore.hasPermission(
        'calendar_events',
        CrudOperation.create,
      );
      final canDelete = authStore.hasPermission(
        'calendar_events',
        CrudOperation.delete,
      );

      return GradientScaffold(
        title: 'Kalender',
        showBack: true,
        // Keep the calendar at full height when the keyboard opens for the
        // create-event dialog. Resizing the body squeezes SfCalendar into a
        // tiny height, which makes Syncfusion throw a layout assertion and
        // crash. The dialog floats above the keyboard and scrolls its own
        // content, so it doesn't need the page to shrink.
        resizeToAvoidBottomInset: false,
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_CalendarViewMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _CalendarViewMode.day,
                      label: Text('Dag'),
                    ),
                    ButtonSegment(
                      value: _CalendarViewMode.week,
                      label: Text('Vecka'),
                    ),
                    ButtonSegment(
                      value: _CalendarViewMode.month,
                      label: Text('Månad'),
                    ),
                    ButtonSegment(
                      value: _CalendarViewMode.list,
                      label: Text('Lista'),
                    ),
                  ],
                  selected: {viewMode.value},
                  onSelectionChanged: (modes) {
                    final mode = modes.first;
                    viewMode.value = mode;
                    final view = _toCalendarView(mode);
                    if (view != null) calendarController.view = view;
                  },
                ),
              ),
            ),

            // Calendar or list
            Expanded(
              child: loading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : viewMode.value == _CalendarViewMode.list
                  ? _EventListView(
                      items: items,
                      calendarStore: calendarStore,
                      canDelete: canDelete,
                    )
                  : SfCalendar(
                      controller: calendarController,
                      dataSource: _EventDataSource(items),
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
                          final item = appointment.id as CalendarItem;
                          _showEventDetails(
                            context,
                            item,
                            calendarStore,
                            canDelete,
                          );
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
  CalendarItem event,
  CalendarStore calendarStore,
  bool canDelete,
) {
  showAppBottomSheet(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: event.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                event.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Posts are managed under Inlägg and can't be deleted from here.
            if (canDelete && !event.isPost)
              EntityActionMenu(
                actions: [
                  EntityAction.delete(() async {
                    await calendarStore.deleteEvent(event.id);
                    if (context.mounted) Navigator.of(context).pop();
                  }),
                ],
              ),
          ],
        ),
        if (event.isPost) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Inlägg',
              style: TextStyle(
                color: event.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (event.description.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          RichDescription(html: event.description),
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
  );
}

String _formatEventTime(CalendarItem event) {
  final start = event.start;
  final end = event.end;
  final startStr =
      '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final endStr =
      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  return '$startStr - $endStr';
}

/// The selectable views. The first three map to Syncfusion calendar views;
/// [list] renders a plain scrollable list of events instead of a calendar.
enum _CalendarViewMode { day, week, month, list }

CalendarView? _toCalendarView(_CalendarViewMode mode) {
  switch (mode) {
    case _CalendarViewMode.day:
      return CalendarView.day;
    case _CalendarViewMode.week:
      return CalendarView.week;
    case _CalendarViewMode.month:
      return CalendarView.month;
    case _CalendarViewMode.list:
      return null;
  }
}

/// A simple chronological list of all events, used by the "Lista" view mode.
class _EventListView extends StatelessWidget {
  const _EventListView({
    required this.items,
    required this.calendarStore,
    required this.canDelete,
  });

  final List<CalendarItem> items;
  final CalendarStore calendarStore;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Inga händelser.'));
    }

    final sorted = [...items]..sort((a, b) => a.start.compareTo(b.start));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final event = sorted[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: event.color,
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_formatEventTime(event)),
            trailing: event.isPost
                ? const Icon(Icons.article_outlined, size: 18)
                : const Icon(Icons.chevron_right),
            onTap: () =>
                _showEventDetails(context, event, calendarStore, canDelete),
          ),
        );
      },
    );
  }
}

class _EventDataSource extends CalendarDataSource {
  _EventDataSource(List<CalendarItem> items) {
    appointments = items.map((e) {
      return Appointment(
        startTime: e.start,
        endTime: e.end,
        subject: e.title,
        color: e.color,
        notes: e.description,
        id: e,
      );
    }).toList();
  }
}
