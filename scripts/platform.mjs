import { spawnSync } from "node:child_process";
import process from "node:process";

const command = process.argv[2];
if (!command || !["setup", "doctor"].includes(command)) {
  console.error("usage: node scripts/platform.mjs {setup|doctor}");
  process.exit(2);
}

const isWindows = process.platform === "win32";
const script = isWindows ? `scripts/${command}.ps1` : `scripts/${command}.sh`;
const shell = isWindows ? "powershell.exe" : "bash";
const args = isWindows
  ? ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script]
  : [script];
const result = spawnSync(shell, args, { stdio: "inherit", cwd: new URL("..", import.meta.url) });
if (result.error) {
  console.error(`could not run ${shell}: ${result.error.message}`);
  process.exit(1);
}
process.exit(result.status ?? 1);
