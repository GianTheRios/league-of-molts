"""
WebSocket client for League of Molts Agent SDK
"""

import asyncio
import json
import logging
from dataclasses import dataclass, field
from typing import Callable, Optional, List, Awaitable
from abc import ABC, abstractmethod

try:
    import websockets
    from websockets.client import WebSocketClientProtocol
except ImportError:
    raise ImportError("Please install websockets: pip install websockets")

from .types import Observation, Action

logger = logging.getLogger(__name__)


@dataclass
class AgentConfig:
    """Configuration for the agent client."""
    agent_id: str
    server_url: str = "ws://localhost:9050"
    token: Optional[str] = None
    reconnect_attempts: int = 5
    reconnect_delay: float = 1.0


class BaseAgent(ABC):
    """
    Base class for League of Molts agents.

    Subclass this and implement the `decide` method to create your agent.
    """

    @abstractmethod
    def decide(self, observation: Observation) -> List[Action]:
        """
        Decide what actions to take given the current observation.

        Args:
            observation: Current game state from the agent's perspective

        Returns:
            List of actions to execute this tick
        """
        pass

    def on_connect(self, team: str) -> None:
        """Called when successfully connected to the match."""
        pass

    def on_disconnect(self) -> None:
        """Called when disconnected from the match."""
        pass

    def on_match_start(self) -> None:
        """Called when the match starts."""
        pass

    def on_match_end(self, winner: str, duration: float) -> None:
        """Called when the match ends."""
        pass


class AgentClient:
    """
    WebSocket client for connecting to League of Molts matches.

    Example usage:

        class MyAgent(BaseAgent):
            def decide(self, obs: Observation) -> List[Action]:
                # Simple bot: attack nearest enemy
                enemy = obs.get_nearest_enemy()
                if enemy:
                    return [AttackAction(target_id=enemy.id)]
                return []

        config = AgentConfig(agent_id="my-bot-1")
        client = AgentClient(config, MyAgent())
        asyncio.run(client.run())
    """

    def __init__(self, config: AgentConfig, agent: BaseAgent):
        self.config = config
        self.agent = agent
        self.ws: Optional[WebSocketClientProtocol] = None
        self.running = False
        self.team: Optional[str] = None
        self._reconnect_count = 0

    async def run(self) -> None:
        """Connect to the server and run the agent loop."""
        self.running = True

        while self.running and self._reconnect_count < self.config.reconnect_attempts:
            try:
                await self._connect_and_run()
            except Exception as e:
                logger.error(f"Connection error: {e}")
                self._reconnect_count += 1
                if self._reconnect_count < self.config.reconnect_attempts:
                    logger.info(f"Reconnecting in {self.config.reconnect_delay}s... ({self._reconnect_count}/{self.config.reconnect_attempts})")
                    await asyncio.sleep(self.config.reconnect_delay)

        if hasattr(self.agent, 'on_disconnect'):
            self.agent.on_disconnect()

    async def _connect_and_run(self) -> None:
        """Establish connection and run message loop."""
        logger.info(f"Connecting to {self.config.server_url}...")

        async with websockets.connect(self.config.server_url) as ws:
            self.ws = ws
            self._reconnect_count = 0

            # Authenticate
            await self._authenticate()

            # Main message loop
            await self._message_loop()

    async def _authenticate(self) -> None:
        """Send authentication message and wait for response."""
        auth_msg = {
            "type": "auth",
            "agent_id": self.config.agent_id,
        }
        if self.config.token:
            auth_msg["token"] = self.config.token

        await self._send(auth_msg)

        # Wait for auth response
        response = await self._receive()

        if response.get("type") == "auth_success":
            self.team = response.get("team")
            logger.info(f"Authenticated as {self.config.agent_id} on team {self.team}")
            self.agent.on_connect(self.team)
        elif response.get("type") == "auth_error":
            raise Exception(f"Authentication failed: {response.get('message')}")
        else:
            raise Exception(f"Unexpected auth response: {response}")

    async def _message_loop(self) -> None:
        """Process incoming messages."""
        while self.running:
            try:
                message = await self._receive()
                await self._handle_message(message)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error in message loop: {e}")
                raise

    async def _handle_message(self, message: dict) -> None:
        """Handle an incoming message."""
        msg_type = message.get("type")

        if msg_type == "observation":
            observation = Observation.from_dict(message)
            actions = self.agent.decide(observation)
            await self._send_actions(actions)

        elif msg_type == "match_start":
            self.agent.on_match_start()

        elif msg_type == "match_end":
            self.agent.on_match_end(
                winner=message.get("winner", ""),
                duration=message.get("duration", 0),
            )
            self.running = False

        elif msg_type == "pong":
            pass  # Heartbeat response

        else:
            logger.debug(f"Unknown message type: {msg_type}")

    async def _send_actions(self, actions: List[Action]) -> None:
        """Send actions to the server."""
        if not actions:
            return

        msg = {
            "type": "action",
            "actions": [a.to_dict() for a in actions],
        }
        await self._send(msg)

    async def _send(self, message: dict) -> None:
        """Send a JSON message."""
        if self.ws:
            await self.ws.send(json.dumps(message))

    async def _receive(self) -> dict:
        """Receive and parse a JSON message."""
        if not self.ws:
            raise Exception("Not connected")
        raw = await self.ws.recv()
        return json.loads(raw)

    def stop(self) -> None:
        """Stop the agent."""
        self.running = False


def run_agent(agent: BaseAgent, agent_id: str, server_url: str = "ws://localhost:9050") -> None:
    """
    Convenience function to run an agent.

    Args:
        agent: The agent instance to run
        agent_id: Unique identifier for this agent
        server_url: WebSocket URL of the game server
    """
    config = AgentConfig(agent_id=agent_id, server_url=server_url)
    client = AgentClient(config, agent)
    asyncio.run(client.run())
