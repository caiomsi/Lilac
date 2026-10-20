# Lilac (Caio's private page for Gabi)

- **Not a normal static site.** The source `src/app.html` is gitignored and must never be committed. Only the encrypted `index.html` ships.
- Rebuild after every edit: `LILAC_PASSWORD=<pw> node tools/encrypt.mjs` (Caio knows the password; don't write it into any tracked file).
- Keep `tools/salt.txt` stable. Changing it logs out every "remembered" device.
- SEO is deliberately off: `noindex` and `robots.txt Disallow`. The repo name and `<title>` stay neutral. Gabi's name only appears inside the encrypted page.
- **Step sync:** Supabase project `tempo` (yjvkfzbjiivsktyfronh), table `public.lilac_steps` (row id `gabi`).
  - RLS is on and there are no table grants.
  - Access goes only through the RPCs `lilac_get(secret)` and `lilac_step(secret, delta, note)`. `delta` must be 10 or -5. The total is clamped at ≥ 0, and history keeps the latest 200 entries.
  - The sync secret is embedded in `src/app.html`. Its sha256 hash is stored in the row.
- Edit points at the top of the app script: `SONGS` (Spotify links), `MILESTONES` (notes), `GOOD_LINES` / `OOPS_LINES`.
