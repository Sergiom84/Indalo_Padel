import { useState, useCallback } from 'react';
import apiClient from '../../../lib/apiClient';

export function usePadelBooking() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const getAvailability = useCallback(async (venueId, date) => {
    setLoading(true);
    setError(null);
    try {
      const data = await apiClient.get(`/padel/venues/${venueId}/availability?date=${date}`);
      return data;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const createBooking = useCallback(async (bookingData) => {
    setLoading(true);
    setError(null);
    try {
      const data = await apiClient.post('/padel/bookings', bookingData);
      return data;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const getMyBookings = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await apiClient.get('/padel/bookings/my');
      return data;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const confirmBooking = useCallback(async (bookingId) => {
    setLoading(true);
    try {
      const data = await apiClient.put(`/padel/bookings/${bookingId}/confirm`);
      return data;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const cancelBooking = useCallback(async (bookingId) => {
    setLoading(true);
    try {
      const data = await apiClient.put(`/padel/bookings/${bookingId}/cancel`);
      return data;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  return { loading, error, getAvailability, createBooking, getMyBookings, confirmBooking, cancelBooking };
}
