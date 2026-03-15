/*
Migration script: migrate likes arrays to a likes subcollection and populate likeCount.

Usage:
1. Create a Firebase service account JSON and set the path in GOOGLE_APPLICATION_CREDENTIALS env var,
   or replace with the path below.
2. Install dependencies: npm install firebase-admin
3. Run: node scripts/migrate_likes.js

This script will:
- For each document in `posts` that has a `likes` array, create documents under `posts/{postId}/likes/{userId}`
  with { createdAt: admin.firestore.FieldValue.serverTimestamp() }.
- Set `likeCount` to the length of the likes array.
- Optionally remove the `likes` array (currently commented out).

Notes:
- This script uses batched writes (max 500 ops per batch).
- Test on a small dataset or staging project first.
*/

const admin = require('firebase-admin');
const fs = require('fs');

// If you prefer to load a specific service account key file, set the path here:
// const serviceAccount = require('../serviceAccountKey.json');
// admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

// Otherwise, use GOOGLE_APPLICATION_CREDENTIALS environment variable.
admin.initializeApp();

const db = admin.firestore();

async function migrate() {
  console.log('Starting migration: scanning posts collection...');
  const postsSnap = await db.collection('posts').get();
  console.log(`Found ${postsSnap.size} posts`);
  let processed = 0;

  for (const postDoc of postsSnap.docs) {
    const data = postDoc.data();
    const likesArray = Array.isArray(data.likes) ? data.likes : null;
    if (!likesArray || likesArray.length === 0) {
      // ensure likeCount exists
      if (!('likeCount' in data)) {
        await postDoc.ref.update({ likeCount: 0 });
        console.log(`Post ${postDoc.id}: set likeCount=0`);
      }
      processed++;
      continue;
    }

    console.log(`Migrating ${likesArray.length} likes for post ${postDoc.id}`);
    // process in batches of 400 to be safe
    const batchLimit = 400;
    let i = 0;
    while (i < likesArray.length) {
      const batch = db.batch();
      const chunk = likesArray.slice(i, i + batchLimit);
      for (const uid of chunk) {
        const likeRef = postDoc.ref.collection('likes').doc(uid);
        batch.set(likeRef, { createdAt: admin.firestore.FieldValue.serverTimestamp() });
      }
      // update likeCount as well
      batch.update(postDoc.ref, { likeCount: likesArray.length });
      // Optionally remove the likes array to save space:
      // batch.update(postDoc.ref, { likes: admin.firestore.FieldValue.delete() });
      await batch.commit();
      i += batchLimit;
    }

    console.log(`Post ${postDoc.id}: migrated ${likesArray.length} likes`);
    processed++;
  }

  console.log(`Migration complete. Processed ${processed} posts.`);
}

migrate().then(() => process.exit(0)).catch(err => { console.error(err); process.exit(1); });
