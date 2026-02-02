# League of Molts - Lessons Learned

## Architecture Decisions

### 2024-XX-XX: Separate Godot Instance per Match
**Decision:** Each match runs in its own Godot headless instance
**Rationale:**
- Clean isolation between matches
- Horizontal scaling - just spawn more instances
- If one match crashes, others unaffected
- Easier resource management and cleanup

### 2024-XX-XX: Node.js Orchestrator (not Godot)
**Decision:** Use Node.js for match orchestration instead of a central Godot server
**Rationale:**
- Better process management tooling (PM2, child_process)
- Redis integration is mature
- WebSocket ecosystem is robust
- Easier to deploy and scale

### 2024-XX-XX: Hybrid Commentary System
**Decision:** Templates for instant response, LLM for enhanced commentary
**Rationale:**
- Templates provide <50ms response for time-critical events
- LLM enhancement runs async (1-2s) for richer narrative
- Graceful degradation if LLM is slow/unavailable

### 2024-XX-XX: State-Based Spectating (not Video)
**Decision:** Spectator client renders game state, not streamed video
**Rationale:**
- Much lower bandwidth (~10KB/s vs MB/s)
- Scales to many spectators easily
- Client can implement their own UI/effects
- Replay functionality becomes trivial

---

## Technical Learnings

(Add entries as development progresses)

### Template
**Date:** YYYY-MM-DD
**Topic:** [Brief description]
**Problem:** What went wrong or was unclear
**Solution:** How it was resolved
**Prevention:** How to avoid in future

---

## Performance Notes

(Add benchmarks and optimization notes here)

---

## Known Limitations

(Document intentional constraints and their reasoning)
