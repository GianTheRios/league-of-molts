"""
Commentary Generator

Generates commentary using templates and optional LLM enhancement.
"""

import os
import random
from typing import Optional

from event_detector import GameEvent, EventType

# Template-based commentary for fast response
TEMPLATES = {
    EventType.MATCH_START: [
        "Welcome to the Rift! The match has begun!",
        "Let's get ready to rumble! Match is starting!",
        "Champions are taking their positions. The battle begins!",
    ],

    EventType.FIRST_BLOOD: [
        "{killer} draws first blood on {victim}!",
        "FIRST BLOOD! {killer} takes down {victim}!",
        "{killer} gets the first kill of the game against {victim}!",
    ],

    EventType.CHAMPION_KILL: [
        "{killer} eliminates {victim}!",
        "{victim} has been slain by {killer}.",
        "{killer} takes down {victim}!",
        "And {victim} goes down to {killer}!",
    ],

    EventType.DOUBLE_KILL: [
        "DOUBLE KILL for {champion}!",
        "{champion} picks up a double kill!",
        "Two down! {champion} is on fire!",
    ],

    EventType.TRIPLE_KILL: [
        "TRIPLE KILL! {champion} is unstoppable!",
        "{champion} with the TRIPLE KILL!",
        "Three kills for {champion}! What a play!",
    ],

    EventType.MULTI_KILL: [
        "{champion} IS ON A RAMPAGE! {count} KILLS!",
        "LEGENDARY! {champion} with {count} kills!",
        "{champion} is absolutely dominating with {count} kills!",
    ],

    EventType.SHUTDOWN: [
        "{killer} SHUTS DOWN {victim}! End of a {streak} kill streak!",
        "The rampage is over! {killer} stops {victim}!",
        "{killer} puts an end to {victim}'s killing spree!",
    ],

    EventType.ACE: [
        "ACE! {by_team} team wipes out {aced_team}!",
        "ACED! Not a single {aced_team} champion standing!",
        "Total annihilation! {by_team} aces {aced_team}!",
    ],

    EventType.TOWER_DESTROYED: [
        "{team}'s tower has been destroyed!",
        "Tower down for {team}!",
        "Another tower falls for {team}!",
    ],

    EventType.NEXUS_LOW: [
        "{team}'s nexus is critical! Only {health} HP remaining!",
        "The {team} nexus is under heavy attack!",
        "Things are looking dire for {team}!",
    ],

    EventType.NEXUS_DESTROYED: [
        "{winner} destroys the nexus! VICTORY!",
        "GG! {winner} wins the match!",
        "And that's the game! {winner} takes the victory!",
    ],

    EventType.LEVEL_UP: [
        "{champion} reaches level {new_level}.",
        "{champion} levels up to {new_level}!",
    ],

    EventType.ULTIMATE_READY: [
        "{champion}'s ultimate is now available!",
        "Watch out! {champion} has their ultimate ready!",
    ],

    EventType.MATCH_END: [
        "GG! {winner} wins in {duration:.0f} seconds!",
        "What a match! {winner} takes the victory!",
        "And it's over! {winner} claims victory!",
    ],
}


class CommentaryGenerator:
    """Generates commentary for game events."""

    def __init__(self, enable_llm: bool = False):
        self.enable_llm = enable_llm
        self.anthropic_client = None

        if enable_llm:
            try:
                import anthropic
                self.anthropic_client = anthropic.Anthropic()
            except ImportError:
                print("Warning: anthropic package not installed, LLM disabled")
                self.enable_llm = False

    def generate_template(self, event: GameEvent) -> Optional[str]:
        """Generate commentary from templates (fast path)."""
        templates = TEMPLATES.get(event.event_type)
        if not templates:
            return None

        template = random.choice(templates)

        # Format with event data
        try:
            return template.format(**event.data)
        except KeyError:
            return template

    async def enhance_with_llm(self, event: GameEvent) -> Optional[str]:
        """Enhance commentary using LLM (slow path, async)."""
        if not self.enable_llm or not self.anthropic_client:
            return None

        # Build context for LLM
        prompt = self._build_enhancement_prompt(event)

        try:
            response = self.anthropic_client.messages.create(
                model="claude-3-haiku-20240307",  # Fast model for real-time
                max_tokens=100,
                messages=[{"role": "user", "content": prompt}],
            )
            return response.content[0].text.strip()
        except Exception as e:
            print(f"LLM enhancement failed: {e}")
            return None

    def _build_enhancement_prompt(self, event: GameEvent) -> str:
        """Build prompt for LLM enhancement."""
        base = f"""You are an esports commentator for a MOBA game called League of Molts.
Generate one exciting, energetic commentary line for this event.
Keep it brief (under 20 words) and hype.

Event: {event.event_type.value}
Details: {event.data}

Commentary:"""
        return base
