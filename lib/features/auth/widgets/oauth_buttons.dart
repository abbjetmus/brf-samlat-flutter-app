import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/di/injection_keys.dart';

/// "Fortsätt med Google / Microsoft / Apple". Only the providers switched on
/// for the users collection in PocketBase are shown, so nothing appears until
/// OAuth is enabled there. Same buttons as the web app's AuthOAuthButtons.
class OAuthButtons extends CompositionWidget {
  const OAuthButtons({
    super.key,
    required this.onSelected,
    this.busyProvider,
    this.disabled = false,
    this.actionText = 'Fortsätt med',
    this.dividerText = 'eller',
  });

  final void Function(String provider) onSelected;

  /// The provider whose sign-in is running; it shows a spinner and all buttons
  /// are disabled meanwhile.
  final String? busyProvider;
  final bool disabled;
  final String actionText;
  final String dividerText;

  static const _supported = [
    (name: 'google', label: 'Google', asset: 'assets/icons/google.svg'),
    (name: 'microsoft', label: 'Microsoft', asset: 'assets/icons/microsoft.svg'),
    // An icon rather than an image so it follows the theme (black/white).
    (name: 'apple', label: 'Apple', asset: null),
  ];

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final authStore = inject(authStoreKey);
    final theme = useTheme();
    final enabled = ref<List<String>>(const []);

    onMounted(() async {
      enabled.value = await authStore.loadOAuthProviders();
    });

    final providers = computed(
      () => _supported.where((p) => enabled.value.contains(p.name)).toList(),
    );

    return (context) {
      if (providers.value.isEmpty) return const SizedBox.shrink();
      final p = props.value;
      final locked = p.disabled || p.busyProvider != null;
      final muted = theme.value.colorScheme.onSurfaceVariant;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(p.dividerText, style: TextStyle(color: muted)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          for (final provider in providers.value) ...[
            OutlinedButton(
              onPressed: locked ? null : () => p.onSelected(provider.name),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: p.busyProvider == provider.name
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : provider.asset != null
                        ? SvgPicture.asset(provider.asset!)
                        : Icon(
                            Icons.apple,
                            size: 22,
                            color: theme.value.colorScheme.onSurface,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${p.actionText} ${provider.label}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    };
  }
}
