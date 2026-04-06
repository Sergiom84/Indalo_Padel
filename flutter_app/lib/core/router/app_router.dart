import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/venues/screens/venue_list_screen.dart';
import '../../features/venues/screens/venue_detail_screen.dart';
import '../../features/bookings/screens/booking_form_screen.dart';
import '../../features/bookings/screens/booking_confirmation_screen.dart';
import '../../features/bookings/screens/my_bookings_screen.dart';
import '../../features/matches/screens/match_list_screen.dart';
import '../../features/matches/screens/match_create_screen.dart';
import '../../features/matches/screens/match_detail_screen.dart';
import '../../features/players/screens/player_search_screen.dart';
import '../../features/players/screens/player_profile_screen.dart';
import '../../features/players/screens/favorites_list_screen.dart';
import '../../shared/widgets/app_bottom_nav.dart';

// Shell route key
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoading = authState.loading;
      if (isLoading) return null;

      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/';
      return null;
    },
    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Booking confirmation (full screen, no bottom nav)
      GoRoute(
        path: '/booking/:id/confirmation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return BookingConfirmationScreen(bookingData: extra);
        },
      ),
      // Shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(child: child, location: state.matchedLocation);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
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
              return BookingFormScreen(courtId: courtId, bookingState: extra);
            },
          ),
          GoRoute(
            path: '/my-bookings',
            builder: (context, state) => const MyBookingsScreen(),
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
          GoRoute(
            path: '/players',
            builder: (context, state) => const PlayerSearchScreen(),
            routes: [
              GoRoute(
                path: 'favorites',
                builder: (context, state) => const FavoritesListScreen(),
              ),
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
    ],
  );
});
