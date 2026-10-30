import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:brf_samlat_flutter_app/core/utils/pb_error.dart';

ClientException _err(int status, Map<String, dynamic> response,
        {bool isAbort = false}) =>
    ClientException(statusCode: status, response: response, isAbort: isAbort);

void main() {
  const fallback = 'Kunde inte boka.';

  group('pbErrorMessage', () {
    test('non-ClientException gives fallback', () {
      expect(pbErrorMessage(Exception('x'), fallback), fallback);
    });

    test('network error and abort', () {
      expect(
        pbErrorMessage(_err(0, {}), fallback),
        'Kunde inte nå servern. Kontrollera din anslutning och försök igen.',
      );
      expect(pbErrorMessage(_err(0, {}, isAbort: true), fallback), fallback);
    });

    test('Swedish server messages are shown as-is', () {
      expect(
        pbErrorMessage(_err(400, {'message': ' Tiden är redan bokad. '}),
            fallback),
        'Tiden är redan bokad.',
      );
      expect(
        pbErrorMessage(
            _err(403, {'message': 'Endast administratörer kan skapa användare.'}),
            fallback),
        'Endast administratörer kan skapa användare.',
      );
    });

    test('English PocketBase defaults are not shown', () {
      for (final m in [
        'Failed to create record.',
        'Something went wrong while processing your request.',
        "The requested resource wasn't found.",
        'Only administrators can create users',
      ]) {
        expect(pbErrorMessage(_err(400, {'message': m}), fallback), fallback);
      }
    });

    test('field errors are summarised', () {
      expect(
        pbErrorMessage(
          _err(400, {
            'message': 'Failed to create record.',
            'data': {
              'email': {'code': 'validation_not_unique', 'message': 'x'},
              'start_at': {'code': 'validation_required', 'message': 'x'},
              'end_at': {'code': 'validation_invalid_date', 'message': 'x'},
              'max_room_capacity': {'code': 'validation_max_number_constraint'},
              'title': {'code': 'validation_length_out_of_range'},
              'other_field': {'code': 'custom', 'message': 'Fel värde här'},
              'x_y': {'code': 'custom', 'message': 'Must be valid'},
            },
          }),
          fallback,
        ),
        'E-post används redan; Starttid måste fyllas i; '
        'Sluttid är inget giltigt datum; '
        'Max room capacity har ett ogiltigt värde; Titel har fel längd; '
        'Other field Fel värde här; X y är ogiltigt.',
      );
    });

    test('status code messages', () {
      final english = {'message': 'The request is forbidden.'};
      expect(pbErrorMessage(_err(403, english), fallback),
          'Du saknar behörighet för denna åtgärd.');
      expect(pbErrorMessage(_err(429, english), fallback),
          'För många försök. Vänta en stund och försök igen.');
      expect(pbErrorMessage(_err(401, english), fallback),
          'Du behöver logga in igen.');
      expect(pbErrorMessage(_err(404, english), fallback), fallback);
      expect(pbErrorMessage(_err(400, {'data': {}}), fallback), fallback);
    });
  });
}
