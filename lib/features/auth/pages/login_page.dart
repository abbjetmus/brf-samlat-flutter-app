import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../auth_store.dart' show OAuthCancelledException;
import '../widgets/oauth_buttons.dart';
import 'forgot_password_page.dart';
import '../../dashboard/pages/dashboard_page.dart';

class LoginPage extends CompositionWidget {
  static const String path = '/login';

  const LoginPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final formKey = GlobalKey<FormState>();
    final (emailController, _, __) = useTextEditingController();
    final (passwordController, ___, ____) = useTextEditingController();
    final authStore = inject(authStoreKey);

    final isPasswordVisible = ref(false);
    final loading = ref(false);
    final oauthProvider = ref<String?>(null);
    final authError = ref<String?>(null);
    final contextRef = useContext();
    final theme = useTheme();

    // E-mail or username: an association can create members without an
    // e-mail address and give them a username (an identity field in PocketBase,
    // matched case-insensitively, so lower-casing the input is fine).
    String? validateEmail(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'E-post eller användarnamn krävs';
      }
      return null;
    }

    String? validatePassword(String? value) {
      if (value == null || value.isEmpty) return 'Lösenord krävs';
      return null;
    }

    Future<void> handleLogin() async {
      if (!formKey.currentState!.validate()) return;

      loading.value = true;
      authError.value = null;

      try {
        await authStore.signIn(
          emailController.text.trim().toLowerCase(),
          passwordController.text,
        );

        final context = contextRef.value;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inloggning lyckades!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
          context.go(DashboardPage.path);
        }
      } catch (error) {
        authError.value = error.toString().replaceAll('Exception: ', '');
        final context = contextRef.value;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authError.value ?? 'Inloggning misslyckades'),
              backgroundColor: theme.value.colorScheme.error,
            ),
          );
        }
      } finally {
        loading.value = false;
      }
    }

    // Google/Microsoft/Apple. An existing account with the provider's e-mail
    // is signed in; otherwise one is created only when there is a pending
    // invitation for that address (the server sets association and roles).
    Future<void> handleOAuthLogin(String provider) async {
      oauthProvider.value = provider;
      authError.value = null;

      try {
        await authStore.signInWithOAuth2(provider);
        final context = contextRef.value;
        if (context != null && context.mounted) {
          context.go(DashboardPage.path);
        }
      } on OAuthCancelledException {
        // The member closed the sign-in sheet — nothing to report.
      } catch (error) {
        final message = error.toString().replaceAll('Exception: ', '');
        authError.value = message.toLowerCase().contains('inbjudan')
            ? 'Det finns inget konto i BRF Samlat för den e-postadressen. '
                  'Logga in med e-post och lösenord, eller be din förening om '
                  'en inbjudan.'
            : message;
      } finally {
        oauthProvider.value = null;
      }
    }

    return (context) => Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.pine,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(
                      Icons.home_work,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'BRF Samlat',
                    style: theme.value.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Föreningen samlad på ett ställe',
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.value.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Form
                  Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (authError.value != null)
                          Builder(
                            builder: (context) {
                              final error = theme.value.colorScheme.error;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: error),
                                ),
                                child: Text(
                                  authError.value!,
                                  style: TextStyle(color: error),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),

                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9@._\-+]'),
                            ),
                          ],
                          autofillHints: const [AutofillHints.username],
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'E-post eller användarnamn',
                            prefixIcon: Icon(Icons.person_outlined),
                          ),
                          validator: validateEmail,
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
                              onPressed: () => isPasswordVisible.value =
                                  !isPasswordVisible.value,
                            ),
                          ),
                          validator: validatePassword,
                        ),
                        const SizedBox(height: 24),

                        FilledButton(
                          onPressed: loading.value || oauthProvider.value != null
                              ? null
                              : handleLogin,
                          child: loading.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Logga in',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                        const SizedBox(height: 8),

                        OAuthButtons(
                          actionText: 'Logga in med',
                          busyProvider: oauthProvider.value,
                          disabled: loading.value,
                          onSelected: handleOAuthLogin,
                        ),
                        const SizedBox(height: 8),

                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: () =>
                                context.push(ForgotPasswordPage.path),
                            child: const Text('Glömt lösenord?'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
