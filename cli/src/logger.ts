import chalk from "chalk";

export interface Logger {
  info(msg: string): void;
  success(msg: string): void;
  warn(msg: string): void;
  error(msg: string): void;
  debug(msg: string): void;
  blank(): void;
  header(msg: string): void;
}

export function createLogger(debugEnabled: boolean): Logger {
  return {
    info(msg: string) {
      process.stdout.write(chalk.cyan("  i ") + msg + "\n");
    },
    success(msg: string) {
      process.stdout.write(chalk.green("  \u2714 ") + msg + "\n");
    },
    warn(msg: string) {
      process.stderr.write(chalk.yellow("  \u26A0 ") + msg + "\n");
    },
    error(msg: string) {
      process.stderr.write(chalk.red("  \u2716 ") + msg + "\n");
    },
    debug(msg: string) {
      if (debugEnabled) {
        process.stderr.write(chalk.gray("  [debug] " + msg) + "\n");
      }
    },
    blank() {
      process.stdout.write("\n");
    },
    header(msg: string) {
      process.stdout.write("\n" + chalk.bold.white("  " + msg) + "\n\n");
    },
  };
}
