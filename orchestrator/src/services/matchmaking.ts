/**
 * Matchmaking Service
 *
 * Manages the queue and creates matches when enough players are ready.
 */

import { v4 as uuidv4 } from "uuid";
import { InstanceManager } from "./instance-manager.js";

interface QueuedAgent {
  id: string;
  joinedAt: number;
  rating?: number;
}

export class MatchmakingService {
  private queue: QueuedAgent[] = [];
  private instanceManager: InstanceManager;
  private running = false;
  private matchInterval: NodeJS.Timeout | null = null;

  // Configuration
  private readonly AGENTS_PER_MATCH = 6; // 3v3
  private readonly MATCH_CHECK_INTERVAL = 1000; // 1 second
  private readonly MIN_AGENTS_TO_START = 2; // For testing, normally 6

  constructor(instanceManager: InstanceManager) {
    this.instanceManager = instanceManager;
  }

  start(): void {
    if (this.running) return;

    this.running = true;
    this.matchInterval = setInterval(() => {
      this.checkForMatch();
    }, this.MATCH_CHECK_INTERVAL);

    console.log("[Matchmaking] Started");
  }

  stop(): void {
    this.running = false;
    if (this.matchInterval) {
      clearInterval(this.matchInterval);
      this.matchInterval = null;
    }
    console.log("[Matchmaking] Stopped");
  }

  async addToQueue(agentId: string, rating?: number): Promise<number> {
    // Check if already in queue
    const existing = this.queue.findIndex((a) => a.id === agentId);
    if (existing !== -1) {
      return existing + 1; // Return existing position
    }

    const agent: QueuedAgent = {
      id: agentId,
      joinedAt: Date.now(),
      rating,
    };

    this.queue.push(agent);
    console.log(`[Matchmaking] Agent ${agentId} joined queue (position ${this.queue.length})`);

    return this.queue.length;
  }

  removeFromQueue(agentId: string): boolean {
    const index = this.queue.findIndex((a) => a.id === agentId);
    if (index === -1) return false;

    this.queue.splice(index, 1);
    console.log(`[Matchmaking] Agent ${agentId} left queue`);
    return true;
  }

  getQueueSize(): number {
    return this.queue.length;
  }

  getQueuePosition(agentId: string): number {
    const index = this.queue.findIndex((a) => a.id === agentId);
    return index === -1 ? -1 : index + 1;
  }

  private async checkForMatch(): Promise<void> {
    if (this.queue.length < this.MIN_AGENTS_TO_START) {
      return;
    }

    // Take agents for match (up to 6)
    const agentsForMatch = Math.min(this.queue.length, this.AGENTS_PER_MATCH);
    const matchAgents = this.queue.splice(0, agentsForMatch);

    // Assign teams (simple alternating for now)
    const blueTeam: string[] = [];
    const redTeam: string[] = [];

    matchAgents.forEach((agent, index) => {
      if (index % 2 === 0) {
        blueTeam.push(agent.id);
      } else {
        redTeam.push(agent.id);
      }
    });

    // Create match
    const matchId = uuidv4();
    console.log(
      `[Matchmaking] Creating match ${matchId} with ${matchAgents.length} agents`
    );

    try {
      await this.instanceManager.createMatch(matchId, blueTeam, redTeam);
    } catch (error) {
      console.error(`[Matchmaking] Failed to create match: ${error}`);
      // Return agents to queue
      this.queue.unshift(...matchAgents);
    }
  }
}
