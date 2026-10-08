// Validates every schema, then requires fixtures/valid/<schema>/*.json to pass
// and fixtures/invalid/<schema>/*.json to fail. An invalid fixture that passes
// means the contract is looser than documented, so it fails the run.
import { readdirSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";
import { loadValidators, readJson } from "./validators.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const fixtureDir = join(root, "fixtures");

function fixtureFiles(expectation, schemaName) {
  const dir = join(fixtureDir, expectation, schemaName);
  try {
    return readdirSync(dir).filter((f) => f.endsWith(".json")).map((f) => join(dir, f));
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

function checkFixtures(validators) {
  const failures = [];
  let checked = 0;
  for (const [name, validate] of validators) {
    for (const expectation of ["valid", "invalid"]) {
      for (const path of fixtureFiles(expectation, name)) {
        checked += 1;
        const passed = validate(readJson(path));
        if (passed !== (expectation === "valid")) {
          const detail = passed ? "unexpectedly passed" : JSON.stringify(validate.errors);
          failures.push(`${expectation}/${name}/${basename(path)}: ${detail}`);
        }
      }
    }
  }
  return { checked, failures };
}

const { validators } = loadValidators();
const { checked, failures } = checkFixtures(validators);
if (failures.length > 0) {
  console.error(failures.join("\n"));
  console.error(`contracts: ${failures.length} of ${checked} fixtures failed`);
  process.exit(1);
}
console.log(`contracts: ${validators.size} schemas compiled, ${checked} fixtures behaved as expected`);
