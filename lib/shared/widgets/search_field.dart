import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

/// A compact, rounded search field with a magnifier icon and a clear button.
///
/// Mirrors the filter inputs used across the BRF Samlat web app. It owns its
/// own [TextEditingController] (via `useTextEditingController`); callers just
/// react to [onChanged].
class SearchField extends CompositionWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const SearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Sök...',
  });

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();
    final (controller, text, _) = useTextEditingController();

    return (context) => TextField(
          controller: controller,
          onChanged: props.value.onChanged,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: props.value.hintText,
            prefixIcon: const Icon(Icons.search, size: 22),
            isDense: true,
            // Use the surface colour (white in light mode) so the field stands
            // out against the slightly off-white page background.
            filled: true,
            fillColor: theme.value.colorScheme.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: text.value.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Rensa',
                    onPressed: () {
                      controller.clear();
                      props.value.onChanged('');
                    },
                  ),
          ),
        );
  }
}
