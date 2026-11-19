import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'rich_image.dart';

/// Serializes a Quill [Document] to the HTML we store on the backend (the same
/// flavour the web admin's Tiptap editor produces and [RichDescription] renders).
String quillDocumentToHtml(Document document) {
  final ops = document
      .toDelta()
      .toJson()
      .cast<Map<String, dynamic>>()
      .map(_imageWidthToAttribute)
      .toList();
  return QuillDeltaToHtmlConverter(ops, ConverterOptions()).convert();
}

/// Images keep the width chosen in the web editor: HtmlToDelta reads it from
/// `style="width:…"` (see [imageWidthToStyle]) and the HTML converter writes
/// it back as `width="…"`, which is what Tiptap and [RichDescription] read.
Map<String, dynamic> _imageWidthToAttribute(Map<String, dynamic> op) {
  final insert = op['insert'];
  final attributes = op['attributes'];
  if (insert is! Map || !insert.containsKey('image') || attributes is! Map) {
    return op;
  }
  final style = attributes['style'];
  if (style is! String) return op;
  final match = RegExp(r'width\s*:\s*(\d+(?:\.\d+)?)px').firstMatch(style);
  if (match == null) return op;
  return {
    ...op,
    'attributes': {
      ...Map<String, dynamic>.from(attributes)..remove('style'),
      'width': match.group(1)!.split('.').first,
    },
  };
}

/// Tiptap saves an image's size as `width="320" height="200"`; HtmlToDelta
/// only reads sizes from `style`, so move the width there before converting.
String imageWidthToStyle(String html) => html.replaceAllMapped(
  RegExp(r'<img\b([^>]*?)\swidth="(\d+)"([^>]*)>', caseSensitive: false),
  (m) {
    final rest = '${m[1]}${m[3]}';
    if (rest.contains('style=')) return m[0]!;
    return '<img$rest style="width:${m[2]}px">';
  },
);

/// True when [html] carries no visible text (e.g. an empty editor's `<p></p>`).
bool htmlIsEmpty(String html) {
  final stripped = html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .trim();
  return stripped.isEmpty;
}

/// A WYSIWYG rich-text field (bold, italic, lists, links, headings) that reads
/// and writes HTML, so users edit formatted text instead of raw tags. Reports
/// the current HTML through [onChanged]; embed inside a scroll view.
class RichTextEditor extends CompositionWidget {
  const RichTextEditor({
    super.key,
    required this.initialHtml,
    required this.onChanged,
    this.placeholder = 'Skriv en beskrivning...',
    this.minHeight = 160,
  });

  final String initialHtml;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final double minHeight;

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final theme = useTheme();
    // FocusNode and ScrollController are auto-disposed on unmount.
    final focusRef = useFocusNode();
    final scrollRef = useScrollController();

    // QuillController has no composable, so create and tear it down by hand.
    final initial = props.value.initialHtml.trim();
    Document document;
    if (initial.isEmpty) {
      document = Document();
    } else {
      try {
        document = Document.fromDelta(
          HtmlToDelta().convert(imageWidthToStyle(initial)),
        );
      } catch (_) {
        // Fall back to treating the stored value as plain text.
        document = Document()..insert(0, initial);
      }
    }
    final controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    void handleChange() {
      props.value.onChanged(quillDocumentToHtml(controller.document));
    }

    controller.addListener(handleChange);
    onUnmounted(() {
      controller.removeListener(handleChange);
      controller.dispose();
    });

    return (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuillSimpleToolbar(
          controller: controller,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showFontFamily: false,
            showFontSize: false,
            showBackgroundColorButton: false,
            showColorButton: false,
            showCodeBlock: false,
            showInlineCode: false,
            showSubscript: false,
            showSuperscript: false,
            showSearchButton: false,
            showClearFormat: false,
            showIndent: false,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(minHeight: props.value.minHeight),
          decoration: BoxDecoration(
            border: Border.all(color: theme.value.colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: QuillEditor.basic(
            controller: controller,
            focusNode: focusRef.value,
            scrollController: scrollRef.value,
            config: QuillEditorConfig(
              // Bilder från webbens editor (inlägg) visas och behålls.
              embedBuilders: const [RichImageEmbedBuilder()],
              // The page already scrolls; let the editor grow with content.
              scrollable: false,
              expands: false,
              placeholder: props.value.placeholder,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
