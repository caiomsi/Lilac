// Encrypts src/app.html into index.html (lock screen + AES-GCM ciphertext).
// Two logins: LILAC_PASSWORD is hers, LILAC_PASSWORD_2 is his. The page is encrypted
// once with her key; his password unlocks a wrapped copy of that key.
// Usage: LILAC_PASSWORD=xxxxxx LILAC_PASSWORD_2=yyyyyy node tools/encrypt.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { webcrypto as crypto } from "node:crypto";

const root = new URL("..", import.meta.url);
const password = process.env.LILAC_PASSWORD, password2 = process.env.LILAC_PASSWORD_2;
if (!password || !password2) {
  console.error("Set both passwords first, e.g. LILAC_PASSWORD=xxxxxx LILAC_PASSWORD_2=yyyyyy node tools/encrypt.mjs");
  process.exit(1);
}
if (password === password2) { console.error("The two passwords must differ."); process.exit(1); }

const ITER = 600000;
const salt = Buffer.from(readFileSync(new URL("tools/salt.txt", root), "utf8").trim(), "base64");
const iv = crypto.getRandomValues(new Uint8Array(12));
const app = readFileSync(new URL("src/app.html", root));

async function derive(pw) {
  const base = await crypto.subtle.importKey("raw", new TextEncoder().encode(pw), "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey({ name: "PBKDF2", salt, iterations: ITER, hash: "SHA-256" }, base, { name: "AES-GCM", length: 256 }, true, ["encrypt"]);
}
const key = await derive(password);
const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, app);
const iv2 = crypto.getRandomValues(new Uint8Array(12));
const wrapped = await crypto.subtle.encrypt({ name: "AES-GCM", iv: iv2 }, await derive(password2), await crypto.subtle.exportKey("raw", key));

const payload = JSON.stringify({
  salt: salt.toString("base64"),
  iv: Buffer.from(iv).toString("base64"),
  iter: ITER,
  ct: Buffer.from(ct).toString("base64"),
  alt: { iv: Buffer.from(iv2).toString("base64"), ct: Buffer.from(wrapped).toString("base64") }
});
const lock = readFileSync(new URL("tools/lock.html", root), "utf8");
writeFileSync(new URL("index.html", root), lock.replace("__PAYLOAD__", () => payload));
console.log(`index.html written (${(payload.length / 1024).toFixed(1)} KB encrypted)`);
