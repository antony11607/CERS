# Firestore Composite Indexes Required

This document lists all composite indexes required for the CERS (Community Emergency Response System) application.

## How to Create Indexes

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Indexes** tab
4. Click **"Create Index"**
5. Add the fields as specified below
6. Click **"Create"** and wait for the index to build (usually 2-5 minutes)

---

## Required Indexes

### Index 1: Emergency Queries for User's Active Emergencies

**Collection:** `emergencies`

**Fields:**
- `victimId` - Ascending
- `status` - Ascending
- `createdAt` - Descending

**Used By:**
- `emergency_service.dart` - `hasActiveEmergency()` method (line 22-27)
- `sos_screens.dart` - `_listenToActiveEmergency()` method (line 38-44)
- `sos_screens.dart` - `_listenToEmergencyUpdates()` method (line 767-772)

**Query Example:**
```dart
FirebaseFirestore.instance
  .collection('emergencies')
  .where('victimId', isEqualTo: userId)
  .where('status', whereIn: ['waiting', 'accepted', 'en_route'])
  .orderBy('createdAt', descending: true)
  .limit(1)
  .get();
```

**Why Required:**
This query filters by `victimId` and `status` (with `whereIn`), then orders by `createdAt`. Firestore requires a composite index for queries that combine multiple `where` clauses with `orderBy`.

**Error Without Index:**
```
The query requires an index. You can create it here: <firebase-console-link>
```

---

### Index 2: Volunteer Approval Applications by Status

**Collection:** `volunteer_approval`

**Fields:**
- `status` - Ascending
- `submittedAt` - Descending

**Used By:**
- `admin_dashboard.dart` - `_getApplicationsStream()` method (line 172-176)

**Query Example:**
```dart
FirebaseFirestore.instance
  .collection('volunteer_approval')
  .where('status', isEqualTo: 'pending')
  .orderBy('submittedAt', descending: true)
  .snapshots();
```

**Why Required:**
This query filters by `status` and orders by `submittedAt`. When filtering on one field and ordering by another, Firestore requires a composite index.

**Error Without Index:**
```
The query requires an index. You can create it here: <firebase-console-link>
```

---

## Optional Indexes (For Future Optimization)

These indexes are not currently required but may improve performance as the application scales:

### Optional Index 1: All Emergencies Ordered by Date

**Collection:** `emergencies`

**Fields:**
- `status` - Ascending
- `createdAt` - Descending

**Use Case:** If you need to query all emergencies by status and sort by creation date.

---

## Index Creation via Firebase CLI

Alternatively, you can create indexes using the Firebase CLI by adding them to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "emergencies",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "victimId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "volunteer_approval",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "submittedAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

Then deploy with:
```bash
firebase deploy --only firestore:indexes
```

---

## Verification

After creating the indexes:

1. Wait for the index status to change from "Building" to "Enabled" (check Firebase Console)
2. Test the following workflows:
   - User creates an SOS emergency
   - Admin dashboard loads volunteer applications
   - Volunteer dashboard shows nearby emergencies
3. Monitor Firestore logs in Firebase Console for any remaining index errors

---

## Troubleshooting

If you still see "The query requires an index" errors:

1. **Check the error message** - Firebase provides a direct link to create the required index
2. **Verify index is enabled** - Indexes must be fully built before queries will work
3. **Clear app cache** - Sometimes the app caches the error
4. **Check field names** - Ensure field names in the code match the index exactly (case-sensitive)

---

## Current Status

- [x] Index 1: emergencies (victimId, status, createdAt) - **REQUIRED**
- [x] Index 2: volunteer_approval (status, submittedAt) - **REQUIRED**

**Action Required:** Create both indexes in Firebase Console before testing the application.