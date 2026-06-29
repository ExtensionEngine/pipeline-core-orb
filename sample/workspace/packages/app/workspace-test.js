import { writeFileSync } from "node:fs";
import { resolve } from "node:path";

const scriptArgs = process.argv.slice(2).filter((arg) => arg !== "--");
const [outputFile, ...args] = scriptArgs;

if (!outputFile) {
  throw new Error("Missing output file argument");
}

writeFileSync(resolve(process.cwd(), outputFile), args.join("|"));
