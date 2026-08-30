import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderLocales } from "./generate-picker-locales.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (...parts) => fs.readFileSync(path.join(root, ...parts));
const sha256 = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");
const lock = JSON.parse(read("Design", "source-lock.json"));
const tokenBytes = read("Design", "tokens.json");
const localeBytes = read("Design", "locale_strings.json");
const componentBytes = read("Design", "components.md");

const failures = [];
const check = (condition, message) => { if (!condition) failures.push(message); };
check(sha256(tokenBytes) === lock.tokensSha256, "Design/tokens.json does not match source-lock.json");
check(sha256(localeBytes) === lock.localeStringsSha256, "Design/locale_strings.json does not match source-lock.json");
check(sha256(componentBytes) === lock.componentsSha256, "Design/components.md does not match source-lock.json");

const swift = read("Sources", "SeatLayer", "Picker", "SeatLayerPickerDesign.swift").toString();
check(swift.includes(lock.tokensSha256), "Swift token source hash is stale");
check(swift.includes(lock.localeStringsSha256), "Swift locale source hash is stale");
check(swift.includes(lock.componentsSha256), "Swift component source hash is stale");

const localeSource = JSON.parse(localeBytes);
const generated = read("Sources", "SeatLayer", "Picker", "SeatLayerPickerLocales.g.swift").toString();
check(generated === renderLocales(localeSource), "SeatLayerPickerLocales.g.swift is stale; run the locale generator");
check(Object.keys(localeSource.strings ?? {}).length === 37, "The canonical locale source must contain exactly 37 locales");

if (failures.length) {
  for (const failure of failures) console.error(`picker design validation: ${failure}`);
  process.exit(1);
}
console.log(
  `picker design validation passed: tokens=${lock.tokensSha256} locales=${lock.localeStringsSha256} components=${lock.componentsSha256}`,
);
