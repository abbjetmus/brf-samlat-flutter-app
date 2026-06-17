import 'package:go_router/go_router.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/account/pages/account_page.dart';
import '../../features/posts/pages/posts_list_page.dart';
import '../../features/posts/pages/post_detail_page.dart';
import '../../features/posts/pages/create_post_page.dart';
import '../../features/issues/pages/issues_list_page.dart';
import '../../features/issues/pages/issue_detail_page.dart';
import '../../features/issues/pages/create_issue_page.dart';
import '../../features/calendar/pages/calendar_page.dart';
import '../../features/places/pages/places_list_page.dart';
import '../../features/places/pages/place_detail_page.dart';
import '../../features/places/pages/create_place_page.dart';
import '../../features/gadgets/pages/gadgets_list_page.dart';
import '../../features/gadgets/pages/gadget_detail_page.dart';
import '../../features/gadgets/pages/create_gadget_page.dart';
import '../../features/residences/pages/residences_list_page.dart';
import '../../features/residences/pages/residence_detail_page.dart';
import '../../features/residences/pages/create_residence_page.dart';
import '../../features/parking/pages/parking_lots_list_page.dart';
import '../../features/parking/pages/parking_lot_detail_page.dart';
import '../../features/parking/pages/create_parking_lot_page.dart';
import '../../features/folders/pages/folders_page.dart';
import '../../features/board/pages/board_meetings_list_page.dart';
import '../../features/board/pages/board_meeting_detail_page.dart';
import '../../features/board/pages/create_board_meeting_page.dart';
import '../../features/users/pages/users_list_page.dart';
import '../../features/invoices/pages/invoices_list_page.dart';
import '../../features/invoices/pages/invoice_detail_page.dart';
import '../../features/forms/pages/forms_list_page.dart';
import '../../features/forms/pages/form_detail_page.dart';
import '../../features/chat/pages/chat_rooms_page.dart';
import '../../features/chat/pages/chat_room_page.dart';
import '../../features/chat/pages/new_chat_page.dart';
import 'auth_guard.dart';

final router = GoRouter(
  initialLocation: DashboardPage.path,
  redirect: authGuard,
  routes: [
    GoRoute(
      path: DashboardPage.path,
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: LoginPage.path,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: RegisterPage.path,
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: ForgotPasswordPage.path,
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: SettingsPage.path,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: AccountPage.path,
      builder: (context, state) => const AccountPage(),
    ),
    // Posts
    GoRoute(
      path: PostsListPage.path,
      builder: (context, state) => const PostsListPage(),
    ),
    GoRoute(
      path: '${PostDetailPage.path}/:id',
      builder: (context, state) => PostDetailPage(
        postId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: CreatePostPage.path,
      builder: (context, state) => const CreatePostPage(),
    ),
    // Issues
    GoRoute(
      path: IssuesListPage.path,
      builder: (context, state) => const IssuesListPage(),
    ),
    GoRoute(
      path: '${IssueDetailPage.path}/:id',
      builder: (context, state) => IssueDetailPage(
        issueId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: CreateIssuePage.path,
      builder: (context, state) => const CreateIssuePage(),
    ),
    // Calendar
    GoRoute(
      path: CalendarPage.path,
      builder: (context, state) => const CalendarPage(),
    ),
    // Places
    GoRoute(
      path: PlacesListPage.path,
      builder: (context, state) => const PlacesListPage(),
    ),
    GoRoute(
      path: '${PlaceDetailPage.path}/:id',
      builder: (context, state) => PlaceDetailPage(
        placeId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: CreatePlacePage.path,
      builder: (context, state) => const CreatePlacePage(),
    ),
    // Gadgets
    GoRoute(
      path: GadgetsListPage.path,
      builder: (context, state) => const GadgetsListPage(),
    ),
    GoRoute(
      path: '${GadgetDetailPage.path}/:id',
      builder: (context, state) => GadgetDetailPage(
        gadgetId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: CreateGadgetPage.path,
      builder: (context, state) => const CreateGadgetPage(),
    ),
    // Residences
    GoRoute(
      path: ResidencesListPage.path,
      builder: (context, state) => const ResidencesListPage(),
    ),
    GoRoute(
      path: '${ResidenceDetailPage.path}/:id',
      builder: (context, state) => ResidenceDetailPage(
        residenceId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: CreateResidencePage.path,
      builder: (context, state) => const CreateResidencePage(),
    ),
    // Parking
    GoRoute(
      path: ParkingLotsListPage.path,
      builder: (context, state) => const ParkingLotsListPage(),
    ),
    GoRoute(
      path: '${ParkingLotDetailPage.path}/:id',
      builder: (context, state) => ParkingLotDetailPage(
        parkingLotId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: CreateParkingLotPage.path,
      builder: (context, state) => const CreateParkingLotPage(),
    ),
    // Folders & Files
    GoRoute(
      path: FoldersPage.path,
      builder: (context, state) => const FoldersPage(),
    ),
    // Board Meetings
    GoRoute(
      path: BoardMeetingsListPage.path,
      builder: (context, state) => const BoardMeetingsListPage(),
    ),
    GoRoute(
      path: '${BoardMeetingDetailPage.path}/:id',
      builder: (context, state) => BoardMeetingDetailPage(
        meetingId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: CreateBoardMeetingPage.path,
      builder: (context, state) => const CreateBoardMeetingPage(),
    ),
    // Users
    GoRoute(
      path: UsersListPage.path,
      builder: (context, state) => const UsersListPage(),
    ),
    // Invoices
    GoRoute(
      path: InvoicesListPage.path,
      builder: (context, state) => const InvoicesListPage(),
    ),
    GoRoute(
      path: '${InvoiceDetailPage.path}/:id',
      builder: (context, state) => InvoiceDetailPage(
        invoiceId: state.pathParameters['id']!,
      ),
    ),
    // Chat
    GoRoute(
      path: ChatRoomsPage.path,
      builder: (context, state) => const ChatRoomsPage(),
    ),
    GoRoute(
      path: NewChatPage.path,
      builder: (context, state) => const NewChatPage(),
    ),
    GoRoute(
      path: '${ChatRoomPage.path}/:id',
      builder: (context, state) => ChatRoomPage(
        roomId: state.pathParameters['id']!,
        title: state.extra as String? ?? 'Chatt',
      ),
    ),
    // Forms
    GoRoute(
      path: FormsListPage.path,
      builder: (context, state) => const FormsListPage(),
    ),
    GoRoute(
      path: '${FormDetailPage.path}/:id',
      builder: (context, state) => FormDetailPage(
        formResponseId: state.pathParameters['id']!,
      ),
    ),
  ],
);
