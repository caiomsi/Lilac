// Recovers src/app.html from the shipped index.html (the reverse of encrypt.mjs).
// Use it when src/app.html is missing or older than what's deployed.
// Usage: LILAC_PASSWORD=xxxxxx node tools/decrypt.mjs   (her password)
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { webcrypto as crypto } from "node:crypto";

const root = new URL("..", import.meta.url);
const password = process.env.LILAC_PASSWORD;
if (!password) { console.error("Set LILAC_PASSWORD first."); process.exit(1); }
const html = readFileSync(new URL("index.html", root), "utf8");
const P = JSON.parse(html.match(/<script id="payload" type="application\/json">(.*?)<\/script>/s)[1]);
const b = s => Buffer.from(s, "base64");
const base = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveKey"]);
const key = await crypto.subtle.deriveKey({ name: "PBKDF2", salt: b(P.salt), iterations: P.iter, hash: "SHA-256" }, base, { name: "AES-GCM", length: 256 }, false, ["decrypt"]);
const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: b(P.iv) }, key, b(P.ct));
mkdirSync(new URL("src/", root), { recursive: true });
writeFileSync(new URL("src/app.html", root), Buffer.from(plain));
console.log(`src/app.html written (${(plain.byteLength / 1024).toFixed(1)} KB)`);
