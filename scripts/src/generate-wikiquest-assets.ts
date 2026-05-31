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

function compassMark(size = 1024, stroke = colors.ink, accent = colors.race, compact = false): string {
  const scale = size / 1024;
  const cx = 512 * scale;
  const cy = (compact ? 540 : 558) * scale;
  const radius = (compact ? 202 : 214) * scale;
  const strokeWidth = (compact ? 52 : 58) * scale;
  const accentWidth = (compact ? 40 : 46) * scale;
  return `<g fill="none" stroke-linecap="round" stroke-linejoin="round">
    <circle cx="${cx}" cy="${cy}" r="${radius}" stroke="${stroke}" stroke-width="${strokeWidth}"/>
    <path d="M${cx} ${cy - radius - 82 * scale}V${cy - radius - 12 * scale}M${cx} ${cy + radius + 12 * scale}V${cy + radius + 82 * scale}M${cx - radius - 82 * scale} ${cy}H${cx - radius - 12 * scale}M${cx + radius + 12 * scale} ${cy}H${cx + radius + 82 * scale}" stroke="${stroke}" stroke-width="${Math.max(8, 25 * scale)}" opacity="0.72"/>
    <path d="M${304 * scale} ${692 * scale}C${386 * scale} ${614 * scale} ${456 * scale} ${600 * scale} ${514 * scale} ${546 * scale}C${586 * scale} ${480 * scale} ${646 * scale} ${418 * scale} ${760 * scale} ${376 * scale}" stroke="${accent}" stroke-width="${accentWidth}"/>
    <circle cx="${304 * scale}" cy="${692 * scale}" r="${38 * scale}" fill="${colors.mystery}" stroke="${stroke}" stroke-width="${Math.max(8, 17 * scale)}"/>
    <circle cx="${514 * scale}" cy="${546 * scale}" r="${32 * scale}" fill="${colors.paperLight}" stroke="${accent}" stroke-width="${Math.max(8, 18 * scale)}"/>
    <circle cx="${760 * scale}" cy="${376 * scale}" r="${38 * scale}" fill="${colors.nearby}" stroke="${stroke}" stroke-width="${Math.max(8, 17 * scale)}"/>
    <path d="M${482 * scale} ${302 * scale}L${592 * scale} ${566 * scale}L${438 * scale} ${814 * scale}L${512 * scale} ${552 * scale}Z" fill="${stroke}" stroke="${stroke}" stroke-width="${Math.max(6, 12 * scale)}"/>
    <path d="M${512 * scale} ${552 * scale}L${592 * scale} ${566 * scale}L${482 * scale} ${302 * scale}Z" fill="${colors.paperLight}" opacity="0.82"/>
  </g>
  <path d="M${232 * scale} ${852 * scale}H${792 * scale}" stroke="${colors.muted}" stroke-width="${compact ? 22 * scale : 26 * scale}" stroke-linecap="round" opacity="0.38"/>`;
}

function appIconSvg(size: number): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="${colors.ink}"/>
  <path d="M150 132H874C914 132 944 162 944 202V822C944 862 914 892 874 892H150C110 892 80 862 80 822V202C80 162 110 132 150 132Z" fill="${colors.paperLight}"/>
  <path d="M142 302H882" stroke="${colors.ink}" stroke-width="34" opacity="0.95"/>
  <rect x="184" y="186" width="150" height="64" rx="14" fill="${colors.mystery}"/>
  <rect x="437" y="186" width="150" height="64" rx="14" fill="${colors.race}"/>
  <rect x="690" y="186" width="150" height="64" rx="14" fill="${colors.nearby}"/>
  <circle cx="512" cy="586" r="220" stroke="${colors.ink}" stroke-width="70" fill="none"/>
  <path d="M284 704C374 622 450 624 515 566C600 490 676 420 808 388" stroke="${colors.race}" stroke-width="58" fill="none" stroke-linecap="round"/>
  <circle cx="284" cy="704" r="46" fill="${colors.mystery}" stroke="${colors.ink}" stroke-width="28"/>
  <circle cx="808" cy="388" r="46" fill="${colors.nearby}" stroke="${colors.ink}" stroke-width="28"/>
  <path d="M462 342L594 592L418 814L512 586Z" fill="${colors.ink}"/>
  <path d="M512 586L594 592L462 342Z" fill="${colors.paperLight}" opacity="0.88"/>
  <path d="M262 820H762" stroke="${colors.muted}" stroke-width="30" stroke-linecap="round" opacity="0.42"/>
