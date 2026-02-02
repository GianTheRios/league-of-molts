/**
 * Instance Manager
 *
 * Spawns and manages Godot match instances.
 */

import { spawn, ChildProcess } from "child_process";
import { EventEmitter } from "events";

interface MatchInstance {
  id: string;
  process: ChildProcess | null;
  port: number;
  status: "starting" | "running" | "ending" | "ended";
  blueTeam: string[];
  redTeam: string[];
  startedAt: number;
  endedAt?: number;
}

export class InstanceManager extends EventEmitter {
  private matches: Map<string, MatchInstance> = new Map();
  private nextPort = 9050;
  private totalMatches = 0;

  // Configuration
  private readonly GODOT_EXECUTABLE = process.env.GODOT_PATH || "godot";
  private readonly GAME_PATH = process.env.GAME_PATH || "../godot-game";
  private readonly HEADLESS = process.env.HEADLESS !== "false";

  async createMatch(
    matchId: string,
    blueTeam: string[],
    redTeam: string[]
  ): Promise<MatchInstance> {
    const port = this.allocatePort();

    const instance: MatchInstance = {
      id: matchId,
      process: null,
      port,
      status: "starting",
      blueTeam,
      redTeam,
      startedAt: Date.now(),
    };

    this.matches.set(matchId, instance);
    this.totalMatches++;

    try {
      await this.spawnGodotProcess(instance);
      instance.status = "running";
      console.log(`[InstanceManager] Match ${matchId} running on port ${port}`);
    } catch (error) {
      instance.status = "ended";
      console.error(`[InstanceManager] Failed to start match ${matchId}: ${error}`);
      throw error;
    }

    return instance;
  }

  private async spawnGodotProcess(instance: MatchInstance): Promise<void> {
    const args = [
      "--path",
      this.GAME_PATH,
      "--",
      `--match-id=${instance.id}`,
      `--port=${instance.port}`,
      `--blue-team=${instance.blueTeam.join(",")}`,
      `--red-team=${instance.redTeam.join(",")}`,
    ];

    if (this.HEADLESS) {
      args.unshift("--headless");
    }

    return new Promise((resolve, reject) => {
      try {
        const proc = spawn(this.GODOT_EXECUTABLE, args, {
          stdio: ["ignore", "pipe", "pipe"],
        });

        instance.process = proc;

        proc.stdout?.on("data", (data) => {
          console.log(`[Match ${instance.id}] ${data.toString().trim()}`);
        });

        proc.stderr?.on("data", (data) => {
          console.error(`[Match ${instance.id}] ${data.toString().trim()}`);
        });

        proc.on("error", (error) => {
          console.error(`[Match ${instance.id}] Process error: ${error}`);
          this.handleMatchEnd(instance.id);
          reject(error);
        });

        proc.on("exit", (code) => {
          console.log(`[Match ${instance.id}] Process exited with code ${code}`);
          this.handleMatchEnd(instance.id);
        });

        // Wait a bit for process to start
        setTimeout(() => {
          if (proc.killed || proc.exitCode !== null) {
            reject(new Error("Process died immediately"));
          } else {
            resolve();
          }
        }, 1000);
      } catch (error) {
        reject(error);
      }
    });
  }

  private handleMatchEnd(matchId: string): void {
    const instance = this.matches.get(matchId);
    if (instance) {
      instance.status = "ended";
      instance.endedAt = Date.now();
      this.emit("matchEnded", matchId);
    }
  }

  endMatch(matchId: string): boolean {
    const instance = this.matches.get(matchId);
    if (!instance) return false;

    if (instance.process && !instance.process.killed) {
      instance.process.kill("SIGTERM");
    }

    instance.status = "ending";
    return true;
  }

  getMatch(matchId: string): MatchInstance | undefined {
    return this.matches.get(matchId);
  }

  getMatchForAgent(agentId: string): MatchInstance | undefined {
    for (const [, instance] of this.matches) {
      if (
        instance.status === "running" &&
        (instance.blueTeam.includes(agentId) || instance.redTeam.includes(agentId))
      ) {
        return instance;
      }
    }
    return undefined;
  }

  getMatchList(): Array<{
    id: string;
    port: number;
    status: string;
    blueTeam: string[];
    redTeam: string[];
    duration: number;
  }> {
    return Array.from(this.matches.values()).map((m) => ({
      id: m.id,
      port: m.port,
      status: m.status,
      blueTeam: m.blueTeam,
      redTeam: m.redTeam,
      duration: (m.endedAt || Date.now()) - m.startedAt,
    }));
  }

  getActiveMatchCount(): number {
    let count = 0;
    for (const [, instance] of this.matches) {
      if (instance.status === "running") {
        count++;
      }
    }
    return count;
  }

  getTotalMatchCount(): number {
    return this.totalMatches;
  }

  private allocatePort(): number {
    const port = this.nextPort;
    this.nextPort++;

    // Wrap around to avoid port exhaustion
    if (this.nextPort > 9999) {
      this.nextPort = 9050;
    }

    return port;
  }

  async cleanup(): Promise<void> {
    console.log("[InstanceManager] Cleaning up all matches...");

    for (const [matchId, instance] of this.matches) {
      if (instance.process && !instance.process.killed) {
        instance.process.kill("SIGTERM");
      }
    }

    this.matches.clear();
  }
}
