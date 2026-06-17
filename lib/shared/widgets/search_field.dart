import 'package:flutter/material.dart';

/// A compact, rounded search field with a magnifier icon and a clear button.
///
/// Mirrors the filter inputs used across the BRF Samlat web app. It owns its
/// own [TextEditingController]; callers just react to [onChanged].
class SearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const SearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Sök...',
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, size: 22),
        isDense: true,
        // Use the surface colour (white in light mode) so the field stands out
        // against the slightly off-white page background.
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Rensa',
              onPressed: () {
                _controller.clear();
                widget.onChanged('');
              },
            );
          },
        ),
      ),
    );
  }
}
