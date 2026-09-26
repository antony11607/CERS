const jwt = require('jsonwebtoken');
require('dotenv').config();

/**
 * Middleware to verify Firebase ID token
 * Expects Authorization header: "Bearer <firebase-id-token>"
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'No token provided. Please authenticate.',
      });
    }

    const token = authHeader.split('Bearer ')[1];
    
    // Verify the Firebase ID token
    const decodedToken = await req.app.get('firebaseAdmin').auth().verifyIdToken(token);
    
    // Attach user info to request
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      emailVerified: decodedToken.email_verified,
    };

    console.log(`[Auth] User authenticated: ${req.user.uid} (${req.user.email})`);
    next();
  } catch (error) {
    console.error('[Auth] Authentication failed:', error.message);
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token. Please authenticate again.',
    });
  }
};

/**
 * Optional authentication - doesn't fail if no token provided
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      req.user = null;
      return next();
    }

    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await req.app.get('firebaseAdmin').auth().verifyIdToken(token);
    
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      emailVerified: decodedToken.email_verified,
    };

    console.log(`[Auth] Optional auth - User: ${req.user.uid}`);
    next();
  } catch (error) {
    // Silently fail for optional auth
    req.user = null;
    next();
  }
};

module.exports = { authenticate, optionalAuth };