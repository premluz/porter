// Usage: node validate-messages.mjs <file.json>
// The file holds an array of bridge envelopes captured from a real implementation. Each envelope
// must satisfy envelope.schema.json and its payload must satisfy the schema for its type.
import { loadValidators, readJson } from "./validators.mjs";

const PAYLOAD_DEFS = {
  hello: "hello",
  "hello.ack": "helloAck",
  "inventory.snapshot": "inventorySnapshot",
  "destination.upsert": "destinationUpsert",
  "destination.remove": "destinationRemove",
  heartbeat: "empty",
  "snapshot.request": "empty",
  "activate.request": "activateRequest",
  error: "error",
};
const ACTIVATE_RESULT = "activate.result";
const BRIDGE_PAYLOAD_ID = "https://contracts.porter.invalid/v1/bridge-payload.schema.json";

const file = process.argv[2];
if (file === undefined) throw new Error("usage: validate-messages.mjs <file.json>");
const envelopes = readJson(file);
if (!Array.isArray(envelopes) || envelopes.length === 0) throw new Error(`${file} holds no envelopes`);

const { ajv, validators } = loadValidators();
const envelopeValidator = validators.get("envelope");
const problems = [];
envelopes.forEach((envelope, index) => {
  if (!envelopeValidator(envelope)) {
    problems.push(`#${index} envelope: ${JSON.stringify(envelopeValidator.errors)}`);
    return;
  }
  const payloadValidator = envelope.type === ACTIVATE_RESULT
    ? validators.get("activation-result")
    : ajv.getSchema(`${BRIDGE_PAYLOAD_ID}#/$defs/${PAYLOAD_DEFS[envelope.type]}`);
  if (!payloadValidator) {
    problems.push(`#${index} no payload schema for type ${envelope.type}`);
  } else if (!payloadValidator(envelope.payload)) {
    problems.push(`#${index} ${envelope.type} payload: ${JSON.stringify(payloadValidator.errors)}`);
  }
});
if (problems.length > 0) {
  console.error(problems.join("\n"));
  process.exit(1);
}
console.log(`${envelopes.length} envelope(s) satisfy the contract`);
