import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/client_account/presentation/screens/client_account_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/job_request/presentation/screens/bidding_screen.dart';
import '../../features/job_request/presentation/screens/direct_quote_screen.dart';
import '../../features/job_request/presentation/screens/mode_chooser_screen.dart';
import '../../features/job_request/presentation/screens/project_quote_screen.dart';
import '../../features/onboarding/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/register_screen.dart';
import '../../features/payment/presentation/screens/app_fee_screen.dart';
import '../../features/payment/presentation/screens/job_rating_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/technician/presentation/screens/tech_docs_screen.dart';
import '../../features/technician/presentation/screens/tech_profile_screen.dart';
import '../../features/technician/presentation/screens/technician_job_detail_screen.dart';
import '../../features/technician/presentation/screens/technician_jobs_screen.dart';
import '../../features/technician/presentation/screens/technician_profile_screen.dart';
import '../../features/tracking/presentation/screens/tracking_screen.dart';
import '../../features/welcome/presentation/screens/welcome_screen.dart';
import 'app_shell.dart';
import 'route_paths.dart';

part 'app_router.g.dart';

// Routes reachable without an authenticated session; the splash screen
// owns its own timing/navigation, so it's exempt from the guard below.
const _publicRoutes = {RoutePaths.splash, RoutePaths.login, RoutePaths.register};

// Routes that only make sense for a client account. A technician account
// hitting one of these (e.g. a stale deep link) is bounced to their job inbox.
// `chat` is deliberately excluded: both a client and the technician assigned
// to a job need it, keyed off the same shared job session.
const _clientOnlyRoutes = {
  RoutePaths.home,
  RoutePaths.providerProfile,
  RoutePaths.jobMode,
  RoutePaths.jobDirect,
  RoutePaths.jobBidding,
  RoutePaths.jobProjectQuote,
  RoutePaths.jobFee,
  RoutePaths.tracking,
  RoutePaths.jobRating,
  RoutePaths.clientAccount,
};

// Routes that only make sense for a technician account.
const _technicianOnlyRoutes = {
  RoutePaths.techDocs,
  RoutePaths.techProfile,
  RoutePaths.technicianJobs,
  RoutePaths.technicianJobDetail,
};

/// Bridges a Riverpod provider to the `Listenable` GoRouter wants, so the
/// guard below re-runs on every session change.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

/// Built **once** per app run, on purpose.
///
/// Watching `authControllerProvider` here instead would rebuild the
/// provider — and with it the whole `GoRouter` — on every session
/// change, and a fresh router starts over at `initialLocation`. That is
/// how a failed login used to dump the person on the splash screen
/// rather than leaving them on the form with the error. `refreshListenable`
/// gets the redirect re-evaluated without throwing the router away.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (_publicRoutes.contains(location)) return null;

      return ref.read(authControllerProvider).when(
        data: (session) {
          if (session == null) return RoutePaths.login;
          if (session.user.isTechnician && _clientOnlyRoutes.contains(location)) {
            return RoutePaths.technicianJobs;
          }
          if (session.user.isClient && _technicianOnlyRoutes.contains(location)) {
            return RoutePaths.home;
          }
          return null;
        },
        loading: () => null,
        error: (_, _) => RoutePaths.login,
      );
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.techDocs,
        builder: (context, state) => const TechDocsScreen(),
      ),
      GoRoute(
        path: RoutePaths.technicianJobDetail,
        builder: (context, state) => const TechnicianJobDetailScreen(),
      ),
      GoRoute(
        path: RoutePaths.providerProfile,
        builder: (context, state) => const TechnicianProfileScreen(),
      ),
      // Client hub: Inicio / Cuenta share one persistent bottom nav instead
      // of the header-avatar shortcut being the only way between them.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          tabs: const [
            AppShellTab(label: 'Inicio', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
            AppShellTab(label: 'Cuenta', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.home, builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.clientAccount, builder: (context, state) => const ClientAccountScreen()),
          ]),
        ],
      ),
      // Technician hub: Trabajos / Perfil, same pattern.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          tabs: const [
            AppShellTab(label: 'Trabajos', icon: Icons.work_outline_rounded, activeIcon: Icons.work_rounded),
            AppShellTab(label: 'Perfil', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.technicianJobs, builder: (context, state) => const TechnicianJobsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.techProfile, builder: (context, state) => const TechProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: RoutePaths.jobMode,
        builder: (context, state) => const ModeChooserScreen(),
      ),
      GoRoute(
        path: RoutePaths.jobDirect,
        builder: (context, state) => const DirectQuoteScreen(),
      ),
      GoRoute(
        path: RoutePaths.jobBidding,
        builder: (context, state) => const BiddingScreen(),
      ),
      GoRoute(
        path: RoutePaths.jobProjectQuote,
        builder: (context, state) => const ProjectQuoteScreen(),
      ),
      GoRoute(
        path: RoutePaths.jobFee,
        builder: (context, state) => const AppFeeScreen(),
      ),
      GoRoute(
        path: RoutePaths.chat,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: RoutePaths.tracking,
        builder: (context, state) => const TrackingScreen(),
      ),
      GoRoute(
        path: RoutePaths.jobRating,
        builder: (context, state) => const JobRatingScreen(),
      ),
    ],
  );
}
