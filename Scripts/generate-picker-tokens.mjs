// Generates the Swift picker token constants from `Design/tokens.json`.
//
//   node Scripts/generate-picker-tokens.mjs          # write the files
//   node Scripts/generate-picker-tokens.mjs --check  # fail if any is stale
//
// `Design/tokens.json` is the single source for the picker's colours, sizes,
// radii, elevations, opacities, type scale, motion, haptics and default
// strings. Keeping the Swift defaults generated is what stops this package and
// the Flutter, Android and React Native ports from drifting apart: they all
// read one file.
//
// The reader is `Scripts/picker-design-core.mjs`, which is shared verbatim
// with the other SDKs. Only the emitters below are Swift-shaped.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  COUNT_SIZE_KEYS,
  loadDesign,
  pluralFamilies,
  section,
  stringTokens,
} from "./picker-design-core.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outputDirectory = path.join(root, "Sources", "SeatLayer", "Picker");

/// The Swift line cap this package holds every source file to. A generated
/// group that would cross it is a bug in the split, not an exception.
const LINE_CAP = 1_500;

const swiftString = (value) =>
  JSON.stringify(value)
    .replaceAll("\\u2028", "\\u{2028}")
    .replaceAll("\\u2029", "\\u{2029}");

const swiftDouble = (value) =>
  Number.isInteger(value) ? `${value}` : `${value}`;

/// A doc comment carrying the token's own value, so a reader of the Swift
/// never has to open the JSON to see what a name means.
const doc = (value) => `    /// \`${String(value).replaceAll("\n", " ")}\``;

function header(...notes) {
  return [
    "// GENERATED — do not edit.",
    "//",
    "// Source: Design/tokens.json",
    "// Regenerate: node Scripts/generate-picker-tokens.mjs",
    "//",
    ...notes.map((note) => `// ${note}`),
    "import Foundation",
    "",
  ];
}

function namespace(lines, name, docLines, body) {
  for (const line of docLines) lines.push(`/// ${line}`);
  lines.push(`public enum ${name} {`);
  lines.push(...body);
  lines.push("}", "");
}

function renderColor(tokens) {
  const lines = header(
    "Every colour is the canonical `#RRGGBB` or `#AARRGGBB` string, so the",
    "same literal reaches SwiftUI, UIKit and the map renderer unchanged.",
  );
  for (const [mode, name] of [
    ["light", "SeatLayerPickerLightColorTokens"],
    ["dark", "SeatLayerPickerDarkColorTokens"],
  ]) {
    const entries = section(tokens, "color", mode);
    const body = [];
    for (const [key, value] of entries) {
      body.push(doc(value), `    public static let ${key} = ${swiftString(value)}`);
    }
    body.push(
      "",
      "    /// Every role in this palette, keyed by its token name.",
      "    public static let all: [String: String] = [",
      ...entries.map(([key]) => `        ${swiftString(key)}: ${key},`),
      "    ]",
    );
    namespace(
      lines,
      name,
      [`The ${mode} palette.`],
      body,
    );
  }
  return lines.join("\n");
}

function renderSize(tokens) {
  const entries = section(tokens, "size");
  const body = [];
  for (const [key, value] of entries) {
    body.push(doc(value));
    body.push(
      COUNT_SIZE_KEYS.has(key)
        ? `    public static let ${key} = ${Math.trunc(value)}`
        : `    public static let ${key}: Double = ${swiftDouble(value)}`,
    );
  }
  body.push(
    "",
    "    /// Every size, keyed by its token name. Counts widen to `Double` so",
    "    /// one table can carry the whole group.",
    "    public static let all: [String: Double] = [",
    ...entries.map(
      ([key]) =>
        COUNT_SIZE_KEYS.has(key)
          ? `        ${swiftString(key)}: Double(${key}),`
          : `        ${swiftString(key)}: ${key},`,
    ),
    "    ]",
  );
  const lines = header("The measured sizes the native chrome is built from.");
  namespace(
    lines,
    "SeatLayerPickerSizeTokens",
    ["The measured sizes the native picker chrome is built from."],
    body,
  );
  return lines.join("\n");
}

function renderScalar(tokens, group, name, docLines, sourceNote) {
  const body = [];
  for (const [key, value] of section(tokens, group)) {
    body.push(doc(value), `    public static let ${key}: Double = ${swiftDouble(value)}`);
  }
  body.push(
    "",
    "    /// Every value in this group, keyed by its token name.",
    "    public static let all: [String: Double] = [",
    ...section(tokens, group).map(
      ([key]) => `        ${swiftString(key)}: ${key},`,
    ),
    "    ]",
  );
  const lines = header(sourceNote);
  namespace(lines, name, docLines, body);
  return lines.join("\n");
}

