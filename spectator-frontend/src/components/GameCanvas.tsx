import { useRef, useEffect } from "react";
import * as PIXI from "pixi.js";
import { useGameStore } from "../store/gameStore";

// Arena dimensions
const ARENA_WIDTH = 8000;
const ARENA_HEIGHT = 4000;
const LANE_Y = 2000;

// Colors
const COLORS = {
  background: 0x1a1c24,
  lane: 0x2a2c35,
  blueTeam: 0x3498db,
  redTeam: 0xe74c3c,
  blueChampion: 0x5dade2,
  redChampion: 0xec7063,
  blueMinion: 0x85c1e9,
  redMinion: 0xf1948a,
  blueTower: 0x2980b9,
  redTower: 0xc0392b,
  healthBar: 0x2ecc71,
  healthBarBg: 0x1a1a1a,
  manaBar: 0x3498db,
};

export function GameCanvas() {
  const containerRef = useRef<HTMLDivElement>(null);
  const appRef = useRef<PIXI.Application | null>(null);
  const gameState = useGameStore((state) => state.gameState);

  useEffect(() => {
    if (!containerRef.current) return;

    // Initialize Pixi application
    const app = new PIXI.Application();

    const initApp = async () => {
      await app.init({
        background: COLORS.background,
        resizeTo: containerRef.current!,
        antialias: true,
      });

      containerRef.current!.appendChild(app.canvas);
      appRef.current = app;

      // Create game layers
      const backgroundLayer = new PIXI.Container();
      const entityLayer = new PIXI.Container();
      const uiLayer = new PIXI.Container();

      app.stage.addChild(backgroundLayer);
      app.stage.addChild(entityLayer);
      app.stage.addChild(uiLayer);

      // Draw background
      drawBackground(backgroundLayer);

      // Store references for updates
      (app.stage as any).entityLayer = entityLayer;
      (app.stage as any).uiLayer = uiLayer;
    };

    initApp();

    return () => {
      app.destroy(true, { children: true });
    };
  }, []);

  // Update entities when game state changes
  useEffect(() => {
    if (!appRef.current) return;

    const entityLayer = (appRef.current.stage as any).entityLayer as PIXI.Container;
    if (!entityLayer) return;

    // Clear previous entities
    entityLayer.removeChildren();

    // Calculate scale to fit arena in viewport
    const viewWidth = appRef.current.screen.width;
    const viewHeight = appRef.current.screen.height;
    const scale = Math.min(viewWidth / ARENA_WIDTH, viewHeight / ARENA_HEIGHT);

    entityLayer.scale.set(scale);

    // Center the arena
    entityLayer.position.set(
      (viewWidth - ARENA_WIDTH * scale) / 2,
      (viewHeight - ARENA_HEIGHT * scale) / 2
    );

    // Draw towers
    drawTowers(entityLayer, gameState.towers);

    // Draw minions
    drawMinions(entityLayer, gameState.minions);

    // Draw champions
    drawChampions(entityLayer, gameState.champions);

  }, [gameState]);

  return (
    <div
      ref={containerRef}
      className="game-canvas"
      style={{ width: "100%", height: "100%" }}
    />
  );
}

function drawBackground(container: PIXI.Container) {
  // Lane path
  const lane = new PIXI.Graphics();
  lane.rect(0, LANE_Y - 200, ARENA_WIDTH, 400);
  lane.fill(COLORS.lane);
  container.addChild(lane);

  // Base areas
  const blueBase = new PIXI.Graphics();
  blueBase.circle(500, LANE_Y, 300);
  blueBase.fill({ color: COLORS.blueTeam, alpha: 0.3 });
  container.addChild(blueBase);

  const redBase = new PIXI.Graphics();
  redBase.circle(7500, LANE_Y, 300);
  redBase.fill({ color: COLORS.redTeam, alpha: 0.3 });
  container.addChild(redBase);

  // Nexus indicators
  const blueNexus = new PIXI.Graphics();
  blueNexus.rect(400, LANE_Y - 75, 200, 150);
  blueNexus.fill(COLORS.blueTeam);
  container.addChild(blueNexus);

  const redNexus = new PIXI.Graphics();
  redNexus.rect(7400, LANE_Y - 75, 200, 150);
  redNexus.fill(COLORS.redTeam);
  container.addChild(redNexus);
}

