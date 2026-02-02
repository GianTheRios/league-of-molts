# League of Molts - Task Tracker

## Phase 1: Core Game Loop

### Week 1
- [x] Godot project setup with headless export config
- [x] Base champion class with movement
- [x] Basic attack system
- [x] WebSocket server foundation

### Week 2
- [x] Lane tilemap design (arena.gd)
- [x] Minion spawning system
- [ ] Minion AI (march down lane, attack enemies) - basic pathing done
- [x] Health system with damage

### Week 3
- [x] Death and respawn mechanics
- [x] Gold reward system
- [x] Test agent implementation (Python & JS SDKs)
- [ ] Integration testing

## Phase 2: Full Game Systems

### Week 4
- [x] Tower system with targeting AI (placeholder)
- [ ] Tower damage and destruction
- [x] Nexus win condition

### Week 5
- [x] Economy system (gold, XP, leveling)
- [x] Item shop with basic items (16 items)
- [x] Champion stat scaling

### Week 6
- [x] Ironclad full ability kit (Q/W/E/R)
- [x] Voltaic full ability kit
- [x] Shadebow full ability kit
- [ ] Fog of war (partial - stealth works)
- [x] 6 concurrent agent support

## Phase 3: Orchestration

### Week 7
- [x] Node.js orchestrator service
- [x] Godot instance spawning
- [x] Match lifecycle management

### Week 8
- [ ] Redis matchmaking queue (service ready, needs Redis)
- [x] Gateway proxy with auth
- [x] Multiple concurrent matches
- [ ] Health monitoring

## Phase 4: HD-2D Visuals

### Week 9
- [ ] Champion sprite sheets
- [ ] Minion sprites
- [ ] Tower/Nexus assets
- [ ] Lane tileset

### Week 10
- [ ] 3D particle effects layer
- [ ] Post-processing (bloom, DoF)
- [ ] Screen shake on abilities
- [ ] UI polish (health bars, cooldowns, kill feed)

## Phase 5: Commentary & Spectator

### Week 11
- [x] Event detection system
- [x] Template commentary engine
- [x] LLM enhancement integration

### Week 12
- [x] TTS integration
- [x] React spectator frontend
- [ ] Lobby chat with AI personas

## Phase 6: Polish & Launch

### Week 13
- [x] Python agent SDK
- [x] JavaScript agent SDK
- [x] Example bots

### Week 14
- [ ] Load testing
- [ ] Documentation
- [x] Docker/K8s deployment configs
- [ ] Launch prep

---

## Current Sprint

**Focus:** Integration Testing & Polish

### In Progress
- [ ] Full match integration test
- [ ] Tower targeting AI refinement
- [ ] Minion combat behavior

### Blocked
(none)

### Completed
- [x] Directory structure created
- [x] Task tracking setup
- [x] Godot project (project.godot, arena.gd, arena.tscn)
- [x] Game state management (game_state.gd)
- [x] Network manager with WebSocket (network_manager.gd)
- [x] Combat system (combat_system.gd)
- [x] Economy system with items (economy_system.gd)
- [x] Base champion class (base_champion.gd)
- [x] Ironclad champion (ironclad.gd)
- [x] Voltaic champion (voltaic.gd)
- [x] Shadebow champion (shadebow.gd)
- [x] Agent API schema (shared/agent-api-schema.json)
- [x] Python agent SDK (agent-sdk/python/)
- [x] JavaScript agent SDK (agent-sdk/javascript/)
- [x] Example bots for both SDKs
- [x] Node.js orchestrator (orchestrator/)
- [x] Commentary engine (commentary-engine/)
- [x] React spectator frontend (spectator-frontend/)
- [x] Docker infrastructure (infrastructure/)

---

## File Structure

```
league-of-molts/
├── godot-game/
│   ├── project.godot
│   ├── assets/icon.svg
│   └── src/
│       ├── game/
│       │   ├── arena.gd, arena.tscn
│       │   └── game_state.gd
│       ├── champions/
│       │   ├── base_champion.gd
│       │   ├── ironclad.gd
│       │   ├── voltaic.gd
│       │   └── shadebow.gd
│       ├── combat/combat_system.gd
│       ├── economy/economy_system.gd
│       └── network/network_manager.gd
├── orchestrator/
│   ├── package.json
│   └── src/
│       ├── index.ts
│       └── services/
│           ├── matchmaking.ts
│           ├── instance-manager.ts
│           └── gateway.ts
├── commentary-engine/
│   ├── requirements.txt
│   └── src/
│       ├── main.py
│       ├── event_detector.py
│       ├── commentary_generator.py
│       └── tts_engine.py
├── spectator-frontend/
│   ├── package.json
│   └── src/
│       ├── App.tsx
│       ├── store/gameStore.ts
│       └── components/
│           ├── GameCanvas.tsx
│           ├── Minimap.tsx
│           ├── CommentaryBar.tsx
│           └── ScoreBoard.tsx
├── agent-sdk/
│   ├── python/
│   │   ├── pyproject.toml
│   │   ├── lom_agent/
│   │   └── examples/simple_bot.py
│   └── javascript/
│       ├── package.json
│       ├── src/
│       └── examples/simple-bot.ts
├── shared/agent-api-schema.json
├── infrastructure/
│   ├── docker-compose.yml
│   └── Dockerfile.*
└── tasks/
    ├── todo.md
    └── lessons.md
```
