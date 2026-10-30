import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import 'board_meeting_detail_page.dart';
import 'create_board_meeting_page.dart';

/// The board landing page. Shows two tabs: the association's members with
/// roles (which can be added/removed) and the list of board meetings. The
/// members tab lists the board (users with a board role) and, separately,
/// "Övriga roller" (e.g. valberedning, fastighetsskötare).
class BoardDetailsPage extends CompositionWidget {
  static const String path = '/board';

  const BoardDetailsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final boardStore = inject(boardStoreKey);
    final usersStore = inject(usersStoreKey);
    final authStore = inject(authStoreKey);
    final contextRef = useContext();

    onMounted(() {
      boardStore.getBoardMembers();
      // Role names and the board/other split of roles come from the lookup.
      if (authStore.associationRoleTypes.value.isEmpty) {
        authStore.loadAssociationRoleTypes();
      }
      // Only fetch meetings if allowed — members with `board` read see the roster
      // but not meetings (the API now enforces board_meetings read too).
      if (authStore.hasPermission('board_meetings', CrudOperation.read)) {
        boardStore.getAllBoardMeetings();
      }
    });

    // Comma-separated display names of a member's assigned association roles.
    String roleNamesFor(UsersRecord user) {
      final roleTypes = authStore.associationRoleTypes.value;
      return user.associationRoleTypes
          .map((id) {
            final role = roleTypes.where((r) => r.id == id).firstOrNull;
            if (role == null) return '';
            return role.displayName.isNotEmpty ? role.displayName : role.name;
          })
          .where((name) => name.isNotEmpty)
          .join(', ');
    }

