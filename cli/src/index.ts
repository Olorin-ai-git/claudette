import { Command } from "commander";
import { runSetup } from "./commands/setup.js";

const program = new Command();

program
  .name("claudette-setup")
  .description("Set up your Mac for Claudette remote access")
  .version("1.0.0")
  .option("-p, --port <number>", "SSH port override", parseInt)
  .option("--ip <address>", "IP address override")
  .option("--skip-checks", "Skip environment checks and issue resolution")
  .option("--debug", "Enable verbose debug output")
  .action(
    async (options: {
      port?: number;
      ip?: string;
      skipChecks?: boolean;
      debug?: boolean;
    }) => {
      await runSetup({
        port: options.port,
        ip: options.ip,
        skipChecks: options.skipChecks,
        debug: options.debug,
      });
    },
  );

program.parse();
