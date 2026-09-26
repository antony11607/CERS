const admin = require('firebase-admin');
require('dotenv').config();

// Initialize Firebase Admin SDK
const initializeFirebase = () => {
  try {
    // Check if already initialized
    if (admin.apps.length > 0) {
      console.log('[Firebase] Already initialized');
      return admin.app();
    }

    // Initialize with service account credentials
    const serviceAccount = {
      type: 'service_account',
      project_id: process.env.FIREBASE_PROJECT_ID,
      client_email: process.env.FIREBASE_CLIENT_EMAIL,
      private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    };

    const app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    console.log('[Firebase] Admin SDK initialized successfully');
    console.log(`[Firebase] Project ID: ${process.env.FIREBASE_PROJECT_ID}`);
    
    return app;
  } catch (error) {
    console.error('[Firebase] Failed to initialize:', error.message);
    throw error;
  }
};

module.exports = { initializeFirebase };