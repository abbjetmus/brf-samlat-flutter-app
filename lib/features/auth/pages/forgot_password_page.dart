import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class ForgotPasswordPage extends CompositionWidget {
  static const String path = '/forgot-password';

  const ForgotPasswordPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final formKey = GlobalKey<FormState>();
    final (emailController, _, __) = useTextEditingController();
    final authStore = inject(authStoreKey);

    final loading = ref(false);
    final emailSent = ref(false);
    final contextRef = useContext();

    Future<void> handleReset() async {
      if (!formKey.currentState!.validate()) return;

      loading.value = true;

      try {
        final success = await authStore.forgotPassword(
          emailController.text.trim().toLowerCase(),
        );

        final context = contextRef.value;
        if (context != null) {
          if (success) {
            emailSent.value = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Återställningslänk skickad till din e-post!'),
                backgroundColor: AppTheme.primaryColor,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kunde inte skicka återställningslänk.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } finally {
        loading.value = false;
      }
    }

    return (context) => GradientScaffold(
      title: 'Glömt lösenord',
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: emailSent.value
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.mark_email_read_outlined,
                          size: 80,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'E-post skickad!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Kontrollera din e-post för en länk att återställa ditt lösenord.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 32),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Tillbaka till inloggning'),
                        ),
                      ],
                    )
                  : Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Återställ lösenord',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ange din e-postadress så skickar vi en återställningslänk.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-post',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'E-post krävs';
                              }
                              if (!value.contains('@')) {
                                return 'Ogiltig e-postadress';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          FilledButton(
                            onPressed: loading.value ? null : handleReset,
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
                                    'Skicka återställningslänk',
                                    style: TextStyle(fontSize: 16),
                                  ),
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
