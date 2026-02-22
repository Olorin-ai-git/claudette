import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const DEFAULT_TIMEOUT_MS = 30_000;

export interface ExecResult {
  stdout: string;
  stderr: string;
}

export async function exec(
  command: string,
  args: string[] = [],
  options?: { timeout?: number },
): Promise<ExecResult> {
  const { stdout, stderr } = await execFileAsync(command, args, {
    timeout: options?.timeout ?? DEFAULT_TIMEOUT_MS,
    encoding: "utf-8",
  });
  return { stdout: stdout ?? "", stderr: stderr ?? "" };
}

export async function commandExists(command: string): Promise<string | null> {
  try {
    const { stdout } = await exec("which", [command]);
    const resolvedPath = stdout.trim();
    return resolvedPath || null;
  } catch {
    return null;
  }
}
