#!/usr/bin/env python3
"""
Simple Example Bot for League of Molts

This bot demonstrates basic agent behavior:
- Moves toward enemy side of map
- Last-hits minions when possible
- Uses abilities on nearby enemies
- Falls back when low health
"""

import logging
from typing import List

from lom_agent import (
    AgentClient,
    AgentConfig,
    BaseAgent,
    Observation,
    Action,
    MoveAction,
    AttackAction,
    AbilityAction,
    Position,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SimpleBot(BaseAgent):
    """A simple bot that pushes lane and fights enemies."""

    def __init__(self):
        self.team = None
        # Lane positions
        self.blue_base = Position(800, 2000)
        self.red_base = Position(7200, 2000)
        self.lane_center = Position(4000, 2000)

    def on_connect(self, team: str) -> None:
        self.team = team
        logger.info(f"Connected on team {team}")

    def decide(self, obs: Observation) -> List[Action]:
        actions = []
        me = obs.self_state

        # Don't act if dead
        if not me.is_alive:
            return []

        # Determine push direction
        if self.team == "blue":
            push_target = self.red_base
            retreat_target = self.blue_base
        else:
            push_target = self.blue_base
            retreat_target = self.red_base

        # Check if we should retreat (low health)
        if me.health_percent < 0.25:
            logger.info("Low health, retreating!")
            return [MoveAction(target=retreat_target)]

        # Try to last-hit minions
        low_hp_minion = obs.get_low_health_enemy_minion(threshold=0.25)
        if low_hp_minion:
            dist = me.position.distance_to(low_hp_minion.position)
            if dist <= me.stats.attack_range:
                return [AttackAction(target_id=low_hp_minion.id)]
            else:
                # Move toward it
                return [MoveAction(target=low_hp_minion.position)]

        # Look for enemy champions
        nearest_enemy = obs.get_nearest_enemy()
        if nearest_enemy and nearest_enemy.is_alive:
            enemy_dist = me.position.distance_to(nearest_enemy.position)

            # Use abilities if in range
            if enemy_dist < 600:
                # Try to use Q
                if me.can_use_ability("Q"):
                    actions.append(AbilityAction(
                        ability="Q",
                        target=nearest_enemy.position,
                        target_id=nearest_enemy.id,
                    ))

                # If enemy is close and we have E (usually mobility/defensive)
                if enemy_dist < 200 and me.can_use_ability("E"):
                    # Use E defensively (move away)
                    escape_dir = nearest_enemy.position.direction_to(me.position)
                    escape_pos = me.position + escape_dir * 300
                    actions.append(AbilityAction(ability="E", target=escape_pos))

                # Use R if enemy is low
                if nearest_enemy.health_percent < 0.4 and me.can_use_ability("R"):
                    actions.append(AbilityAction(
                        ability="R",
                        target=nearest_enemy.position,
                    ))

            # Auto attack if in range
            if enemy_dist <= me.stats.attack_range:
                actions.append(AttackAction(target_id=nearest_enemy.id))
            elif enemy_dist < 800:
                # Move toward enemy to fight
                actions.append(MoveAction(target=nearest_enemy.position))

            if actions:
                return actions

        # Attack nearest enemy minion if no champions around
        nearest_minion = obs.get_nearest_enemy_minion()
        if nearest_minion:
            dist = me.position.distance_to(nearest_minion.position)
            if dist <= me.stats.attack_range:
                return [AttackAction(target_id=nearest_minion.id)]
            elif dist < 600:
                return [MoveAction(target=nearest_minion.position)]

        # Default: push toward enemy base
        return [MoveAction(target=push_target)]

    def on_match_start(self) -> None:
        logger.info("Match started!")

    def on_match_end(self, winner: str, duration: float) -> None:
        result = "WON" if winner == self.team else "LOST"
        logger.info(f"Match ended! We {result}. Duration: {duration:.1f}s")


def main():
    import sys

    agent_id = sys.argv[1] if len(sys.argv) > 1 else "simple-bot-1"
    server_url = sys.argv[2] if len(sys.argv) > 2 else "ws://localhost:9050"

    config = AgentConfig(
        agent_id=agent_id,
        server_url=server_url,
    )

    agent = SimpleBot()
    client = AgentClient(config, agent)

    logger.info(f"Starting {agent_id} connecting to {server_url}")

    import asyncio
    asyncio.run(client.run())


if __name__ == "__main__":
    main()
