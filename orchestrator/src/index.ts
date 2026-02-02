/**
 * League of Molts - Match Orchestrator
 *
 * Manages matchmaking, spawns Godot match instances, and routes connections.
 */

import Fastify from "fastify";
import { WebSocketServer, WebSocket } from "ws";
import { createServer } from "http";
import { MatchmakingService } from "./services/matchmaking.js";
import { InstanceManager } from "./services/instance-manager.js";
import { GatewayService } from "./services/gateway.js";

const PORT = parseInt(process.env.PORT || "8080");

async function main() {
  console.log("Starting League of Molts Orchestrator...");

  // Initialize services
  const instanceManager = new InstanceManager();
  const matchmaking = new MatchmakingService(instanceManager);

  // Create Fastify server
  const app = Fastify({
    logger: true,
  });

  // Health check endpoint
  app.get("/health", async () => {
    return {
      status: "healthy",
      matches: instanceManager.getActiveMatchCount(),
      queued: matchmaking.getQueueSize(),
    };
  });

  // Stats endpoint
  app.get("/stats", async () => {
    return {
      matches: {
        active: instanceManager.getActiveMatchCount(),
        total: instanceManager.getTotalMatchCount(),
      },
      queue: {
        size: matchmaking.getQueueSize(),
      },
    };
  });

  // REST API for match management
  app.post("/api/queue", async (req, reply) => {
    const body = req.body as { agent_id: string; token?: string };

    if (!body.agent_id) {
      return reply.status(400).send({ error: "agent_id required" });
    }

    const position = await matchmaking.addToQueue(body.agent_id);
    return { queued: true, position };
  });

  app.delete("/api/queue/:agent_id", async (req, reply) => {
    const { agent_id } = req.params as { agent_id: string };
    const removed = matchmaking.removeFromQueue(agent_id);
    return { removed };
  });

  app.get("/api/matches", async () => {
    return instanceManager.getMatchList();
  });

  app.get("/api/matches/:match_id", async (req, reply) => {
    const { match_id } = req.params as { match_id: string };
    const match = instanceManager.getMatch(match_id);

    if (!match) {
      return reply.status(404).send({ error: "Match not found" });
    }

    return match;
  });

  // Create HTTP server from Fastify
  const server = createServer((req, res) => {
    app.server.emit("request", req, res);
  });

  // Create WebSocket server on /ws path
  const wss = new WebSocketServer({ noServer: true });

  server.on("upgrade", (request, socket, head) => {
    const url = new URL(request.url || "", `http://${request.headers.host}`);

    if (url.pathname === "/ws") {
      wss.handleUpgrade(request, socket, head, (ws) => {
        wss.emit("connection", ws, request);
      });
    } else {
      socket.destroy();
    }
  });

  wss.on("connection", (socket: WebSocket) => {
    console.log("New WebSocket connection");
    const gateway = new GatewayService(socket, matchmaking, instanceManager);
    gateway.start();
  });

  // Start Fastify without listening (we use our own server)
  await app.ready();

  // Start the combined server
  server.listen(PORT, "0.0.0.0", () => {
    console.log(`Orchestrator listening on port ${PORT}`);
    console.log(`WebSocket endpoint: ws://localhost:${PORT}/ws`);

    // Start matchmaking loop
    matchmaking.start();
  });
}

main().catch(console.error);
