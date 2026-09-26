# CERS Admin Dashboard

A dedicated web dashboard for the CERS emergency response system. This project is intentionally separate from the existing Flutter app and Node.js backend.

## Features

- Admin-only authentication with Firebase
- Firestore-backed dashboard widgets and live updates
- Volunteer approval workflow with approve/reject actions
- Active emergency list with status filtering
- Live tracking map using React Leaflet + OpenStreetMap
- Recharts-based emergency and volunteer activity analytics
- Responsive CERS red-and-white admin UI matching the provided design reference

## Project structure

```text
admin-dashboard/
├── src/
│   ├── components/
│   ├── context/
│   ├── firebase/
│   ├── hooks/
│   ├── layouts/
│   ├── pages/
│   ├── routes/
│   ├── services/
│   ├── App.jsx
│   ├── index.css
│   └── main.jsx
├── public/
├── index.html
├── package.json
├── vite.config.js
└── README.md
```

## Firebase connection

This admin app connects to the existing Firebase project used by the CERS application:

- Project ID: `cers-5bf5d`
- Auth domain: `cers-5bf5d.firebaseapp.com`
- Firestore collections used:
  - `users`
  - `volunteers`
  - `volunteer_approval`
  - `emergencies`

The app initializes Firebase in `src/firebase/config.js` and uses `onSnapshot()` to subscribe to Firestore collections for real-time updates.

## Admin authentication

The admin login screen authenticates with Firebase Authentication and checks the matching `users/{uid}` Firestore document.

Only users whose profile has:

```js
role: 'admin'
```

are granted access to the dashboard. Unauthorized users are redirected back to the login screen.

## Backend map integration

The live tracking page fetches route geometry from the existing Node.js backend at:

```text
http://localhost:3000/api/maps/route
```

This backend is the same one already used by the CERS project and exposes route/distance/ETA endpoints via OpenRouteService.

## Run locally

From the project root:

```bash
cd admin-dashboard
npm install
npm run dev
```

Then open the local Vite app in your browser, usually at:

```text
http://localhost:5173
```

## Build for production

```bash
cd admin-dashboard
npm run build
```

## Important notes

- This dashboard is web-only and does not modify the Flutter app or Node.js backend.
- The dashboard uses the existing CERS Firebase project rather than creating a new one.
- Firestore read/write operations are intentionally targeted to the existing collections only.
- Debug logging is included for Firestore reads, writes, approvals, and route fetches.
