import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/file_utils.dart';

/// "Bilagor" on a detail screen: images as thumbnails (tap → full screen),
/// other files as a list (tap → opened by the system via url_launcher).
///
/// [collection] is the PocketBase collection id or name and [recordId] the
/// record the files belong to; [files] are the stored file names.
class AttachmentsSection extends StatelessWidget {
  const AttachmentsSection({
    super.key,
    required this.collection,
    required this.recordId,
    required this.files,
    this.title = 'Bilagor',
  });

  final String collection;
  final String recordId;
  final List<String> files;
  final String title;

  // Formats Image.network can decode (svg is shown as a file).
  static const _displayableImages = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  };

  String _url(String file) =>
      getImageUrl(collection, recordId, Uri.encodeComponent(file));

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    final images = <String>[];
    final others = <String>[];
    for (final f in files) {
      (_displayableImages.contains(parseFilename(f).extension)
              ? images
              : others)
          .add(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${files.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in images)
                _Thumbnail(
                  url: _url(f),
                  label: displayFileName(f),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => _ImageViewerPage(
                        url: _url(f),
                        title: displayFileName(f),
                        onOpenExternally: () => _open(_url(f)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (images.isNotEmpty && others.isNotEmpty) const SizedBox(height: 8),
        for (final f in others)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(parseFilename(f).icon),
            title: Text(
              displayFileName(f),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () => _open(_url(f)),
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.url,
    required this.label,
    required this.onTap,
  });

  final String url;
  final String label;
  final VoidCallback onTap;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            cacheWidth: (_size * dpr).round(),
            errorBuilder: (_, _, _) => Container(
              width: _size,
              height: _size,
              color: colors.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image,
                color: colors.onSurfaceVariant,
              ),
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    width: _size,
                    height: _size,
                    color: colors.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen, zoomable image with a button to open it in the system viewer
/// (to save or share it).
class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({
    required this.url,
    required this.title,
    required this.onOpenExternally,
  });

  final String url;
  final String title;
  final VoidCallback onOpenExternally;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Öppna',
            onPressed: onOpenExternally,
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (_, _, _) => const Text(
              'Bilden kunde inte visas.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
