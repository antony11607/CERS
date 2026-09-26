# Report Incident Refactoring Summary

## Changes Made

### 1. `cers/lib/emergency_service.dart`
- Added `createReportIncident()` method that creates a document in the existing `emergencies` collection
- Reuses existing fields: `victimId`, `victimLatitude`, `victimLongitude`, timestamps, volunteer fields
- Sets `status: "reported"` (new status for report incidents)
- Adds new fields: `source: "report"`, `incidentType`, `description`, `reporterId`, `reporterName`, `address`
- Updated `acceptEmergencyDirectly()` to accept both "waiting" and "reported" statuses
- Updated `getNearbyEmergenciesStream()` to query both "waiting" and "reported" statuses
- Updated `cancelEmergency()` to allow cancellation from "reported" status
- Updated `hasActiveEmergency()` to check for "reported" status
- Comprehensive debug logs throughout

### 2. `cers/lib/screens/volunteer/volunteer_service.dart`
- Updated `getNearbyEmergencies()` to query both "waiting" and "reported" statuses
- Updated `getEmergenciesStream()` to query both "waiting" and "reported" statuses
- Added `source`, `incidentType`, `address` fields to returned emergency data

### 3. `cers/lib/screens/volunteer/volunteer_dashboard_screen.dart`
- Shows "Reported Incident" or specific incident type title for report source emergencies
- Shows address text for reported incidents
- Uses appropriate icon (flag) for reported incidents vs SOS

### 4. `cers/lib/screens/user/report_incident_screen.dart`
- **No UI changes** - UI preserved exactly as before
- Added live location fetching via `LocationService`
- Added address resolution via `BackendApiService.reverseGeocode()`
- Added user name fetching from Firestore `user` collection
- Submit button calls `EmergencyService.createReportIncident()` to create document in emergencies collection
- On success, navigates to `FindingHelpScreen` with the emergency ID
- Shows loading indicator during submission
- Validates location and authentication before submission
- Checks for active emergencies before creating a new one

### 5. `cers/lib/screens/user/finding_help_screen.dart`
- Updated checklist status checks to handle both "waiting" and "reported" statuses

### 6. `cers/firestore.rules`
- Added create rule for report incidents (status == "reported" && source == "report")
- Added cancel rule for reported status
- Updated volunteer accept rule to allow both "waiting" and "reported" statuses

## What Was NOT Changed
- No new Firestore collections were created
- No SOS logic was duplicated
- Existing services (`EmergencyService`, `VolunteerService`) were extended, not duplicated
- Existing screens (`FindingHelpScreen`, `VolunteerAcceptedScreen`, `VolunteerArrivedScreen`, `EmergencyCompletedScreen`, `EmergencyResponseScreen`) are reused as-is
- The volunteer workflow (`reported → accepted → arrived → resolved`) uses the exact same lifecycle
- UI of `report_incident_screen.dart` is preserved

## Flow
1. User fills out Report Incident form
2. User taps "Send Alert"
3. App gets live location + address + user name
4. Creates document in `emergencies` collection with `status: "reported"`, `source: "report"`, + new fields
5. User is navigated to `FindingHelpScreen` which listens for status changes
6. Volunteers see the incident on their dashboard (mixed with SOS emergencies)
7. Volunteer accepts → status changes to "accepted" (same transaction logic)
8. User navigates through the same lifecycle screens as SOS