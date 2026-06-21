import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/theme/app_theme.dart';
import 'form_field_common.dart';

/// Single-choice radio question. The selected answer is the chosen option's
/// id (matching the web BlitzForm `:val="radio.id"` binding), so responses
/// stay compatible across apps.
class FormFieldRadio extends CompositionWidget {
  const FormFieldRadio({
    super.key,
    required this.title,
    required this.required,
    required this.options,
    required this.initialValue,
    required this.validate,
    required this.onChanged,
  });

  final String title;
  final bool required;
  final List<({String id, String text})> options;
  final String? initialValue;
  final bool validate;
  final void Function(String?) onChanged;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final selected = ref<String?>(props.value.initialValue);

    final showError = computed(
      () =>
          props.value.validate &&
          props.value.required &&
          (selected.value == null || selected.value!.isEmpty),
    );

    void select(String? value) {
      selected.value = value;
      props.value.onChanged(value);
    }

    return (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(text: props.value.title, required: props.value.required),
        const SizedBox(height: 4),
        RadioGroup<String>(
          groupValue: selected.value,
          onChanged: select,
          child: Column(
            children: props.value.options
                .map(
                  (opt) => RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(opt.text),
                    value: opt.id,
                    activeColor: AppTheme.primaryColor,
                  ),
                )
                .toList(),
          ),
        ),
        if (showError.value) const FieldError(message: 'Obligatoriskt fält'),
      ],
    );
  }
}
