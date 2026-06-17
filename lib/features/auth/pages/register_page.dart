import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';

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
    final contextRef = useContext();

    Future<void> handleRegister() async {
      if (!formKey.currentState!.validate()) return;

      loading.value = true;

      try {
        final success = await authStore.signUp(
          email: emailController.text.trim().toLowerCase(),
          password: passwordController.text,
          name: nameController.text.trim(),
          invitationToken: tokenController.text.trim(),
        );

        final context = contextRef.value;
        if (context != null) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Konto skapat! Du kan nu logga in.'),
                backgroundColor: AppTheme.primaryColor,
              ),
            );
            context.pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registrering misslyckades. Kontrollera inbjudningskoden.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } finally {
        loading.value = false;
      }
    }

    return (context) => Scaffold(
      appBar: AppBar(
        title: const Text('Registrera'),
      ),
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
                      onPressed: loading.value ? null : handleRegister,
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
