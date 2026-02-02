/**
 * Mock Match Server
 *
 * A simple WebSocket server that simulates a Godot match for testing.
 * Run this to test the full flow without Godot installed.
 */

import { WebSocketServer, WebSocket } from "ws";

const PORT = parseInt(process.argv[2] || "9050");

interface Agent {
  id: string;
  team: "blue" | "red";
  socket: WebSocket;
  position: { x: number; y: number };
  health: number;
  maxHealth: number;
  level: number;
}

const agents: Map<string, Agent> = new Map();
let tick = 0;
let matchStarted = false;

const wss = new WebSocketServer({ port: PORT });

console.log(`Mock Match Server running on port ${PORT}`);

wss.on("connection", (socket) => {
  console.log("Agent connected");
  let agentId: string | null = null;

  socket.on("message", (data) => {
    try {
      const msg = JSON.parse(data.toString());

      if (msg.type === "auth") {
        agentId = msg.agent_id;

        // Assign team
        const blueCount = [...agents.values()].filter((a) => a.team === "blue").length;
        const team = blueCount < 3 ? "blue" : "red";

        // Initial position
        const spawnX = team === "blue" ? 800 : 7200;

        agents.set(agentId, {
          id: agentId,
          team,
          socket,
          position: { x: spawnX, y: 2000 },
          health: 600,
          maxHealth: 600,
          level: 1,
        });

        // Send auth success with team
        socket.send(
          JSON.stringify({
            type: "auth_success",
            agent_id: agentId,
            team,
          })
        );

        console.log(`Agent ${agentId} joined team ${team}`);

        // Start match if we have 2+ agents
        if (agents.size >= 2 && !matchStarted) {
          startMatch();
        }
      } else if (msg.type === "action" && agentId) {
        handleAction(agentId, msg.actions || []);
      }
    } catch (e) {
      console.error("Error parsing message:", e);
    }
  });

  socket.on("close", () => {
    if (agentId) {
      agents.delete(agentId);
      console.log(`Agent ${agentId} disconnected`);
    }
  });
});

function startMatch() {
  matchStarted = true;
  console.log("Match starting!");

  // Broadcast match start
  broadcast({ type: "match_start" });

  // Start game loop
  setInterval(() => {
    tick++;
    broadcastObservations();
  }, 50); // 20 Hz
}

function handleAction(agentId: string, actions: any[]) {
  const agent = agents.get(agentId);
  if (!agent) return;

  for (const action of actions) {
    if (action.action_type === "move") {
      // Simple instant move (for testing)
      const target = action.target;
      const dx = target.x - agent.position.x;
      const dy = target.y - agent.position.y;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist > 0) {
        const moveSpeed = 350 * 0.05; // speed * tick interval
        const moveDist = Math.min(dist, moveSpeed);
        agent.position.x += (dx / dist) * moveDist;
        agent.position.y += (dy / dist) * moveDist;
      }
    }
  }
}

function broadcastObservations() {
  for (const [id, agent] of agents) {
    const obs = buildObservation(agent);
    agent.socket.send(JSON.stringify(obs));
  }
}

function buildObservation(agent: Agent) {
  const allies = [...agents.values()]
    .filter((a) => a.team === agent.team && a.id !== agent.id)
    .map((a) => ({
      id: a.id,
      champion: "Ironclad",
      position: a.position,
      health: a.health,
      max_health: a.maxHealth,
      level: a.level,
      is_alive: true,
    }));

  const enemies = [...agents.values()]
    .filter((a) => a.team !== agent.team)
    .map((a) => ({
      id: a.id,
      champion: "Ironclad",
      position: a.position,
      health: a.health,
      max_health: a.maxHealth,
      level: a.level,
      is_alive: true,
    }));

  return {
    type: "observation",
    tick,
    match_time: tick * 0.05,
    self: {
      id: agent.id,
      champion: "Ironclad",
      position: agent.position,
      health: agent.health,
      max_health: agent.maxHealth,
      mana: 300,
      max_mana: 300,
      level: agent.level,
      xp: 0,
      gold: 500,
      is_alive: true,
      abilities: {
        Q: { name: "Shield Bash", ready: true, cooldown_remaining: 0, mana_cost: 40 },
        W: { name: "Iron Will", ready: true, cooldown_remaining: 0, mana_cost: 60 },
        E: { name: "Tremor", ready: true, cooldown_remaining: 0, mana_cost: 50 },
        R: { name: "Unstoppable Charge", ready: false, cooldown_remaining: 0, mana_cost: 100, level_required: 6, unlocked: false },
      },
      items: [],
      stats: {
        attack_damage: 62,
        ability_power: 0,
        armor: 38,
        magic_resist: 32,
        move_speed: 340,
        attack_range: 125,
        attack_speed: 0.65,
      },
    },
    allies,
    enemies,
    minions: { allied: [], enemy: [] },
    structures: {
      towers: { blue: [], red: [] },
      nexus: { blue: { health: 5000 }, red: { health: 5000 } },
    },
  };
}

function broadcast(message: object) {
  const data = JSON.stringify(message);
  for (const agent of agents.values()) {
    agent.socket.send(data);
  }
}
