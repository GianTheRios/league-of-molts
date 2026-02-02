import { useGameStore } from "../store/gameStore";
import { useEffect, useRef } from "react";

export function CommentaryBar() {
  const commentary = useGameStore((state) => state.commentary);
  const containerRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to latest comment
  useEffect(() => {
    if (containerRef.current) {
      containerRef.current.scrollTop = containerRef.current.scrollHeight;
    }
  }, [commentary]);

  return (
    <div style={styles.container} ref={containerRef}>
      <div style={styles.header}>
        <span style={styles.icon}>🎙️</span>
        <span>Live Commentary</span>
      </div>

      <div style={styles.lines}>
        {commentary.length === 0 ? (
          <div style={styles.placeholder}>Waiting for action...</div>
        ) : (
          commentary.map((line) => (
            <div
              key={line.id}
              style={{
                ...styles.line,
                ...getLineStyle(line.type),
              }}
            >
              {line.text}
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function getLineStyle(type: string): React.CSSProperties {
  switch (type) {
    case "kill":
      return { color: "#e74c3c", fontWeight: "bold" };
    case "objective":
      return { color: "#f1c40f", fontWeight: "bold" };
    case "hype":
      return { color: "#9b59b6", fontStyle: "italic" };
    default:
      return {};
  }
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    background: "linear-gradient(180deg, #1a1c24 0%, #0d0e12 100%)",
    borderTop: "1px solid #2a2c35",
    height: "120px",
    overflow: "hidden",
    display: "flex",
    flexDirection: "column",
  },
  header: {
    display: "flex",
    alignItems: "center",
    gap: "8px",
    padding: "8px 16px",
    borderBottom: "1px solid #2a2c35",
    fontSize: "14px",
    color: "#888",
    fontWeight: "500",
  },
  icon: {
    fontSize: "16px",
  },
  lines: {
    flex: 1,
    overflowY: "auto",
    padding: "8px 16px",
  },
  line: {
    padding: "4px 0",
    color: "#ccc",
    fontSize: "14px",
    lineHeight: 1.4,
    animation: "fadeIn 0.3s ease-in",
  },
  placeholder: {
    color: "#555",
    fontStyle: "italic",
    textAlign: "center",
    paddingTop: "16px",
  },
};
