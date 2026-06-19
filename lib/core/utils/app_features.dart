/// Features a BRF/association can switch on or off for the whole association.
///
/// A token listed in `associations.disabled_features` is hidden everywhere
/// (menu + dashboard) for every user, including admins. Core/administrative
/// features (users, behörigheter, föreningen, konto, inställningar, hjälp) are
/// intentionally NOT toggleable so an association can't lock itself out.
class ToggleableFeature {
  final String token;
  final String label;
  const ToggleableFeature(this.token, this.label);
}

const toggleableFeatures = <ToggleableFeature>[
  ToggleableFeature('posts', 'Nyheter'),
  ToggleableFeature('chat', 'Meddelanden'),
  ToggleableFeature('calendar_events', 'Kalender'),
  ToggleableFeature('forms', 'Formulär'),
  ToggleableFeature('form_builder', 'Formulär Byggaren'),
  ToggleableFeature('issues', 'Felanmälan & ärenden'),
  ToggleableFeature('residence_issues', 'Felanmälan & ärenden (bostäder)'),
  ToggleableFeature('residences', 'Bostäder'),
  ToggleableFeature('places', 'Lokaler'),
  ToggleableFeature('parking_lots', 'Parkeringar'),
  ToggleableFeature('gadgets', 'Prylar'),
  ToggleableFeature('folders_and_files', 'Dokument'),
  // `board` = the whole Styrelsen section; `board_meetings` = the meeting/
  // template sub-views inside it (matches the web board tabs).
  ToggleableFeature('board', 'Styrelsen'),
  ToggleableFeature('board_meetings', 'Styrelsemöten'),
  ToggleableFeature('invoices', 'Fakturor'),
  ToggleableFeature('invoice_builder', 'Faktura Byggaren'),
];
