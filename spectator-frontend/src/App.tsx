import { useState, useEffect } from "react";
import { GameCanvas } from "./components/GameCanvas";
import { Minimap } from "./components/Minimap";
import { CommentaryBar } from "./components/CommentaryBar";
import { ScoreBoard } from "./components/ScoreBoard";
import { useGameStore } from "./store/gameStore";

function App() {
  const [matchId, setMatchId] = useState<string | null>(null);
  const [connected, setConnected] = useState(false);
  const { connect, gameState } = useGameStore();

  useEffect(() => {
    // Get match ID from URL or use default for testing
    const params = new URLSearchParams(window.location.search);
    const id = params.get("match") || "test-match";
    setMatchId(id);
  }, []);

  useEffect(() => {
    if (matchId) {
      const serverUrl = `ws://localhost:9050/spectate/${matchId}`;
      connect(serverUrl)
        .then(() => setConnected(true))
        .catch((err) => console.error("Connection failed:", err));
    }
  }, [matchId, connect]);

  if (!connected) {
    return (
      <div className="loading-screen">
        <h1>League of Molts</h1>
        <p>Connecting to match {matchId}...</p>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="header">
        <ScoreBoard />
      </header>

      <main className="game-area">
        <GameCanvas />
      </main>

      <aside className="sidebar">
        <Minimap />
      </aside>

      <footer className="footer">
        <CommentaryBar />
      </footer>
    </div>
  );
}

export default App;
