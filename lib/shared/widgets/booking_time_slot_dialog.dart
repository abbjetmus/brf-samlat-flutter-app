import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

/// Result returned by [showBookingTimeSlotDialog] when the user confirms a
/// booking. Times are in local time; convert with `.toUtc()` before sending.
class BookingDialogResult {
  final DateTime startAt;
  final DateTime endAt;
  final String title;
  final bool isAllDay;
  final bool isBlock;

  const BookingDialogResult({
    required this.startAt,
    required this.endAt,
    required this.title,
    required this.isAllDay,
    required this.isBlock,
  });
}

/// An existing booking, used to mark slots / days as taken.
class ExistingBooking {
  final DateTime start;
  final DateTime end;
  const ExistingBooking(this.start, this.end);
}

/// Shows the booking dialog whose time picker mirrors the web app
/// (GadgetDetailsPage.vue / TimeSlotSelector.vue):
///
/// * For `Minuter` / `Timmar` durations the user picks a date and then a
///   discrete slot generated between [bookingStartTime] and [bookingEndTime],
///   e.g. 08:00 - 09:00, 09:00 - 10:00, ...
/// * For `Dagar` durations the user picks a date and the booking spans
///   [slotDurationLength] day(s), with fixed check-in / check-out times.
Future<BookingDialogResult?> showBookingTimeSlotDialog({
  required BuildContext context,
  required String bookingStartTime,
  required String bookingEndTime,
  required int slotDurationLength,
  required String slotDurationType,
  List<ExistingBooking> existingBookings = const [],
  bool isAdmin = false,
}) {
  return showDialog<BookingDialogResult>(
    context: context,
    builder: (_) => _BookingTimeSlotDialog(
      bookingStartTime: bookingStartTime,
      bookingEndTime: bookingEndTime,
      slotDurationLength: slotDurationLength,
      slotDurationType: slotDurationType,
      existingBookings: existingBookings,
      isAdmin: isAdmin,
    ),
  );
}

class _Slot {
  final String start; // "HH:mm"
  final String end; // "HH:mm" (may be "24:00")
  const _Slot(this.start, this.end);

  String get display => '$start - $end';
}

class _BookingTimeSlotDialog extends CompositionWidget {
  final String bookingStartTime;
  final String bookingEndTime;
  final int slotDurationLength;
  final String slotDurationType;
  final List<ExistingBooking> existingBookings;
  final bool isAdmin;

