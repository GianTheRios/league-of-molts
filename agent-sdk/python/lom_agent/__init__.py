"""
League of Molts - Python Agent SDK

A simple SDK for building AI agents that compete in League of Molts.
"""

from .client import AgentClient, AgentConfig, BaseAgent
from .types import (
    Observation,
    SelfState,
    AllyState,
    EnemyState,
    MinionState,
    Position,
    AbilityState,
    Action,
    MoveAction,
    AttackAction,
    AbilityAction,
    BuyAction,
    StopAction,
)

__version__ = "0.1.0"
__all__ = [
    "AgentClient",
    "AgentConfig",
    "BaseAgent",
    "Observation",
    "SelfState",
    "AllyState",
    "EnemyState",
    "MinionState",
    "Position",
    "AbilityState",
    "Action",
    "MoveAction",
    "AttackAction",
    "AbilityAction",
    "BuyAction",
    "StopAction",
]
