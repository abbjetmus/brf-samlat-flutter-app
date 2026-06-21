import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/theme/app_theme.dart';
import 'form_field_common.dart';

/// Multi-choice checkbox question. The answer is a `{optionId: bool}` map
/// (matching the web BlitzForm checkbox model), reported in full on every
/// toggle so the parent only needs to store it.
class FormFieldCheckbox extends CompositionWidget {
  const FormFieldCheckbox({
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
  final Map<String, bool>? initialValue;
  final bool validate;
  final void Function(Map<String, bool>) onChanged;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final selected = ref<Map<String, bool>>({...?props.value.initialValue});

    final showError = computed(
      () =>
          props.value.validate &&
          props.value.required &&
          !selected.value.values.any((v) => v == true),
    );

    void toggle(String optId, bool checked) {
      final next = {...selected.value};
      next[optId] = checked;
      selected.value = next;
      props.value.onChanged(next);
    }

    return (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(text: props.value.title, required: props.value.required),
        const SizedBox(height: 4),
        ...props.value.options.map(
          (opt) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(opt.text),
            value: selected.value[opt.id] == true,
            activeColor: AppTheme.primaryColor,
            onChanged: (v) => toggle(opt.id, v ?? false),
          ),
        ),
        if (showError.value)
          const FieldError(message: 'Välj minst ett alternativ'),
      ],
    );
  }
}