  const _BookingTimeSlotDialog({
    required this.bookingStartTime,
    required this.bookingEndTime,
    required this.slotDurationLength,
    required this.slotDurationType,
    required this.existingBookings,
    required this.isAdmin,
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();
    final (titleController, _, _) = useTextEditingController();

    final now = DateTime.now();
    final selectedDate = ref(DateTime(now.year, now.month, now.day));
    final selectedSlot = ref<String?>(null); // display e.g. "08:00 - 09:00"
    final isBlock = ref(false);

    bool isDays() => props.value.slotDurationType == 'Dagar';

    // --- Slot generation (mirrors TimeSlotSelector.vue) ---

    int durationInMinutes() => props.value.slotDurationType == 'Timmar'
        ? props.value.slotDurationLength * 60
        : props.value.slotDurationLength;

    String formatMinutes(int totalMinutes) {
      final h = (totalMinutes ~/ 60) % 24;
      final m = totalMinutes % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    List<_Slot> generateSlots() {
      final slots = <_Slot>[];
      final duration = durationInMinutes();
      if (duration <= 0) return slots;

      final startParts = props.value.bookingStartTime.split(':');
      final endParts = props.value.bookingEndTime.split(':');
      if (startParts.length != 2 || endParts.length != 2) return slots;

      final startTotal =
          (int.tryParse(startParts[0]) ?? 0) * 60 +
          (int.tryParse(startParts[1]) ?? 0);
      final endTotal =
          (int.tryParse(endParts[0]) ?? 0) * 60 +
          (int.tryParse(endParts[1]) ?? 0);

      final totalSlots = ((endTotal - startTotal) / duration).floor();

      for (var i = 0; i < totalSlots; i++) {
        final startMin = startTotal + (i * duration);
        final endMin = startMin + duration;
        final start = formatMinutes(startMin);
        var end = formatMinutes(endMin);
        if (end == '00:00') end = '24:00';
        slots.add(_Slot(start, end));
      }
      return slots;
    }

    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    DateTime combine(DateTime date, String time) {
      if (time == '24:00') {
        return DateTime(date.year, date.month, date.day).add(
          const Duration(days: 1),
        );
      }
      final parts = time.split(':');
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0,
      );
    }

    /// Slots already booked on the selected date, as display strings.
    Set<String> takenSlots() {
      final result = <String>{};
      for (final b in props.value.existingBookings) {
        final start = b.start.toLocal();
        if (ymd(start) == ymd(selectedDate.value)) {
          result.add('${hhmm(start)} - ${hhmm(b.end.toLocal())}');
        }
      }
      return result;
    }

    /// Dates that already have a (day) booking — used to block day selection.
    bool isDayTaken(DateTime day) {
      return props.value.existingBookings.any(
        (b) => ymd(b.start.toLocal()) == ymd(day),
      );
    }

    bool isSlotInPast(_Slot slot) {
      final today = DateTime.now();
      final isToday = ymd(selectedDate.value) == ymd(today);
      if (!isToday) return false;
      return combine(selectedDate.value, slot.end).isBefore(DateTime.now());
    }

    void onConfirm(BuildContext context) {
      final blocked = props.value.isAdmin && isBlock.value;
      final title = titleController.text.trim();

      if (isDays()) {
        final start = combine(selectedDate.value, props.value.bookingStartTime);
        final end = combine(
          selectedDate.value.add(Duration(days: props.value.slotDurationLength)),
          props.value.bookingEndTime,
        );
        Navigator.of(context).pop(
          BookingDialogResult(
            startAt: start,
            endAt: end,
            title: title,
            isAllDay: true,
            isBlock: blocked,
          ),
        );
        return;
      }

      final slot = generateSlots().firstWhere(
        (s) => s.display == selectedSlot.value,
        orElse: () => const _Slot('', ''),
      );
      if (slot.start.isEmpty) return;

      Navigator.of(context).pop(
        BookingDialogResult(
          startAt: combine(selectedDate.value, slot.start),
          endAt: combine(selectedDate.value, slot.end),
          title: title,
          isAllDay: false,
          isBlock: blocked,
        ),
      );
    }

    Widget buildDaysSummary(ThemeData themeData) {
      final checkIn = combine(selectedDate.value, props.value.bookingStartTime);
      final checkOut = combine(
        selectedDate.value.add(Duration(days: props.value.slotDurationLength)),
        props.value.bookingEndTime,
      );

      if (isDayTaken(selectedDate.value)) {
        return Text(
          'Detta datum är redan bokat.',
          style: TextStyle(color: themeData.colorScheme.error),
        );
      }

      String fmt(DateTime d) =>
          '${ymd(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bokningstid',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Incheckning: ${fmt(checkIn)}'),
          Text('Utcheckning: ${fmt(checkOut)}'),
        ],
      );
    }

    Widget buildSlotPicker(ThemeData themeData) {
      final slots = generateSlots();
      final taken = takenSlots();

      if (slots.isEmpty) {
        return const Text('Inga tillgängliga tider.');
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Välj tid', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              final isTaken = taken.contains(slot.display);
              final isPast = isSlotInPast(slot);
              final isDisabled = isTaken || isPast;
              final isSelected = selectedSlot.value == slot.display;

              Color? bg;
              Color? fg;
              if (isSelected) {
                bg = const Color(0xFF2ed188);
                fg = Colors.white;
              } else if (isTaken) {
                bg = const Color(0xFFfecaca);
                fg = Colors.black;
              } else if (isPast) {
                bg = const Color(0xFFe5e7eb);
                fg = const Color(0xFF9ca3af);
              }

              return ChoiceChip(
                label: Text(slot.display),
                selected: isSelected,
                backgroundColor: bg,
                selectedColor: const Color(0xFF2ed188),
                labelStyle: fg != null ? TextStyle(color: fg) : null,
                onSelected: isDisabled
                    ? null
                    : (_) => selectedSlot.value = slot.display,
              );
            }).toList(),
          ),
        ],
      );
    }

    return (context) {
      final themeData = theme.value;
      final canConfirm = isDays()
          ? !isDayTaken(selectedDate.value)
          : selectedSlot.value != null;

      return AlertDialog(
        title: const Text('Ny bokning'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titel (valfritt)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Välj datum för bokningen'),
                const SizedBox(height: 8),
                CalendarDatePicker(
                  initialDate: selectedDate.value,
                  firstDate: DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  ),
                  lastDate: DateTime(DateTime.now().year + 5),
                  onDateChanged: (d) {
                    selectedDate.value = DateTime(d.year, d.month, d.day);
                    selectedSlot.value = null;
                  },
                ),
                const SizedBox(height: 8),
                if (isDays())
                  buildDaysSummary(themeData)
                else
                  buildSlotPicker(themeData),
                if (props.value.isAdmin) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Blockera i kalendern'),
                    value: isBlock.value,
                    onChanged: (v) => isBlock.value = v,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: canConfirm ? () => onConfirm(context) : null,
            child: Text(isBlock.value ? 'Blockera' : 'Boka'),
          ),
        ],
      );
    };
  }
}
