import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import 'signature_page.dart';

/// "Att signera": the protocols the current user has been asked to sign.
class SignaturesListPage extends CompositionWidget {
  static const String path = '/signatures';

  const SignaturesListPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final signaturesStore = inject(signaturesStoreKey);
    final loading = ref(true);

    Future<void> load() async {
      await signaturesStore.getMine();
      loading.value = false;
    }

    onMounted(load);

    return (context) {
      final items = signaturesStore.mine.value;

      return GradientScaffold(
        title: 'Att signera',
        subtitle: 'Protokoll du har ombetts att signera',
        body: Column(
          children: [
            const HelpTip(
              id: 'signatures',
              text:
                'Tryck på ett protokoll som väntar på din signatur, läs '
                'igenom det och signera med en engångskod som skickas till '
                'din e-post. Signerade protokoll ligger kvar här.',
            ),
            Expanded(
              child: loading.value
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Icon(
                            Icons.draw_outlined,
                            size: 56,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Inget att signera',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(height: 4),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'När styrelsen skickar ett protokoll till dig för signering hamnar det här.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final color = item.isSigned
                              ? AppTheme.primaryColor
                              : Colors.orange;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(
                                item.isSigned
                                    ? Icons.verified_outlined
                                    : Icons.draw_outlined,
                                color: color,
                              ),
                            ),
                            title: Text(
                              item.documentTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (item.role.isNotEmpty) item.role,
                                item.isSigned
                                    ? 'Signerad'
                                    : 'Väntar på din signatur',
                              ].join(' · '),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await context.push(
                                '${SignaturePage.path}/${item.id}',
                              );
                              signaturesStore.getMine();
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      );
    };
  }
}
