import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../chat_format.dart';

class _MediaItem {
  const _MediaItem({
    required this.message,
    required this.file,
    required this.isImage,
  });

  final ChatMessagesRecord message;
  final String file;
  final bool isImage;

  String get url => getImageUrl(Collections.chatMessages, message.id, file);
  String get thumb =>
      getImageUrlThumb(Collections.chatMessages, message.id, file);
  String get name => displayFileName(file);
}

/// "Media och filer": every image and file sent in one room, newest first.
/// "Visa i chatten" pops with the message id; [ChatRoomPage] scrolls to it.
class ChatMediaPage extends CompositionWidget {
  const ChatMediaPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final chatStore = inject(chatStoreKey);
    final theme = useTheme();

    final tab = ref('images');
    final items = ref<List<_MediaItem>>([]);
    final loading = ref(true);
    final hasMore = ref(false);
    final page = ref(1);

    Future<void> load(int nextPage) async {
      loading.value = true;
      try {
        final res = await chatStore.mediaMessages(
          props.value.roomId,
          page: nextPage,
        );
        final mapped = [
          for (final m in res.items)
            for (final f in m.files)
              _MediaItem(
                message: m,
                file: f,
                isImage: RegExp(
                  r'\.(jpe?g|png|gif|webp)$',
                  caseSensitive: false,
                ).hasMatch(f),
              ),
        ];
        items.value = nextPage == 1 ? mapped : [...items.value, ...mapped];
        hasMore.value = res.hasMore;
        page.value = nextPage;
      } catch (e) {
        debugPrint('ChatMediaPage: $e');
      } finally {
        loading.value = false;
      }
    }

    onMounted(() => load(1));

    Future<void> openImage(BuildContext context, _MediaItem item) async {
      final showInChat = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Stäng',
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                    Expanded(
                      child: Text(
                        '${senderName(item.message)} · ${formatChatWhen(item.message.created)}',
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Center(child: Image.network(item.url)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Visa i chatten'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (showInChat == true && context.mounted) {
        Navigator.of(context).pop(item.message.id);
      }
    }

    return (context) {
      final images = items.value.where((i) => i.isImage).toList();
      final files = items.value.where((i) => !i.isImage).toList();
      final more = hasMore.value ? '+' : '';
      final showImages = tab.value == 'images';
      final list = showImages ? images : files;

      Widget loadMore() => hasMore.value
          ? Center(
              child: TextButton(
                onPressed: loading.value ? null : () => load(page.value + 1),
                child: const Text('Visa fler'),
              ),
            )
          : const SizedBox.shrink();

      Widget body;
      if (loading.value && items.value.isEmpty) {
        body = const Center(child: CircularProgressIndicator());
      } else if (list.isEmpty && !hasMore.value) {
        body = Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            showImages
                ? 'Inga bilder har skickats i chatten.'
                : 'Inga filer har skickats i chatten.',
            textAlign: TextAlign.center,
          ),
        );
      } else if (showImages) {
        body = CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: images.length,
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => openImage(context, images[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      images[i].thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: theme.value.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: loadMore()),
          ],
        );
      } else {
        body = ListView.separated(
          itemCount: files.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, i) {
            if (i == files.length) return loadMore();
            final item = files[i];
            final info = parseFilename(item.file);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.value.colorScheme.primaryContainer,
                child: Icon(info.icon),
              ),
              title: Text(item.name, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${senderName(item.message)} · ${formatChatWhen(item.message.created)}',
              ),
              onTap: () => launchUrl(
                Uri.parse(item.url),
                mode: LaunchMode.externalApplication,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.chat_outlined),
                tooltip: 'Visa i chatten',
                onPressed: () => Navigator.of(context).pop(item.message.id),
              ),
            );
          },
        );
      }

      return GradientScaffold(
        title: 'Media och filer',
        showMenu: false,
        onBack: () => Navigator.of(context).pop(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'images',
                      label: Text('Bilder (${images.length}$more)'),
                    ),
                    ButtonSegment(
                      value: 'files',
                      label: Text('Filer (${files.length}$more)'),
                    ),
                  ],
                  selected: {tab.value},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => tab.value = v.first,
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
