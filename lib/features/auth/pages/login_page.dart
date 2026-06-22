import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
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
    final authError = ref<String?>(null);
    final contextRef = useContext();
    final theme = useTheme();

    String? validateEmail(String? value) {
      if (value == null || value.isEmpty) return 'E-post krävs';
      if (!value.contains('@')) return 'Ogiltig e-postadress';
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
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        loading.value = false;
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
                      gradient: AppTheme.brandGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
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
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: theme.value.colorScheme.onSurface,
                    ),
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
                              final error = Theme.of(context).colorScheme.error;
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
                          decoration: const InputDecoration(
                            labelText: 'E-post',
                            prefixIcon: Icon(Icons.email_outlined),
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
                          onPressed: loading.value ? null : handleLogin,
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
                        const SizedBox(height: 24),

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
