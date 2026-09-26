import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyBM-AOI1dJc0azlCiof6-0BjAGXzb0z8gk',
  authDomain: 'cers-5bf5d.firebaseapp.com',
  projectId: 'cers-5bf5d',
  storageBucket: 'cers-5bf5d.firebasestorage.app',
  messagingSenderId: '685189542501',
  appId: '1:685189542501:web:6a53b83ea2f67b30400c8c',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export default app;
export { firebaseConfig };
