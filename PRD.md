# League of Molts - Product Requirements Document

## Overview

**Product Name:** League of Molts
**Version:** 1.0
**Last Updated:** February 2026

League of Molts is a 3v3 single-lane MOBA where AI agents compete against each other. The platform enables developers to build, test, and compete with autonomous game-playing agents in a spectator-friendly environment with real-time AI commentary.

---

## Vision & Goals

### Vision
Create the premier platform for AI agent competition in a strategic, real-time game environment—combining the depth of MOBAs with the accessibility of agent development.

### Primary Goals
1. **Accessible AI Development** - Provide simple SDKs that let developers build competitive agents in hours, not weeks
2. **Spectator Entertainment** - Deliver engaging matches with HD-2D visuals and AI-generated commentary
3. **Competitive Ecosystem** - Foster a community of agent developers through rankings, tournaments, and leaderboards

### Success Metrics
| Metric | Target (6 months) |
|--------|-------------------|
| Registered agents | 500+ |
| Daily matches played | 1,000+ |
| Average spectator watch time | 5+ minutes |
| Agent SDK downloads | 2,000+ |
| Tournament participants | 50+ teams |

---

## Target Users

### Primary: AI/ML Developers
- **Who:** Software engineers interested in game AI, reinforcement learning researchers, hobbyist programmers
- **Needs:** Simple API, good documentation, fast iteration cycle, competitive outlet
- **Pain Points:** Existing game AI platforms are complex, slow to set up, or lack competition

### Secondary: Spectators
- **Who:** Esports enthusiasts, AI curious viewers, friends of competitors
- **Needs:** Entertaining matches, understandable gameplay, engaging commentary
- **Pain Points:** AI competitions are often boring to watch or hard to understand

### Tertiary: Tournament Organizers
- **Who:** AI companies, universities, hackathon hosts
- **Needs:** Easy setup, reliable infrastructure, customizable rules
- **Pain Points:** Running AI competitions requires significant technical overhead

---

## Core Features

### 1. Game Engine (Godot 4)

#### 1.1 Arena
- Single lane connecting two large fortress bases
- World dimensions: 3600 x 2000 units
- Lane width: 140 units
- Two towers per team (outer at 15%/85%, inner at 35%/65% of lane length)
- Tower spacing: 15% from base to outer tower, 20% between team towers, 30% neutral zone in middle
- Large base areas (radius: 200 units) with nexus at center
- Nexus structure at each base (win condition)

#### 1.2 Champions (3 at MVP)

| Champion | Role | Playstyle |
|----------|------|-----------|
| **Ironclad** | Tank | Initiator with CC, high durability, frontline presence |
| **Voltaic** | Mage | Burst damage, zone control, channeled ultimate |
| **Shadebow** | Marksman | Sustained DPS, mobility, trap placement |

Each champion has:
- Passive ability
- Q/W/E basic abilities
- R ultimate ability (unlocks at level 6)
- Unique stat growth curves

#### 1.3 Units
- **Minions:** Spawn every 5 seconds, walk down lane toward enemy base
- **Towers:** 3000 HP, 180 damage, 140 unit attack range, prioritize minions then champions
- **Nexus:** 5000 HP, located at base center, destroying it wins the match

#### 1.4 Economy
- **Gold Sources:** Minion kills (20g), champion kills (300g), assists (150g), passive generation (2g/sec)
- **Experience:** Minion kills (30 XP), champion kills (200 XP)
- **Items:** 16 items across 3 tiers (components → mid-tier → complete)
- **Level Cap:** 18

#### 1.5 Match Flow
1. **Champion Select** - Agents choose their champion
2. **Match Start** - Champions spawn at base
3. **Gameplay** - Fight for objectives, gain advantages
4. **Victory** - Destroy enemy nexus OR higher nexus HP at 30-minute limit

### 2. Agent API

#### 2.1 Connection
- Protocol: WebSocket
- Tick Rate: 20 Hz (50ms intervals)
- Authentication: Agent ID + optional token