    // Create (member == null) or edit a member's roles: pick a user and assign
    // one or more association roles (board roles and/or other roles).
    Future<void> showMemberDialog({UsersRecord? member}) async {
      final isEdit = member != null;
      final roleTypes = authStore.associationRoleTypes.value;
      final boardRoles = roleTypes.where((r) => r.isBoardRole).toList();
      final otherRoles = roleTypes.where((r) => !r.isBoardRole).toList();

      // When adding, offer association users without roles; users that already
      // have roles are edited via "Redigera roller" so none are overwritten.
      List<UsersRecord> candidates = const [];
      if (!isEdit) {
        final all = await usersStore.getAllAssociationUsers();
        final memberIds = {
          ...boardStore.boardMembers.value.map((m) => m.id),
          ...boardStore.otherRoleMembers.value.map((m) => m.id),
        };
        candidates = all.where((u) => !memberIds.contains(u.id)).toList();
      }

      final context = contextRef.value;
      if (context == null || !context.mounted) return;

      String? selectedUserId = member?.id;
      final selectedRoleIds = List<String>.from(
        member?.associationRoleTypes ?? const [],
      );

      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) {
            Widget roleChips(List<AssociationRoleTypesRecord> roles) => Wrap(
              spacing: 8,
              runSpacing: 4,
              children: roles.map((rt) {
                final selected = selectedRoleIds.contains(rt.id);
                return FilterChip(
                  label: Text(
                    rt.displayName.isNotEmpty ? rt.displayName : rt.name,
                  ),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        if (!selectedRoleIds.contains(rt.id)) {
                          selectedRoleIds.add(rt.id);
                        }
                      } else {
                        selectedRoleIds.remove(rt.id);
                      }
                    });
                  },
                );
              }).toList(),
            );

            return AlertDialog(
              title: Text(isEdit ? 'Redigera roller' : 'Tilldela roller'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEdit)
                      Text(
                        member.name.isNotEmpty
                            ? member.name
                            : (member.email ?? member.id),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (candidates.isEmpty)
                      const Text('Inga fler användare att lägga till.')
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selectedUserId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Användare',
                          border: OutlineInputBorder(),
                        ),
                        items: candidates
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text(
                                  u.name.isNotEmpty
                                      ? u.name
                                      : (u.email ?? u.id),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => selectedUserId = v),
                      ),
                    if (roleTypes.isEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Inga roller tillgängliga.'),
                    ],
                    if (boardRoles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Styrelseroller',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      roleChips(boardRoles),
                    ],
                    if (otherRoles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Övriga roller',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      roleChips(otherRoles),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Avbryt'),
                ),
                FilledButton(
                  onPressed:
                      (selectedUserId != null && selectedRoleIds.isNotEmpty)
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: Text(isEdit ? 'Spara' : 'Lägg till'),
                ),
              ],
            );
          },
        ),
      );

      if (result == true && selectedUserId != null) {
        await boardStore.setBoardMemberRoles(
          userId: selectedUserId!,
          roleTypeIds: selectedRoleIds,
        );
      }
    }

    return (context) {
      final members = boardStore.boardMembers.value;
      final otherMembers = boardStore.otherRoleMembers.value;
      final meetings = boardStore.boardMeetings.value;
      final meetingsLoading = boardStore.listLoading.value;
      final loadingMore = boardStore.loadingMore.value;
      final hasMore = boardStore.hasMore.value;

      final canManageMembers = authStore.hasPermission(
        'board',
        CrudOperation.update,
      );
      // Meetings & protocols are a separate permission; members with only `board`
      // read see the roster but not the Möten tab.
      final canReadMeetings = authStore.hasPermission(
        'board_meetings',
        CrudOperation.read,
      );
      final canCreateMeeting = authStore.hasPermission(
        'board_meetings',
        CrudOperation.create,
      );

      Widget memberCard(UsersRecord member, {required bool isBoard}) {
        final roles = roleNamesFor(member);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                member.name.isNotEmpty
                    ? member.name
                    : (member.email ?? member.id),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roles.isNotEmpty)
                    Text(
                      roles,
                      style: TextStyle(
                        color: isBoard
                            ? AppTheme.primaryColor
                            : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (member.email != null && member.email!.isNotEmpty)
                    Text(
                      member.email!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
              trailing: canManageMembers
                  ? EntityActionMenu(
                      actions: [
                        EntityAction.update(
                          () => showMemberDialog(member: member),
                          label: 'Redigera roller',
                        ),
                        EntityAction.delete(
                          () async {
                            final confirmed = await showConfirmDialog(
                              context,
                              title: isBoard
                                  ? 'Ta bort från styrelsen'
                                  : 'Ta bort roller',
                              message: isBoard
                                  ? 'Är du säker på att du vill ta bort personen från styrelsen? Eventuella övriga roller behålls.'
                                  : 'Är du säker på att du vill ta bort personens roller?',
                              okLabel: 'Ta bort',
                              okColor: Colors.red,
                            );
                            if (!confirmed) return;
                            if (isBoard) {
                              await boardStore.removeBoardMember(member);
                            } else {
                              await boardStore.removeAllRoles(member.id);
                            }
                          },
                          label: isBoard
                              ? 'Ta bort från styrelsen'
                              : 'Ta bort roller',
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        );
      }

      Widget sectionHeader(String title, {String? subtitle}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
      );

      Widget membersTab() {
        if (members.isEmpty && otherMembers.isEmpty) {
          return const Center(child: Text('Inga styrelsemedlemmar ännu.'));
        }
        return RefreshIndicator(
          onRefresh: boardStore.getBoardMembers,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              sectionHeader('Styrelsemedlemmar'),
              if (members.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Inga styrelsemedlemmar ännu.'),
                )
              else
                for (final member in members) memberCard(member, isBoard: true),
              // Roles outside the board (valberedning, fastighetsskötare, …).
              if (otherMembers.isNotEmpty) ...[
                sectionHeader(
                  'Övriga roller',
                  subtitle: 'Roller utanför styrelsen',
                ),
                for (final member in otherMembers)
                  memberCard(member, isBoard: false),
              ],
            ],
          ),
        );
      }

      Widget meetingsTab() {
        if (meetingsLoading && meetings.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (meetings.isEmpty) {
          return const Center(child: Text('Inga styrelsemöten ännu.'));
        }
        return PaginatedListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: meetings.length,
          hasMore: hasMore,
          loadingMore: loadingMore,
          onLoadMore: boardStore.fetchNextBoardMeetings,
          onRefresh: boardStore.getAllBoardMeetings,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final meeting = meetings[index];
            final dateStr = AppDateUtils.formatDateLong(meeting.startAt);
            final timeStr = AppDateUtils.formatTime(meeting.startAt);
            final address =
                '${meeting.streetAddress}, ${meeting.zipCode} ${meeting.locality}';

            return Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(
                  Icons.groups_outlined,
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  dateStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kl. $timeStr',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '${BoardMeetingDetailPage.path}/${meeting.id}',
                ),
              ),
            );
          },
        );
      }

      final boardTip = [
        if (canManageMembers)
          'Styrelsen är de som har en styrelseroll. Övriga föreningsroller, '
              't.ex. valberedning, visas under Övriga roller.',
        if (canReadMeetings && canCreateMeeting)
          'Under Möten skriver du protokoll och skickar det för e-signering.',
      ].join(' ');

      return DefaultTabController(
        length: canReadMeetings ? 2 : 1,
        child: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return GradientScaffold(
              title: 'Styrelsen',
              floatingActionButton: AnimatedBuilder(
                animation: tabController,
                builder: (context, _) {
                  if (tabController.index == 0 && canManageMembers) {
                    return FloatingActionButton(
                      onPressed: () => showMemberDialog(),
                      child: const Icon(Icons.person_add),
                    );
                  }
                  if (canReadMeetings &&
                      tabController.index == 1 &&
                      canCreateMeeting) {
                    return FloatingActionButton(
                      onPressed: () =>
                          context.push(CreateBoardMeetingPage.path),
                      child: const Icon(Icons.add),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              body: Column(
                children: [
                  if (boardTip.isNotEmpty)
                    HelpTip(id: 'board', text: boardTip),
                  TabBar(
                    tabs: [
                      const Tab(text: 'Medlemmar'),
                      if (canReadMeetings) const Tab(text: 'Möten'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        membersTab(),
                        if (canReadMeetings) meetingsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    };
  }
}