function drawTowers(
  container: PIXI.Container,
  towers: Array<{ id: string; team: "blue" | "red"; position: { x: number; y: number }; health: number; maxHealth: number }>
) {
  for (const tower of towers) {
    const color = tower.team === "blue" ? COLORS.blueTower : COLORS.redTower;

    const towerGraphic = new PIXI.Graphics();
    towerGraphic.rect(-40, -60, 80, 120);
    towerGraphic.fill(color);
    towerGraphic.position.set(tower.position.x, tower.position.y);
    container.addChild(towerGraphic);

    // Health bar
    const healthBar = createHealthBar(tower.health, tower.maxHealth, 70);
    healthBar.position.set(tower.position.x - 35, tower.position.y - 80);
    container.addChild(healthBar);
  }
}

function drawMinions(
  container: PIXI.Container,
  minions: Array<{ id: string; team: "blue" | "red"; position: { x: number; y: number }; isMelee: boolean }>
) {
  for (const minion of minions) {
    const color = minion.team === "blue" ? COLORS.blueMinion : COLORS.redMinion;
    const size = minion.isMelee ? 20 : 16;

    const minionGraphic = new PIXI.Graphics();
    minionGraphic.circle(0, 0, size);
    minionGraphic.fill(color);
    minionGraphic.position.set(minion.position.x, minion.position.y);
    container.addChild(minionGraphic);
  }
}

function drawChampions(
  container: PIXI.Container,
  champions: Array<{
    id: string;
    champion: string;
    team: "blue" | "red";
    position: { x: number; y: number };
    health: number;
    maxHealth: number;
    mana: number;
    maxMana: number;
    level: number;
    isAlive: boolean;
  }>
) {
  for (const champ of champions) {
    if (!champ.isAlive) continue;

    const color = champ.team === "blue" ? COLORS.blueChampion : COLORS.redChampion;

    // Champion body
    const champGraphic = new PIXI.Graphics();
    champGraphic.circle(0, 0, 35);
    champGraphic.fill(color);
    champGraphic.stroke({ color: 0xffffff, width: 2 });
    champGraphic.position.set(champ.position.x, champ.position.y);
    container.addChild(champGraphic);

    // Champion name/level indicator
    const label = new PIXI.Text({
      text: `${champ.champion[0]}${champ.level}`,
      style: {
        fontFamily: "Arial",
        fontSize: 18,
        fill: 0xffffff,
        fontWeight: "bold",
      },
    });
    label.anchor.set(0.5);
    label.position.set(champ.position.x, champ.position.y);
    container.addChild(label);

    // Health bar
    const healthBar = createHealthBar(champ.health, champ.maxHealth, 60);
    healthBar.position.set(champ.position.x - 30, champ.position.y - 55);
    container.addChild(healthBar);

    // Mana bar
    const manaBar = createManaBar(champ.mana, champ.maxMana, 60);
    manaBar.position.set(champ.position.x - 30, champ.position.y - 45);
    container.addChild(manaBar);
  }
}

function createHealthBar(current: number, max: number, width: number): PIXI.Container {
  const container = new PIXI.Container();
  const height = 8;

  // Background
  const bg = new PIXI.Graphics();
  bg.rect(0, 0, width, height);
  bg.fill(COLORS.healthBarBg);
  container.addChild(bg);

  // Health fill
  const fillWidth = max > 0 ? (current / max) * width : 0;
  const fill = new PIXI.Graphics();
  fill.rect(0, 0, fillWidth, height);
  fill.fill(COLORS.healthBar);
  container.addChild(fill);

  return container;
}

function createManaBar(current: number, max: number, width: number): PIXI.Container {
  const container = new PIXI.Container();
  const height = 4;

  // Background
  const bg = new PIXI.Graphics();
  bg.rect(0, 0, width, height);
  bg.fill(COLORS.healthBarBg);
  container.addChild(bg);

  // Mana fill
  const fillWidth = max > 0 ? (current / max) * width : 0;
  const fill = new PIXI.Graphics();
  fill.rect(0, 0, fillWidth, height);
  fill.fill(COLORS.manaBar);
  container.addChild(fill);

  return container;
}
