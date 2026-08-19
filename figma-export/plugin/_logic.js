// ---- Components Studio -> Figma importer (HIG-aware) ------------------------
// Audits the app's screens, rebuilds the NATIVE iOS components (nav bar, grouped
// list, back button, status bar, FABs) to Apple HIG specs — using SF Pro / SF
// Symbols when installed (free from developer.apple.com), else Inter + drawn
// glyphs. Shader / preview art is embedded as an image fill (Metal can't be
// vectorised). Also emits an Audit / Specs frame. IMAGES is defined above.

// ---- base64 -> Uint8Array (the plugin sandbox has no atob) -------------------
function b64ToBytes(b64) {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const lookup = new Uint8Array(256);
  for (let i = 0; i < chars.length; i++) lookup[chars.charCodeAt(i)] = i;
  const len = b64.length;
  let pad = 0;
  if (b64[len - 1] === "=") pad++;
  if (b64[len - 2] === "=") pad++;
  const bytes = new Uint8Array((len / 4) * 3 - pad);
  let p = 0;
  for (let i = 0; i < len; i += 4) {
    const e1 = lookup[b64.charCodeAt(i)];
    const e2 = lookup[b64.charCodeAt(i + 1)];
    const e3 = lookup[b64.charCodeAt(i + 2)];
    const e4 = lookup[b64.charCodeAt(i + 3)];
    bytes[p++] = (e1 << 2) | (e2 >> 4);
    if (b64.charCodeAt(i + 2) !== 61) bytes[p++] = ((e2 & 15) << 4) | (e3 >> 2);
    if (b64.charCodeAt(i + 3) !== 61) bytes[p++] = ((e3 & 3) << 6) | e4;
  }
  return bytes;
}

// ---- Apple system colors (light mode) ---------------------------------------
const C = {
  label: { r: 0, g: 0, b: 0 },
  ink: { r: 0x16 / 255, g: 0x16 / 255, b: 0x1a / 255 }, // app brand ink
  secondaryLabel: { r: 60 / 255, g: 60 / 255, b: 67 / 255 }, // @0.6
  tertiary: { r: 60 / 255, g: 60 / 255, b: 67 / 255 }, // @0.3
  groupedBg: { r: 0xf2 / 255, g: 0xf2 / 255, b: 0xf7 / 255 }, // systemGroupedBackground
  cellBg: { r: 1, g: 1, b: 1 },
  separator: { r: 0xc6 / 255, g: 0xc6 / 255, b: 0xc8 / 255 }, // opaqueSeparator
  blue: { r: 0, g: 0x7a / 255, b: 1 }, // systemBlue
  green: { r: 0x34 / 255, g: 0xc7 / 255, b: 0x59 / 255 }, // systemGreen
  gray3: { r: 0xc7 / 255, g: 0xc7 / 255, b: 0xcc / 255 }, // systemGray3
  gray6: { r: 0xf2 / 255, g: 0xf2 / 255, b: 0xf7 / 255 }, // systemGray6
  white: { r: 1, g: 1, b: 1 },
};

function solid(color, opacity) {
  return { type: "SOLID", color: color, opacity: opacity == null ? 1 : opacity };
}

// ---- font resolution: SF Pro if installed, else Inter -----------------------
let FONT = null;
async function resolveFonts() {
  async function tryFamily(fam, styles) {
    try {
      for (const s of styles) await figma.loadFontAsync({ family: fam, style: s });
      return true;
    } catch (e) {
      return false;
    }
  }
  const sfText = await tryFamily("SF Pro Text", ["Regular", "Medium", "Semibold", "Bold"]);
  const sfDisplay = await tryFamily("SF Pro Display", ["Bold", "Semibold"]);
  if (sfText && sfDisplay) {
    FONT = {
      kind: "SF Pro",
      regular: { family: "SF Pro Text", style: "Regular" },
      medium: { family: "SF Pro Text", style: "Medium" },
      semibold: { family: "SF Pro Text", style: "Semibold" },
      bold: { family: "SF Pro Text", style: "Bold" },
      display: { family: "SF Pro Display", style: "Bold" },
    };
    return;
  }
  await tryFamily("Inter", ["Regular", "Medium", "Semi Bold", "Bold"]);
  FONT = {
    kind: "Inter (SF Pro not installed)",
    regular: { family: "Inter", style: "Regular" },
    medium: { family: "Inter", style: "Medium" },
    semibold: { family: "Inter", style: "Semi Bold" },
    bold: { family: "Inter", style: "Bold" },
    display: { family: "Inter", style: "Bold" },
  };
}