function renderType(tokens) {
  const lines = header("The type ramp and the per-surface Dynamic Type clamps.");
  lines.push(
    "/// One role in the picker's type ramp.",
    "public struct SeatLayerPickerTypeToken: Sendable, Equatable {",
    "    /// Point size before the platform's text-size setting is applied.",
    "    public let size: Double",
    "    /// Numeric weight, on the 100–950 scale the design sources use.",
    "    public let weight: Double",
    "",
    "    public init(size: Double, weight: Double) {",
    "        self.size = size",
    "        self.weight = weight",
    "    }",
    "}",
    "",
  );
  const roles = Object.entries(tokens.type).filter(
    ([key, value]) =>
      key !== "scaleClamp" &&
      value !== null &&
      typeof value === "object" &&
      "size" in value,
  );
  const body = [];
  for (const [key, value] of roles) {
    body.push(
      doc(`size ${value.size}, weight ${value.weight}`),
      `    public static let ${key} = SeatLayerPickerTypeToken(`,
      `        size: ${swiftDouble(value.size)},`,
      `        weight: ${swiftDouble(value.weight)}`,
      "    )",
    );
  }
  body.push(
    "",
    "    /// Every role, keyed by its token name.",
    "    public static let all: [String: SeatLayerPickerTypeToken] = [",
    ...roles.map(([key]) => `        ${swiftString(key)}: ${key},`),
    "    ]",
  );
  namespace(
    lines,
    "SeatLayerPickerTypeTokens",
    ["The picker's type ramp: one point size and weight per role."],
    body,
  );

  const clamps = section(tokens, "type", "scaleClamp");
  const clampBody = [];
  for (const [key, value] of clamps) {
    clampBody.push(doc(value), `    public static let ${key}: Double = ${swiftDouble(value)}`);
  }
  clampBody.push(
    "",
    "    /// Every clamp, keyed by its surface name.",
    "    public static let all: [String: Double] = [",
    ...clamps.map(([key]) => `        ${swiftString(key)}: ${key},`),
    "    ]",
  );
  namespace(
    lines,
    "SeatLayerPickerTypeScaleTokens",
    [
      "How far each surface lets the platform grow its type.",
      "",
      "A clamp is a promise about a layout, not a preference: past it the",
      "surface would clip or overflow rather than read larger. Surfaces that",
      "own the screen are absent on purpose.",
    ],
    clampBody,
  );
  return lines.join("\n");
}

function renderMotion(tokens) {
  const motion = tokens.motion;
  const durations = section(tokens, "motion", "duration");
  const outside = section(tokens, "motion", "durationOutsideBudget");
  const physics = section(tokens, "motion", "physics");
  const curves = Object.entries(motion.curve);

  const lines = header("Motion durations, curves and the touch simulation.");
  const durationBody = [
    "    /// Nothing in this namespace's in-budget durations may exceed this.",
    `    public static let budgetMs = ${Math.trunc(motion.budgetMs)}`,
  ];
  for (const [key, value] of durations) {
    durationBody.push(doc(`${value} ms`), `    public static let ${key} = ${Math.trunc(value)}`);
  }
  for (const [key, value] of outside) {
    durationBody.push(
      `    /// \`${value}\` ms — deliberately outside the budget.`,
      `    public static let ${key} = ${Math.trunc(value)}`,
    );
  }
  durationBody.push(
    "",
    "    /// The durations inside the budget, keyed by token name.",
    "    public static let inBudget: [String: Int] = [",
    ...durations.map(([key]) => `        ${swiftString(key)}: ${key},`),
    "    ]",
    "",
    "    /// The durations deliberately outside the budget, keyed by token name.",
    "    public static let outsideBudget: [String: Int] = [",
    ...outside.map(([key]) => `        ${swiftString(key)}: ${key},`),
    "    ]",
    "",
    "    /// What the picker does when the viewer asks for less movement.",
    `    public static let reducedMotionPolicy = ${swiftString(motion.reducedMotion)}`,
  );
  namespace(
    lines,
    "SeatLayerPickerMotionDurationTokens",
    ["Motion durations, in milliseconds."],
    durationBody,
  );

  const physicsBody = [];
  for (const [key, value] of physics) {
    physicsBody.push(doc(value), `    public static let ${key}: Double = ${swiftDouble(value)}`);
  }
  physicsBody.push(
    "",
    "    /// Every constant in the simulation, keyed by its token name.",
    "    public static let all: [String: Double] = [",
    ...physics.map(([key]) => `        ${swiftString(key)}: ${key},`),
    "    ]",
  );
  namespace(
    lines,
    "SeatLayerPickerPhysicsTokens",
    [
      "What a finger on glass is answered with.",
      "",
      "Native-only: the web picker has no simulation to feed.",
    ],
    physicsBody,
  );

  const curveBody = [];
  for (const [key, value] of curves) {
    const [x1, y1, x2, y2] = value.cubicBezier;
    curveBody.push(
      doc(`${value.name} ${value.cubicBezier.join(", ")}`),
      `    public static let ${key} = SeatLayerPickerCubicBezier(`,
      `        x1: ${swiftDouble(x1)}, y1: ${swiftDouble(y1)},`,
      `        x2: ${swiftDouble(x2)}, y2: ${swiftDouble(y2)}`,
      "    )",
    );
  }
  curveBody.push(
    "",
    "    /// Every curve, keyed by its token name.",
    "    public static let all: [String: SeatLayerPickerCubicBezier] = [",
    ...curves.map(([key]) => `        ${swiftString(key)}: ${key},`),
    "    ]",
  );
  namespace(
    lines,
    "SeatLayerPickerCurveTokens",
    ["The cubic-Bézier curves the picker animates along."],
    curveBody,
  );
  return lines.join("\n");
}

