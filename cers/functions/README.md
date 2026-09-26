# CERS Backend API

Firebase Cloud Functions backend for the CERS (Community Emergency Response System) application.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env and add your OpenRouteService API key
   ```

3. Set Firebase Functions configuration:
   ```bash
   firebase functions:config:set ors.api_key="YOUR_API_KEY"
   ```

4. Run locally with emulators:
   ```bash
   npm run serve
   ```

5. Deploy to production:
   ```bash
   npm run deploy
   ```

## API Endpoints

### Maps API

#### Get Route
```
GET /api/maps/route?startLat={lat}&startLng={lng}&endLat={lat}&endLng={lng}
```

#### Get Distance and ETA
```
GET /api/maps/distance?startLat={lat}&startLng={lng}&endLat={lat}&endLng={lng}
```

#### Reverse Geocode
```
GET /api/maps/geocode?lat={lat}&lng={lng}
```

### Health Check
```
GET /api/health/check
```

## Project Structure

```
functions/
├── lib/
│   ├── index.js              # Main Express app
│   ├── controllers/          # Request handlers
│   │   └── mapController.js
│   └── routes/               # API routes
│       ├── mapRoutes.js
│       └── healthRoutes.js
├── .env.example              # Environment variables template
├── package.json
└── README.md
```

## Technologies

- Firebase Cloud Functions
- Express.js
- OpenRouteService API
- Node.js 18