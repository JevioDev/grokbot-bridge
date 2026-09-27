import { readdirSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const dirs = ["shim", "test"];
const files = dirs.flatMap((dir) => readdirSync(join(root, dir)).filter((file) => file.endsWith(".mjs")).map((file) => join(root, dir, file)));
for (const file of files) {
  const result = spawnSync(process.execPath, ["--check", file], { stdio: "inherit" });
  if (result.status !== 0) process.exit(result.status ?? 1);
}
console.log(`checked ${files.length} JavaScript files`);