// ---- node helpers -----------------------------------------------------------
function text(parent, chars, x, y, opts) {
  opts = opts || {};
  const t = figma.createText();
  t.fontName = opts.font || FONT.regular;
  t.fontSize = opts.size || 16;
  if (opts.width) {
    t.textAutoResize = "HEIGHT";
    t.resize(opts.width, 20);
  }
  t.characters = chars;
  t.x = x;
  t.y = y;
  t.fills = [solid(opts.color || C.label, opts.colorOpacity)];
  if (opts.letterSpacing != null) t.letterSpacing = { unit: "PIXELS", value: opts.letterSpacing };
  if (opts.lineHeight != null) t.lineHeight = { unit: "PIXELS", value: opts.lineHeight };
  if (opts.align) t.textAlignHorizontal = opts.align;
  parent.appendChild(t);
  return t;
}

function rect(parent, x, y, w, h, opts) {
  opts = opts || {};
  const r = figma.createRectangle();
  r.x = x;
  r.y = y;
  r.resize(w, h);
  if (opts.radius != null) r.cornerRadius = opts.radius;
  r.fills = opts.fills ? opts.fills : opts.fill ? [solid(opts.fill, opts.fillOpacity)] : [];
  if (opts.stroke) {
    r.strokes = [solid(opts.stroke, opts.strokeOpacity)];
    r.strokeWeight = opts.strokeWeight || 1;
  }
  if (opts.effects) r.effects = opts.effects;
  parent.appendChild(r);
  return r;
}

function ellipse(parent, x, y, d, opts) {
  opts = opts || {};
  const e = figma.createEllipse();
  e.x = x;
  e.y = y;
  e.resize(d, d);
  e.fills = opts.fill ? [solid(opts.fill, opts.fillOpacity)] : [];
  if (opts.stroke) {
    e.strokes = [solid(opts.stroke, opts.strokeOpacity)];
    e.strokeWeight = opts.strokeWeight || 1;
  }
  if (opts.effects) e.effects = opts.effects;
  parent.appendChild(e);
  return e;
}

// SF-Symbol-style chevron. dir "<" or ">".
function chevron(parent, x, y, dir, color, weight, size, opacity) {
  const v = figma.createVector();
  v.strokes = [solid(color, opacity)];
  v.strokeWeight = weight;
  v.strokeCap = "ROUND";
  v.strokeJoin = "ROUND";
  v.fills = [];
  const d =
    dir === "<"
      ? "M " + size + " 0 L 0 " + size + " L " + size + " " + size * 2
      : "M 0 0 L " + size + " " + size + " L 0 " + size * 2;
  v.vectorPaths = [{ windingRule: "NONE", data: d }];
  v.x = x;
  v.y = y;
  parent.appendChild(v);
  return v;
}

function imageFill(key) {
  const img = figma.createImage(b64ToBytes(IMAGES[key]));
  return [{ type: "IMAGE", scaleMode: "FILL", imageHash: img.hash }];
}

const SHADOW = function (a, y, blur) {
  return [{ type: "DROP_SHADOW", color: { r: 0, g: 0, b: 0, a: a }, offset: { x: 0, y: y }, radius: blur, spread: 0, visible: true, blendMode: "NORMAL" }];
};

function makeFrame(name, x, y, bg) {
  const f = figma.createFrame();
  f.name = name;
  f.resize(402, 874);
  f.x = x;
  f.y = y;
  f.fills = [solid(bg || C.white)];
  f.clipsContent = true;
  f.cornerRadius = 0;
  return f;
}

// ---- iOS chrome (HIG) -------------------------------------------------------
function statusBar(frame) {
  text(frame, "9:41", 30, 16, { font: FONT.semibold, size: 15, color: C.label });
  rect(frame, 402 - 42, 18, 22, 11, { radius: 3, stroke: C.label, strokeOpacity: 0.4, strokeWeight: 1 });
  rect(frame, 402 - 39, 20.5, 15, 6, { radius: 1.5, fill: C.label });
  rect(frame, 402 - 19, 21, 1.5, 5, { radius: 1, fill: C.label, fillOpacity: 0.4 });
}

// iOS 26 Liquid-Glass circular back button (UINavigationBar back)
function backButton(frame) {
  ellipse(frame, 20, 66, 36, { fill: C.gray6, fillOpacity: 0.9, effects: SHADOW(0.06, 1, 3) });
  chevron(frame, 33, 78, "<", C.blue, 2.2, 5);
}

