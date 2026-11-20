import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../chat_format.dart';

/// "Sök i chatten": messages in one room that contain the search text. Tapping
/// a result pops with its message id; [ChatRoomPage] then scrolls to it.
class ChatSearchPage extends CompositionWidget {
  const ChatSearchPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final chatStore = inject(chatStoreKey);
    final theme = useTheme();
    final (controller, text, _) = useTextEditingController();

    final results = ref<List<ChatMessagesRecord>>([]);
    final loading = ref(false);
    final hasMore = ref(false);
    final page = ref(1);
    final query = computed(() => text.value.trim());
    Timer? debounce;
    var generation = 0;

    Future<void> search(int nextPage) async {
      final q = query.value;
      if (q.length < 2) return;
      final mine = ++generation;
      loading.value = true;
      try {
        final res = await chatStore.searchMessages(
          props.value.roomId,
          q,
          page: nextPage,
        );
        if (mine != generation) return;
        results.value = nextPage == 1
            ? res.items
            : [...results.value, ...res.items];
        hasMore.value = res.hasMore;
        page.value = nextPage;
      } catch (e) {
        debugPrint('ChatSearchPage: $e');
      } finally {
        if (mine == generation) loading.value = false;
      }
    }

    watch(() => query.value, (q, _) {
      debounce?.cancel();
      results.value = [];
      hasMore.value = false;
      if (q.length >= 2) {
        debounce = Timer(const Duration(milliseconds: 300), () => search(1));
      }
    });
    onUnmounted(() => debounce?.cancel());

    return (context) {
      final q = query.value;
      final colors = theme.value.colorScheme;
      Widget body;
      if (q.length < 2) {
        body = const _Hint('Skriv minst två tecken för att söka.');
      } else if (!loading.value && results.value.isEmpty) {
        body = _Hint('Inga meddelanden innehåller ”$q”.');
      } else {
        body = ListView.separated(
          itemCount: results.value.length + (hasMore.value ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == results.value.length) {
              return Center(
                child: TextButton(
                  onPressed: loading.value
                      ? null
                      : () => search(page.value + 1),
                  child: const Text('Visa fler'),
                ),
              );
            }
            final m = results.value[index];
            return ListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      senderName(m),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatChatWhen(m.created),
                    style: theme.value.textTheme.bodySmall,
                  ),
                ],
              ),
              subtitle: Text.rich(
                highlightMatches(
                  excerptAround(m.content ?? '', q),
                  q,
                  TextStyle(
                    backgroundColor: colors.primary.withValues(alpha: 0.25),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(m.id),
            );
          },
        );
      }

      return GradientScaffold(
        title: 'Sök i chatten',
        showMenu: false,
        onBack: () => Navigator.of(context).pop(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Sök efter ord i meddelandena',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: loading.value
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Rensa',
                          onPressed: () => text.value = '',
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    };
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}
