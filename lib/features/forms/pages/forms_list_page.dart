import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import 'form_detail_page.dart';

class FormsListPage extends CompositionWidget {
  static const String path = '/forms';

  const FormsListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final formsStore = inject(formsStoreKey);

    onMounted(() {
      formsStore.getUserFormResponses();
    });

    return (context) {
      final responses = formsStore.userFormResponses.value;
      final loading = formsStore.listLoading.value;
      final loadingMore = formsStore.loadingMore.value;
      final hasMore = formsStore.hasMore.value;

      return GradientScaffold(
        title: 'Formulär',
        body: loading && responses.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : responses.isEmpty
            ? const Center(child: Text('Inga formulär.'))
            : PaginatedListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: responses.length,
                hasMore: hasMore,
                loadingMore: loadingMore,
                onLoadMore: formsStore.fetchNextForms,
                onRefresh: formsStore.getUserFormResponses,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final response = responses[index];
                  final expandForm = response.expand?['form'];
                  String formName = 'Formulär';
                  if (expandForm is Map<String, dynamic>) {
                    formName = expandForm['name'] as String? ?? 'Formulär';
                  } else if (expandForm is List && expandForm.isNotEmpty) {
                    formName =
                        (expandForm.first as Map<String, dynamic>)['name']
                            as String? ??
                        'Formulär';
                  }
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: Text(
                        formName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('${FormDetailPage.path}/${response.id}'),
                    ),
                  );
                },
              ),
      );
    };
  }
}
