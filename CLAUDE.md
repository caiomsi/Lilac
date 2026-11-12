# Lilac (Caio's private page for Gabi)

- **Not a normal static site.** The source `src/app.html` is gitignored and must never be committed. Only the encrypted `index.html` ships.
- Rebuild after every edit: `LILAC_PASSWORD=<hers> LILAC_PASSWORD_2=<his> node tools/encrypt.mjs` (Caio knows both passwords; don't write them into any tracked file).
- **Two logins.** Her password decrypts the page directly; his unwraps a copy of the same key (`alt` in the payload). The lock screen stores which one was used in `lilac.who` (`g` or `c`), and the page reads it to know who is signed in.
- Keep `tools/salt.txt` stable. Changing it logs out every "remembered" device.
- SEO is deliberately off: `noindex` and `robots.txt Disallow`. The repo name and `<title>` stay neutral. Gabi's name only appears inside the encrypted page.
- **Step sync:** Supabase project `tempo` (yjvkfzbjiivsktyfronh), table `public.lilac_steps` (row id `gabi`).
  - RLS is on and there are no table grants.
  - Access goes only through the RPCs `lilac_get(secret)` and `lilac_step(secret, delta, note)`. `delta` must be 10 or -5. The total is clamped at ≥ 0, and history keeps the latest 200 entries.
  - The sync secret is embedded in `src/app.html`. Its sha256 hash is stored in the row.
- **Album sync** (everything except steps: flower diary, selfies, letters, date jar, daily question, places, songs, timeline, hearts): tables `public.lilac_items` and `public.lilac_blobs` (photos as base64), defined in `supabase/album.sql`.
  - Same model as steps: RLS on, no grants, access only through `lilac_list / lilac_put / lilac_del / lilac_thumbs / lilac_blob`, each checking the same secret.
  - The server hides the other person's daily answer until you've answered, and a date-locked letter's body until its date.
  - In the page, each section is a block in the script that uses the shared `A` helper (`A.items`, `A.put`, `A.pickPhoto`, ...).
- Third parties the page loads: Google Fonts, Spotify embeds (song of the week), Leaflet from cdnjs with OpenStreetMap tiles, and Nominatim to look up a place name when one is added.
- Edit points at the top of the app script: `SONGS` (Spotify links), `MILESTONES` (notes), `GOOD_LINES` / `OOPS_LINES`.
