import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/image_thumbnail.dart';
import '../../auth/pages/login_page.dart';

class AccountPage extends CompositionWidget {
  static const String path = '/account';

  const AccountPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final pocketBase = inject(pocketBaseKey);
    final (nameController, _, __) = useTextEditingController();
    final (emailController, ___, ____) = useTextEditingController();
    final (oldPasswordController, _____, ______) = useTextEditingController();
    final (newPasswordController, _______, ________) = useTextEditingController();
    final (confirmPasswordController, _________, __________) = useTextEditingController();

    final loading = ref(false);
    final contextRef = useContext();
    final imagePicker = ImagePicker();

    onMounted(() {
      final user = authStore.currentUser.value;
      if (user != null) {
        nameController.text = user.name;
        emailController.text = user.email ?? '';
      }
    });

    String? avatarUrl(UsersRecord? user) {
      if (user == null || user.avatar == null || user.avatar!.isEmpty) {
        return null;
      }
      return getImageUrl(Collections.users, user.id, user.avatar!);
    }

    Future<void> handleImage(File? file) async {
      loading.value = true;
      // An empty list tells the store to clear the avatar.
      final success = await authStore.updateUserImage(file ?? []);
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        final removing = file == null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (removing ? 'Profilbild borttagen!' : 'Profilbild uppdaterad!')
                  : (removing
                        ? 'Kunde inte ta bort profilbild.'
                        : 'Kunde inte uppdatera profilbild.'),
            ),
            backgroundColor: success ? AppTheme.primaryColor : Colors.red,
          ),
        );
      }
    }

    Future<void> pickImage() async {
      final picked = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        await handleImage(File(picked.path));
      }
    }

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

    // GDPR: "Ladda ner mina uppgifter". The app can't save files without an
    // extra plugin, so the export (GET /api/users/export) is opened in the
    // browser instead, authenticated by a short-lived file token in the link —
    // the browser has no session of its own. The link only works for a few
    // minutes, and the browser downloads or shows the JSON file.
    Future<void> exportData() async {
      loading.value = true;
      var opened = false;
      try {
        final token = await pocketBase.files.getToken();
        final uri = pocketBase.buildURL('/api/users/export', {'token': token});
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('AccountPage: Error exporting data: $e');
        opened = false;
      }
      loading.value = false;

      final context = contextRef.value;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              opened
                  ? 'Dina uppgifter öppnas i webbläsaren.'
                  : 'Kunde inte hämta dina uppgifter.',
            ),
            backgroundColor: opened ? AppTheme.primaryColor : Colors.red,
          ),
        );
      }
    }

    Future<void> deleteAccount() async {
      final context = contextRef.value;
      if (context == null || !context.mounted) return;

      final confirmed = await showConfirmDialog(
        context,
        title: 'Radera ditt konto?',
        message:
            'Kontot raderas permanent och du kan inte logga in igen. Dina '
            'personuppgifter, notisinställningar och formulärsvar tas bort. '
            'Föreningens inlägg och felanmälningar står kvar men visar '
            '"Borttagen användare" som avsändare.\n\nÅtgärden kan inte ångras.',
        okLabel: 'Radera konto',
        okColor: Colors.red,
      );
      if (!confirmed) return;

      loading.value = true;
      final failure = await authStore.deleteAccount();
      loading.value = false;

      final current = contextRef.value;
      if (current == null || !current.mounted) return;

      if (failure != null) {
        ScaffoldMessenger.of(current).showSnackBar(
          SnackBar(content: Text(failure), backgroundColor: Colors.red),
        );
        return;
      }
      current.go(LoginPage.path);
    }

    return (context) {
      final user = authStore.currentUser.value;
      return GradientScaffold(
      title: 'Mitt konto',
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile image
            const SizedBox(height: 8),
            Center(
              child: ImageThumbnail(
                size: 140,
                photoUrl: avatarUrl(user),
                onPickImage: loading.value ? () {} : pickImage,
                onRemoveImage: loading.value ? () {} : () => handleImage(null),
              ),
            ),
            const SizedBox(height: 24),

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
            const SizedBox(height: 16),

            // GDPR data export (art. 15/20).
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ladda ner mina uppgifter',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Få en fil med allt som har sparats om dig: profil, bostad, '
                      'felanmälningar, bokningar, formulärsvar, chattmeddelanden, '
                      'notiser, avgifter och signeringar. Filen öppnas i '
                      'webbläsaren via en länk som bara gäller i några minuter.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: loading.value ? null : exportData,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Ladda ner mina uppgifter'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Account deletion. App Store and Google Play both require this for
            // an app that lets people register, and brfsamlat.se/radera-konto
            // points members here.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Radera konto',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ditt konto raderas permanent och du kan inte logga in igen. '
                      'Dina personuppgifter, notisinställningar och formulärsvar '
                      'tas bort.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: loading.value ? null : deleteAccount,
                      icon: const Icon(Icons.delete_forever_outlined, size: 18),
                      label: const Text('Radera mitt konto'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    };
  }
}
