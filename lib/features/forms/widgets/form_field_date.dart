import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'form_field_common.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Date question. Stores the answer as a `yyyy-MM-dd` string.
class FormFieldDate extends CompositionWidget {
  const FormFieldDate({
    super.key,
    required this.title,
    required this.required,
    required this.initialValue,
    required this.validate,
    required this.onChanged,
  });

  final String title;
  final bool required;
  final String? initialValue;
  final bool validate;
  final void Function(String) onChanged;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final value = ref<String?>(props.value.initialValue);

    final showError = computed(
      () =>
          props.value.validate &&
          props.value.required &&
          (value.value == null || value.value!.isEmpty),
    );

    Future<void> pick(BuildContext context) async {
      final initial = DateTime.tryParse(value.value ?? '') ?? DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        locale: const Locale('sv', 'SE'),
      );
      if (picked != null) {
        final formatted =
            '${picked.year}-${_two(picked.month)}-${_two(picked.day)}';
        value.value = formatted;
        props.value.onChanged(formatted);
      }
    }

    return (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(text: props.value.title, required: props.value.required),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            value.value == null || value.value!.isEmpty
                ? 'Välj datum'
                : value.value!,
          ),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: () => pick(context),
        ),
        if (showError.value) const FieldError(message: 'Obligatoriskt fält'),
      ],
    );
  }
}
