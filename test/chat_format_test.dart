import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brf_samlat_flutter_app/features/chat/chat_format.dart';

void main() {
  test('excerptAround keeps the match and marks cuts', () {
    final long = '${'a ' * 80}ytterdörren är trasig ${'b ' * 100}';
    final e = excerptAround(long, 'Ytterdörren');
    expect(e, contains('ytterdörren'));
    expect(e.startsWith('…'), isTrue);
    expect(e.endsWith('…'), isTrue);
    expect(excerptAround('Kort text', 'kort'), 'Kort text');
  });

  test('highlightMatches marks every case-insensitive match', () {
    const style = TextStyle(fontWeight: FontWeight.w600);
    final span = highlightMatches('Dörr och DÖRR', 'dörr', style);
    final parts = span.children!.cast<TextSpan>();
    expect(parts.where((p) => p.style == style).map((p) => p.text), ['Dörr', 'DÖRR']);
    expect(parts.map((p) => p.text).join(), 'Dörr och DÖRR');
  });
}
