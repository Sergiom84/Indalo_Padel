import { createContext, useContext, useState, useEffect } from 'react';
import apiClient from '../lib/apiClient';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem('padel_user');
    return saved ? JSON.parse(saved) : null;
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('padel_token');
    if (token) {
      apiClient.get('/padel/auth/verify')
        .then(data => {
          setUser(data.user);
          localStorage.setItem('padel_user', JSON.stringify(data.user));
        })
        .catch(() => {
          localStorage.removeItem('padel_token');
          localStorage.removeItem('padel_user');
          setUser(null);
        })
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, []);

  const login = async (email, password) => {
    const data = await apiClient.post('/padel/auth/login', { email, password });
    localStorage.setItem('padel_token', data.token);
    localStorage.setItem('padel_user', JSON.stringify(data.user));
    setUser(data.user);
    return data;
  };

  const register = async (userData) => {
    const data = await apiClient.post('/padel/auth/register', userData);
    localStorage.setItem('padel_token', data.token);
    localStorage.setItem('padel_user', JSON.stringify(data.user));
    setUser(data.user);
    return data;
  };

  const logout = () => {
    localStorage.removeItem('padel_token');
    localStorage.removeItem('padel_user');
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

export default AuthContext;
