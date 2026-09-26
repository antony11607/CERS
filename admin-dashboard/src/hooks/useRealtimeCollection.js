import { useEffect, useState } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '../firebase/config';

export function useRealtimeCollection(path) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!path) {
      setData([]);
      setLoading(false);
      return undefined;
    }

    const collectionRef = collection(db, path);
    const unsubscribe = onSnapshot(
      collectionRef,
      (snapshot) => {
        const items = snapshot.docs.map((docSnapshot) => ({
          id: docSnapshot.id,
          ...docSnapshot.data(),
        }));

        console.log(`[Firestore] ${path} snapshot updated (${items.length} records)`);
        setData(items);
        setLoading(false);
        setError(null);
      },
      (snapshotError) => {
        console.error(`[Firestore] ${path} read error:`, snapshotError);
        setError(snapshotError.message || 'Failed to load data');
        setLoading(false);
      },
    );

    return () => unsubscribe();
  }, [path]);

  return { data, loading, error };
}
