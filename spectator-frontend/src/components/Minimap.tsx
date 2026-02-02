import { useGameStore } from "../store/gameStore";

const MINIMAP_WIDTH = 200;
const MINIMAP_HEIGHT = 100;
const ARENA_WIDTH = 8000;
const ARENA_HEIGHT = 4000;

export function Minimap() {
  const gameState = useGameStore((state) => state.gameState);

  const scaleX = MINIMAP_WIDTH / ARENA_WIDTH;
  const scaleY = MINIMAP_HEIGHT / ARENA_HEIGHT;

  return (
    <div className="minimap" style={styles.container}>
      <svg width={MINIMAP_WIDTH} height={MINIMAP_HEIGHT} style={styles.svg}>
        {/* Background */}
        <rect width="100%" height="100%" fill="#1a1c24" />

        {/* Lane */}
        <rect
          x={0}
          y={MINIMAP_HEIGHT / 2 - 10}
          width={MINIMAP_WIDTH}
          height={20}
          fill="#2a2c35"
        />

        {/* Bases */}
        <circle cx={12} cy={MINIMAP_HEIGHT / 2} r={10} fill="#3498db" opacity={0.5} />
        <circle
          cx={MINIMAP_WIDTH - 12}
          cy={MINIMAP_HEIGHT / 2}
          r={10}
          fill="#e74c3c"
          opacity={0.5}
        />

        {/* Towers */}
        {gameState.towers.map((tower) => (
          <rect
            key={tower.id}
            x={tower.position.x * scaleX - 4}
            y={tower.position.y * scaleY - 6}
            width={8}
            height={12}
            fill={tower.team === "blue" ? "#2980b9" : "#c0392b"}
          />
        ))}

        {/* Minions (small dots) */}
        {gameState.minions.map((minion) => (
          <circle
            key={minion.id}
            cx={minion.position.x * scaleX}
            cy={minion.position.y * scaleY}
            r={2}
            fill={minion.team === "blue" ? "#85c1e9" : "#f1948a"}
          />
        ))}

        {/* Champions */}
        {gameState.champions
          .filter((c) => c.isAlive)
          .map((champ) => (
            <g key={champ.id}>
              <circle
                cx={champ.position.x * scaleX}
                cy={champ.position.y * scaleY}
                r={6}
                fill={champ.team === "blue" ? "#5dade2" : "#ec7063"}
                stroke="white"
                strokeWidth={1}
              />
              <text
                x={champ.position.x * scaleX}
                y={champ.position.y * scaleY + 3}
                fontSize={8}
                fill="white"
                textAnchor="middle"
                fontWeight="bold"
              >
                {champ.champion[0]}
              </text>
            </g>
          ))}
      </svg>

      {/* Match time */}
      <div style={styles.time}>{formatTime(gameState.matchTime)}</div>
    </div>
  );
}

function formatTime(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs.toString().padStart(2, "0")}`;
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    background: "#0d0e12",
    borderRadius: "8px",
    padding: "8px",
    border: "1px solid #2a2c35",
  },
  svg: {
    display: "block",
    borderRadius: "4px",
  },
  time: {
    textAlign: "center",
    color: "#888",
    fontSize: "12px",
    marginTop: "4px",
    fontFamily: "monospace",
  },
};