</svg>`;
}

function compactSvg(size: number): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="38" fill="${colors.ink}"/>
  <rect x="26" y="28" width="55" height="20" rx="4" fill="${colors.mystery}"/>
  <rect x="101" y="28" width="55" height="20" rx="4" fill="${colors.race}"/>
  <rect x="176" y="28" width="55" height="20" rx="4" fill="${colors.nearby}"/>
  <circle cx="128" cy="139" r="58" stroke="${colors.paperLight}" stroke-width="16" fill="none"/>
  <path d="M82 165C107 144 123 146 140 127C158 108 178 93 204 87" stroke="${colors.race}" stroke-width="13" fill="none" stroke-linecap="round"/>
  <circle cx="82" cy="165" r="10" fill="${colors.mystery}"/>
  <circle cx="204" cy="87" r="10" fill="${colors.nearby}"/>
  <path d="M118 72L145 143L105 205L128 139Z" fill="${colors.paperLight}"/>
  <path d="M128 139L145 143L118 72Z" fill="${colors.ink}" opacity="0.44"/>
</svg>`;
}

function brandMarkSvg(size: number): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="72" fill="${colors.ink}"/>
  <path d="M71 66H441C462 66 478 82 478 103V411C478 432 462 448 441 448H71C50 448 34 432 34 411V103C34 82 50 66 71 66Z" fill="${colors.paperLight}"/>
  <path d="M68 151H444" stroke="${colors.ink}" stroke-width="16" opacity="0.92"/>
  <path d="M91 92H174V124H91Z" fill="${colors.mystery}"/>
  <path d="M215 92H298V124H215Z" fill="${colors.race}"/>
  <path d="M339 92H422V124H339Z" fill="${colors.nearby}"/>
  <circle cx="256" cy="290" r="108" stroke="${colors.ink}" stroke-width="31" fill="none"/>
  <path d="M144 348C188 306 228 307 258 279C302 238 342 206 405 190" stroke="${colors.race}" stroke-width="25" fill="none" stroke-linecap="round"/>
  <circle cx="144" cy="348" r="20" fill="${colors.mystery}" stroke="${colors.ink}" stroke-width="10"/>
  <circle cx="405" cy="190" r="20" fill="${colors.nearby}" stroke="${colors.ink}" stroke-width="10"/>
  <path d="M231 166L292 294L211 401L256 290Z" fill="${colors.ink}"/>
  <path d="M256 290L292 294L231 166Z" fill="${colors.paperLight}" opacity="0.86"/>
  <path d="M105 412H407" stroke="${colors.muted}" stroke-width="13" stroke-linecap="round" opacity="0.42"/>
</svg>`;
}

function brandGlyphSvg(size: number): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 256 256">
  <path d="M40 48H90" stroke="${colors.mystery}" stroke-width="14" stroke-linecap="round"/>
  <path d="M104 48H154" stroke="${colors.race}" stroke-width="14" stroke-linecap="round"/>
  <path d="M168 48H218" stroke="${colors.nearby}" stroke-width="14" stroke-linecap="round"/>
  <circle cx="128" cy="142" r="60" stroke="${colors.ink}" stroke-width="16" fill="none"/>
  <path d="M72 170C100 146 120 148 138 130C159 110 181 94 214 87" stroke="${colors.race}" stroke-width="13" fill="none" stroke-linecap="round"/>
  <circle cx="72" cy="170" r="9" fill="${colors.mystery}"/>
  <circle cx="214" cy="87" r="9" fill="${colors.nearby}"/>
  <path d="M117 75L148 144L104 210L128 142Z" fill="${colors.ink}"/>
  <path d="M128 142L148 144L117 75Z" fill="${colors.paperLight}" opacity="0.82"/>
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
