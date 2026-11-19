import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// An image from rich-text HTML (posts can contain `<img src width>` from the
/// web editor, uploaded to the content_images collection). Shown at its saved
/// width, never wider than the available space, keeping its proportions. Tap
/// to view it full screen.
class RichImage extends StatelessWidget {
  const RichImage({
    super.key,
    required this.src,
    this.width,
    this.zoomable = true,
  });

  final String src;

  /// Width in logical pixels chosen in the editor; null = as wide as fits.
  final double? width;
  final bool zoomable;

  /// `width="320"` or a style value like `320px` → 320.
  static double? parseWidth(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*(px)?\s*$').firstMatch(value);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  void _openFullScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.network(src)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        src,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width ?? double.infinity),
        child: zoomable
            ? GestureDetector(
                onTap: () => _openFullScreen(context),
                child: image,
              )
            : image,
      ),
    );
  }
}

/// Shows image embeds in the Quill editor (editing a post that has images
/// from the web). Without it Quill can't render an `image` embed.
class RichImageEmbedBuilder extends EmbedBuilder {
  const RichImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final src = embedContext.node.value.data as String? ?? '';
    final style = embedContext.node.style.attributes['style']?.value as String?;
    double? width;
    for (final part in (style ?? '').split(';')) {
      final kv = part.split(':');
      if (kv.length == 2 && kv[0].trim() == 'width') {
        width = RichImage.parseWidth(kv[1]);
      }
    }
    return RichImage(src: src, width: width, zoomable: false);
  }
}
