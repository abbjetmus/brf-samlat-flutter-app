import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/pb_error.dart';

/// "Prenumerera på kalendern" — den personliga iCal-adressen.
///
/// POST /api/calendar/feed-token (brf-samlat-pb/pb_hooks/api/calendar_feed.pb.js)
/// skapar adressen första gången och returnerar den befintliga därefter;
/// `{ rotate: true }` byter den (gamla adresser slutar fungera).
///
/// iPhone: `webcal://` öppnar Kalender-appens prenumerationsdialog.
/// Android: Google Kalender prenumererar via
/// `calendar.google.com/calendar/render?cid=<webcal-adress>`.
class CalendarSubscriptionSheet extends CompositionWidget {
  const CalendarSubscriptionSheet({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pb = inject(pocketBaseKey);
    final theme = useTheme();
    final contextRef = useContext();

    final loading = ref(true);
    final rotating = ref(false);
    final error = ref<String?>(null);
    final feedUrl = ref<String?>(null);

    final webcalUrl = computed(
      () => feedUrl.value?.replaceFirst(RegExp(r'^https?://'), 'webcal://'),
    );

    void snack(String text) {
      final ctx = contextRef.value;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(text)));
      }
    }

    Future<void> load({bool rotate = false}) async {
      error.value = null;
      if (rotate) {
        rotating.value = true;
      } else {
        loading.value = true;
      }
      try {
        final res = await pb.send(
          '/api/calendar/feed-token',
          method: 'POST',
          body: rotate ? {'rotate': true} : <String, dynamic>{},
        );
        final path = res is Map ? res['path'] as String? : null;
        feedUrl.value = path == null ? null : pb.buildURL(path).toString();
        if (rotate) {
          snack('En ny länk har skapats. Den gamla fungerar inte längre.');
        }
      } catch (e) {
        error.value = pbErrorMessage(e, 'Kunde inte hämta kalenderadressen.');
      } finally {
        loading.value = false;
        rotating.value = false;
      }
    }

    onMounted(load);

    Future<void> copy() async {
      final url = feedUrl.value;
      if (url == null) return;
      await Clipboard.setData(ClipboardData(text: url));
      snack('Adressen kopierad');
    }

    Future<void> open(Uri uri) async {
      var opened = false;
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
      if (!opened) {
        await copy();
        snack(
          'Kunde inte öppna kalendern. Adressen är kopierad — klistra in den i din kalenderapp.',
        );
      }
    }

    Future<void> confirmRotate() async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final ok = await showDialog<bool>(
        context: ctx,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Skapa ny länk?'),
          content: const Text(
            'Den nuvarande adressen slutar fungera direkt. Kalendrar som '
            'prenumererar på den slutar uppdateras och måste läggas till igen '
            'med den nya adressen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Avbryt'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: theme.value.colorScheme.error,
              ),
              child: const Text('Skapa ny länk'),
            ),
          ],
        ),
      );
      if (ok == true) await load(rotate: true);
    }

    return (context) {
      final url = feedUrl.value;
      final webcal = webcalUrl.value;
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final colors = theme.value.colorScheme;
      final caption = TextStyle(fontSize: 13, color: colors.onSurfaceVariant);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Prenumerera på kalendern',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Lägg till föreningens kalender i telefonens kalender, Google '
            'Kalender eller Outlook. Händelserna uppdateras automatiskt och du '
            'ser samma händelser som här i appen.',
            style: caption,
          ),
          const SizedBox(height: 16),
          if (loading.value)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (url == null || webcal == null)
            Text(
              error.value ?? 'Kunde inte hämta kalenderadressen.',
              style: TextStyle(color: colors.error),
            )
          else ...[
            if (isIOS)
              FilledButton.icon(
                onPressed: () => open(Uri.parse(webcal)),
                icon: const Icon(Icons.event_repeat),
                label: const Text('Öppna i Kalender'),
              ),
            if (isIOS) const SizedBox(height: 8),
            if (isIOS)
              OutlinedButton.icon(
                onPressed: () => open(_googleCalendarUri(webcal)),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Lägg till i Google Kalender'),
              )
            else
              FilledButton.icon(
                onPressed: () => open(_googleCalendarUri(webcal)),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Lägg till i Google Kalender'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: copy,
              icon: const Icon(Icons.copy),
              label: const Text('Kopiera adress'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(url, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 8),
            Text(
              'Outlook: Lägg till kalender → Prenumerera från webben och '
              'klistra in adressen.',
              style: caption,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Adressen är personlig — den som har den kan se din kalender. '
                'Har den kommit i fel händer, skapa en ny länk. Den gamla slutar '
                'då att fungera.',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onTertiaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: rotating.value ? null : confirmRotate,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                icon: rotating.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Skapa ny länk'),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      );
    };
  }
}

Uri _googleCalendarUri(String webcalUrl) =>
    Uri.https('calendar.google.com', '/calendar/render', {'cid': webcalUrl});
