import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../features/auth/auth_store.dart' as auth;
import '../../features/dashboard/dashboard_store.dart';
import '../../features/posts/posts_store.dart';
import '../../features/issues/issues_store.dart';
import '../../features/calendar/calendar_store.dart';
import '../../features/places/places_store.dart';
import '../../features/gadgets/gadgets_store.dart';
import '../../features/parking/parking_store.dart';
import '../../features/residences/residences_store.dart';
import '../../features/folders/folders_store.dart';
import '../../features/board/board_store.dart';
import '../../features/users/users_store.dart';
import '../../features/invoices/invoices_store.dart';
import '../../features/forms/forms_store.dart';
import '../../features/chat/chat_store.dart';
import '../theme/theme_store.dart';
import '../services/notification_service.dart';

const pocketBaseKey = InjectionKey<PocketBase>('pocketBase');
const themeStoreKey = InjectionKey<ThemeStore>('themeStore');
const notificationServiceKey =
    InjectionKey<NotificationService>('notificationService');
const authStoreKey = InjectionKey<auth.AuthStore>('authStore');
const dashboardStoreKey = InjectionKey<DashboardStore>('dashboardStore');
const postsStoreKey = InjectionKey<PostsStore>('postsStore');
const issuesStoreKey = InjectionKey<IssuesStore>('issuesStore');
const calendarStoreKey = InjectionKey<CalendarStore>('calendarStore');
const placesStoreKey = InjectionKey<PlacesStore>('placesStore');
const gadgetsStoreKey = InjectionKey<GadgetsStore>('gadgetsStore');
const parkingStoreKey = InjectionKey<ParkingStore>('parkingStore');
const residencesStoreKey = InjectionKey<ResidencesStore>('residencesStore');
const foldersStoreKey = InjectionKey<FoldersStore>('foldersStore');
const boardStoreKey = InjectionKey<BoardStore>('boardStore');
const usersStoreKey = InjectionKey<UsersStore>('usersStore');
const invoicesStoreKey = InjectionKey<InvoicesStore>('invoicesStore');
const formsStoreKey = InjectionKey<FormsStore>('formsStore');
const chatStoreKey = InjectionKey<ChatStore>('chatStore');

auth.AuthStore? _globalAuthStore;

void setGlobalAuthStore(auth.AuthStore store) {
  _globalAuthStore = store;
}

auth.AuthStore? getGlobalAuthStore() {
  return _globalAuthStore;
}

// Global handle so the theme can be toggled from anywhere (e.g. settings),
// even outside a CompositionWidget setup scope.
ThemeStore? _globalThemeStore;

void setGlobalThemeStore(ThemeStore store) {
  _globalThemeStore = store;
}

ThemeStore? getGlobalThemeStore() {
  return _globalThemeStore;
}
