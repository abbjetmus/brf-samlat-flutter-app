import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../dashboard/pages/dashboard_page.dart';
import '../auth_store.dart' show OAuthCancelledException;
import '../widgets/oauth_buttons.dart';

class RegisterPage extends CompositionWidget {
  static const String path = '/register';

  const RegisterPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final formKey = GlobalKey<FormState>();
    final (nameController, _, __) = useTextEditingController();
    final (emailController, ___, ____) = useTextEditingController();
    final (passwordController, _____, ______) = useTextEditingController();
    final (tokenController, _______, ________) = useTextEditingController();
    final authStore = inject(authStoreKey);

    final isPasswordVisible = ref(false);
    final loading = ref(false);
    final oauthProvider = ref<String?>(null);
    final contextRef = useContext();

    void showMessage(String text, {bool error = false}) {
      final context = contextRef.value;
      if (context == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : AppTheme.primaryColor,
        ),
      );
    }

    // Google/Microsoft/Apple: only the invitation code is needed. The account
    // gets the invitation's e-mail and name even when the provider's address
    // differs (another Gmail, Apple's "Hide My Email"); association and roles
    // come from the invitation on the server (users onRecordCreateRequest).
    Future<void> handleOAuthRegister(String provider) async {
      final token = tokenController.text.trim();
      if (token.isEmpty) {
        showMessage('Ange inbjudningskoden först.', error: true);
        return;
      }

      oauthProvider.value = provider;
      try {
        final invitation = await authStore.findInvitation(token);
        if (invitation == null) {
          showMessage(
            'Inbjudan hittades inte eller har redan använts.',
            error: true,
          );
          return;
        }

        final isNew = await authStore.signInWithOAuth2(
          provider,
          createData: {
            'email': invitation.email,
            'emailVisibility': true,
            'name': invitation.name,
          },
        );

        // The provider's e-mail already belonged to another account, so
        // PocketBase signed in to that one instead of using the invitation.
        if (!isNew) {
          final existingEmail = authStore.currentUser.value?.email ?? '';
          authStore.signOut();
          showMessage(
            existingEmail.isNotEmpty
                ? 'Det kontot är redan kopplat till $existingEmail i BRF Samlat. '
                      'Logga in med det i stället.'
                : 'Det kontot är redan kopplat till ett annat konto i BRF Samlat.',
            error: true,
          );
          return;
        }

        showMessage('Konto skapat! Du är nu inloggad.');
        final context = contextRef.value;
        if (context != null && context.mounted) {
          context.go(DashboardPage.path);
        }
      } on OAuthCancelledException {
        // The member closed the sign-in sheet — nothing to report.
      } catch (error) {
        showMessage(
          error.toString().replaceAll('Exception: ', ''),
          error: true,
        );
      } finally {
        oauthProvider.value = null;
      }
    }

    Future<void> handleRegister() async {
      if (!formKey.currentState!.validate()) return;

      loading.value = true;

      try {
        final failure = await authStore.signUp(
          email: emailController.text.trim().toLowerCase(),
          password: passwordController.text,
          name: nameController.text.trim(),
          invitationToken: tokenController.text.trim(),
        );

        final context = contextRef.value;
        if (context != null && context.mounted) {
          if (failure == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Konto skapat! Du kan nu logga in.'),
                backgroundColor: AppTheme.primaryColor,
              ),
            );
            context.pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure), backgroundColor: Colors.red),
            );
          }
        }
      } finally {
        loading.value = false;
      }
    }

    return (context) => GradientScaffold(
      title: 'Registrera',
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Skapa konto',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ange inbjudningskoden du fått för att registrera dig.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Inbjudningskod',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Inbjudningskod krävs';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Namn',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Namn krävs';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-post',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'E-post krävs';
                        if (!value.contains('@')) return 'Ogiltig e-postadress';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible.value,
                      decoration: InputDecoration(
                        labelText: 'Lösenord',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              isPasswordVisible.value = !isPasswordVisible.value,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Lösenord krävs';
                        if (value.length < 8) return 'Minst 8 tecken';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: loading.value || oauthProvider.value != null
                          ? null
                          : handleRegister,
                      child: loading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Registrera', style: TextStyle(fontSize: 16)),
                    ),

                    OAuthButtons(
                      dividerText: 'eller skapa kontot med',
                      busyProvider: oauthProvider.value,
                      disabled: loading.value,
                      onSelected: handleOAuthRegister,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
