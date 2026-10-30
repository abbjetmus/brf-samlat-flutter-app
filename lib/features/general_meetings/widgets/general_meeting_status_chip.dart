import 'package:flutter/material.dart';
import '../../../shared/widgets/status_chip.dart';
import '../general_meetings_models.dart';

class GeneralMeetingStatusChip extends StatelessWidget {
  const GeneralMeetingStatusChip({
    super.key,
    required this.meeting,
    this.board = false,
  });

  final GeneralMeeting meeting;

  /// Styrelsens etiketter ("Utkast" i stället för "Tar emot motioner").
  final bool board;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (meeting.status) {
      GeneralMeetingStatus.draft => (StatusTone.info, Icons.edit_note),
      GeneralMeetingStatus.called => (StatusTone.success, Icons.mail_outline),
      GeneralMeetingStatus.ongoing => (StatusTone.warning, Icons.how_to_vote),
      _ => (StatusTone.neutral, Icons.check_circle_outline),
    };
    final label = board
        ? meetingStatusLabels[meeting.status] ?? meeting.status
        : meeting.statusLabel;
    return StatusChip(label: label, icon: icon, tone: tone);
  }
}

class VoteStatusChip extends StatelessWidget {
  const VoteStatusChip({super.key, required this.voteStatus});

  final String voteStatus;

  @override
  Widget build(BuildContext context) {
    return switch (voteStatus) {
      VoteStatus.open => const StatusChip(
        label: 'Omröstning öppen',
        icon: Icons.how_to_vote,
        tone: StatusTone.success,
      ),
      VoteStatus.closed => const StatusChip(
        label: 'Omröstning stängd',
        icon: Icons.lock_outline,
        tone: StatusTone.neutral,
      ),
      _ => const StatusChip(label: 'Beslutspunkt', tone: StatusTone.info),
    };
  }
}