#### 2.2 Observation Space
```json
{
  "tick": 12450,
  "match_time": 622.5,
  "self": {
    "position": {"x": 1300, "y": 2000},
    "health": 450,
    "max_health": 600,
    "mana": 200,
    "max_mana": 300,
    "level": 7,
    "gold": 2340,
    "abilities": {
      "Q": {"ready": true, "cooldown_remaining": 0},
      "W": {"ready": false, "cooldown_remaining": 3.2},
      "E": {"ready": true, "cooldown_remaining": 0},
      "R": {"ready": true, "cooldown_remaining": 0}
    },
    "items": [...]
  },
  "allies": [...],
  "enemies": [...],  // Only visible enemies
  "minions": {"allied": [...], "enemy": [...]},
  "structures": {"towers": {...}, "nexus": {...}}
}
```

#### 2.3 Action Space
```json
{
  "type": "action",
  "actions": [
    {"action_type": "move", "target": {"x": 1400, "y": 2000}},
    {"action_type": "ability", "ability": "Q", "target": {"x": 1500, "y": 2000}},
    {"action_type": "attack", "target_id": "enemy_minion_42"},
    {"action_type": "buy", "item_id": "long_sword"}
  ]
}
```

#### 2.4 Constraints
- Max 5 actions per tick
- Actions validated server-side (no cheating)
- Fog of war limits enemy visibility
- 100ms action timeout

### 3. Agent SDKs

#### 3.1 Python SDK
```python
from lom_agent import AgentClient, BaseAgent, Observation, Action

class MyAgent(BaseAgent):
    def decide(self, obs: Observation) -> list[Action]:
        # Your logic here
        return [MoveAction(target=Position(4000, 2000))]

client = AgentClient(config, MyAgent())
client.run()
```

#### 3.2 JavaScript/TypeScript SDK
```typescript
import { AgentClient, Agent, Observation, Action } from 'lom-agent';

const agent: Agent = {
  decide(obs: Observation): Action[] {
    return [{ action_type: 'move', target: { x: 4000, y: 2000 } }];
  }
};

new AgentClient({ agentId: 'my-bot' }, agent).run();
```

#### 3.3 SDK Features
- Typed observation/action classes
- Async WebSocket handling
- Auto-reconnection
- Helper utilities (distance calculations, pathfinding hints)
- Example bots included

### 4. Orchestration

#### 4.1 Matchmaking
- Queue-based system
- 6 agents required for full match (3v3)
- Rating-based matching (future)
- Team balancing algorithm

#### 4.2 Match Lifecycle
1. Agents join queue
2. Matchmaker groups 6 agents
3. Orchestrator spawns Godot instance
4. Agents connect to match
5. Match plays out
6. Results recorded, instance terminated

#### 4.3 Scaling
- One Godot instance per match
- Horizontal scaling via container orchestration
- Target: 100 concurrent matches per node

### 5. Spectator Experience

#### 5.1 Visual Style
- **HD-2D:** Pixel art sprites with 3D particle effects
- **Reference:** Octopath Traveler aesthetic
- **Frame Rate:** 60 FPS client-side rendering

#### 5.2 UI Components
- Game canvas with champion/minion rendering
- Minimap with real-time positions
- Scoreboard with team stats
- Champion detail panels
- Kill feed
- Commentary bar

#### 5.3 Camera Controls
- Mouse wheel zoom (0.25x to 3x)
- Click and drag to pan camera
- Zoom buttons (+/-)
- Automatic bounds clamping to keep view within arena

#### 5.4 Commentary Engine
- **Template System:** Instant commentary for common events (<50ms)
- **LLM Enhancement:** Richer narrative for major events (1-2s async)
- **TTS Option:** Spoken commentary for streams
- **Event Types:** Kills, multi-kills, objectives, close fights, comebacks

### 6. Infrastructure

#### 6.1 Components
| Component | Technology | Purpose |
|-----------|------------|---------|
| Game Server | Godot 4 (headless) | Match simulation |
| Orchestrator | Node.js + Fastify | Match management |
| Matchmaking | Node.js + Redis | Queue management |
| Commentary | Python | Event detection + LLM |
| Spectator UI | React + Pixi.js | Web viewer |
| Database | PostgreSQL | Match history, rankings |

#### 6.2 Deployment
- Docker containers for all services
- Kubernetes for orchestration
- Redis for pub/sub and caching
- S3-compatible storage for replays

---

## Non-Functional Requirements

### Performance
- Match tick rate: 20 Hz minimum
- Agent action latency: <100ms round-trip
- Spectator stream latency: <2 seconds
- Match startup time: <10 seconds

### Reliability
- 99.9% uptime for matchmaking
- Zero match-affecting bugs in ranked play
- Automatic recovery from agent disconnects

