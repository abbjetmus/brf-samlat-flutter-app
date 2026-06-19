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
import '../../../shared/widgets/paginated_list_view.dart';
import 'board_meeting_detail_page.dart';
import 'create_board_meeting_page.dart';

/// The board landing page. Shows two tabs: the association's board members
/// (which can be added/removed) and the list of board meetings.
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
      boardStore.getAllBoardMeetings();
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

    // Create (member == null) or edit a board member: pick a user and assign
    // one or more association roles.
    Future<void> showMemberDialog({UsersRecord? member}) async {
      final isEdit = member != null;
      final roleTypes = authStore.associationRoleTypes.value;

      // When adding, offer association users that aren't already members.
      List<UsersRecord> candidates = const [];
      if (!isEdit) {
        final all = await usersStore.getAllAssociationUsers();
        final memberIds = boardStore.boardMembers.value
            .map((m) => m.id)
            .toSet();
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
          builder: (context, setState) => AlertDialog(
            title: Text(
              isEdit ? 'Redigera styrelsemedlem' : 'Lägg till styrelsemedlem',
            ),
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
                                u.name.isNotEmpty ? u.name : (u.email ?? u.id),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedUserId = v),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Roller',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (roleTypes.isEmpty)
                    const Text('Inga roller tillgängliga.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: roleTypes.map((rt) {
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
                    ),
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
          ),
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
      final meetings = boardStore.boardMeetings.value;
      final meetingsLoading = boardStore.listLoading.value;
      final loadingMore = boardStore.loadingMore.value;
      final hasMore = boardStore.hasMore.value;

      final canManageMembers = authStore.hasPermission(
        'board_meetings',
        CrudOperation.update,
      );
      final canCreateMeeting = authStore.hasPermission(
        'board_meetings',
        CrudOperation.create,
      );

      Widget membersTab() {
        if (members.isEmpty) {
          return const Center(child: Text('Inga styrelsemedlemmar ännu.'));
        }
        return RefreshIndicator(
          onRefresh: boardStore.getBoardMembers,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final member = members[index];
              final roles = roleNamesFor(member);
              return Card(
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
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (member.email != null && member.email!.isNotEmpty)
                        Text(
                          member.email!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
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
                            EntityAction.delete(() async {
                              final confirmed = await showConfirmDialog(
                                context,
                                title: 'Ta bort styrelsemedlem',
                                message:
                                    'Är du säker på att du vill ta bort denna styrelsemedlem?',
                                okLabel: 'Ta bort',
                                okColor: Colors.red,
                              );
                              if (confirmed) {
                                await boardStore.removeBoardMember(member.id);
                              }
                            }, label: 'Ta bort'),
                          ],
                        )
                      : null,
                ),
              );
            },
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

      return DefaultTabController(
        length: 2,
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
                  if (tabController.index == 1 && canCreateMeeting) {
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
                  const TabBar(
                    tabs: [
                      Tab(text: 'Medlemmar'),
                      Tab(text: 'Möten'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [membersTab(), meetingsTab()],
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
