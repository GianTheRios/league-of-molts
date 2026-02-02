/**
 * Gateway Service
 *
 * Handles agent WebSocket connections and routes them to matches.
 */

import WebSocket from "ws";
import { MatchmakingService } from "./matchmaking.js";
import { InstanceManager } from "./instance-manager.js";

interface AgentSession {
  agentId: string;
  authenticated: boolean;
  matchId?: string;
  matchSocket?: WebSocket;
}

export class GatewayService {
  private socket: WebSocket;
  private matchmaking: MatchmakingService;
  private instanceManager: InstanceManager;
  private session: AgentSession | null = null;

  constructor(
    socket: WebSocket,
    matchmaking: MatchmakingService,
    instanceManager: InstanceManager
  ) {
    this.socket = socket;
    this.matchmaking = matchmaking;
    this.instanceManager = instanceManager;
  }

  start(): void {
    this.socket.on("message", (data) => {
      this.handleMessage(data.toString());
    });

    this.socket.on("close", () => {
      this.handleDisconnect();
    });

    this.socket.on("error", (error) => {
      console.error("[Gateway] Socket error:", error);
    });
  }

  private handleMessage(rawData: string): void {
    try {
      const message = JSON.parse(rawData);
      const type = message.type;

      switch (type) {
        case "auth":
          this.handleAuth(message);
          break;

        case "queue":
          this.handleQueue(message);
          break;

        case "leave_queue":
          this.handleLeaveQueue();
          break;

        default:
          // Forward to match if connected
          if (this.session?.matchSocket) {
            this.session.matchSocket.send(rawData);
          }
      }
    } catch (error) {
      console.error("[Gateway] Error handling message:", error);
      this.sendError("Invalid message format");
    }
  }

  private handleAuth(message: { agent_id: string; token?: string }): void {
    const { agent_id, token } = message;
    console.log(`[Gateway] Handling auth for agent: ${agent_id}`);

    if (!agent_id) {
      this.sendError("Missing agent_id");
      return;
    }

    // TODO: Validate token if provided

    this.session = {
      agentId: agent_id,
      authenticated: true,
    };

    console.log(`[Gateway] Agent ${agent_id} authenticated`);

    // Check if agent has an existing match
    const existingMatch = this.instanceManager.getMatchForAgent(agent_id);
    if (existingMatch) {
      this.connectToMatch(existingMatch.id, existingMatch.port);
      return;
    }

    // Send auth success
    const response = {
      type: "auth_success",
      agent_id,
      status: "ready",
    };
    console.log(`[Gateway] Sending auth response:`, response);
    this.send(response);
  }

  private async handleQueue(message: { rating?: number }): Promise<void> {
    if (!this.session?.authenticated) {
      this.sendError("Not authenticated");
      return;
    }

    const position = await this.matchmaking.addToQueue(
      this.session.agentId,
      message.rating
    );

    this.send({
      type: "queue_joined",
      position,
    });

    // Listen for match assignment
    this.instanceManager.on("matchCreated", (matchId: string) => {
      const match = this.instanceManager.getMatch(matchId);
      if (
        match &&
        (match.blueTeam.includes(this.session!.agentId) ||
          match.redTeam.includes(this.session!.agentId))
      ) {
        this.connectToMatch(matchId, match.port);
      }
    });
  }

  private handleLeaveQueue(): void {
    if (!this.session?.authenticated) {
      return;
    }

    this.matchmaking.removeFromQueue(this.session.agentId);
    this.send({ type: "queue_left" });
  }

  private connectToMatch(matchId: string, port: number): void {
    if (!this.session) return;

    console.log(
      `[Gateway] Connecting agent ${this.session.agentId} to match ${matchId} on port ${port}`
    );

    // Connect to match instance
    const matchSocket = new WebSocket(`ws://localhost:${port}`);

    matchSocket.on("open", () => {
      // Forward auth to match
      matchSocket.send(
        JSON.stringify({
          type: "auth",
          agent_id: this.session!.agentId,
        })
      );
    });

    matchSocket.on("message", (data) => {
      // Forward match messages to agent
      if (this.socket.readyState === WebSocket.OPEN) {
        this.socket.send(data.toString());
      }
    });

    matchSocket.on("close", () => {
      console.log(`[Gateway] Match connection closed for ${this.session?.agentId}`);
      this.session!.matchSocket = undefined;
      this.session!.matchId = undefined;

      // Notify agent
      this.send({ type: "match_disconnected" });
    });

    matchSocket.on("error", (error) => {
      console.error(`[Gateway] Match socket error: ${error}`);
    });

    this.session.matchSocket = matchSocket;
    this.session.matchId = matchId;

    this.send({
      type: "match_found",
      match_id: matchId,
    });
  }

  private handleDisconnect(): void {
    if (this.session) {
      console.log(`[Gateway] Agent ${this.session.agentId} disconnected`);

      // Remove from queue if queued
      this.matchmaking.removeFromQueue(this.session.agentId);

      // Close match connection if exists
      if (this.session.matchSocket) {
        this.session.matchSocket.close();
      }
    }
  }

  private send(message: object): void {
    const data = JSON.stringify(message);
    console.log(`[Gateway] Sending (readyState=${this.socket.readyState}):`, data);
    // readyState 1 = OPEN
    if (this.socket.readyState === 1) {
      this.socket.send(data);
      console.log(`[Gateway] Sent successfully`);
    } else {
      console.log(`[Gateway] Socket not open, cannot send`);
    }
  }

  private sendError(message: string): void {
    this.send({ type: "error", message });
  }
}