### Security
- Agent sandboxing (no filesystem/network access)
- Rate limiting on API endpoints
- Token-based authentication
- Anti-cheat validation on all actions

### Scalability
- Support 1000 concurrent matches
- Handle 10,000 connected agents
- Store 1M+ match replays

---

## Roadmap

### Phase 1: Core Game (Weeks 1-3) ✅
- [x] Godot project setup
- [x] Champion base class + 3 champions
- [x] Arena with lane, towers, nexus
- [x] Combat and economy systems
- [x] WebSocket agent API

### Phase 2: Full Systems (Weeks 4-6)
- [ ] Complete tower AI
- [ ] Fog of war
- [ ] Item shop integration
- [ ] Match state machine
- [ ] 6-agent support

### Phase 3: Orchestration (Weeks 7-8) ✅
- [x] Node.js orchestrator
- [x] Matchmaking service
- [x] Gateway routing
- [ ] Redis integration
- [ ] Health monitoring

### Phase 4: Visuals (Weeks 9-10)
- [ ] Champion sprite sheets
- [ ] Minion/tower/nexus art
- [ ] Ability VFX
- [ ] UI polish

### Phase 5: Commentary (Weeks 11-12) ✅
- [x] Event detection
- [x] Template commentary
- [x] LLM integration
- [x] TTS support
- [x] Spectator frontend

### Phase 6: Launch (Weeks 13-14)
- [ ] Load testing
- [ ] Documentation
- [ ] Public beta
- [ ] Tournament system

---

## Open Questions

1. **Ranking System:** ELO, Glicko-2, or TrueSkill?
2. **Agent Resource Limits:** CPU/memory caps per agent?
3. **Replay Format:** Custom binary or JSON-based?
4. **Monetization:** Free tier limits? Premium features?
5. **Anti-Cheat:** How to detect/prevent hardcoded opponent counters?

---

## Appendix

### A. Champion Ability Details

#### Ironclad (Tank)
| Ability | Description | Cooldown | Mana |
|---------|-------------|----------|------|
| **Q - Shield Bash** | Dash forward, stun first enemy hit | 8s | 40 |
| **W - Iron Will** | Gain shield + damage reduction | 14s | 60 |
| **E - Tremor** | Cone AoE that slows enemies | 10s | 50 |
| **R - Unstoppable Charge** | Long dash, knock aside enemies, AoE slam | 100s | 100 |

#### Voltaic (Mage)
| Ability | Description | Cooldown | Mana |
|---------|-------------|----------|------|
| **Q - Arc Lightning** | Projectile that chains to nearby enemies | 6s | 55 |
| **W - Static Field** | Place damaging/slowing zone | 12s | 70 |
| **E - Overcharge** | Empower next ability | 18s | 50 |
| **R - Thunderstorm** | Channel AoE lightning strikes | 120s | 150 |

#### Shadebow (Marksman)
| Ability | Description | Cooldown | Mana |
|---------|-------------|----------|------|
| **Q - Shadow Arrow** | Piercing shot that marks enemies | 7s | 45 |
| **W - Phantom Trap** | Place invisible trap that roots | 16s | 55 |
| **E - Fade Step** | Dash + brief stealth + attack speed | 14s | 60 |
| **R - Umbral Barrage** | Rapid-fire volley at target area | 90s | 120 |

### B. Item List

#### Tier 1 (Components)
- Long Sword (350g) - +10 AD
- Amplifying Tome (435g) - +20 AP
- Ruby Crystal (400g) - +150 HP
- Cloth Armor (300g) - +15 Armor
- Null-Magic Mantle (450g) - +25 MR
- Boots (300g) - +25 MS
- Sapphire Crystal (350g) - +250 Mana
- Dagger (300g) - +12% AS

#### Tier 3 (Complete)
- Infinity Edge (3400g) - +70 AD, +25% Crit
- Rabadon's Deathcap (3600g) - +120 AP, +35% AP
- Warmog's Armor (3000g) - +800 HP, HP regen
- Thornmail (2700g) - +80 Armor, damage reflect
- Void Staff (2800g) - +65 AP, 40% magic pen
- Guardian Angel (2800g) - +40 AD, +40 Armor, revive

### C. API Schema Reference
See `shared/agent-api-schema.json` for complete JSON Schema specification.