// custom Liquid-Glass FAB (flagged custom in the audit)
function fab(frame, cx, cy, kind) {
  const d = 34;
  ellipse(frame, cx - d / 2, cy - d / 2, d, {
    fill: C.white,
    fillOpacity: 0.92,
    stroke: C.label,
    strokeOpacity: 0.08,
    strokeWeight: 1,
    effects: SHADOW(0.1, 3, 6),
  });
  if (kind === "sliders") {
    const ys = [cy - 5, cy, cy + 5];
    const knobX = [cx + 3, cx - 4, cx + 5];
    for (let i = 0; i < 3; i++) {
      rect(frame, cx - 6, ys[i] - 0.8, 12, 1.6, { radius: 1, fill: C.ink, fillOpacity: 0.85 });
      ellipse(frame, knobX[i] - 1.6, ys[i] - 1.6, 3.2, { fill: C.ink });
    }
  } else {
    const handle = rect(frame, cx - 1.4, cy - 6, 2.8, 12, { radius: 1.4, fill: C.ink, fillOpacity: 0.85 });
    handle.rotation = -45;
    ellipse(frame, cx - 6, cy - 6, 5.5, { stroke: C.ink, strokeOpacity: 0.85, strokeWeight: 1.6 });
  }
}

function splitTitle(t) {
  const w = t.split(" ");
  if (w.length < 2) return [t];
  const mid = Math.floor((w.length + 1) / 2);
  return [w.slice(0, mid).join(" "), w.slice(mid).join(" ")];
}

// ---- page builders ----------------------------------------------------------
function buildShaderPage(frame, title, key) {
  statusBar(frame);
  backButton(frame);
  const lines = splitTitle(title);
  text(frame, lines.join("\n"), 24, 96, {
    font: FONT.display, // SF Pro Display Bold
    size: 40,
    color: C.ink,
    letterSpacing: -1.2,
    lineHeight: 44,
  });
  const card = figma.createRectangle();
  card.x = 24;
  card.y = 337;
  card.resize(354, 445);
  card.cornerRadius = 28;
  card.fills = imageFill(key);
  frame.appendChild(card);
  fab(frame, 319, 799, "sliders");
  fab(frame, 361, 799, "tools");
}

function buildImagePage(frame, key) {
  frame.fills = imageFill(key);
}

// Home: UINavigationBar (inline) + UITableView inset-grouped + disclosure rows
function buildHome(frame) {
  statusBar(frame);
  text(frame, "APACH Components Studio", 0, 56, {
    font: FONT.semibold,
    size: 17,
    color: C.label,
    width: 402,
    align: "CENTER",
  });

  const sections = [
    { header: "Shaders", rows: ["Refractive Sphere", "Interactive Tiles", "Refractive Text", "Dotted Background", "Neumorphic Digit", "Photo Ripple", "Liquid Photo", "Spheric Mesh", "Glass Effect"] },
    { header: "Cards", rows: ["Satelite Cards"] },
    { header: "Pills", rows: ["Glass Pill"] },
    { header: "Loading", rows: ["Summary Blur Loading"] },
    { header: "Scroll", rows: ["Vertical card deck"] },
    { header: "Search", rows: ["AI Search"] },
  ];

  let cy = 108;
  const rowH = 44;
  for (const s of sections) {
    text(frame, s.header, 32, cy, { font: FONT.regular, size: 13, color: C.secondaryLabel, colorOpacity: 0.6 });
    cy += 26;
    const h = s.rows.length * rowH;
    rect(frame, 16, cy, 370, h, { radius: 10, fill: C.cellBg });
    for (let i = 0; i < s.rows.length; i++) {
      const top = cy + i * rowH;
      text(frame, s.rows[i], 32, top + 13, { font: FONT.regular, size: 17, color: C.label });
      chevron(frame, 366, top + rowH / 2 - 4, ">", C.gray3, 2, 4);
      if (i < s.rows.length - 1) rect(frame, 32, top + rowH - 0.5, 354, 1, { fill: C.separator, fillOpacity: 0.6 });
    }
    cy += h + 26;
  }
}

// ---- Audit / Specs frame ----------------------------------------------------
const AUDIT_NATIVE = [
  ["Navigation bar (inline)", "UINavigationBar", "H 44 · title SF Pro Semibold 17 · back = chevron.left, systemBlue, glass circle (iOS 26)"],
  ["Grouped list", "UITableView · insetGrouped", "card radius 10 · row H 44 · side inset 16 · bg systemGroupedBackground #F2F2F7"],
  ["Disclosure row", "UITableViewCell + accessory", "title SF Pro 17 label · leading 32 · chevron.right tertiaryLabel"],
  ["Separator", "opaqueSeparator", "#C6C6C8 @0.29 · 0.33pt · inset to text leading"],
  ["Slider", "UISlider", "track 4 · thumb ⌀28 white · minTrack systemBlue #007AFF"],
  ["Switch", "UISwitch", "51 × 31 · on systemGreen #34C759 · off systemGray5"],
  ["Text field", "UITextField", "SF Pro 17 · cursor tint · clear button"],
  ["Activity indicator", "UIActivityIndicatorView", "medium · systemGray spinner"],
  ["Liquid Glass surface", ".glassEffect / UIGlassEffect (iOS 26)", "regular.interactive · capsule / continuous rounded"],
  ["Status bar", "System", "time SF Pro Semibold 15 · battery / signal glyphs"],
];
const AUDIT_CUSTOM = [
  "52pt display headline — custom Text (not nav largeTitle)",
  "Metal shaders ×9 — Refractive/Photo/Dotted/Spheric/Glass/Tiles/Digit",
  "Circular FAB buttons — custom Liquid-Glass",
  "Preset chip rows / customize toolbox — custom",
  "Bubble & satellite cards, vertical place deck — custom",
];

