import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class AccountPage extends CompositionWidget {
  static const String path = '/account';

  const AccountPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final (nameController, _, __) = useTextEditingController();
    final (emailController, ___, ____) = useTextEditingController();
    final (oldPasswordController, _____, ______) = useTextEditingController();
    final (newPasswordController, _______, ________) = useTextEditingController();
    final (confirmPasswordController, _________, __________) = useTextEditingController();

    final loading = ref(false);
    final contextRef = useContext();

    onMounted(() {
      final user = authStore.currentUser.value;
      if (user != null) {
        nameController.text = user.name;
        emailController.text = user.email ?? '';
      }
    });

    Future<void> saveName() async {
      loading.value = true;
      final success = await authStore.updateUserName(nameController.text.trim());
      loading.value = false;
      final context = contextRef.value;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Namn uppdaterat!' : 'Kunde inte uppdatera namn.'),
            backgroundColor: success ? AppTheme.primaryColor : Colors.red,
          ),
        );
      }
    }

    Future<void> saveEmail() async {
      loading.value = true;
      final success = await authStore.updateUserEmail(emailController.text.trim());
      loading.value = false;
      final context = contextRef.value;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'E-post uppdaterad!' : 'Kunde inte uppdatera e-post.'),
            backgroundColor: success ? AppTheme.primaryColor : Colors.red,
          ),
        );
      }
    }

    Future<void> savePassword() async {
      if (newPasswordController.text != confirmPasswordController.text) {
        final context = contextRef.value;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lösenorden matchar inte.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      loading.value = true;
      final success = await authStore.updateUserPassword(
        oldPassword: oldPasswordController.text,
        password: newPasswordController.text,
        passwordConfirm: confirmPasswordController.text,
      );
      loading.value = false;

      if (success) {
        oldPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();
      }

      final context = contextRef.value;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Lösenord uppdaterat!' : 'Kunde inte uppdatera lösenord.'),
            backgroundColor: success ? AppTheme.primaryColor : Colors.red,
          ),
        );
      }
    }

    return (context) => GradientScaffold(
      title: 'Mitt konto',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Namn',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Namn',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loading.value ? null : saveName,
                      child: const Text('Spara namn'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Email section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'E-post',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-post',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loading.value ? null : saveEmail,
                      child: const Text('Spara e-post'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Password section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lösenord',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: oldPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nuvarande lösenord',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nytt lösenord',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Bekräfta nytt lösenord',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loading.value ? null : savePassword,
                      child: const Text('Byt lösenord'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
