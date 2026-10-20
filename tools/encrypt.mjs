// Encrypts src/app.html into index.html (lock screen + AES-GCM ciphertext).
// Usage: LILAC_PASSWORD=xxxxxx node tools/encrypt.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { webcrypto as crypto } from "node:crypto";

const root = new URL("..", import.meta.url);
const password = process.env.LILAC_PASSWORD;
if (!password) {
  console.error("Set LILAC_PASSWORD first, e.g. LILAC_PASSWORD=xxxxxx node tools/encrypt.mjs");
  process.exit(1);
}

const ITER = 600000;
const salt = Buffer.from(readFileSync(new URL("tools/salt.txt", root), "utf8").trim(), "base64");
const iv = crypto.getRandomValues(new Uint8Array(12));
const app = readFileSync(new URL("src/app.html", root));

const base = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveKey"]);
const key = await crypto.subtle.deriveKey(
  { name: "PBKDF2", salt, iterations: ITER, hash: "SHA-256" },
  base,
  { name: "AES-GCM", length: 256 },
  false,
  ["encrypt"]
);
const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, app);

const payload = JSON.stringify({
  salt: salt.toString("base64"),
  iv: Buffer.from(iv).toString("base64"),
  iter: ITER,
  ct: Buffer.from(ct).toString("base64")
});
const lock = readFileSync(new URL("tools/lock.html", root), "utf8");
writeFileSync(new URL("index.html", root), lock.replace("__PAYLOAD__", () => payload));
console.log(`index.html written (${(payload.length / 1024).toFixed(1)} KB encrypted)`);
