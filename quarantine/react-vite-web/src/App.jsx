import { lazy, Suspense } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './contexts/AuthContext';
import Navigation from './components/Navigation';

const PadelHome = lazy(() => import('./components/Padel/PadelHome'));
const PadelLogin = lazy(() => import('./components/Padel/PadelLogin'));
const PadelRegister = lazy(() => import('./components/Padel/PadelRegister'));
const VenueList = lazy(() => import('./components/Padel/venues/VenueList'));
const VenueDetail = lazy(() => import('./components/Padel/venues/VenueDetail'));
const BookingForm = lazy(() => import('./components/Padel/booking/BookingForm'));
const BookingConfirmation = lazy(() => import('./components/Padel/booking/BookingConfirmation'));
const MyBookings = lazy(() => import('./components/Padel/booking/MyBookings'));
const MatchList = lazy(() => import('./components/Padel/matches/MatchList'));
const MatchCreate = lazy(() => import('./components/Padel/matches/MatchCreate'));
const MatchDetail = lazy(() => import('./components/Padel/matches/MatchDetail'));
const PlayerProfile = lazy(() => import('./components/Padel/players/PlayerProfile'));
const PlayerSearch = lazy(() => import('./components/Padel/players/PlayerSearch'));
const FavoritesList = lazy(() => import('./components/Padel/players/FavoritesList'));

function LoadingSpinner() {
  return (
    <div className="flex items-center justify-center min-h-[60vh]">
      <div className="w-10 h-10 border-4 border-padel-primary border-t-transparent rounded-full animate-spin" />
    </div>
  );
}

function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();
  if (loading) return <LoadingSpinner />;
  if (!user) return <Navigate to="/login" replace />;
  return children;
}

export default function App() {
  return (
    <div className="min-h-screen bg-padel-dark">
      <Navigation />
      <main className="pb-20 md:pb-6">
        <Suspense fallback={<LoadingSpinner />}>
          <Routes>
            <Route path="/login" element={<PadelLogin />} />
            <Route path="/register" element={<PadelRegister />} />
            <Route path="/" element={<ProtectedRoute><PadelHome /></ProtectedRoute>} />
            <Route path="/venues" element={<ProtectedRoute><VenueList /></ProtectedRoute>} />
            <Route path="/venues/:id" element={<ProtectedRoute><VenueDetail /></ProtectedRoute>} />
            <Route path="/booking/:courtId" element={<ProtectedRoute><BookingForm /></ProtectedRoute>} />
            <Route path="/booking/:id/confirmation" element={<ProtectedRoute><BookingConfirmation /></ProtectedRoute>} />
            <Route path="/my-bookings" element={<ProtectedRoute><MyBookings /></ProtectedRoute>} />
            <Route path="/matches" element={<ProtectedRoute><MatchList /></ProtectedRoute>} />
            <Route path="/matches/create" element={<ProtectedRoute><MatchCreate /></ProtectedRoute>} />
            <Route path="/matches/:id" element={<ProtectedRoute><MatchDetail /></ProtectedRoute>} />
            <Route path="/players" element={<ProtectedRoute><PlayerSearch /></ProtectedRoute>} />
            <Route path="/players/favorites" element={<ProtectedRoute><FavoritesList /></ProtectedRoute>} />
            <Route path="/players/:id" element={<ProtectedRoute><PlayerProfile /></ProtectedRoute>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Suspense>
      </main>
    </div>
  );
}
