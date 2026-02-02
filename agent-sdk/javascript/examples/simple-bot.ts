#!/usr/bin/env tsx
/**
 * Simple Example Bot for League of Molts
 *
 * This bot demonstrates basic agent behavior:
 * - Moves toward enemy side of map
 * - Last-hits minions when possible
 * - Uses abilities on nearby enemies
 * - Falls back when low health
 */

import {
  Agent,
  AgentClient,
  Action,
  Observation,
  Position,
  Team,
  MinionState,
  EnemyState,
  distanceTo,
  directionTo,
  addPositions,
  scalePosition,
  healthPercent,
  canUseAbility,
} from "../src/index.js";

const BLUE_BASE: Position = { x: 800, y: 2000 };
const RED_BASE: Position = { x: 7200, y: 2000 };

class SimpleBot implements Agent {
  private team: Team | null = null;

  onConnect(team: Team): void {
    this.team = team;
    console.log(`Connected on team ${team}`);
  }

  onMatchStart(): void {
    console.log("Match started!");
  }

  onMatchEnd(winner: Team, duration: number): void {
    const result = winner === this.team ? "WON" : "LOST";
    console.log(`Match ended! We ${result}. Duration: ${duration.toFixed(1)}s`);
  }

  decide(obs: Observation): Action[] {
    const me = obs.self;

    // Don't act if dead
    if (!me.is_alive) {
      return [];
    }

    // Determine push/retreat targets
    const pushTarget = this.team === "blue" ? RED_BASE : BLUE_BASE;
    const retreatTarget = this.team === "blue" ? BLUE_BASE : RED_BASE;

    // Retreat if low health
    if (healthPercent(me) < 0.25) {
      console.log("Low health, retreating!");
      return [{ action_type: "move", target: retreatTarget }];
    }

    // Try to last-hit minions
    const lowHpMinion = this.getLowHealthMinion(obs, 0.25);
    if (lowHpMinion) {
      const dist = distanceTo(me.position, lowHpMinion.position);
      if (dist <= me.stats.attack_range) {
        return [{ action_type: "attack", target_id: lowHpMinion.id }];
      } else {
        return [{ action_type: "move", target: lowHpMinion.position }];
      }
    }

    // Look for enemy champions
    const nearestEnemy = this.getNearestEnemy(obs);
    if (nearestEnemy && nearestEnemy.is_alive) {
      const enemyDist = distanceTo(me.position, nearestEnemy.position);
      const actions: Action[] = [];

      // Use abilities if in range
      if (enemyDist < 600) {
        // Try to use Q
        if (canUseAbility(me, "Q")) {
          actions.push({
            action_type: "ability",
            ability: "Q",
            target: nearestEnemy.position,
            target_id: nearestEnemy.id,
          });
        }

        // Use E defensively if enemy is close
        if (enemyDist < 200 && canUseAbility(me, "E")) {
          const escapeDir = directionTo(nearestEnemy.position, me.position);
          const escapePos = addPositions(me.position, scalePosition(escapeDir, 300));
          actions.push({
            action_type: "ability",
            ability: "E",
            target: escapePos,
          });
        }

        // Use R if enemy is low
        if (healthPercent(nearestEnemy) < 0.4 && canUseAbility(me, "R")) {
          actions.push({
            action_type: "ability",
            ability: "R",
            target: nearestEnemy.position,
          });
        }
      }

      // Auto attack if in range
      if (enemyDist <= me.stats.attack_range) {
        actions.push({ action_type: "attack", target_id: nearestEnemy.id });
      } else if (enemyDist < 800) {
        // Move toward enemy to fight
        actions.push({ action_type: "move", target: nearestEnemy.position });
      }

      if (actions.length > 0) {
        return actions;
      }
    }

    // Attack nearest enemy minion
    const nearestMinion = this.getNearestMinion(obs);
    if (nearestMinion) {
      const dist = distanceTo(me.position, nearestMinion.position);
      if (dist <= me.stats.attack_range) {
        return [{ action_type: "attack", target_id: nearestMinion.id }];
      } else if (dist < 600) {
        return [{ action_type: "move", target: nearestMinion.position }];
      }
    }

    // Default: push toward enemy base
    return [{ action_type: "move", target: pushTarget }];
  }

  private getNearestEnemy(obs: Observation): EnemyState | null {
    const alive = obs.enemies.filter((e) => e.is_alive);
    if (alive.length === 0) return null;

    return alive.reduce((nearest, enemy) =>
      distanceTo(obs.self.position, enemy.position) <
      distanceTo(obs.self.position, nearest.position)
        ? enemy
        : nearest
    );
  }

  private getNearestMinion(obs: Observation): MinionState | null {
    const minions = obs.minions.enemy;
    if (minions.length === 0) return null;

    return minions.reduce((nearest, minion) =>
      distanceTo(obs.self.position, minion.position) <
      distanceTo(obs.self.position, nearest.position)
        ? minion
        : nearest
    );
  }

  private getLowHealthMinion(obs: Observation, threshold: number): MinionState | null {
    const lowHealth = obs.minions.enemy.filter(
      (m) => healthPercent(m) <= threshold
    );
    if (lowHealth.length === 0) return null;

    return lowHealth.reduce((nearest, minion) =>
      distanceTo(obs.self.position, minion.position) <
      distanceTo(obs.self.position, nearest.position)
        ? minion
        : nearest
    );
  }
}

// Main
const agentId = process.argv[2] || "simple-bot-js-1";
const serverUrl = process.argv[3] || "ws://localhost:9050";

console.log(`Starting ${agentId} connecting to ${serverUrl}`);

const client = new AgentClient(
  { agentId, serverUrl },
  new SimpleBot()
);

client.run().catch(console.error);
