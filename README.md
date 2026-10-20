# Lilac

A small private page: a countdown and a lily-field walk. The page is password-protected.
`index.html` contains only a lock screen plus AES-GCM ciphertext, so nothing readable is in this repo.

## How it works
- `src/app.html` is the real page. It is **gitignored** and lives only on Caio's Mac, so back it up.
- `tools/encrypt.mjs` encrypts it into `index.html`. The key comes from PBKDF2-SHA256 with 600k iterations over the password, using the public salt in `tools/salt.txt`.
- `tools/lock.html` is the lock-screen template.

## Edit and publish
1. Edit `src/app.html`. Songs (`SONGS`) and the milestone notes (`MILESTONES`) are at the top of its script.
2. Run `LILAC_PASSWORD=… node tools/encrypt.mjs`
3. `git add -A && git commit -m "…" && git push`
