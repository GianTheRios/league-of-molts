/**
 * Type definitions for League of Molts Agent SDK
 */

export interface Position {
  x: number;
  y: number;
}

export type Team = "blue" | "red";
export type Champion = "Ironclad" | "Voltaic" | "Shadebow";
export type AbilityKey = "Q" | "W" | "E" | "R";

export interface AbilityState {
  name: string;
  ready: boolean;
  cooldown_remaining: number;
  mana_cost: number;
  level_required?: number;
  unlocked: boolean;
}

export interface Item {
  id: string;
  name: string;
  cost?: number;
  health?: number;
  mana?: number;
  attack_damage?: number;
  ability_power?: number;
  armor?: number;
  magic_resist?: number;
  move_speed?: number;
}

export interface ChampionStats {
  attack_damage: number;
  ability_power: number;
  armor: number;
  magic_resist: number;
  move_speed: number;
  attack_range: number;
  attack_speed: number;
}

export interface SelfState {
  id: string;
  champion: Champion;
  position: Position;
  health: number;
  max_health: number;
  mana: number;
  max_mana: number;
  level: number;
  xp: number;
  gold: number;
  is_alive: boolean;
  abilities: Record<AbilityKey, AbilityState>;
  items: Item[];
  stats: ChampionStats;
}

export interface AllyState {
  id: string;
  champion: Champion;
  position: Position;
  health: number;
  max_health: number;
  mana: number;
  max_mana: number;
  level: number;
  is_alive: boolean;
}

export interface EnemyState {
  id: string;
  champion: Champion;
  position: Position;
  health: number;
  max_health: number;
  level: number;
  is_alive: boolean;
}

export interface MinionState {
  id: string;
  position: Position;
  health: number;
  max_health: number;
  is_melee: boolean;
}

export interface StructureState {
  towers: {
    blue: unknown[];
    red: unknown[];
  };
  nexus: {
    blue: { health: number };
    red: { health: number };
  };
}

export interface Observation {
  tick: number;
  match_time: number;
  self: SelfState;
  allies: AllyState[];
  enemies: EnemyState[];
  minions: {
    allied: MinionState[];
    enemy: MinionState[];
  };
  structures: StructureState;
}

// Actions

export interface MoveAction {
  action_type: "move";
  target: Position;
}

export interface StopAction {
  action_type: "stop";
}

export interface AttackAction {
  action_type: "attack";
  target_id: string;
}

export interface AbilityAction {
  action_type: "ability";
  ability: AbilityKey;
  target?: Position;
  target_id?: string;
}

export interface BuyAction {
  action_type: "buy";
  item_id: string;
}

export type Action = MoveAction | StopAction | AttackAction | AbilityAction | BuyAction;

// Messages

export interface AuthMessage {
  type: "auth";
  agent_id: string;
  token?: string;
}

export interface AuthSuccessMessage {
  type: "auth_success";
  agent_id: string;
  team: Team;
}

export interface AuthErrorMessage {
  type: "auth_error";
  message: string;
}

export interface ObservationMessage extends Observation {
  type: "observation";
}

export interface ActionMessage {
  type: "action";
  actions: Action[];
}

export interface MatchStartMessage {
  type: "match_start";
}

export interface MatchEndMessage {
  type: "match_end";
  winner: Team;
  duration: number;
}

export type ServerMessage =
  | AuthSuccessMessage
  | AuthErrorMessage
  | ObservationMessage
  | MatchStartMessage
  | MatchEndMessage;

// Utility functions

export function distanceTo(a: Position, b: Position): number {
  return Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2);
}

export function directionTo(from: Position, to: Position): Position {
  const dist = distanceTo(from, to);
  if (dist === 0) return { x: 0, y: 0 };
  return {
    x: (to.x - from.x) / dist,
    y: (to.y - from.y) / dist,
  };
}

export function addPositions(a: Position, b: Position): Position {
  return { x: a.x + b.x, y: a.y + b.y };
}

export function scalePosition(p: Position, scalar: number): Position {
  return { x: p.x * scalar, y: p.y * scalar };
}

export function healthPercent(state: { health: number; max_health: number }): number {
  return state.max_health > 0 ? state.health / state.max_health : 0;
}

export function manaPercent(state: { mana: number; max_mana: number }): number {
  return state.max_mana > 0 ? state.mana / state.max_mana : 0;
}

export function canUseAbility(self: SelfState, key: AbilityKey): boolean {
  const ability = self.abilities[key];
  return ability.ready && ability.unlocked && self.mana >= ability.mana_cost;
}
