import { Resvg } from "@resvg/resvg-js";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDir, "..", "..");

const assetCatalogDir = path.join(root, "Resources/Assets.xcassets");
const iconDir = path.join(assetCatalogDir, "AppIcon.appiconset");
const publicDir = path.join(root, "WebAssets");

const appIconSizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024];
const faviconSizes = [16, 32, 48];

const colors = {
  paper: "#f2ead8",
  paperLight: "#fffaf0",
  ink: "#181b1f",
  rule: "#cabf9f",
  muted: "#817961",
  mystery: "#c68117",
  race: "#245ca8",
  nearby: "#247047",
  danger: "#b1392f",
  wikiBlue: "#1557b0",
  wikiBlueDark: "#0b3678",
};

function grid(size = 1024, step = 128, opacity = 0.2): string {
  const lines: string[] = [];
  for (let value = step; value < size; value += step) {
    lines.push(`M${value} 0V${size}`, `M0 ${value}H${size}`);
  }
  return `<path d="${lines.join("")}" stroke="${colors.rule}" stroke-width="8" opacity="${opacity}"/>`;
}

function tabs(width = 1024): string {
  const scale = width / 1024;
  const y = 120 * scale;
  const h = 86 * scale;
  const radius = 12 * scale;
  const tabWidth = 205 * scale;
  const gap = 61 * scale;
  const start = 153 * scale;
  const items = [
    { x: start, fill: colors.mystery },
    { x: start + tabWidth + gap, fill: colors.race },
    { x: start + (tabWidth + gap) * 2, fill: colors.nearby },
  ];
  return items
    .map(
      (item) =>
        `<rect x="${item.x}" y="${y}" width="${tabWidth}" height="${h}" rx="${radius}" fill="${item.fill}"/>`,
    )
    .join("");
}

function simpleWPath(viewBoxSize = 1024): string {
  const scale = viewBoxSize / 1024;
  // Optical W mark: compact enough for iOS masking, open enough for 20px icons.
  const points = [
    [196, 304],
    [306, 304],
    [386, 668],
    [480, 430],
    [546, 430],
    [640, 668],
    [724, 304],
    [836, 304],
    [686, 760],
    [586, 760],
    [514, 558],
    [438, 760],
    [334, 760],
  ]
    .map(([x, y]) => `${Math.round(x * scale)} ${Math.round(y * scale)}`)
    .join("L");
  return `M${points}Z`;
}

function simpleWMark(viewBoxSize = 1024, fill = colors.wikiBlue): string {
  return `<path d="${simpleWPath(viewBoxSize)}" fill="${fill}"/>`;
}

function appIconSvg(size: number): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="${colors.paperLight}"/>
  ${simpleWMark(1024)}
</svg>`;
}

function compactSvg(size: number): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="44" fill="${colors.paperLight}"/>
  ${simpleWMark(256)}
</svg>`;
}

function brandMarkSvg(size: number): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="92" fill="${colors.paperLight}"/>
  ${simpleWMark(512)}
</svg>`;
}

function brandGlyphSvg(size: number): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 256 256">
  ${simpleWMark(256)}
</svg>`;
}

type ModeName = "Mystery" | "Race" | "Nearby";

