"""
Event Detector

Analyzes game state changes to detect significant events for commentary.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, List, Dict, Any


class EventType(Enum):
    # Kill events
    CHAMPION_KILL = "champion_kill"
    FIRST_BLOOD = "first_blood"
    DOUBLE_KILL = "double_kill"
    TRIPLE_KILL = "triple_kill"
    MULTI_KILL = "multi_kill"
    SHUTDOWN = "shutdown"
    ACE = "ace"

    # Objective events
    TOWER_DESTROYED = "tower_destroyed"
    NEXUS_LOW = "nexus_low"
    NEXUS_DESTROYED = "nexus_destroyed"

    # Combat events
    CLOSE_FIGHT = "close_fight"
    TEAMFIGHT_START = "teamfight_start"
    TEAMFIGHT_END = "teamfight_end"

    # Lane events
    MINION_WAVE = "minion_wave"
    PUSH_ADVANTAGE = "push_advantage"

    # Champion events
    LEVEL_UP = "level_up"
    ULTIMATE_READY = "ultimate_ready"
    BIG_PLAY = "big_play"

    # Match events
    MATCH_START = "match_start"
    MATCH_END = "match_end"


@dataclass
class GameEvent:
    """Represents a detected game event."""
    event_type: EventType
    timestamp: float
    tick: int
    data: Dict[str, Any] = field(default_factory=dict)

    @property
    def is_major(self) -> bool:
        """Is this a major event worth LLM enhancement?"""
        major_types = {
            EventType.FIRST_BLOOD,
            EventType.DOUBLE_KILL,
            EventType.TRIPLE_KILL,
            EventType.MULTI_KILL,
            EventType.ACE,
            EventType.SHUTDOWN,
            EventType.TOWER_DESTROYED,
            EventType.NEXUS_LOW,
            EventType.NEXUS_DESTROYED,
            EventType.TEAMFIGHT_END,
            EventType.BIG_PLAY,
            EventType.MATCH_END,
        }
        return self.event_type in major_types


@dataclass
class ChampionState:
    """Tracked state for a champion."""
    id: str
    champion: str
    team: str
    health: float
    max_health: float
    level: int
    is_alive: bool
    position: Dict[str, float]
    kill_streak: int = 0
    recent_kills: List[float] = field(default_factory=list)  # timestamps


class EventDetector:
    """Detects game events by comparing state changes."""

    def __init__(self):
        self.previous_state: Optional[Dict] = None
        self.champion_states: Dict[str, ChampionState] = {}
        self.first_blood_occurred = False
        self.team_alive_count: Dict[str, int] = {"blue": 0, "red": 0}
        self.towers_destroyed: Dict[str, int] = {"blue": 0, "red": 0}
        self.match_started = False

    def detect(self, current_state: Dict) -> List[GameEvent]:
        """Detect events from the current game state."""
        events: List[GameEvent] = []
        tick = current_state.get("tick", 0)
        timestamp = current_state.get("match_time", 0.0)

        # Match start
        if not self.match_started and current_state.get("status") == "playing":
            self.match_started = True
            events.append(GameEvent(
                event_type=EventType.MATCH_START,
                timestamp=timestamp,
                tick=tick,
            ))

        # Process champions
        champions = current_state.get("champions", [])
        for champ_data in champions:
            events.extend(self._process_champion(champ_data, tick, timestamp))

        # Check for ace
        events.extend(self._check_ace(tick, timestamp))

        # Process structures
        events.extend(self._process_structures(current_state, tick, timestamp))

        # Match end
        if current_state.get("status") == "ended":
            events.append(GameEvent(
                event_type=EventType.MATCH_END,
                timestamp=timestamp,
                tick=tick,
                data={
                    "winner": current_state.get("winner"),
                    "duration": timestamp,
                },
            ))

        self.previous_state = current_state
        return events

    def _process_champion(
        self, champ_data: Dict, tick: int, timestamp: float
    ) -> List[GameEvent]:
        """Process champion state changes."""
        events = []
        champ_id = champ_data.get("id", "")

        # Get or create state
        if champ_id not in self.champion_states:
            self.champion_states[champ_id] = ChampionState(
                id=champ_id,
                champion=champ_data.get("champion", "Unknown"),
                team=champ_data.get("team", "blue"),
                health=champ_data.get("health", 0),
                max_health=champ_data.get("max_health", 600),
                level=champ_data.get("level", 1),
                is_alive=champ_data.get("is_alive", True),
                position=champ_data.get("position", {"x": 0, "y": 0}),
            )
            return events

        prev_state = self.champion_states[champ_id]
        is_alive = champ_data.get("is_alive", True)
        level = champ_data.get("level", 1)

        # Death detection
        if prev_state.is_alive and not is_alive:
            events.extend(self._on_champion_death(prev_state, tick, timestamp))

        # Respawn
        if not prev_state.is_alive and is_alive:
            prev_state.kill_streak = 0

        # Level up
        if level > prev_state.level:
            events.append(GameEvent(
                event_type=EventType.LEVEL_UP,
                timestamp=timestamp,
                tick=tick,
                data={
                    "champion_id": champ_id,
                    "champion": prev_state.champion,
                    "team": prev_state.team,
                    "new_level": level,
                },
            ))

            # Ultimate ready at 6
            if level == 6:
                events.append(GameEvent(
                    event_type=EventType.ULTIMATE_READY,
                    timestamp=timestamp,
                    tick=tick,
                    data={
                        "champion_id": champ_id,
                        "champion": prev_state.champion,
                        "team": prev_state.team,
                    },
                ))

        # Update state
        prev_state.health = champ_data.get("health", 0)
        prev_state.max_health = champ_data.get("max_health", 600)
        prev_state.level = level
        prev_state.is_alive = is_alive
        prev_state.position = champ_data.get("position", {"x": 0, "y": 0})

        return events

    def _on_champion_death(
        self, victim: ChampionState, tick: int, timestamp: float
    ) -> List[GameEvent]:
        """Handle a champion death."""
        events = []

        # Find likely killer (closest enemy champion)
        killer = self._find_likely_killer(victim)

        kill_data = {
            "victim_id": victim.id,
            "victim": victim.champion,
            "victim_team": victim.team,
            "killer_id": killer.id if killer else None,
            "killer": killer.champion if killer else "Unknown",
            "killer_team": killer.team if killer else None,
        }

        # First blood
        if not self.first_blood_occurred:
            self.first_blood_occurred = True
            events.append(GameEvent(
                event_type=EventType.FIRST_BLOOD,
                timestamp=timestamp,
                tick=tick,
                data=kill_data,
            ))
        else:
            events.append(GameEvent(
                event_type=EventType.CHAMPION_KILL,
                timestamp=timestamp,
                tick=tick,
                data=kill_data,
            ))

        # Track kill streak for killer
        if killer:
            killer.kill_streak += 1
            killer.recent_kills.append(timestamp)

            # Clean old kills (10 second window for multikill)
            killer.recent_kills = [t for t in killer.recent_kills if timestamp - t < 10]

            # Check for multikill
            recent_count = len(killer.recent_kills)
            if recent_count == 2:
                events.append(GameEvent(
                    event_type=EventType.DOUBLE_KILL,
                    timestamp=timestamp,
                    tick=tick,
                    data={"champion": killer.champion, "team": killer.team},
                ))
            elif recent_count == 3:
                events.append(GameEvent(
                    event_type=EventType.TRIPLE_KILL,
                    timestamp=timestamp,
                    tick=tick,
                    data={"champion": killer.champion, "team": killer.team},
                ))
            elif recent_count > 3:
                events.append(GameEvent(
                    event_type=EventType.MULTI_KILL,
                    timestamp=timestamp,
                    tick=tick,
                    data={"champion": killer.champion, "team": killer.team, "count": recent_count},
                ))

            # Shutdown (ended a 3+ kill streak)
            if victim.kill_streak >= 3:
                events.append(GameEvent(
                    event_type=EventType.SHUTDOWN,
                    timestamp=timestamp,
                    tick=tick,
                    data={
                        "victim": victim.champion,
                        "killer": killer.champion,
                        "streak": victim.kill_streak,
                    },
                ))

        return events

    def _find_likely_killer(self, victim: ChampionState) -> Optional[ChampionState]:
        """Find the most likely killer (closest enemy)."""
        enemy_team = "red" if victim.team == "blue" else "blue"
        closest = None
        closest_dist = float("inf")

        for champ in self.champion_states.values():
            if champ.team != enemy_team or not champ.is_alive:
                continue

            dist = (
                (champ.position["x"] - victim.position["x"]) ** 2 +
                (champ.position["y"] - victim.position["y"]) ** 2
            ) ** 0.5

            if dist < closest_dist:
                closest = champ
                closest_dist = dist

        return closest

    def _check_ace(self, tick: int, timestamp: float) -> List[GameEvent]:
        """Check if either team has been aced."""
        events = []

        for team in ["blue", "red"]:
            alive = sum(
                1 for c in self.champion_states.values()
                if c.team == team and c.is_alive
            )

            prev_alive = self.team_alive_count.get(team, 0)

            if prev_alive > 0 and alive == 0:
                enemy_team = "red" if team == "blue" else "blue"
                events.append(GameEvent(
                    event_type=EventType.ACE,
                    timestamp=timestamp,
                    tick=tick,
                    data={"aced_team": team, "by_team": enemy_team},
                ))

            self.team_alive_count[team] = alive

        return events

    def _process_structures(
        self, state: Dict, tick: int, timestamp: float
    ) -> List[GameEvent]:
        """Process structure state changes."""
        events = []

        # Check nexus health
        for team in ["blue", "red"]:
            key = f"{team}_nexus_health"
            nexus_health = state.get(key, 5000)

            if nexus_health <= 1000 and nexus_health > 0:
                events.append(GameEvent(
                    event_type=EventType.NEXUS_LOW,
                    timestamp=timestamp,
                    tick=tick,
                    data={"team": team, "health": nexus_health},
                ))

        # Tower tracking would go here (need tower data in state)

        return events
