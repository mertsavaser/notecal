# Firebase Storage Rules for Profile Photo Upload

## Upload Path

Profile photos are uploaded to:
```
users/{uid}/profile/profile_{timestamp}.webp
```

Example: `users/abc123/profile/profile_1704067200000.webp`

## Storage Rules Configuration

### A) DIAGNOSIS Rules (Temporary - 2 minutes only)

⚠️ **WARNING: Do NOT keep this in production. Restore rules after test.**

Use this only for diagnosing upload issues:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if true;
    }
  }
}
```

**Steps:**
1. Copy the rules above to Firebase Console → Storage → Rules
2. Publish
3. Test upload once
4. **IMMEDIATELY restore production rules** (see below)

---

### B) PRODUCTION Rules (Recommended)

Use this for production. Matches our actual upload path:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile photos: users/{userId}/profile/{allFiles=**}
    match /users/{userId}/profile/{allFiles=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

**Explanation:**
- `{allFiles=**}` matches any files under `/users/{userId}/profile/` including:
  - `profile_1234567890.webp`
  - `profile_9876543210.webp`
  - Any future nested structure
- `read`: Any authenticated user can read (for displaying avatars)
- `write`: Only the owner (matching `userId`) can upload/delete their photos

---

## Quick Checklist

1. **For diagnosis (temporary):**
   - [ ] Set diagnosis rules (allow all)
   - [ ] Test upload once
   - [ ] Check diagnostic logs in console
   - [ ] **Restore production rules immediately**

2. **For production:**
   - [ ] Use production rules (user-specific write)
   - [ ] Verify path matches: `users/{uid}/profile/*.webp`
   - [ ] Test authenticated upload
   - [ ] Test that other users cannot write to your path

---

## Path Verification

The app uploads to paths like:
- ✅ `users/abc123/profile/profile_1704067200000.webp` (correct)
- ❌ `users/abc123/profile.webp` (old format, not used)
- ❌ `users/abc123/profile/profile/profile_123.webp` (incorrect nesting)

Ensure your Storage Rules match the `users/{userId}/profile/{allFiles=**}` pattern.
