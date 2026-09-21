import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/pages/attendance_button_page.dart';
import '../../features/attendance/presentation/pages/attendance_history_page.dart';
import '../../features/attendance/presentation/pages/attendance_status_page.dart';
import '../../features/attendance/presentation/pages/scan_success_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/kpi/presentation/pages/kpi_history_page.dart';
import '../../features/kpi/presentation/pages/kpi_leaderboard_page.dart';
import '../../features/kpi/presentation/pages/my_kpi_page.dart';
import '../../features/leave/presentation/pages/leave_balance_page.dart';
import '../../features/leave/presentation/pages/leave_confirm_page.dart';
import '../../features/leave/presentation/pages/leave_form_step1_page.dart';
import '../../features/leave/presentation/pages/leave_form_step2_page.dart';
import '../../features/leave/presentation/pages/leave_history_page.dart';
import '../../features/loans/presentation/pages/loan_history_page.dart';
import '../../features/loans/presentation/pages/loan_status_page.dart';
import '../../features/notifications/presentation/pages/notification_detail_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/payroll/presentation/pages/payslip_detail_page.dart';
import '../../features/payroll/presentation/pages/payslip_list_page.dart';
import '../../features/payroll/presentation/pages/payslip_share_page.dart';
import '../../features/profile/presentation/pages/change_password_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/notification_settings_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/spv/presentation/pages/team_attendance_page.dart';
import '../../shared/models/loan_model.dart';
import '../../shared/models/notification_model.dart';
import '../../shared/models/payslip_model.dart';
import '../../shared/widgets/bottom_nav_shell.dart';

/// Navigator root — dipakai untuk menampilkan dialog dari luar konteks halaman
/// (mis. splash yang sudah digantikan router saat dialog perlu tampil).
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // read (bukan watch) supaya router hanya dibuat sekali;
  // perubahan auth memicu redirect via refreshListenable.
  final auth = ref.read(authControllerProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      try {
        final loc = state.matchedLocation;
        final isAuthPage =
            loc == '/login' || loc == '/forgot' || loc == '/reset' || loc == '/splash';

        switch (auth.status) {
          case AuthStatus.unknown:
            return loc == '/splash' ? null : '/splash';
          case AuthStatus.unauthenticated:
            return (loc == '/login' || loc == '/forgot' || loc == '/reset') ? null : '/login';
          case AuthStatus.authenticated:
            if (isAuthPage) return '/';
            if (loc.startsWith('/spv') && !auth.canSeeTeam) return '/';
            return null;
        }
      } catch (_) {
        // Guard tidak boleh throw — kalau ada state tak terduga, aman
        // untuk lempar ke /login daripada crash seluruh app.
        return '/login';
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(
        path: '/reset',
        builder: (_, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token']),
      ),

      // ── Fullscreen (tanpa bottom nav) ──────────────────
      GoRoute(
        path: '/absensi/scan',
        builder: (_, state) => AttendanceButtonPage(
          purpose: state.uri.queryParameters['tujuan'] == 'checkout'
              ? AttendancePurpose.checkOut
              : AttendancePurpose.checkIn,
        ),
      ),
      GoRoute(
        path: '/absensi/sukses',
        builder: (_, state) =>
            ScanSuccessPage(result: state.extra as Map<String, dynamic>? ?? const {}),
      ),
      GoRoute(path: '/cuti/ajukan', builder: (_, _) => const LeaveFormStep1Page()),
      GoRoute(path: '/cuti/ajukan/2', builder: (_, _) => const LeaveFormStep2Page()),
      GoRoute(path: '/cuti/konfirmasi', builder: (_, _) => const LeaveConfirmPage()),
      GoRoute(path: '/kpi', builder: (_, _) => const MyKpiPage()),
      GoRoute(path: '/kpi/riwayat', builder: (_, _) => const KpiHistoryPage()),
      GoRoute(path: '/kpi/leaderboard', builder: (_, _) => const KpiLeaderboardPage()),
      GoRoute(path: '/slip', builder: (_, _) => const PayslipListPage()),
      GoRoute(
        path: '/slip/bagikan',
        builder: (_, state) => PayslipSharePage(slip: state.extra as Payslip),
      ),
      GoRoute(
        path: '/slip/:id',
        builder: (_, state) => PayslipDetailPage(
          slipId: state.pathParameters['id']!,
          initial: state.extra is Payslip ? state.extra as Payslip : null,
        ),
      ),
      GoRoute(path: '/pinjaman', builder: (_, _) => const LoanStatusPage()),
      GoRoute(
        path: '/pinjaman/riwayat',
        builder: (_, state) =>
            LoanHistoryPage(loan: state.extra is EmployeeLoan ? state.extra as EmployeeLoan : null),
      ),
      GoRoute(path: '/notifikasi', builder: (_, _) => const NotificationsPage()),
      GoRoute(
        path: '/notifikasi/detail',
        builder: (_, state) =>
            NotificationDetailPage(notification: state.extra as AppNotification),
      ),

      // ── Shell bottom navigation ────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            BottomNavShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/absensi',
              builder: (_, _) => const AttendanceStatusPage(),
              routes: [
                GoRoute(
                  path: 'riwayat',
                  builder: (_, _) => const AttendanceHistoryPage(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cuti',
              builder: (_, _) => const LeaveBalancePage(),
              routes: [
                GoRoute(
                  path: 'riwayat',
                  builder: (_, _) => const LeaveHistoryPage(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/spv/tim', builder: (_, _) => const TeamAttendancePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profil',
              builder: (_, _) => const ProfilePage(),
              routes: [
                GoRoute(path: 'edit', builder: (_, _) => const EditProfilePage()),
                GoRoute(path: 'password', builder: (_, _) => const ChangePasswordPage()),
                GoRoute(
                  path: 'notifikasi',
                  builder: (_, _) => const NotificationSettingsPage(),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});