function buildAudit(x, y) {
  const W = 560;
  const f = figma.createFrame();
  f.name = "Audit · iOS HIG components";
  f.x = x;
  f.y = y;
  f.resize(W, 920);
  f.fills = [solid(C.white)];
  f.cornerRadius = 16;
  f.clipsContent = true;

  text(f, "iOS HIG Audit", 28, 28, { font: FONT.bold, size: 24, color: C.label });
  text(f, "Fonts: " + FONT.kind, 28, 62, { font: FONT.regular, size: 12, color: C.secondaryLabel, colorOpacity: 0.7 });

  text(f, "NATIVE — rebuilt to Apple specs", 28, 96, { font: FONT.semibold, size: 13, color: C.green });
  let cy = 122;
  for (const [comp, apple, specs] of AUDIT_NATIVE) {
    text(f, comp, 28, cy, { font: FONT.semibold, size: 14, color: C.label });
    text(f, apple, 28, cy + 19, { font: FONT.medium, size: 12, color: C.blue });
    text(f, specs, 28, cy + 36, { font: FONT.regular, size: 11.5, color: C.secondaryLabel, colorOpacity: 0.85, width: W - 56 });
    rect(f, 28, cy + 58, W - 56, 1, { fill: C.separator, fillOpacity: 0.5 });
    cy += 70;
  }

  cy += 8;
  text(f, "CUSTOM — kept as art (no Apple equivalent)", 28, cy, { font: FONT.semibold, size: 13, color: { r: 0.85, g: 0.45, b: 0.1 } });
  cy += 26;
  for (const line of AUDIT_CUSTOM) {
    text(f, "•  " + line, 28, cy, { font: FONT.regular, size: 12, color: C.label, width: W - 56 });
    cy += 24;
  }
  return f;
}

// ---- main -------------------------------------------------------------------
const shaderPages = [
  { key: "interactive_tiles", title: "Interactive Tiles" },
  { key: "refractive_sphere", title: "Refractive Sphere" },
  { key: "refractive_text", title: "Refractive Text" },
  { key: "dotted_background", title: "Dotted Background" },
  { key: "neumorphic_digit", title: "Neumorphic Digit" },
  { key: "photo_ripple", title: "Photo Ripple" },
  { key: "liquid_photo", title: "Liquid Photo" },
  { key: "spheric_mesh", title: "Spheric Mesh" },
  { key: "glass_effect", title: "Glass Effect" },
];
const otherPages = [
  { key: "satelite_cards", title: "Satelite Cards" },
  { key: "glass_pill", title: "Glass Pill" },
  { key: "summary_blur_loading", title: "Summary Blur Loading" },
  { key: "vertical_card_deck", title: "Vertical card deck" },
  { key: "ai_search", title: "AI Search" },
];

(async () => {
  await resolveFonts();

  const GAP_X = 140;
  const GAP_Y = 240;
  const PER_ROW = 5;
  const frames = [];

  function place(i) {
    const col = i % PER_ROW;
    const row = Math.floor(i / PER_ROW);
    return { x: col * (402 + GAP_X), y: row * (874 + GAP_Y) };
  }

  // audit frame to the left of the grid
  const audit = buildAudit(-(560 + 160), 0);

  const all = [{ kind: "home", title: "Home", key: "home" }]
    .concat(shaderPages.map((p) => ({ kind: "shader", title: p.title, key: p.key })))
    .concat(otherPages.map((p) => ({ kind: "image", title: p.title, key: p.key })));

  for (let i = 0; i < all.length; i++) {
    const item = all[i];
    const pos = place(i);
    const bg = item.kind === "home" ? C.groupedBg : C.white;
    const frame = makeFrame(item.title, pos.x, pos.y, bg);
    text(figma.currentPage, item.title, pos.x, pos.y - 36, { font: FONT.semibold, size: 18, color: { r: 0.2, g: 0.2, b: 0.2 } });
    if (item.kind === "home") buildHome(frame);
    else if (item.kind === "shader") buildShaderPage(frame, item.title, item.key);
    else buildImagePage(frame, item.key);
    frames.push(frame);
  }

  const selection = [audit].concat(frames);
  figma.currentPage.selection = selection;
  figma.viewport.scrollAndZoomIntoView(selection);
  figma.notify("Components Studio: " + frames.length + " screens + audit imported ✓  (" + FONT.kind + ")");
  figma.closePlugin("Imported " + frames.length + " screens + audit");
})();
