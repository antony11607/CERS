# CERS Migration Guide: Firebase Functions to Node.js Backend

## Overview

This guide documents the migration from Firebase Cloud Functions to a separate Node.js/Express backend for the CERS (Community Emergency Response System) application.

## Architecture Changes

### Before (Firebase Cloud Functions)
- Backend logic deployed as Firebase Cloud Functions
- Direct Firebase Functions HTTPS endpoints
- Functions deployed alongside Firebase hosting

### After (Node.js Backend)
- Separate Node.js/Express backend in `backend/` folder
- REST API endpoints served independently
- Firebase Admin SDK for secure Firestore access
- Backend can be deployed to any Node.js hosting service

## Project Structure

```
cers/
├── backend/                          # NEW: Separate Node.js backend
│   ├── config/
│   │   └── firebase.js              # Firebase Admin SDK initialization
│   ├── controllers/
│   │   ├── emergencyController.js   # Emergency CRUD operations
│   │   ├── volunteerController.js   # Volunteer operations
│   │   └── mapController.js         # OpenRouteService integration
│   ├── routes/
│   │   ├── emergencyRoutes.js       # Emergency API routes
│   │   ├── volunteerRoutes.js       # Volunteer API routes
│   │   ├── mapRoutes.js             # Map API routes
│   │   └── healthRoutes.js          # Health check route
│   ├── middleware/
│   │   ├── auth.js                  # Firebase ID token verification
│   │   └── validation.js            # Request payload validation
│   ├── server.js                    # Express server entry point
│   ├── package.json
│   ├── .env.example
│   ├── .gitignore
│   └── README.md
│
├── cers/
│   ├── lib/
│   │   ├── services/
│   │   │   ├── backend_api_service.dart  # NEW: Backend API client
│   │   │   ├── api_service.dart          # DEPRECATED: Old Firebase Functions client
│   │   │   ├── emergency_service.dart    # MODIFIED: Uses backend API
│   │   │   └── map_service.dart          # MODIFIED: Uses backend API
│   │   └── screens/
│   │       └── volunteer/
│   │           └── volunteer_service.dart # MODIFIED: Uses backend API
│   └── functions/                          # DEPRECATED: Old Firebase Functions
│       ├── index.js
│       ├── package.json
│       └── controllers/
│           └── mapController.js
```

## Modified Files

### Flutter Files Modified
1. **cers/lib/services/backend_api_service.dart** - NEW
   - Complete backend API client implementation
   - All API methods with Firebase ID token authentication
   - Fallback mechanisms for reliability

2. **cers/lib/services/emergency_service.dart** - MODIFIED
   - `createEmergency()` - Now calls backend API
   - `updateEmergencyStatus()` - Now calls backend API
   - `cancelEmergency()` - Now calls backend API
   - Firestore streams remain unchanged

3. **cers/lib/services/map_service.dart** - MODIFIED
   - `getRoute()` - Now uses BackendApiService
   - `getDistanceAndDuration()` - Now uses BackendApiService
   - Helper methods now use BackendApiService

4. **cers/lib/screens/volunteer/volunteer_service.dart** - MODIFIED
   - `acceptEmergencyWithTransaction()` - Now calls backend API
   - Backend handles transaction logic

### Backend Files Created
1. **backend/package.json** - Dependencies and scripts
2. **backend/.env.example** - Environment configuration template
3. **backend/.gitignore** - Git ignore rules
4. **backend/README.md** - Backend documentation
5. **backend/config/firebase.js** - Firebase Admin SDK setup
6. **backend/middleware/auth.js** - Authentication middleware
7. **backend/middleware/validation.js** - Request validation
8. **backend/controllers/emergencyController.js** - Emergency operations
9. **backend/controllers/volunteerController.js** - Volunteer operations
10. **backend/controllers/mapController.js** - Map operations
11. **backend/routes/emergencyRoutes.js** - Emergency routes
12. **backend/routes/volunteerRoutes.js** - Volunteer routes
13. **backend/routes/mapRoutes.js** - Map routes
14. **backend/routes/healthRoutes.js** - Health check route
15. **backend/server.js** - Express server setup

## Required Packages

### Backend (npm)
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "firebase-admin": "^11.11.0",
    "axios": "^1.6.2",
    "joi": "^17.11.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.2",
    "eslint": "^8.54.0"
  }
}
```

### Flutter (pubspec.yaml)
No new packages required! Uses existing:
- `http` - Already in pubspec.yaml
- `flutter_map` - Already in pubspec.yaml
- `geolocator` - Already in pubspec.yaml
- `cloud_firestore` - Already in pubspec.yaml
- `firebase_auth` - Already in pubspec.yaml

## Setup Instructions

### 1. Backend Setup

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Create .env file from .env.example
cp .env.example .env

# Edit .env with your credentials
# - Firebase Admin SDK credentials
# - OpenRouteService API key
# - CORS origins

# Start development server
npm run dev

# Or start production server
npm start
```

### 2. Firebase Admin SDK Setup

1. Go to Firebase Console > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Download the JSON file
4. Copy values to `.env`:
   - `FIREBASE_PROJECT_ID` - project_id
   - `FIREBASE_CLIENT_EMAIL` - client_email
   - `FIREBASE_PRIVATE_KEY` - private_key (keep the \n characters)

### 3. OpenRouteService API Key

1. Sign up at https://openrouteservice.org/
2. Get your API key from dashboard
3. Add to `.env` as `ORS_API_KEY`

### 4. Flutter Configuration