function renderHaptics(tokens) {
  const entries = section(tokens, "haptics");
  const body = [];
  for (const [key, value] of entries) {
    body.push(doc(value), `    public static let ${key} = ${swiftString(value)}`);
  }
  body.push(
    "",
    "    /// Every cue, keyed by its token name.",
    "    public static let all: [String: String] = [",
    ...entries.map(([key]) => `        ${swiftString(key)}: ${key},`),
    "    ]",
    "",
    "    /// The first snapshot of a session never fires a cue.",
    `    public static let firstSnapshotPolicy = ${swiftString(tokens.haptics.note)}`,
  );
  const lines = header("Which platform haptic each cue fires.");
  namespace(
    lines,
    "SeatLayerPickerHapticNameTokens",
    ["Which platform haptic each buyer-facing cue fires."],
    body,
  );
  return lines.join("\n");
}

function renderStrings(tokens) {
  const entries = stringTokens(tokens);
  const families = pluralFamilies(tokens);
  const lines = header(
    "The English default for every buyer-facing chrome string, and the",
    "typed key each one is addressed by.",
  );
  lines.push(
    "/// Every buyer-facing string the native picker chrome can render.",
    "///",
    "/// The raw value is the cross-platform token name. `localeKey` is the",
    "/// name the runtime's own translated dictionaries use, which differs for",
    "/// plural forms (`ticketCountOne` is `ticketCount.one` there).",
    "public enum SeatLayerPickerStringKey: String, CaseIterable, Sendable {",
  );
  for (const entry of entries) {
    lines.push(`    /// ${String(entry.value).replaceAll("\n", " ")}`);
    lines.push(`    case ${entry.key}`);
  }
  lines.push("");
  lines.push("    /// The key this string carries in the translated dictionaries.");
  lines.push("    public var localeKey: String {");
  lines.push("        switch self {");
  for (const entry of entries.filter((entry) => entry.plural)) {
    lines.push(`        case .${entry.key}: return ${swiftString(entry.localeKey)}`);
  }
  lines.push("        default: return rawValue");
  lines.push("        }");
  lines.push("    }");
  lines.push("");
  lines.push("    /// The English default.");
  lines.push("    public var englishDefault: String {");
  lines.push("        SeatLayerPickerStringTokens.english[self] ?? rawValue");
  lines.push("    }");
  lines.push("}", "");

  lines.push("/// A string that has one wording for a count of one and another");
  lines.push("/// for every other count.");
  lines.push("public struct SeatLayerPickerPluralKey: Sendable, Equatable {");
  lines.push("    public let one: SeatLayerPickerStringKey");
  lines.push("    public let other: SeatLayerPickerStringKey");
  lines.push("");
  lines.push("    /// The form that names `count`.");
  lines.push("    public func form(_ count: Int) -> SeatLayerPickerStringKey {");
  lines.push("        count == 1 ? one : other");
  lines.push("    }");
  lines.push("}", "");

  const familyBody = [];
  for (const family of families) {
    if (!family.forms.one || !family.forms.other) continue;
    familyBody.push(
      `    /// \`${family.base}\``,
      `    public static let ${family.base} = SeatLayerPickerPluralKey(`,
      `        one: .${family.forms.one},`,
      `        other: .${family.forms.other}`,
      "    )",
    );
  }
  namespace(
    lines,
    "SeatLayerPickerPluralKeys",
    ["Every string that has singular and plural wordings."],
    familyBody,
  );

  const body = [
    "    /// The English default for every key.",
    "    public static let english: [SeatLayerPickerStringKey: String] = [",
    ...entries.map(
      (entry) => `        .${entry.key}: ${swiftString(entry.value)},`,
    ),
    "    ]",
  ];
  namespace(
    lines,
    "SeatLayerPickerStringTokens",
    ["The English default for every buyer-facing chrome string."],
    body,
  );
  return lines.join("\n");
}

