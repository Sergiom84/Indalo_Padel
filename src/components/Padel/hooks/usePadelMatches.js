import { useState, useCallback } from 'react';
import apiClient from '../../../lib/apiClient';

export function usePadelMatches() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const getMatches = useCallback(async (filters = {}) => {
    setLoading(true);
    setError(null);
    try {
      const query = new URLSearchParams(filters).toString();
      return await apiClient.get(`/padel/matches?${query}`);
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const getMatch = useCallback(async (matchId) => {
    setLoading(true);
    try {
      return await apiClient.get(`/padel/matches/${matchId}`);
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const createMatch = useCallback(async (matchData) => {
    setLoading(true);
    try {
      return await apiClient.post('/padel/matches', matchData);
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const joinMatch = useCallback(async (matchId, team) => {
    setLoading(true);
    try {
      return await apiClient.post(`/padel/matches/${matchId}/join`, { team });
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const leaveMatch = useCallback(async (matchId) => {
    setLoading(true);
    try {
      return await apiClient.post(`/padel/matches/${matchId}/leave`);
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  const updateMatchStatus = useCallback(async (matchId, status) => {
    setLoading(true);
    try {
      return await apiClient.put(`/padel/matches/${matchId}/status`, { status });
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setLoading(false);
    }
  }, []);

  return { loading, error, getMatches, getMatch, createMatch, joinMatch, leaveMatch, updateMatchStatus };
}
