import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:syncfusion_localizations/syncfusion_localizations.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/router/router.dart';
import 'core/pocketbase/pocketbase_client.dart';
import 'core/di/injection_keys.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_store.dart';
import 'core/services/notification_service.dart';
import 'core/utils/date_utils.dart';
import 'features/auth/auth_store.dart' as auth;
import 'features/dashboard/dashboard_store.dart';
import 'features/posts/posts_store.dart';
import 'features/issues/issues_store.dart';
import 'features/calendar/calendar_store.dart';
import 'features/places/places_store.dart';
import 'features/gadgets/gadgets_store.dart';
import 'features/residences/residences_store.dart';
import 'features/parking/parking_store.dart';
import 'features/folders/folders_store.dart';
import 'features/board/board_store.dart';
import 'features/users/users_store.dart';
import 'features/invoices/invoices_store.dart';
import 'features/forms/forms_store.dart';
import 'features/chat/chat_store.dart';
import 'shared/widgets/app_update_banner.dart';

// Top-level background handler so FCM can wake the isolate. The OS displays the
// notification from the tray; nothing extra is needed here.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the app to portrait orientation on all devices.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase from the generated options so config is explicit on
  // both platforms (matches the native google-services.json / plist).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  await PocketBaseClient.initialize();
  await AppDateUtils.initializeLocale();

  runApp(const MyApp());
}

class MyApp extends CompositionWidget {
  const MyApp({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final pocketBase = PocketBaseClient.instance;
    final authStore = auth.AuthStore(pocketBase);
    final dashboardStore = DashboardStore(pocketBase, authStore);
    final postsStore = PostsStore(pocketBase, authStore);
    final issuesStore = IssuesStore(pocketBase, authStore);
    final calendarStore = CalendarStore(pocketBase, authStore);
    final placesStore = PlacesStore(pocketBase, authStore);
    final gadgetsStore = GadgetsStore(pocketBase, authStore);
    final residencesStore = ResidencesStore(pocketBase, authStore);
    final parkingStore = ParkingStore(pocketBase, authStore);
    final foldersStore = FoldersStore(pocketBase, authStore);
    final boardStore = BoardStore(pocketBase, authStore);
    final usersStore = UsersStore(pocketBase, authStore);
    final invoicesStore = InvoicesStore(pocketBase, authStore);
    final formsStore = FormsStore(pocketBase, authStore);
    final chatStore = ChatStore(pocketBase, authStore);
    final themeStore = ThemeStore();
    final notificationService = NotificationService(pocketBase);

    provide(pocketBaseKey, pocketBase);
    provide(themeStoreKey, themeStore);
    provide(notificationServiceKey, notificationService);
    provide(authStoreKey, authStore);
    provide(dashboardStoreKey, dashboardStore);
    provide(postsStoreKey, postsStore);
    provide(issuesStoreKey, issuesStore);
    provide(calendarStoreKey, calendarStore);
    provide(placesStoreKey, placesStore);
    provide(gadgetsStoreKey, gadgetsStore);
    provide(residencesStoreKey, residencesStore);
    provide(parkingStoreKey, parkingStore);
    provide(foldersStoreKey, foldersStore);
    provide(boardStoreKey, boardStore);
    provide(usersStoreKey, usersStore);
    provide(invoicesStoreKey, invoicesStore);
    provide(formsStoreKey, formsStore);
    provide(chatStoreKey, chatStore);

    setGlobalAuthStore(authStore);
    setGlobalThemeStore(themeStore);

    onMounted(() async {
      await themeStore.initialize();
      await notificationService.initialize();
      notificationService.setRouter(router);
    });

    // Register the FCM token when a user logs in, remove it on logout.
    String? previousUserId;
    watchEffect(() {
      final user = authStore.currentUser.value;
      if (user != null && user.id != previousUserId) {
        previousUserId = user.id;
        notificationService.registerToken(user.id);
      } else if (user == null && previousUserId != null) {
        previousUserId = null;
        notificationService.unregisterToken();
      }
    });

    return (context) => MaterialApp.router(
      title: 'BRF Samlat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeStore.themeMode.value,
      routerConfig: router,
      // Force Swedish across Material widgets, date/time pickers and the
      // Syncfusion calendar (month/day names, "today", agenda labels, etc.).
      locale: const Locale('sv'),
      supportedLocales: const [Locale('sv')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        SfGlobalLocalizations.delegate,
      ],
      builder: (context, child) => AppUpdateBanner(
        child: child ?? const SizedBox(),
      ),
    );
  }
}
