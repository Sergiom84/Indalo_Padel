import { useState, useCallback } from 'react';
import apiClient from '../../../lib/apiClient';

export function usePadelPlayers() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const getProfile = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      return await apiClient.get('/padel/players/profile');
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const updateProfile = useCallback(async (profileData) => {
    setLoading(true);
    try {
      return await apiClient.put('/padel/players/profile', profileData);
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const searchPlayers = useCallback(async (params = {}) => {
    setLoading(true);
    setError(null);
    try {
      const query = new URLSearchParams(params).toString();
      return await apiClient.get(`/padel/players/search?${query}`);
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const getPlayer = useCallback(async (playerId) => {
    setLoading(true);
    try {
      return await apiClient.get(`/padel/players/${playerId}`);
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const ratePlayer = useCallback(async (playerId, ratingData) => {
    setLoading(true);
    try {
      return await apiClient.post(`/padel/players/${playerId}/rate`, ratingData);
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const toggleFavorite = useCallback(async (playerId) => {
    try {
      return await apiClient.post(`/padel/players/${playerId}/favorite`);
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  const getFavorites = useCallback(async () => {
    setLoading(true);
    try {
      return await apiClient.get('/padel/players/favorites');
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  return { loading, error, getProfile, updateProfile, searchPlayers, getPlayer, ratePlayer, toggleFavorite, getFavorites };
}
