import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=se.brfsamlat.app';
const _appStoreUrl = 'https://apps.apple.com/se/app/brf-samlat/id6743180669';

/// A blocking force-update gate that wraps the app shell. When a newer
/// version is available in the App Store / Google Play, we render a
/// full-screen, non-dismissible screen with a single "Uppdatera" action that
/// opens the store. The user cannot proceed into the app until they update,
/// so we never have to support outdated client versions.
class AppUpdateBanner extends CompositionWidget {
  final Widget child;

  const AppUpdateBanner({super.key, required this.child});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();

    final upgrader = Upgrader(
      storeController: UpgraderStoreController(
        onAndroid: () => UpgraderPlayStore(),
        oniOS: () => UpgraderAppStore(),
      ),
    );

    final updateRequired = ref<bool>(false);
    StreamSubscription<UpgraderState>? subscription;

    void evaluateUpgrade() {
      final shouldShow = upgrader.shouldDisplayUpgrade();
      if (shouldShow != updateRequired.value) {
        updateRequired.value = shouldShow;
      }
    }

    onMounted(() async {
      subscription = upgrader.stateStream.listen((_) => evaluateUpgrade());
      await upgrader.initialize();
      evaluateUpgrade();
    });

    onUnmounted(() {
      subscription?.cancel();
    });

    Future<void> openStore() async {
      final url = Platform.isIOS ? _appStoreUrl : _playStoreUrl;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    return (context) {
      final child = props.value.child;

      if (!updateRequired.value) return child;

      // Full-screen blocking gate. The user can either update or quit the
      // app — we don't render the rest of the tree at all.
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.system_update,
                        color: Colors.white,
                        size: 72,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'En ny version finns tillgänglig',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'För att fortsätta använda BRF Samlat behöver du '
                        'uppdatera till den senaste versionen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: openStore,
                          icon: const Icon(Icons.system_update),
                          label: const Text('Uppdatera appen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryDarken1,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
    };
  }
}
