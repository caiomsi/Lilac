# Lilac (Caio's private page for Gabi)

- **Not a normal static site.** The source `src/app.html` is gitignored and must never be committed. Only the encrypted `index.html` ships.
- Rebuild after every edit: `LILAC_PASSWORD=<hers> node tools/encrypt.mjs` (Caio knows both passwords; don't write them into any tracked file). Leaving out `LILAC_PASSWORD_2` carries his existing login over from the current `index.html`; set it only to change his password.
- **Two logins.** Her password decrypts the page directly; his unwraps a copy of the same key (`alt` in the payload). The lock screen stores which one was used in `lilac.who` (`g` or `c`), and the page reads it to know who is signed in.
- Keep `tools/salt.txt` stable. Changing it logs out every "remembered" device.
- SEO is deliberately off: `noindex` and `robots.txt Disallow`. The repo name and `<title>` stay neutral. Gabi's name only appears inside the encrypted page.
- **Before us (the old lily field):** the walk game ended on Nov 1, 2026. The section is now a read-only keepsake built from `lilac_get`: stats, then every step and note grouped by day. There are no step buttons anymore.
- **Step data:** Supabase project `tempo` (yjvkfzbjiivsktyfronh), table `public.lilac_steps` (row id `gabi`).
  - RLS is on and there are no table grants.
  - Access goes only through the RPCs `lilac_get(secret)` and `lilac_step(secret, delta, note)`. `delta` must be 10 or -5. The total is clamped at ≥ 0, and history keeps the latest 200 entries.
  - The sync secret is embedded in `src/app.html`. Its sha256 hash is stored in the row.
- **Album sync** (everything except steps: flower diary, selfies, daily question, habits, timeline, hearts; the letters, date jar and places sections were removed on 2026-11-19, but their tables and RPCs were left in place): tables `public.lilac_items` and `public.lilac_blobs` (photos as base64), defined in `supabase/album.sql`.
  - Same model as steps: RLS on, no grants, access only through `lilac_list / lilac_put / lilac_del / lilac_thumbs / lilac_blob`, each checking the same secret.
  - The server hides the other person's daily answer until you've answered, and a date-locked letter's body until its date.
  - In the page, each section is a block in the script that uses the shared `A` helper (`A.items`, `A.put`, `A.pickPhoto`, ...).
- **Habits** (added 2026-11-23): kind `habit`, one item per person per day `{day, talk, read, workout}`. `lilac_put` reuses the existing row for the same who+day, so saves are idempotent. Workout is optional on weekends (doesn't break streaks). `START` in the habits part is the first day counted.
- Third parties the page loads: Google Fonts only.
- Edit point at the top of the app script: `TOGETHER` (the date the together-since counter starts from).