function modeGlyphSvg(mode: ModeName, size: number): string {
  const accent =
    mode === "Mystery" ? colors.mystery : mode === "Race" ? colors.race : colors.nearby;
  const body =
    mode === "Mystery"
      ? `<path d="M96 92C96 66 119 50 151 50C183 50 206 70 206 99C206 122 190 135 170 147C154 157 149 168 149 188" stroke="${colors.ink}" stroke-width="18" fill="none" stroke-linecap="round" stroke-linejoin="round"/><circle cx="149" cy="218" r="10" fill="${colors.ink}"/>`
      : mode === "Race"
        ? `<path d="M98 104L74 128C52 150 52 184 74 206C96 228 130 228 152 206L170 188" stroke="${colors.ink}" stroke-width="18" fill="none" stroke-linecap="round"/><path d="M158 68L180 46C202 24 236 24 258 46C280 68 280 102 258 124L235 147" stroke="${colors.ink}" stroke-width="18" fill="none" stroke-linecap="round" transform="translate(-54 26)"/><path d="M112 166L174 104" stroke="${accent}" stroke-width="16" stroke-linecap="round"/>`
        : `<path d="M128 224C128 224 200 148 200 90C200 50 168 22 128 22C88 22 56 50 56 90C56 148 128 224 128 224Z" stroke="${colors.ink}" stroke-width="18" fill="none" stroke-linejoin="round"/><circle cx="128" cy="91" r="31" stroke="${accent}" stroke-width="16" fill="none"/>`;

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 256 256">
  <rect x="14" y="14" width="228" height="228" rx="34" fill="${colors.paperLight}" stroke="${colors.ink}" stroke-width="10"/>
  <path d="M36 49H220" stroke="${accent}" stroke-width="10" stroke-linecap="round"/>
  ${body}
</svg>`;
}

function renderPng(svg: string, size: number, background?: string): Buffer {
  return Buffer.from(
    new Resvg(svg, {
      fitTo: { mode: "width", value: size },
      ...(background ? { background } : {}),
    })
      .render()
      .asPng(),
  );
}

function writeUInt16LE(value: number): Buffer {
  const buffer = Buffer.alloc(2);
  buffer.writeUInt16LE(value, 0);
  return buffer;
}

function writeUInt32LE(value: number): Buffer {
  const buffer = Buffer.alloc(4);
  buffer.writeUInt32LE(value, 0);
  return buffer;
}

function makeIco(images: Array<{ size: number; png: Buffer }>): Buffer {
  const header = Buffer.concat([
    writeUInt16LE(0),
    writeUInt16LE(1),
    writeUInt16LE(images.length),
  ]);
  const directorySize = 16 * images.length;
  let offset = header.length + directorySize;
  const entries: Buffer[] = [];
  for (const image of images) {
    entries.push(
      Buffer.concat([
        Buffer.from([image.size >= 256 ? 0 : image.size, image.size >= 256 ? 0 : image.size, 0, 0]),
        writeUInt16LE(1),
        writeUInt16LE(32),
        writeUInt32LE(image.png.length),
        writeUInt32LE(offset),
      ]),
    );
    offset += image.png.length;
  }
  return Buffer.concat([header, ...entries, ...images.map((image) => image.png)]);
}

function imageSetContents(name: string): string {
  return `${JSON.stringify(
    {
      images: [
        { filename: `${name}-1x.png`, idiom: "universal", scale: "1x" },
        { filename: `${name}-2x.png`, idiom: "universal", scale: "2x" },
        { filename: `${name}-3x.png`, idiom: "universal", scale: "3x" },
      ],
      info: { author: "xcode", version: 1 },
    },
    null,
    2,
  )}\n`;
}

async function writeImageSet(
  name: string,
  svgFactory: (size: number) => string,
  baseSize: number,
  background?: string,
) {
  const imageSetDir = path.join(assetCatalogDir, `${name}.imageset`);
  await mkdir(imageSetDir, { recursive: true });
  for (const scale of [1, 2, 3]) {
    const size = baseSize * scale;
    await writeFile(
      path.join(imageSetDir, `${name}-${scale}x.png`),
      renderPng(svgFactory(size), size, background),
    );
  }
  await writeFile(path.join(imageSetDir, "Contents.json"), imageSetContents(name));
}

async function main() {
  await mkdir(iconDir, { recursive: true });
  await mkdir(publicDir, { recursive: true });

  const fullSvg = appIconSvg(1024);
  const faviconSvg = compactSvg(256);

  for (const size of appIconSizes) {
    await writeFile(path.join(iconDir, `AppIcon-${size}.png`), renderPng(fullSvg, size, colors.paper));
  }

  await writeFile(path.join(publicDir, "favicon.svg"), compactSvg(64));
  await writeFile(path.join(publicDir, "logo.svg"), brandMarkSvg(512));
  await writeFile(path.join(publicDir, "favicon-32.png"), renderPng(compactSvg(32), 32));
  await writeFile(path.join(publicDir, "favicon-256.png"), renderPng(faviconSvg, 256));
  await writeFile(path.join(publicDir, "apple-touch-icon.png"), renderPng(compactSvg(180), 180));

  const icoImages = faviconSizes.map((size) => ({
    size,
    png: renderPng(compactSvg(size), size),
  }));
  await writeFile(path.join(publicDir, "favicon.ico"), makeIco(icoImages));

  await writeImageSet("BrandMark", brandMarkSvg, 84);
  await writeImageSet("BrandGlyph", brandGlyphSvg, 42);
  await writeImageSet("ModeMysteryMark", (size) => modeGlyphSvg("Mystery", size), 38);
  await writeImageSet("ModeRaceMark", (size) => modeGlyphSvg("Race", size), 38);
  await writeImageSet("ModeNearbyMark", (size) => modeGlyphSvg("Nearby", size), 38);

  const contentsPath = path.join(iconDir, "Contents.json");
  await readFile(contentsPath, "utf8");
  console.log("Generated path-based WikiQuest iOS icons, web favicons, and brand image sets.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
