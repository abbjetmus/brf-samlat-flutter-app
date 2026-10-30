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
import '../../features/board/pages/board_details_page.dart';
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
import '../../features/help/pages/help_page.dart';
import '../../features/permissions/pages/permissions_page.dart';
import '../../features/signatures/pages/signatures_list_page.dart';
import '../../features/signatures/pages/signature_page.dart';
import '../../features/annual_wheel/pages/annual_wheel_page.dart';
import '../../features/general_meetings/pages/general_meetings_list_page.dart';
import '../../features/general_meetings/pages/general_meeting_detail_page.dart';
import '../../features/maintenance_plan/pages/maintenance_plan_page.dart';
import '../../features/residence_applications/pages/residence_applications_page.dart';
import '../../features/residence_applications/pages/create_residence_application_page.dart';
import '../../features/residence_applications/pages/residence_application_detail_page.dart';
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
    GoRoute(
      path: '${CreatePostPage.editPath}/:id',
      builder: (context, state) => CreatePostPage(
        postId: state.pathParameters['id']!,
      ),
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
      builder: (context, state) => CreateIssuePage(
        residenceId: state.uri.queryParameters['residenceId'],
      ),
    ),
    GoRoute(
      path: '${CreateIssuePage.editPath}/:id',
      builder: (context, state) => CreateIssuePage(
        issueId: state.pathParameters['id']!,
      ),
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
    GoRoute(
      path: '${CreatePlacePage.editPath}/:id',
      builder: (context, state) =>
          CreatePlacePage(placeId: state.pathParameters['id']!),
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
    GoRoute(
      path: '${CreateGadgetPage.editPath}/:id',
      builder: (context, state) =>
          CreateGadgetPage(gadgetId: state.pathParameters['id']!),
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
    GoRoute(
      path: '${CreateResidencePage.editPath}/:id',
      builder: (context, state) => CreateResidencePage(
        residenceId: state.pathParameters['id']!,
      ),
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
    GoRoute(
      path: '${CreateParkingLotPage.editPath}/:id',
      builder: (context, state) => CreateParkingLotPage(
        parkingLotId: state.pathParameters['id']!,
      ),
    ),
    // Folders & Files
    GoRoute(
      path: FoldersPage.path,
      builder: (context, state) => const FoldersPage(),
    ),
    // Board Meetings
    GoRoute(
      path: BoardDetailsPage.path,
      builder: (context, state) => const BoardDetailsPage(),
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
    // E-signing
    GoRoute(
      path: SignaturesListPage.path,
      builder: (context, state) => const SignaturesListPage(),
    ),
    GoRoute(
      path: '${SignaturePage.path}/:id',
      builder: (context, state) => SignaturePage(
        signatureId: state.pathParameters['id']!,
      ),
    ),
    // Annual wheel
    GoRoute(
      path: AnnualWheelPage.path,
      builder: (context, state) => const AnnualWheelPage(),
    ),
    // Föreningsstämma (push: /app/general-meetings/<id>)
    GoRoute(
      path: GeneralMeetingsListPage.path,
      builder: (context, state) => const GeneralMeetingsListPage(),
    ),
    GoRoute(
      path: '${GeneralMeetingDetailPage.path}/:id',
      builder: (context, state) => GeneralMeetingDetailPage(
        meetingId: state.pathParameters['id']!,
      ),
    ),
    // Maintenance plan (read-only)
    GoRoute(
      path: MaintenancePlanPage.path,
      builder: (context, state) => const MaintenancePlanPage(),
    ),
    // Residence applications
    GoRoute(
      path: ResidenceApplicationsPage.path,
      builder: (context, state) => const ResidenceApplicationsPage(),
    ),
    GoRoute(
      path: CreateResidenceApplicationPage.path,
      builder: (context, state) => const CreateResidenceApplicationPage(),
    ),
    GoRoute(
      path: '${ResidenceApplicationDetailPage.path}/:id',
      builder: (context, state) => ResidenceApplicationDetailPage(
        applicationId: state.pathParameters['id']!,
      ),
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
    // Permissions
    GoRoute(
      path: PermissionsPage.path,
      builder: (context, state) => const PermissionsPage(),
    ),
    // Help
    GoRoute(
      path: HelpPage.path,
      builder: (context, state) => const HelpPage(),
    ),
  ],
);
