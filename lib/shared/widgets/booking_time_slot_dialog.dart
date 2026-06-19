import 'package:flutter/material.dart';

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

class _BookingTimeSlotDialog extends StatefulWidget {
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
  State<_BookingTimeSlotDialog> createState() => _BookingTimeSlotDialogState();
}

class _BookingTimeSlotDialogState extends State<_BookingTimeSlotDialog> {
  final _titleController = TextEditingController();
  late DateTime _selectedDate;
  String? _selectedSlot; // display string e.g. "08:00 - 09:00"
  bool _isBlock = false;

  bool get _isDays => widget.slotDurationType == 'Dagar';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // --- Slot generation (mirrors TimeSlotSelector.vue) ---

  int get _durationInMinutes => widget.slotDurationType == 'Timmar'
      ? widget.slotDurationLength * 60
      : widget.slotDurationLength;

  List<_Slot> _generateSlots() {
    final slots = <_Slot>[];
    final duration = _durationInMinutes;
    if (duration <= 0) return slots;

    final startParts = widget.bookingStartTime.split(':');
    final endParts = widget.bookingEndTime.split(':');
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
      final start = _formatMinutes(startMin);
      var end = _formatMinutes(endMin);
      if (end == '00:00') end = '24:00';
      slots.add(_Slot(start, end));
    }
    return slots;
  }

  String _formatMinutes(int totalMinutes) {
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Slots already booked on the selected date, as display strings.
  Set<String> get _takenSlots {
    final result = <String>{};
    for (final b in widget.existingBookings) {
      final start = b.start.toLocal();
      if (_ymd(start) == _ymd(_selectedDate)) {
        result.add('${_hhmm(start)} - ${_hhmm(b.end.toLocal())}');
      }
    }
    return result;
  }

  /// Dates that already have a (day) booking — used to block day selection.
  bool _isDayTaken(DateTime day) {
    return widget.existingBookings.any(
      (b) => _ymd(b.start.toLocal()) == _ymd(day),
    );
  }

  bool _isSlotInPast(_Slot slot) {
    final today = DateTime.now();
    final isToday = _ymd(_selectedDate) == _ymd(today);
    if (!isToday) return false;
    return _combine(_selectedDate, slot.end).isBefore(DateTime.now());
  }

  DateTime _combine(DateTime date, String hhmm) {
    if (hhmm == '24:00') {
      return DateTime(date.year, date.month, date.day).add(
        const Duration(days: 1),
      );
    }
    final parts = hhmm.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
  }

  void _onConfirm() {
    final isBlock = widget.isAdmin && _isBlock;
    final title = _titleController.text.trim();

    if (_isDays) {
      final start = _combine(_selectedDate, widget.bookingStartTime);
      final end = _combine(
        _selectedDate.add(Duration(days: widget.slotDurationLength)),
        widget.bookingEndTime,
      );
      Navigator.of(context).pop(
        BookingDialogResult(
          startAt: start,
          endAt: end,
          title: title,
          isAllDay: true,
          isBlock: isBlock,
        ),
      );
      return;
    }

    final slot = _generateSlots().firstWhere(
      (s) => s.display == _selectedSlot,
      orElse: () => const _Slot('', ''),
    );
    if (slot.start.isEmpty) return;

    Navigator.of(context).pop(
      BookingDialogResult(
        startAt: _combine(_selectedDate, slot.start),
        endAt: _combine(_selectedDate, slot.end),
        title: title,
        isAllDay: false,
        isBlock: isBlock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfirm = _isDays
        ? !_isDayTaken(_selectedDate)
        : _selectedSlot != null;

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
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel (valfritt)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Välj datum för bokningen'),
              const SizedBox(height: 8),
              CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                ),
                lastDate: DateTime(DateTime.now().year + 5),
                onDateChanged: (d) {
                  setState(() {
                    _selectedDate = DateTime(d.year, d.month, d.day);
                    _selectedSlot = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              if (_isDays)
                _buildDaysSummary(theme)
              else
                _buildSlotPicker(theme),
              if (widget.isAdmin) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Blockera i kalendern'),
                  value: _isBlock,
                  onChanged: (v) => setState(() => _isBlock = v),
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
          onPressed: canConfirm ? _onConfirm : null,
          child: Text(_isBlock ? 'Blockera' : 'Boka'),
        ),
      ],
    );
  }

  Widget _buildDaysSummary(ThemeData theme) {
    final checkIn = _combine(_selectedDate, widget.bookingStartTime);
    final checkOut = _combine(
      _selectedDate.add(Duration(days: widget.slotDurationLength)),
      widget.bookingEndTime,
    );

    if (_isDayTaken(_selectedDate)) {
      return Text(
        'Detta datum är redan bokat.',
        style: TextStyle(color: theme.colorScheme.error),
      );
    }

    String fmt(DateTime d) =>
        '${_ymd(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bokningstid', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Incheckning: ${fmt(checkIn)}'),
        Text('Utcheckning: ${fmt(checkOut)}'),
      ],
    );
  }

  Widget _buildSlotPicker(ThemeData theme) {
    final slots = _generateSlots();
    final taken = _takenSlots;

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
            final isPast = _isSlotInPast(slot);
            final isDisabled = isTaken || isPast;
            final isSelected = _selectedSlot == slot.display;

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
                  : (_) => setState(() => _selectedSlot = slot.display),
            );
          }).toList(),
        ),
      ],
    );
  }
}
