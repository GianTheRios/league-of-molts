import { create } from "zustand";

interface Position {
  x: number;
  y: number;
}

interface ChampionState {
  id: string;
  champion: string;
  team: "blue" | "red";
  position: Position;
  health: number;
  maxHealth: number;
  mana: number;
  maxMana: number;
  level: number;
  isAlive: boolean;
}

interface MinionState {
  id: string;
  team: "blue" | "red";
  position: Position;
  health: number;
  maxHealth: number;
  isMelee: boolean;
}

interface TowerState {
  id: string;
  team: "blue" | "red";
  position: Position;
  health: number;
  maxHealth: number;
}

interface GameState {
  tick: number;
  matchTime: number;
  status: "waiting" | "playing" | "ended";
  champions: ChampionState[];
  minions: MinionState[];
  towers: TowerState[];
  blueNexusHealth: number;
  redNexusHealth: number;
  winner?: "blue" | "red";
}

interface CommentaryLine {
  id: string;
  text: string;
  timestamp: number;
  type: "normal" | "kill" | "objective" | "hype";
}

interface GameStore {
  gameState: GameState;
  commentary: CommentaryLine[];
  connected: boolean;
  socket: WebSocket | null;

  // Actions
  connect: (serverUrl: string) => Promise<void>;
  disconnect: () => void;
  updateGameState: (state: Partial<GameState>) => void;
  addCommentary: (line: CommentaryLine) => void;
}

const initialGameState: GameState = {
  tick: 0,
  matchTime: 0,
  status: "waiting",
  champions: [],
  minions: [],
  towers: [],
  blueNexusHealth: 5000,
  redNexusHealth: 5000,
};

export const useGameStore = create<GameStore>((set, get) => ({
  gameState: initialGameState,
  commentary: [],
  connected: false,
  socket: null,

  connect: async (serverUrl: string) => {
    return new Promise((resolve, reject) => {
      const socket = new WebSocket(serverUrl);

      socket.onopen = () => {
        console.log("Connected to match server");
        set({ socket, connected: true });

        // Send spectate request
        socket.send(JSON.stringify({ type: "spectate" }));
        resolve();
      };

      socket.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data);
          handleMessage(message, set, get);
        } catch (error) {
          console.error("Error parsing message:", error);
        }
      };

      socket.onclose = () => {
        console.log("Disconnected from match server");
        set({ socket: null, connected: false });
      };

      socket.onerror = (error) => {
        console.error("WebSocket error:", error);
        reject(error);
      };
    });
  },

  disconnect: () => {
    const { socket } = get();
    if (socket) {
      socket.close();
    }
    set({ socket: null, connected: false });
  },

  updateGameState: (state) => {
    set((prev) => ({
      gameState: { ...prev.gameState, ...state },
    }));
  },

  addCommentary: (line) => {
    set((prev) => ({
      commentary: [...prev.commentary.slice(-20), line], // Keep last 20 lines
    }));
  },
}));

function handleMessage(
  message: any,
  set: any,
  get: () => GameStore
): void {
  switch (message.type) {
    case "state":
      // Full state update
      set({
        gameState: parseGameState(message),
      });
      break;

    case "delta":
      // Delta update
      const current = get().gameState;
      set({
        gameState: applyDelta(current, message),
      });
      break;

    case "commentary":
      get().addCommentary({
        id: `${Date.now()}-${Math.random()}`,
        text: message.text,
        timestamp: message.timestamp || Date.now(),
        type: message.commentaryType || "normal",
      });
      break;

    case "match_end":
      set({
        gameState: {
          ...get().gameState,
          status: "ended",
          winner: message.winner,
        },
      });
      break;
  }
}

function parseGameState(data: any): GameState {
  return {
    tick: data.tick || 0,
    matchTime: data.match_time || 0,
    status: data.status || "playing",
    champions: (data.champions || []).map(parseChampion),
    minions: (data.minions || []).map(parseMinion),
    towers: (data.towers || []).map(parseTower),
    blueNexusHealth: data.blue_nexus_health || 5000,
    redNexusHealth: data.red_nexus_health || 5000,
    winner: data.winner,
  };
}

function parseChampion(data: any): ChampionState {
  return {
    id: data.id,
    champion: data.champion,
    team: data.team,
    position: data.position,
    health: data.health,
    maxHealth: data.max_health,
    mana: data.mana,
    maxMana: data.max_mana,
    level: data.level,
    isAlive: data.is_alive,
  };
}

function parseMinion(data: any): MinionState {
  return {
    id: data.id,
    team: data.team,
    position: data.position,
    health: data.health,
    maxHealth: data.max_health,
    isMelee: data.is_melee,
  };
}

function parseTower(data: any): TowerState {
  return {
    id: data.id,
    team: data.team,
    position: data.position,
    health: data.health,
    maxHealth: data.max_health,
  };
}

function applyDelta(current: GameState, delta: any): GameState {
  // Apply incremental updates
  const updated = { ...current };

  if (delta.tick !== undefined) updated.tick = delta.tick;
  if (delta.match_time !== undefined) updated.matchTime = delta.match_time;

  // Update champions
  if (delta.champions) {
    for (const champDelta of delta.champions) {
      const index = updated.champions.findIndex((c) => c.id === champDelta.id);
      if (index !== -1) {
        updated.champions[index] = {
          ...updated.champions[index],
          ...parseChampion(champDelta),
        };
      }
    }
  }

  // Update minions (simplified - full replace)
  if (delta.minions) {
    updated.minions = delta.minions.map(parseMinion);
  }

  return updated;
}
