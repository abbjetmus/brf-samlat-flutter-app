import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

/// Free-text field (single-line input or multi-line textarea).
///
/// Owns its own [TextEditingController] and display state, mirroring the
/// zmartrest native-form pattern: the parent only stores the answer via
/// [onChanged] and never has to rebuild for the field to repaint.
class FormFieldText extends CompositionWidget {
  const FormFieldText({
    super.key,
    required this.title,
    required this.required,
    required this.multiline,
    required this.initialValue,
    required this.validate,
    required this.onChanged,
  });

  final String title;
  final bool required;
  final bool multiline;
  final String? initialValue;

  /// When true, the field shows its required-error if currently empty.
  final bool validate;
  final void Function(String) onChanged;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final (controller, text, _) = useTextEditingController(
      text: props.value.initialValue ?? '',
    );

    final showError = computed(
      () =>
          props.value.validate &&
          props.value.required &&
          text.value.trim().isEmpty,
    );

    return (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: props.value.multiline ? 4 : 1,
          onChanged: props.value.onChanged,
          decoration: InputDecoration(
            labelText: props.value.title,
            hintText: 'Skriv ditt svar...',
            border: const OutlineInputBorder(),
            errorText: showError.value ? 'Obligatoriskt fält' : null,
          ),
        ),
      ],
    );
  }
}
