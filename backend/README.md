# CERS Map Services Backend

Node.js/Express REST API backend for map-related functionality in the CERS (Community Emergency Response System) application.

## Overview

This backend is responsible **only** for map services using OpenRouteService. All Firestore operations (authentication, emergency management, volunteer management) are handled directly by the Flutter app using Firebase SDK.

## Architecture

```
┌─────────────────┐
│   Flutter App   │
│                 │
│  ┌───────────┐  │
│  │ Firebase  │  │
│  │ SDK       │  │
│  │ (Direct)  │  │
│  └───────────┘  │
│        │        │
│        ├────────┼─── Firestore Operations
│        │        │     - User login
│        │        │     - Emergency creation
│        │        │     - Emergency acceptance
│        │        │     - Emergency cancellation
│        │        │     - Volunteer location updates
│        │        │     - Real-time listeners
│        │        │
│        └────────┼─── Map API Calls
│                 │     - GET /api/maps/route
│                 │     - GET /api/maps/distance
│                 │     - GET /api/maps/eta
│                 │     - GET /api/maps/reverse-geocode
└─────────────────┘
          │
          │ HTTP Requests
          ▼
┌─────────────────┐
│  Node.js        │
│  Backend        │
│                 │
│  ┌───────────┐  │
│  │ OpenRoute │  │
│  │ Service   │  │
│  │ API       │  │
│  └───────────┘  │
└─────────────────┘
```

## Features

- **Route Calculation**: Get driving routes between two coordinates
- **Distance & ETA**: Calculate distance and estimated time of arrival
- **Reverse Geocoding**: Convert coordinates to human-readable addresses
- **Health Check**: Monitor backend status

## Prerequisites

- Node.js >= 18.0.0
- OpenRouteService API key ([Get one here](https://openrouteservice.org/))

## Installation

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create a `.env` file based on `.env.example`:
   ```bash
   cp .env.example .env
   ```

4. Add your OpenRouteService API key to `.env`:
   ```
   ORS_API_KEY=your_actual_api_key_here
   ```

## Running the Server

### Development Mode (with auto-reload)
```bash
npm run dev
```

### Production Mode
```bash
npm start
```

The server will start on `http://localhost:3000` (or the port specified in `.env`).

## API Endpoints

### Health Check
- **GET** `/api/health/check`
- Returns server health status

### Map Services

#### 1. Get Route
- **GET** `/api/maps/route`
- **Query Parameters**:
  - `startLat` (required): Starting latitude
  - `startLng` (required): Starting longitude
  - `endLat` (required): Ending latitude
  - `endLng` (required): Ending longitude
- **Response**:
  ```json
  {
    "success": true,
    "data": {
      "route": [[lat1, lng1], [lat2, lng2], ...],
      "distance": 1234.5,
      "duration": 456.7
    }
  }
  ```

#### 2. Get Distance & ETA
- **GET** `/api/maps/distance`
- **Query Parameters**:
  - `startLat` (required): Starting latitude
  - `startLng` (required): Starting longitude
  - `endLat` (required): Ending latitude
  - `endLng` (required): Ending longitude
- **Response**:
  ```json
  {
    "success": true,
    "data": {
      "distance": 1234.5,
      "duration": 456.7
    }
  }
  ```

#### 3. Get ETA
- **GET** `/api/maps/eta`
- **Query Parameters**:
  - `startLat` (required): Starting latitude
  - `startLng` (required): Starting longitude
  - `endLat` (required): Ending latitude
  - `endLng` (required): Ending longitude
- **Response**:
  ```json
  {
    "success": true,
    "data": {
      "etaSeconds": 456.7,
      "etaMinutes": 8
    }
  }
  ```

#### 4. Reverse Geocode
- **GET** `/api/maps/reverse-geocode`
- **Query Parameters**:
  - `lat` (required): Latitude
  - `lng` (required): Longitude
- **Response**:
  ```json
  {
    "success": true,
    "data": {
      "address": "123 Main St, City, Country"
    }
  }
  ```

## Project Structure

```
backend/
├── config/
│   └── database.js          # Database configuration (placeholder)
├── controllers/
│   └── mapController.js     # Map API endpoint handlers
├── routes/
│   ├── healthRoutes.js      # Health check routes
│   └── mapRoutes.js         # Map service routes
├── services/
│   └── orsService.js        # OpenRouteService API client
├── middleware/               # (empty - no auth needed for map services)
├── server.js                # Express app entry point
├── package.json             # Dependencies and scripts
├── .env.example             # Environment variables template
└── README.md                # This file
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `3000` |
| `NODE_ENV` | Environment (development/production) | `development` |
| `CORS_ORIGIN` | Allowed CORS origins (comma-separated) | `*` |
| `ORS_API_KEY` | OpenRouteService API key | (required) |

## Error Handling

All endpoints return consistent error responses:

```json
{
  "success": false,
  "message": "Error description",
  "error": "Detailed error message (development only)"
}
```

## Logging

The backend includes comprehensive logging:
- Request logging with timestamps
- OpenRouteService API call logging
- Error logging with stack traces

## Flutter Integration

The Flutter app connects to this backend via `BackendApiService`:

```dart
// Example: Get route
final route = await BackendApiService.getRoute(
  startLat: 40.7128,
  startLng: -74.0060,
  endLat: 34.0522,
  endLng: -118.2437,
);
```

## Security

- **No authentication required** for map endpoints (public data)
- API key is stored securely in `.env` (never committed to version control)
- CORS configured to restrict origins in production
- All API calls are proxied through backend (API key never exposed to client)

## Performance

- Request timeout: 15 seconds
- Response caching can be added at the Express level
- Fallback to straight-line route if API fails
- Haversine formula fallback for distance calculation

## Troubleshooting

### Server won't start
- Check if port 3000 is already in use
- Verify Node.js version >= 18.0.0
- Ensure `.env` file exists with `ORS_API_KEY`

### Map features not working
- Verify OpenRouteService API key is valid
- Check backend logs for API errors
- Ensure Flutter app's `_baseUrl` matches backend URL
- Check CORS configuration if running on different ports

### Routes not displaying
- Check browser/device console for errors
- Verify coordinates are valid (lat: -90 to 90, lng: -180 to 180)
- Backend returns fallback straight line if route generation fails

## License

Private - CERS Project