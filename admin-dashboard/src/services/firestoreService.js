import { doc, setDoc, updateDoc } from 'firebase/firestore';
import { db } from '../firebase/config';

export async function updateApprovalStatus(applicationId, status, reviewer = 'admin') {
  const applicationRef = doc(db, 'volunteer_approval', applicationId);
  const payload = {
    status,
    reviewedBy: reviewer,
    reviewedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  console.log('[Firestore] Updating volunteer application status', { applicationId, status, reviewer });
  await updateDoc(applicationRef, payload);
  return payload;
}

export async function createOrUpdateVolunteerRecord(applicant, status = 'approved') {
  const volunteerId = applicant?.volunteerId || applicant?.id || applicant?.uid || applicant?.email;
  if (!volunteerId) {
    throw new Error('Volunteer id is required to create or update the volunteer record');
  }

  const volunteerRef = doc(db, 'volunteers', volunteerId);
  const volunteerPayload = {
    id: volunteerId,
    uid: volunteerId,
    fullName: applicant?.fullName || applicant?.name || 'Volunteer',
    email: applicant?.email || '',
    phone: applicant?.phone || '',
    status,
    role: 'volunteer',
    createdAt: applicant?.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  console.log('[Firestore] Writing volunteer record', volunteerPayload);
  await setDoc(volunteerRef, volunteerPayload, { merge: true });
  return volunteerPayload;
}
