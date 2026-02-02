"""
Type definitions for League of Molts Agent SDK
"""

from dataclasses import dataclass, field
from typing import Optional, List, Dict, Any, Union
from enum import Enum


class Team(Enum):
    BLUE = "blue"
    RED = "red"


class Champion(Enum):
    IRONCLAD = "Ironclad"
    VOLTAIC = "Voltaic"
    SHADEBOW = "Shadebow"


class AbilityKey(Enum):
    Q = "Q"
    W = "W"
    E = "E"
    R = "R"


@dataclass
class Position:
    x: float
    y: float

    def distance_to(self, other: "Position") -> float:
        return ((self.x - other.x) ** 2 + (self.y - other.y) ** 2) ** 0.5

    def direction_to(self, other: "Position") -> "Position":
        dist = self.distance_to(other)
        if dist == 0:
            return Position(0, 0)
        return Position((other.x - self.x) / dist, (other.y - self.y) / dist)

    def __add__(self, other: "Position") -> "Position":
        return Position(self.x + other.x, self.y + other.y)

    def __mul__(self, scalar: float) -> "Position":
        return Position(self.x * scalar, self.y * scalar)

    @classmethod
    def from_dict(cls, data: Dict[str, float]) -> "Position":
        return cls(x=data.get("x", 0), y=data.get("y", 0))


@dataclass
class AbilityState:
    name: str
    ready: bool
    cooldown_remaining: float
    mana_cost: float
    level_required: Optional[int] = None
    unlocked: bool = True

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "AbilityState":
        return cls(
            name=data.get("name", ""),
            ready=data.get("ready", False),
            cooldown_remaining=data.get("cooldown_remaining", 0),
            mana_cost=data.get("mana_cost", 0),
            level_required=data.get("level_required"),
            unlocked=data.get("unlocked", True),
        )


@dataclass
class Item:
    id: str
    name: str
    cost: int = 0
    stats: Dict[str, float] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Item":
        stats = {}
        for key in ["health", "mana", "attack_damage", "ability_power", "armor", "magic_resist", "move_speed"]:
            if key in data:
                stats[key] = data[key]
        return cls(
            id=data.get("id", ""),
            name=data.get("name", ""),
            cost=data.get("cost", 0),
            stats=stats,
        )


@dataclass
class ChampionStats:
    attack_damage: float
    ability_power: float
    armor: float
    magic_resist: float
    move_speed: float
    attack_range: float
    attack_speed: float

    @classmethod
    def from_dict(cls, data: Dict[str, float]) -> "ChampionStats":
        return cls(
            attack_damage=data.get("attack_damage", 0),
            ability_power=data.get("ability_power", 0),
            armor=data.get("armor", 0),
            magic_resist=data.get("magic_resist", 0),
            move_speed=data.get("move_speed", 0),
            attack_range=data.get("attack_range", 0),
            attack_speed=data.get("attack_speed", 0),
        )


@dataclass
class SelfState:
    id: str
    champion: str
    position: Position
    health: float
    max_health: float
    mana: float
    max_mana: float
    level: int
    xp: int
    gold: int
    is_alive: bool
    abilities: Dict[str, AbilityState]
    items: List[Item]
    stats: ChampionStats

    @property
    def health_percent(self) -> float:
        return self.health / self.max_health if self.max_health > 0 else 0

    @property
    def mana_percent(self) -> float:
        return self.mana / self.max_mana if self.max_mana > 0 else 0

    def can_use_ability(self, key: str) -> bool:
        ability = self.abilities.get(key)
        if not ability:
            return False
        return ability.ready and ability.unlocked and self.mana >= ability.mana_cost

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "SelfState":
        abilities = {}
        for key, ability_data in data.get("abilities", {}).items():
            abilities[key] = AbilityState.from_dict(ability_data)

        items = [Item.from_dict(item) for item in data.get("items", [])]

        return cls(
            id=data.get("id", ""),
            champion=data.get("champion", ""),
            position=Position.from_dict(data.get("position", {})),
            health=data.get("health", 0),
            max_health=data.get("max_health", 0),
            mana=data.get("mana", 0),
            max_mana=data.get("max_mana", 0),
            level=data.get("level", 1),
            xp=data.get("xp", 0),
            gold=data.get("gold", 0),
            is_alive=data.get("is_alive", True),
            abilities=abilities,
            items=items,
            stats=ChampionStats.from_dict(data.get("stats", {})),
        )


