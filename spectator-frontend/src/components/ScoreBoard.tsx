import { useGameStore } from "../store/gameStore";

export function ScoreBoard() {
  const gameState = useGameStore((state) => state.gameState);

  const blueChampions = gameState.champions.filter((c) => c.team === "blue");
  const redChampions = gameState.champions.filter((c) => c.team === "red");

  return (
    <div style={styles.container}>
      {/* Blue Team */}
      <div style={styles.teamSection}>
        <div style={{ ...styles.teamLabel, color: "#3498db" }}>BLUE</div>
        <div style={styles.champions}>
          {blueChampions.map((champ) => (
            <ChampionPortrait key={champ.id} champion={champ} />
          ))}
        </div>
        <div style={styles.nexusHealth}>
          <div style={styles.nexusLabel}>Nexus</div>
          <HealthBar
            current={gameState.blueNexusHealth}
            max={5000}
            color="#3498db"
          />
        </div>
      </div>

      {/* Center - Match Info */}
      <div style={styles.centerSection}>
        <div style={styles.matchTime}>{formatTime(gameState.matchTime)}</div>
        <div style={styles.vs}>VS</div>
        {gameState.status === "ended" && (
          <div
            style={{
              ...styles.winner,
              color: gameState.winner === "blue" ? "#3498db" : "#e74c3c",
            }}
          >
            {gameState.winner?.toUpperCase()} WINS!
          </div>
        )}
      </div>

      {/* Red Team */}
      <div style={{ ...styles.teamSection, alignItems: "flex-end" }}>
        <div style={{ ...styles.teamLabel, color: "#e74c3c" }}>RED</div>
        <div style={styles.champions}>
          {redChampions.map((champ) => (
            <ChampionPortrait key={champ.id} champion={champ} />
          ))}
        </div>
        <div style={styles.nexusHealth}>
          <div style={styles.nexusLabel}>Nexus</div>
          <HealthBar
            current={gameState.redNexusHealth}
            max={5000}
            color="#e74c3c"
          />
        </div>
      </div>
    </div>
  );
}

interface ChampionPortraitProps {
  champion: {
    id: string;
    champion: string;
    team: "blue" | "red";
    health: number;
    maxHealth: number;
    mana: number;
    maxMana: number;
    level: number;
    isAlive: boolean;
  };
}

function ChampionPortrait({ champion }: ChampionPortraitProps) {
  const borderColor = champion.team === "blue" ? "#3498db" : "#e74c3c";
  const bgColor = champion.team === "blue" ? "#1a3a5c" : "#5c1a1a";

  return (
    <div
      style={{
        ...styles.portrait,
        borderColor,
        backgroundColor: bgColor,
        opacity: champion.isAlive ? 1 : 0.4,
      }}
    >
      <div style={styles.championInitial}>{champion.champion[0]}</div>
      <div style={styles.level}>{champion.level}</div>

      {/* Health bar */}
      <div style={styles.portraitBars}>
        <div
          style={{
            ...styles.portraitBar,
            backgroundColor: "#2ecc71",
            width: `${(champion.health / champion.maxHealth) * 100}%`,
          }}
        />
      </div>
      <div style={styles.portraitBars}>
        <div
          style={{
            ...styles.portraitBar,
            backgroundColor: "#3498db",
            width: `${(champion.mana / champion.maxMana) * 100}%`,
            height: "2px",
          }}
        />
      </div>
    </div>
  );
}

interface HealthBarProps {
  current: number;
  max: number;
  color: string;
}

function HealthBar({ current, max, color }: HealthBarProps) {
  const percent = max > 0 ? (current / max) * 100 : 0;

  return (
    <div style={styles.healthBarContainer}>
      <div
        style={{
          ...styles.healthBarFill,
          width: `${percent}%`,
          backgroundColor: color,
        }}
      />
      <span style={styles.healthText}>
        {Math.round(current)} / {max}
      </span>
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
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    background: "linear-gradient(180deg, #0d0e12 0%, #1a1c24 100%)",
    borderBottom: "1px solid #2a2c35",
    padding: "12px 24px",
    height: "80px",
  },
  teamSection: {
    display: "flex",
    flexDirection: "column",
    gap: "4px",
  },
  teamLabel: {
    fontSize: "12px",
    fontWeight: "bold",
    letterSpacing: "2px",
  },
  champions: {
    display: "flex",
    gap: "8px",
  },
  portrait: {
    width: "50px",
    height: "50px",
    borderRadius: "8px",
    border: "2px solid",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    position: "relative",
  },
  championInitial: {
    fontSize: "20px",
    fontWeight: "bold",
    color: "white",
  },
  level: {
    position: "absolute",
    bottom: "-4px",
    right: "-4px",
    background: "#1a1c24",
    borderRadius: "50%",
    width: "18px",
    height: "18px",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontSize: "10px",
    fontWeight: "bold",
    color: "#f1c40f",
    border: "1px solid #2a2c35",
  },
  portraitBars: {
    position: "absolute",
    bottom: "2px",
    left: "2px",
    right: "2px",
    height: "4px",
    backgroundColor: "#1a1a1a",
    borderRadius: "2px",
    overflow: "hidden",
  },
  portraitBar: {
    height: "100%",
    transition: "width 0.2s ease",
  },
  nexusHealth: {
    display: "flex",
    flexDirection: "column",
    gap: "2px",
  },
  nexusLabel: {
    fontSize: "10px",
    color: "#666",
  },
  healthBarContainer: {
    width: "120px",
    height: "16px",
    backgroundColor: "#1a1a1a",
    borderRadius: "4px",
    overflow: "hidden",
    position: "relative",
  },
  healthBarFill: {
    height: "100%",
    transition: "width 0.3s ease",
  },
  healthText: {
    position: "absolute",
    top: "50%",
    left: "50%",
    transform: "translate(-50%, -50%)",
    fontSize: "10px",
    color: "white",
    fontWeight: "bold",
    textShadow: "0 1px 2px rgba(0,0,0,0.8)",
  },
  centerSection: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: "4px",
  },
  matchTime: {
    fontSize: "24px",
    fontWeight: "bold",
    color: "white",
    fontFamily: "monospace",
  },
  vs: {
    fontSize: "12px",
    color: "#666",
    fontWeight: "bold",
  },
  winner: {
    fontSize: "14px",
    fontWeight: "bold",
    animation: "pulse 1s infinite",
  },
};
