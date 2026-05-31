import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDir, "..", "..");
const assetCatalogDir = path.join(root, "Resources/Assets.xcassets");
const iconDir = path.join(assetCatalogDir, "AppIcon.appiconset");
const publicDir = path.join(root, "WebAssets");

const appIconSizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024];
const imageSets = [
  { name: "BrandMark", baseSize: 84 },
  { name: "BrandGlyph", baseSize: 42 },
  { name: "ModeMysteryMark", baseSize: 38 },
  { name: "ModeRaceMark", baseSize: 38 },
  { name: "ModeNearbyMark", baseSize: 38 },
];

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function pngDimensions(buffer: Buffer): { width: number; height: number } {
  assert(buffer.length > 24, "PNG is too small to contain an IHDR chunk.");
  assert(buffer.toString("ascii", 1, 4) === "PNG", "File is not a PNG.");
  assert(buffer.toString("ascii", 12, 16) === "IHDR", "PNG is missing IHDR.");
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  };
}

async function assertPng(filePath: string, expectedSize: number): Promise<void> {
  const file = await readFile(filePath);
  const details = await stat(filePath);
  assert(details.size > 0, `${filePath} is empty.`);
  const dimensions = pngDimensions(file);
  assert(
    dimensions.width === expectedSize && dimensions.height === expectedSize,
    `${filePath} is ${dimensions.width}x${dimensions.height}, expected ${expectedSize}x${expectedSize}.`,
  );
}

async function assertSvg(filePath: string): Promise<void> {
  const svg = await readFile(filePath, "utf8");
  assert(svg.length > 100, `${filePath} is unexpectedly small.`);
  assert(!svg.includes("<text"), `${filePath} must not contain SVG text nodes.`);
  assert(!svg.includes("font-family"), `${filePath} must not depend on fonts.`);
}

async function assertNonEmptyFile(filePath: string): Promise<void> {
  const details = await stat(filePath);
  assert(details.size > 0, `${filePath} is empty.`);
}

async function assertDirectoryHasNoEmptyFiles(directory: string): Promise<void> {
  const entries = await readdir(directory, { withFileTypes: true });
  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      await assertDirectoryHasNoEmptyFiles(entryPath);
    } else {
      const details = await stat(entryPath);
      assert(details.size > 0, `${entryPath} is empty.`);
    }
  }
}

async function main() {
  let checked = 0;

  for (const size of appIconSizes) {
    await assertPng(path.join(iconDir, `AppIcon-${size}.png`), size);
    checked += 1;
  }

  for (const imageSet of imageSets) {
    const imageSetDir = path.join(assetCatalogDir, `${imageSet.name}.imageset`);
    for (const scale of [1, 2, 3]) {
      await assertPng(
        path.join(imageSetDir, `${imageSet.name}-${scale}x.png`),
        imageSet.baseSize * scale,
      );
      checked += 1;
    }
  }

  await assertSvg(path.join(publicDir, "favicon.svg"));
  await assertSvg(path.join(publicDir, "logo.svg"));
  await assertPng(path.join(publicDir, "favicon-32.png"), 32);
  await assertPng(path.join(publicDir, "favicon-256.png"), 256);
  await assertPng(path.join(publicDir, "apple-touch-icon.png"), 180);
  await assertNonEmptyFile(path.join(publicDir, "favicon.ico"));
  await assertDirectoryHasNoEmptyFiles(assetCatalogDir);
  checked += 7;

  console.log(`Verified ${checked} WikiQuest asset outputs.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
