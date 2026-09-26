# Report Incident Refactoring Plan

## Understanding
- The app uses a single `emergencies` Firestore collection for SOS emergencies
- SOS emergencies use fields: `victimId`, `victimLatitude`, `victimLongitude`, `status: "waiting"`, timestamps, volunteer fields
- Volunteer Dashboard queries for `status == "waiting"` emergencies
- `EmergencyService` handles create, accept, update, cancel operations
- `VolunteerService` streams nearby emergencies and accepts them
- Flow: SOS → `waiting` → `accepted` → `arrived` → `resolved`

## Changes Required

### 1. `EmergencyService` - Add `createReportIncident()` method
- Creates document in `emergencies` collection
- Uses existing `victimId`, `victimLatitude`, `victimLongitude` for compatibility
- Sets `status: "reported"` (new status for reports)
- Adds new fields: `source: "report"`, `incidentType`, `description`, `reporterId`, `reporterName`, `address`

### 2. `EmergencyService` - Update `acceptEmergencyDirectly()`
- Allow accepting when status is "reported" (in addition to "waiting")

### 3. `VolunteerService` - Update streams/queries
- Include `status == "reported"` alongside `status == "waiting"` in streams
- Show incident type info for reported emergencies

### 4. `report_incident_screen.dart` - Replace dummy data
- Import services and get live location
- Get address via LocationService + reverse geocode
- Get user name from Firestore
- On submit: call EmergencyService.createReportIncident()
- Navigate to FindingHelpScreen with the emergency ID

### 5. Firestore rules - Allow reported incidents
- Allow create with `source == "report"`
- Allow volunteer accept from "reported" status

### 6. Debug logs for all operations