import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brf_samlat_flutter_app/shared/widgets/rich_description.dart';
import 'package:brf_samlat_flutter_app/shared/widgets/rich_image.dart';
import 'package:brf_samlat_flutter_app/shared/widgets/rich_text_editor.dart';

void main() {
  test('image width from the web editor survives an edit in the app', () {
    const html =
        '<p>Hej</p><img src="https://pb.example/api/files/content_images/abc/bild.jpg" alt="" width="320" height="200"><p>Slut</p>';
    final doc = Document.fromDelta(
      HtmlToDelta().convert(imageWidthToStyle(html)),
    );
    final out = quillDocumentToHtml(doc);
    expect(
      out,
      contains(
        'src="https://pb.example/api/files/content_images/abc/bild.jpg"',
      ),
    );
    expect(out, contains('width="320"'));
    expect(out, contains('Hej'));
    expect(out, contains('Slut'));
  });

  test('parseWidth', () {
    expect(RichImage.parseWidth('320'), 320);
    expect(RichImage.parseWidth('320px'), 320);
    expect(RichImage.parseWidth('50%'), isNull);
    expect(RichImage.parseWidth(null), isNull);
  });

  // Rendering: an <img> lays out without errors on a narrow screen (the image
  // itself fails to load in tests and falls back to nothing).
  const html =
      '<p>Text</p><img src="https://pb.example/api/files/content_images/abc/bild.jpg" width="900" height="600"><p>Mer</p>';

  testWidgets('RichDescription renders an image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, child: RichDescription(html: html)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(RichImage), findsOneWidget);
  });

  testWidgets('RichTextEditor opens a post with an image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates:
            FlutterQuillLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RichTextEditor(initialHtml: html, onChanged: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(RichImage), findsOneWidget);
    // Stäng editorn så att dess timers (markören) hinner avslutas.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
