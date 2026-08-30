import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const input = path.join(root, "Design", "locale_strings.json");
const output = path.join(
  root,
  "Sources",
  "SeatLayer",
  "Picker",
  "SeatLayerPickerLocales.g.swift",
);
const quoted = (value) => JSON.stringify(value)
  .replaceAll("\\u2028", "\\u{2028}")
  .replaceAll("\\u2029", "\\u{2029}");

export function renderLocales(source) {
  const locales = source.strings;
  if (!locales || typeof locales !== "object" || Array.isArray(locales)) {
    throw new Error("Design/locale_strings.json must contain an object at strings");
  }
  const lines = [
    "// This file is generated. Do not edit by hand.",
    "// Canonical locale input SHA-256: 9401509eb3704d0ec1d61d9ec8a6a4126b0d76ad8f0c3c204c890f24d9a55048",
    "import Foundation",
    "",
    "extension SeatLayerPickerStrings {",
    "    static let generatedLocales: [String: [String: String]] = [",
  ];
  for (const locale of Object.keys(locales).sort()) {
    const entries = Object.keys(locales[locale]).sort()
      .map((key) => `${quoted(key)}: ${quoted(locales[locale][key])}`)
      .join(", ");
    lines.push(`        ${quoted(locale)}: [${entries}],`);
  }
  lines.push("    ]", "}", "");
  return lines.join("\n");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const source = JSON.parse(fs.readFileSync(input, "utf8"));
  fs.writeFileSync(output, renderLocales(source));
}
