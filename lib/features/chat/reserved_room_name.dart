/// "Styrelsen" is reserved for the automatic board chat ("Skriv till
/// styrelsen"), so an ordinary group chat can't be mistaken for it. The server
/// checks the same (brf-samlat-pb pb_hooks/utils/chat_board_utils.js). Case
/// and surrounding spaces are ignored.
const reservedRoomNameMessage =
    'Namnet Styrelsen är reserverat för styrelsechatten. '
    'Välj ett annat namn, t.ex. Styrelsegruppen.';

bool isReservedRoomName(String name) =>
    name.trim().toLowerCase() == 'styrelsen';
