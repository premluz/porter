// Compiles every schema in ../schemas. Shared by the fixture run and the message validator so both
// enforce exactly the same contract.
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

export const SCHEMA_SUFFIX = ".schema.json";
const schemaDir = join(dirname(fileURLToPath(import.meta.url)), "..", "schemas");

export function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(`Cannot read JSON at ${path}: ${error.message}`);
  }
}

export function loadValidators() {
  // strictRequired rejects conditional if/then "required" lists, which the
  // account-scope and destination contracts rely on; every other strict check stays on.
  const ajv = new Ajv2020({ strict: true, strictRequired: false, allErrors: true });
  addFormats(ajv);
  const files = readdirSync(schemaDir).filter((f) => f.endsWith(SCHEMA_SUFFIX));
  for (const file of files) ajv.addSchema(readJson(join(schemaDir, file)));
  const validators = new Map();
  for (const file of files) {
    const id = readJson(join(schemaDir, file)).$id;
    validators.set(basename(file, SCHEMA_SUFFIX), ajv.getSchema(id));
  }
  return { ajv, validators };
}
