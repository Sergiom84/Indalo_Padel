import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/bookings/screens/booking_confirmation_screen.dart';
import '../../features/bookings/screens/booking_form_screen.dart';
import '../../features/bookings/screens/my_bookings_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/matches/screens/match_create_screen.dart';
import '../../features/matches/screens/match_detail_screen.dart';
import '../../features/matches/screens/match_list_screen.dart';
import '../../features/players/screens/player_profile_screen.dart';
import '../../features/players/screens/player_search_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/venues/screens/venue_detail_screen.dart';
import '../../features/venues/screens/venue_list_screen.dart';
import '../../shared/widgets/app_bottom_nav.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _venuesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'venues');
final _calendarNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'calendar');
final _communityNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'community');
final _playersNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'players');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen<AuthState>(authProvider, (_, __) {
    notifier.refresh();
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.loading) {
        return null;
      }

      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/booking/:id/confirmation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return BookingConfirmationScreen(bookingData: extra);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _venuesNavigatorKey,
            routes: [
              GoRoute(
                path: '/venues',
                builder: (context, state) => const VenueListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return VenueDetailScreen(venueId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/booking/:courtId',
                builder: (context, state) {
                  final courtId = state.pathParameters['courtId']!;
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  return BookingFormScreen(
                    courtId: courtId,
                    bookingState: extra,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _calendarNavigatorKey,
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const MyBookingsScreen(),
              ),
              GoRoute(
                path: '/my-bookings',
                builder: (context, state) => const MyBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _communityNavigatorKey,
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) => const CommunityScreen(),
              ),
              GoRoute(
                path: '/matches',
                builder: (context, state) => const MatchListScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const MatchCreateScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return MatchDetailScreen(matchId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _playersNavigatorKey,
            routes: [
              GoRoute(
                path: '/players',
                builder: (context, state) => const PlayerSearchScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return PlayerProfileScreen(playerId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
