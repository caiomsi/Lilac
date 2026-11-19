# Lilac

A small private page for two: a counter, a lily-field walk, and a shared album. The page is password-protected.
`index.html` contains only a lock screen plus AES-GCM ciphertext, so nothing readable is in this repo.

## How it works
- `src/app.html` is the real page. It is **gitignored**. If your copy is missing or stale, `LILAC_PASSWORD=… node tools/decrypt.mjs` rebuilds it from `index.html`.
- `tools/encrypt.mjs` encrypts it into `index.html`. The key comes from PBKDF2-SHA256 with 600k iterations over the password, using the public salt in `tools/salt.txt`.
- `tools/lock.html` is the lock-screen template.

## Edit and publish
1. Edit `src/app.html`.
2. Run `LILAC_PASSWORD=… node tools/encrypt.mjs` (her password; add `LILAC_PASSWORD_2=…` only to change his)
3. `git add -A && git commit -m "…" && git push`
