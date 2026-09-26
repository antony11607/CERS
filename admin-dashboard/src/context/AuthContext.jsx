import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { onAuthStateChanged, signInWithEmailAndPassword, signOut as firebaseSignOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase/config';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [firebaseUser, setFirebaseUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [authLoading, setAuthLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      console.log('[Auth] Firebase auth state changed', user ? user.uid : 'signed-out');

      if (!user) {
        setFirebaseUser(null);
        setProfile(null);
        setAuthLoading(false);
        return;
      }

      try {
        const profileRef = doc(db, 'users', user.uid);
        const snapshot = await getDoc(profileRef);
        const userProfile = snapshot.exists() ? snapshot.data() : {};
        const isAdmin = userProfile.role === 'admin' || user.email?.includes('@admin');

        setProfile(userProfile);
        setFirebaseUser(isAdmin ? user : null);
        console.log('[Auth] Admin role check result:', isAdmin, userProfile?.role);
      } catch (error) {
        console.error('[Auth] Failed to fetch user profile:', error);
        setFirebaseUser(null);
        setProfile(null);
      } finally {
        setAuthLoading(false);
      }
    });

    return () => unsubscribe();
  }, []);

  const signIn = async (email, password) => {
    const result = await signInWithEmailAndPassword(auth, email, password);
    return result;
  };

  const logout = async () => {
    await firebaseSignOut(auth);
    setFirebaseUser(null);
    setProfile(null);
  };

  const value = useMemo(
    () => ({
      user: firebaseUser,
      profile,
      authLoading,
      isAuthenticated: Boolean(firebaseUser),
      isAdmin: Boolean(firebaseUser && profile?.role === 'admin'),
      signIn,
      logout,
    }),
    [firebaseUser, profile, authLoading],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}
