#!/usr/bin/env python3
"""
League of Molts Commentary Engine

Generates real-time commentary for matches using a hybrid approach:
- Template-based commentary for instant response (<50ms)
- LLM enhancement for richer narrative (async, 1-2s)
"""

import asyncio
import json
import os
from typing import Optional

import structlog
import websockets

from event_detector import EventDetector
from commentary_generator import CommentaryGenerator
from tts_engine import TTSEngine

log = structlog.get_logger()

# Configuration
MATCH_SERVER_URL = os.getenv("MATCH_SERVER_URL", "ws://localhost:9050")
BROADCAST_PORT = int(os.getenv("BROADCAST_PORT", "9060"))
ENABLE_TTS = os.getenv("ENABLE_TTS", "false").lower() == "true"
ENABLE_LLM = os.getenv("ENABLE_LLM", "false").lower() == "true"


class CommentaryEngine:
    """Main commentary engine that connects to a match and broadcasts commentary."""

    def __init__(self, match_id: str):
        self.match_id = match_id
        self.event_detector = EventDetector()
        self.commentary_gen = CommentaryGenerator(enable_llm=ENABLE_LLM)
        self.tts_engine = TTSEngine() if ENABLE_TTS else None
        self.spectators: set[websockets.WebSocketServerProtocol] = set()
        self.running = False

    async def start(self):
        """Start the commentary engine."""
        log.info("Starting commentary engine", match_id=self.match_id)
        self.running = True

        # Start broadcast server
        broadcast_server = await websockets.serve(
            self.handle_spectator,
            "0.0.0.0",
            BROADCAST_PORT,
        )
        log.info("Broadcast server started", port=BROADCAST_PORT)

        # Connect to match
        await self.connect_to_match()

        await broadcast_server.wait_closed()

    async def connect_to_match(self):
        """Connect to match server and process game state."""
        url = f"{MATCH_SERVER_URL}/spectate/{self.match_id}"
        log.info("Connecting to match", url=url)

        try:
            async with websockets.connect(url) as ws:
                # Send spectate request
                await ws.send(json.dumps({"type": "spectate"}))

                while self.running:
                    try:
                        message = await ws.recv()
                        data = json.loads(message)
                        await self.process_game_update(data)
                    except websockets.ConnectionClosed:
                        log.warning("Match connection closed")
                        break
        except Exception as e:
            log.error("Failed to connect to match", error=str(e))

    async def process_game_update(self, data: dict):
        """Process a game state update and generate commentary."""
        # Detect events
        events = self.event_detector.detect(data)

        for event in events:
            # Generate template-based commentary (fast)
            commentary = self.commentary_gen.generate_template(event)

            if commentary:
                await self.broadcast_commentary(commentary, event.event_type)

                # Optionally enhance with LLM (async, non-blocking)
                if ENABLE_LLM and event.is_major:
                    asyncio.create_task(self.enhance_commentary(event))

                # TTS if enabled
                if self.tts_engine and event.is_major:
                    asyncio.create_task(self.speak_commentary(commentary))

    async def enhance_commentary(self, event):
        """Enhance commentary with LLM (runs async)."""
        try:
            enhanced = await self.commentary_gen.enhance_with_llm(event)
            if enhanced:
                await self.broadcast_commentary(enhanced, "enhanced")
        except Exception as e:
            log.error("LLM enhancement failed", error=str(e))

    async def speak_commentary(self, text: str):
        """Speak commentary using TTS."""
        if self.tts_engine:
            await self.tts_engine.speak(text)

    async def broadcast_commentary(self, text: str, commentary_type: str = "normal"):
        """Broadcast commentary to all spectators."""
        message = json.dumps({
            "type": "commentary",
            "text": text,
            "commentaryType": commentary_type,
            "timestamp": asyncio.get_event_loop().time(),
        })

        disconnected = set()
        for ws in self.spectators:
            try:
                await ws.send(message)
            except websockets.ConnectionClosed:
                disconnected.add(ws)

        self.spectators -= disconnected

    async def handle_spectator(self, websocket: websockets.WebSocketServerProtocol):
        """Handle a new spectator connection."""
        self.spectators.add(websocket)
        log.info("Spectator connected", total=len(self.spectators))

        try:
            async for message in websocket:
                # Spectators are read-only for now
                pass
        finally:
            self.spectators.discard(websocket)
            log.info("Spectator disconnected", total=len(self.spectators))


async def main():
    import sys

    match_id = sys.argv[1] if len(sys.argv) > 1 else "test-match"

    engine = CommentaryEngine(match_id)
    await engine.start()


if __name__ == "__main__":
    asyncio.run(main())
