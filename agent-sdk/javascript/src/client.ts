/**
 * WebSocket client for League of Molts Agent SDK
 */

import WebSocket from "ws";
import {
  Action,
  Observation,
  ObservationMessage,
  ServerMessage,
  Team,
} from "./types.js";

export interface AgentConfig {
  agentId: string;
  serverUrl?: string;
  token?: string;
  reconnectAttempts?: number;
  reconnectDelay?: number;
}

export interface Agent {
  /**
   * Decide what actions to take given the current observation.
   */
  decide(observation: Observation): Action[];

  /**
   * Called when successfully connected to the match.
   */
  onConnect?(team: Team): void;

  /**
   * Called when disconnected from the match.
   */
  onDisconnect?(): void;

  /**
   * Called when the match starts.
   */
  onMatchStart?(): void;

  /**
   * Called when the match ends.
   */
  onMatchEnd?(winner: Team, duration: number): void;
}

export class AgentClient {
  private config: Required<AgentConfig>;
  private agent: Agent;
  private ws: WebSocket | null = null;
  private running = false;
  private team: Team | null = null;
  private reconnectCount = 0;

  constructor(config: AgentConfig, agent: Agent) {
    this.config = {
      serverUrl: "ws://localhost:9050",
      token: "",
      reconnectAttempts: 5,
      reconnectDelay: 1000,
      ...config,
    };
    this.agent = agent;
  }

  async run(): Promise<void> {
    this.running = true;

    while (this.running && this.reconnectCount < this.config.reconnectAttempts) {
      try {
        await this.connectAndRun();
      } catch (error) {
        console.error("Connection error:", error);
        this.reconnectCount++;

        if (this.reconnectCount < this.config.reconnectAttempts) {
          console.log(
            `Reconnecting in ${this.config.reconnectDelay}ms... (${this.reconnectCount}/${this.config.reconnectAttempts})`
          );
          await this.sleep(this.config.reconnectDelay);
        }
      }
    }

    this.agent.onDisconnect?.();
  }

  private async connectAndRun(): Promise<void> {
    return new Promise((resolve, reject) => {
      console.log(`Connecting to ${this.config.serverUrl}...`);

      this.ws = new WebSocket(this.config.serverUrl);

      this.ws.on("open", () => {
        this.reconnectCount = 0;
        this.authenticate();
      });

      this.ws.on("message", (data) => {
        try {
          const message = JSON.parse(data.toString()) as ServerMessage;
          this.handleMessage(message);
        } catch (error) {
          console.error("Error parsing message:", error);
        }
      });

      this.ws.on("close", () => {
        console.log("Connection closed");
        resolve();
      });

      this.ws.on("error", (error) => {
        reject(error);
      });
    });
  }

  private authenticate(): void {
    const authMsg = {
      type: "auth",
      agent_id: this.config.agentId,
      ...(this.config.token && { token: this.config.token }),
    };
    this.send(authMsg);
  }

  private handleMessage(message: ServerMessage): void {
    switch (message.type) {
      case "auth_success":
        this.team = message.team;
        console.log(`Authenticated as ${this.config.agentId} on team ${this.team}`);
        this.agent.onConnect?.(this.team);
        break;

      case "auth_error":
        console.error("Authentication failed:", message.message);
        this.stop();
        break;

      case "observation":
        this.handleObservation(message);
        break;

      case "match_start":
        this.agent.onMatchStart?.();
        break;

      case "match_end":
        this.agent.onMatchEnd?.(message.winner, message.duration);
        this.running = false;
        break;
    }
  }

  private handleObservation(observation: ObservationMessage): void {
    const actions = this.agent.decide(observation);
    if (actions.length > 0) {
      this.sendActions(actions);
    }
  }

  private sendActions(actions: Action[]): void {
    this.send({
      type: "action",
      actions,
    });
  }

  private send(message: unknown): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    }
  }

  stop(): void {
    this.running = false;
    this.ws?.close();
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

/**
 * Convenience function to run an agent.
 */
export function runAgent(
  agent: Agent,
  agentId: string,
  serverUrl = "ws://localhost:9050"
): Promise<void> {
  const client = new AgentClient({ agentId, serverUrl }, agent);
  return client.run();
}