@dataclass
class AllyState:
    id: str
    champion: str
    position: Position
    health: float
    max_health: float
    mana: float
    max_mana: float
    level: int
    is_alive: bool

    @property
    def health_percent(self) -> float:
        return self.health / self.max_health if self.max_health > 0 else 0

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "AllyState":
        return cls(
            id=data.get("id", ""),
            champion=data.get("champion", ""),
            position=Position.from_dict(data.get("position", {})),
            health=data.get("health", 0),
            max_health=data.get("max_health", 0),
            mana=data.get("mana", 0),
            max_mana=data.get("max_mana", 0),
            level=data.get("level", 1),
            is_alive=data.get("is_alive", True),
        )


@dataclass
class EnemyState:
    id: str
    champion: str
    position: Position
    health: float
    max_health: float
    level: int
    is_alive: bool

    @property
    def health_percent(self) -> float:
        return self.health / self.max_health if self.max_health > 0 else 0

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "EnemyState":
        return cls(
            id=data.get("id", ""),
            champion=data.get("champion", ""),
            position=Position.from_dict(data.get("position", {})),
            health=data.get("health", 0),
            max_health=data.get("max_health", 0),
            level=data.get("level", 1),
            is_alive=data.get("is_alive", True),
        )


@dataclass
class MinionState:
    id: str
    position: Position
    health: float
    max_health: float
    is_melee: bool

    @property
    def health_percent(self) -> float:
        return self.health / self.max_health if self.max_health > 0 else 0

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "MinionState":
        return cls(
            id=data.get("id", ""),
            position=Position.from_dict(data.get("position", {})),
            health=data.get("health", 0),
            max_health=data.get("max_health", 0),
            is_melee=data.get("is_melee", True),
        )


@dataclass
class StructureState:
    # TODO: Full structure tracking
    blue_nexus_health: float
    red_nexus_health: float

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "StructureState":
        nexus = data.get("nexus", {})
        return cls(
            blue_nexus_health=nexus.get("blue", {}).get("health", 5000),
            red_nexus_health=nexus.get("red", {}).get("health", 5000),
        )


@dataclass
class Observation:
    tick: int
    match_time: float
    self_state: SelfState
    allies: List[AllyState]
    enemies: List[EnemyState]
    allied_minions: List[MinionState]
    enemy_minions: List[MinionState]
    structures: StructureState

    def get_nearest_enemy(self) -> Optional[EnemyState]:
        """Get the nearest visible enemy champion."""
        if not self.enemies:
            return None
        return min(
            [e for e in self.enemies if e.is_alive],
            key=lambda e: self.self_state.position.distance_to(e.position),
            default=None,
        )

    def get_nearest_enemy_minion(self) -> Optional[MinionState]:
        """Get the nearest enemy minion."""
        if not self.enemy_minions:
            return None
        return min(
            self.enemy_minions,
            key=lambda m: self.self_state.position.distance_to(m.position),
            default=None,
        )

    def get_low_health_enemy_minion(self, threshold: float = 0.3) -> Optional[MinionState]:
        """Get a low health enemy minion (for last-hitting)."""
        low_health = [m for m in self.enemy_minions if m.health_percent <= threshold]
        if not low_health:
            return None
        return min(
            low_health,
            key=lambda m: self.self_state.position.distance_to(m.position),
        )

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Observation":
        minions = data.get("minions", {})
        return cls(
            tick=data.get("tick", 0),
            match_time=data.get("match_time", 0),
            self_state=SelfState.from_dict(data.get("self", {})),
            allies=[AllyState.from_dict(a) for a in data.get("allies", [])],
            enemies=[EnemyState.from_dict(e) for e in data.get("enemies", [])],
            allied_minions=[MinionState.from_dict(m) for m in minions.get("allied", [])],
            enemy_minions=[MinionState.from_dict(m) for m in minions.get("enemy", [])],
            structures=StructureState.from_dict(data.get("structures", {})),
        )


# === ACTIONS ===

@dataclass
class MoveAction:
    target: Position

    def to_dict(self) -> Dict[str, Any]:
        return {
            "action_type": "move",
            "target": {"x": self.target.x, "y": self.target.y},
        }


@dataclass
class StopAction:
    def to_dict(self) -> Dict[str, Any]:
        return {"action_type": "stop"}


@dataclass
class AttackAction:
    target_id: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "action_type": "attack",
            "target_id": self.target_id,
        }


@dataclass
class AbilityAction:
    ability: str  # "Q", "W", "E", "R"
    target: Optional[Position] = None
    target_id: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        result = {
            "action_type": "ability",
            "ability": self.ability,
        }
        if self.target:
            result["target"] = {"x": self.target.x, "y": self.target.y}
        if self.target_id:
            result["target_id"] = self.target_id
        return result


@dataclass
class BuyAction:
    item_id: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "action_type": "buy",
            "item_id": self.item_id,
        }


Action = Union[MoveAction, StopAction, AttackAction, AbilityAction, BuyAction]