function renderIndex(tokens, files) {
  const lines = header(
    "The index of the generated token groups. Every number the native",
    "picker draws enters Swift through one of the files listed here.",
  );
  lines.push(
    "/// The design-token document version these files were generated from.",
    `public let seatLayerPickerTokensVersion = ${Math.trunc(tokens.version)}`,
    "",
    "/// The generated token files, in the order the generator writes them.",
    "public let seatLayerPickerGeneratedTokenFiles: [String] = [",
    ...files.map((name) => `    ${swiftString(name)},`),
    "]",
    "",
  );
  return lines.join("\n");
}

/// Every generated token file, as `{ name, source }`.
export function renderTokens(tokens) {
  const groups = [
    ["SeatLayerPickerTokensColor.g.swift", renderColor(tokens)],
    ["SeatLayerPickerTokensSize.g.swift", renderSize(tokens)],
    [
      "SeatLayerPickerTokensRadius.g.swift",
      renderScalar(
        tokens,
        "radius",
        "SeatLayerPickerRadiusTokens",
        ["Corner radii."],
        "Corner radii.",
      ),
    ],
    [
      "SeatLayerPickerTokensElevation.g.swift",
      renderScalar(
        tokens,
        "elevation",
        "SeatLayerPickerElevationTokens",
        ["Surface elevations."],
        "Surface elevations.",
      ),
    ],
    [
      "SeatLayerPickerTokensOpacity.g.swift",
      renderScalar(
        tokens,
        "opacity",
        "SeatLayerPickerOpacityTokens",
        [
          "Opacities that carry a meaning of their own.",
          "",
          "Not decoration: each one is a state the buyer is being told about,",
          "and it is the same number on every platform.",
        ],
        "Opacities that carry a meaning of their own.",
      ),
    ],
    ["SeatLayerPickerTokensType.g.swift", renderType(tokens)],
    ["SeatLayerPickerTokensMotion.g.swift", renderMotion(tokens)],
    ["SeatLayerPickerTokensHaptics.g.swift", renderHaptics(tokens)],
    ["SeatLayerPickerTokensStrings.g.swift", renderStrings(tokens)],
  ];
  const files = groups.map(([name, source]) => ({
    name,
    source: source.endsWith("\n") ? source : `${source}\n`,
  }));
  files.unshift({
    name: "SeatLayerPickerTokens.g.swift",
    source: `${renderIndex(
      tokens,
      files.map((file) => file.name),
    )}\n`.replace(/\n\n$/, "\n"),
  });
  return files;
}

export function generatedTokenFiles(packageRoot = root) {
  const { tokens } = loadDesign(packageRoot);
  return renderTokens(tokens);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const check = process.argv.includes("--check");
  const files = generatedTokenFiles();
  const stale = [];
  const oversized = [];
  for (const file of files) {
    const target = path.join(outputDirectory, file.name);
    const current = fs.existsSync(target)
      ? fs.readFileSync(target, "utf8")
      : "";
    if (file.source.split("\n").length - 1 > LINE_CAP) oversized.push(file.name);
    if (current === file.source) continue;
    stale.push(file.name);
    if (!check) fs.writeFileSync(target, file.source);
  }
  if (oversized.length) {
    console.error(
      `picker token generator: ${oversized.join(", ")} exceed ${LINE_CAP} lines; split the group`,
    );
    process.exit(1);
  }
  if (check && stale.length) {
    console.error(
      `picker token generator: ${stale.join(", ")} out of date. Run node Scripts/generate-picker-tokens.mjs`,
    );
    process.exit(1);
  }
  console.log(
    check
      ? `picker token files are up to date (${files.length})`
      : `wrote ${files.length} picker token files`,
  );
}
