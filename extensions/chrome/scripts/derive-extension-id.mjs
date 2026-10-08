// Prints the extension ID Chrome derives from manifest.json's "key": the first 16 bytes of the
// SHA-256 of the DER public key, each nibble written as a letter a-p.
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ID_LENGTH_BYTES = 16;
const ALPHABET_OFFSET = "a".charCodeAt(0);

const manifestPath = join(dirname(fileURLToPath(import.meta.url)), "..", "manifest.json");
const { key } = JSON.parse(readFileSync(manifestPath, "utf8"));
if (typeof key !== "string" || key.length === 0) {
  throw new Error(`${manifestPath} has no "key"; the extension ID would differ per profile`);
}
const digest = createHash("sha256").update(Buffer.from(key, "base64")).digest();
const id = [...digest.subarray(0, ID_LENGTH_BYTES)]
  .flatMap((byte) => [byte >> 4, byte & 0x0f])
  .map((nibble) => String.fromCharCode(ALPHABET_OFFSET + nibble))
  .join("");
console.log(id);