Update the backend URL in `cers/lib/services/backend_api_service.dart`:

```dart
static const String _baseUrl = 'http://localhost:3000'; // Development
// OR
static const String _baseUrl = 'https://your-backend-domain.com'; // Production
```

## API Endpoints

### Health Check
- `GET /api/health/check` - Public endpoint

### Emergencies (Authenticated)
- `POST /api/emergencies` - Create emergency
- `POST /api/emergencies/accept` - Accept emergency
- `POST /api/emergencies/cancel` - Cancel emergency
- `POST /api/emergencies/status` - Update status
- `GET /api/emergencies/nearby` - Get nearby emergencies

### Volunteers (Authenticated)
- `POST /api/volunteers/location` - Update location
- `GET /api/volunteers/nearby` - Get nearby volunteers

### Maps (Public)
- `GET /api/maps/route` - Get route
- `GET /api/maps/distance` - Get distance/ETA
- `GET /api/maps/geocode` - Reverse geocode

## Authentication

All authenticated endpoints require Firebase ID token:
```
Authorization: Bearer <firebase-id-token>
```

The backend verifies tokens using Firebase Admin SDK.

## Firestore Collections (Unchanged)

The following Firestore collections remain unchanged:
- `emergencies` - Emergency documents
- `volunteers` - Volunteer profiles
- `volunteer_approval` - Volunteer applications
- `emergencyContacts` - User emergency contacts
- `users` - User profiles

## Data Flow

### Emergency Creation Flow
1. User taps SOS in Flutter app
2. Flutter gets Firebase ID token
3. Flutter calls `POST /api/emergencies` with token
4. Backend verifies token
5. Backend creates emergency in Firestore
6. Backend returns emergency ID
7. Flutter listens to Firestore for updates (real-time)

### Emergency Acceptance Flow
1. Volunteer sees emergency in dashboard
2. Volunteer taps "Accept Emergency"
3. Flutter gets Firebase ID token
4. Flutter calls `POST /api/emergencies/accept`
5. Backend verifies token and volunteer approval
6. Backend uses Firestore transaction to:
   - Update emergency status to "accepted"
   - Set volunteer as unavailable
7. Backend returns success
8. Both apps update via Firestore listeners

### Route Calculation Flow
1. Volunteer needs route to emergency
2. Flutter calls `GET /api/maps/route`
3. Backend calls OpenRouteService API
4. Backend returns route coordinates
5. Flutter displays route on map

## Commands

### Start Backend
```bash
# Development
cd backend
npm run dev

# Production
cd backend
npm start
```

### Run Flutter Apps
```bash
# From project root
flutter run
```

### Deploy Backend (Example: Railway)
```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Deploy
railway up
```

### Deploy Backend (Example: Heroku)
```bash
# Install Heroku CLI
# Login
heroku login

# Create app
heroku create cers-backend

# Set environment variables
heroku config:set FIREBASE_PROJECT_ID=your-project-id
heroku config:set FIREBASE_CLIENT_EMAIL=your-email
heroku config:set FIREBASE_PRIVATE_KEY="your-key"
heroku config:set ORS_API_KEY=your-key

# Deploy
git push heroku main
```

## Testing

### Test Backend Health
```bash
curl http://localhost:3000/api/health/check
```

### Test Emergency Creation
```bash
curl -X POST http://localhost:3000/api/emergencies \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN" \
  -d '{"latitude": 37.7749, "longitude": -122.4194}'
```

### Test Route Generation
```bash
curl "http://localhost:3000/api/maps/route?startLat=37.7749&startLng=-122.4194&endLat=37.7849&endLng=-122.4094"
```

## Troubleshooting

### Backend won't start
- Check Node.js version >= 18.0.0
- Verify `.env` file exists and has correct values
- Check Firebase credentials are valid

### Authentication fails
- Ensure Firebase ID token is valid
- Check token is passed in Authorization header
- Verify Firebase Admin SDK is initialized correctly

### Firestore permission denied
- Check Firestore security rules allow backend access
- Verify service account has proper permissions
- Ensure Firestore is enabled in Firebase project

### OpenRouteService errors
- Verify API key is correct
- Check API quota hasn't been exceeded
- Ensure coordinates are valid

## Benefits of This Architecture

1. **Separation of Concerns**: Backend independent of Firebase Functions
2. **Flexibility**: Deploy backend anywhere (AWS, Railway, Heroku, etc.)
3. **Scalability**: Backend can scale independently
4. **Maintainability**: Clean architecture with controllers, routes, middleware
5. **Security**: API keys stored securely in backend, not exposed to client
6. **Logging**: Comprehensive debug logs for troubleshooting
7. **Validation**: Request validation before processing
8. **Error Handling**: Proper HTTP status codes and error messages

## Rollback Plan

If issues arise, you can rollback to Firebase Functions:

1. Keep `cers/functions/` directory (don't delete)
2. Revert Flutter files to use `ApiService` instead of `BackendApiService`
3. Redeploy Firebase Functions: `firebase deploy --only functions`

## Next Steps

1. Set up backend hosting ( Railway, Heroku, AWS, etc.)
2. Update Flutter `_baseUrl` to production URL
3. Configure CORS for production domains
4. Set up monitoring and logging
5. Configure auto-scaling if needed
6. Set up CI/CD for backend deployment

## Support

For issues or questions:
- Check backend logs: `npm run dev` shows detailed logs
- Check Flutter debug console for API calls
- Review Firestore rules in `cers/firestore.rules`