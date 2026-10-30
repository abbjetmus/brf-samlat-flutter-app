import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A short, dismissible help tip at the top of a page, the mobile counterpart
/// of the web's `AdminHelpTip`.
///
/// Dismissal is remembered per [id] on the device (shared_preferences key
/// `help_tip_dismissed_<id>`), so a tip the user has closed stays closed. Use
/// the same ids as the web where a tip has a web counterpart. Nothing is shown
/// until the stored state has been read, so a dismissed tip never flashes.
class HelpTip extends CompositionWidget {
  const HelpTip({
    super.key,
    required this.id,
    required this.text,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  /// Stable identifier, e.g. `issues` or `invoice-overview`.
  final String id;

  /// One or two short sentences in Swedish ("tryck", not "klicka").
  final String text;

  /// Outer padding around the card.
  final EdgeInsetsGeometry padding;

  static String _key(String id) => 'help_tip_dismissed_$id';

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();
    // null = not read yet; hidden until we know.
    final dismissed = ref<bool?>(null);

    onMounted(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        dismissed.value = prefs.getBool(_key(props.value.id)) ?? false;
      } catch (_) {
        dismissed.value = false;
      }
    });

    Future<void> dismiss() async {
      dismissed.value = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_key(props.value.id), true);
      } catch (_) {
        // Hidden for this session at least.
      }
    }

    return (context) {
      if (dismissed.value != false) return const SizedBox.shrink();
      final scheme = theme.value.colorScheme;
      return Padding(
        padding: props.value.padding,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    props.value.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Dölj tipset',
                visualDensity: VisualDensity.compact,
                onPressed: dismiss,
              ),
            ],
          ),
        ),
      );
    };
  }
}
