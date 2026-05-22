import { Pause, Play, RotateCcw, SkipForward } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import result from '../../output/result.json';

function samePosition(left, right) {
  return left[0] === right[0] && left[1] === right[1];
}

function positionKey(position) {
  return `${position[0]},${position[1]}`;
}

function buildLookup(positions) {
  return new Set(positions.map(positionKey));
}

function cellLabel(position, start, goal) {
  if (samePosition(position, start)) return 'S';
  if (samePosition(position, goal)) return 'G';
  return '';
}

function Grid({ data, step }) {
  const visibleVisited = data.visited.slice(0, step);
  const visitedSet = useMemo(() => buildLookup(visibleVisited), [visibleVisited]);
  const pathSet = useMemo(() => {
    if (step < data.visited.length) return new Set();
    return buildLookup(data.path);
  }, [data.path, data.visited.length, step]);

  return (
    <div
      className="grid"
      style={{
        gridTemplateColumns: `repeat(${data.grid[0].length}, minmax(0, 1fr))`,
      }}
      aria-label="Pathfinding grid"
    >
      {data.grid.map((row, rowIndex) =>
        row.map((cell, colIndex) => {
          const position = [rowIndex, colIndex];
          const key = positionKey(position);
          const isStart = samePosition(position, data.start);
          const isGoal = samePosition(position, data.goal);
          const classes = [
            'cell',
            cell === 1 ? 'obstacle' : '',
            visitedSet.has(key) ? 'visited' : '',
            pathSet.has(key) ? 'path' : '',
            isStart ? 'start' : '',
            isGoal ? 'goal' : '',
          ]
            .filter(Boolean)
            .join(' ');

          return (
            <div className={classes} key={key}>
              {cellLabel(position, data.start, data.goal)}
            </div>
          );
        }),
      )}
    </div>
  );
}

function Controls({ running, canStep, onPlayPause, onNext, onReset }) {
  return (
    <div className="controls">
      <button
        type="button"
        onClick={onPlayPause}
        disabled={!canStep}
        title={running ? 'Pause' : 'Play'}
      >
        {running ? <Pause size={18} /> : <Play size={18} />}
      </button>
      <button
        type="button"
        onClick={onNext}
        disabled={!canStep}
        title="Next step"
      >
        <SkipForward size={18} />
      </button>
      <button type="button" onClick={onReset} title="Reset">
        <RotateCcw size={18} />
      </button>
    </div>
  );
}

const PLAYBACK_SPEEDS = [1, 2, 4, 8];

const SIZES = [
  { label: 'Tiny (5x5)', size: 5 },
  { label: 'Small (10x10)', size: 10 },
  { label: 'Medium (15x15)', size: 15 },
  { label: 'Large (25x25)', size: 25 },
];

const DENSITIES = [
  { label: 'Empty (0%)', density: 0 },
  { label: 'Sparse (20%)', density: 0.2 },
  { label: 'Moderate (30%)', density: 0.3 },
  { label: 'Dense (45%)', density: 0.45 },
  { label: 'Very Dense (60%)', density: 0.6 },
];

const PATH_MODES = [
  { label: 'Random result', mode: 'random' },
  { label: 'Require valid path', mode: 'solvable' },
  { label: 'Require no path', mode: 'blocked' },
];

const BACKENDS = [
  { label: 'Racket functional A*', backend: 'racket' },
  { label: 'C++ concurrent A*', backend: 'cpp' },
];

function GridConfigurator({ onGenerate, isLoading }) {
  const [selectedSize, setSelectedSize] = useState(5);
  const [selectedDensity, setSelectedDensity] = useState(0.3);
  const [selectedMode, setSelectedMode] = useState('solvable');
  const [selectedBackend, setSelectedBackend] = useState('racket');

  const handleGenerate = () => {
    onGenerate(selectedSize, selectedSize, selectedDensity, selectedMode, selectedBackend);
  };

  return (
    <div className="config-panel">
      <div className="config-section">
        <h3>Grid Size</h3>
        <select
          value={selectedSize}
          onChange={(event) => setSelectedSize(Number(event.target.value))}
          disabled={isLoading}
        >
          {SIZES.map((item) => (
            <option key={item.size} value={item.size}>
              {item.label}
            </option>
          ))}
        </select>
      </div>

      <div className="config-section">
        <h3>Obstacle Density</h3>
        <select
          value={selectedDensity}
          onChange={(event) => setSelectedDensity(Number(event.target.value))}
          disabled={isLoading}
        >
          {DENSITIES.map((item) => (
            <option key={item.density} value={item.density}>
              {item.label}
            </option>
          ))}
        </select>
      </div>

      <div className="config-section">
        <h3>Path Requirement</h3>
        <select
          value={selectedMode}
          onChange={(event) => setSelectedMode(event.target.value)}
          disabled={isLoading}
        >
          {PATH_MODES.map((item) => (
            <option key={item.mode} value={item.mode}>
              {item.label}
            </option>
          ))}
        </select>
      </div>

      <div className="config-section">
        <h3>Backend</h3>
        <select
          value={selectedBackend}
          onChange={(event) => setSelectedBackend(event.target.value)}
          disabled={isLoading}
        >
          {BACKENDS.map((item) => (
            <option key={item.backend} value={item.backend}>
              {item.label}
            </option>
          ))}
        </select>
      </div>

      <button
        className="generate-btn"
        onClick={handleGenerate}
        disabled={isLoading}
      >
        {isLoading ? 'Generating...' : 'Generate & Solve'}
      </button>
    </div>
  );
}

export default function App() {
  const [currentResult, setCurrentResult] = useState(result);
  const [step, setStep] = useState(1);
  const [running, setRunning] = useState(false);
  const [playbackSpeed, setPlaybackSpeed] = useState(1);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);

  const maxStep = currentResult.visited.length;
  const canStep = step < maxStep;
  const playbackDelay = Math.max(60, Math.round(450 / playbackSpeed));

  useEffect(() => {
    if (!running) return undefined;
    const timer = window.setInterval(() => {
      setStep((current) => {
        if (current >= maxStep) {
          setRunning(false);
          return current;
        }
        return current + 1;
      });
    }, playbackDelay);

    return () => window.clearInterval(timer);
  }, [maxStep, playbackDelay, running]);

  const handlePlayPause = () => {
    setRunning((current) => !current);
  };

  const handleNext = () => {
    setStep((current) => Math.min(current + 1, maxStep));
  };

  const handleReset = () => {
    setRunning(false);
    setStep(1);
  };

  const handleGenerate = async (rows, cols, density, mode, backend) => {
    setIsLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({
        rows,
        cols,
        density,
        mode,
      });
      const endpoint = backend === 'cpp' ? '/api/generate-cpp' : '/api/generate';

      const response = await fetch(`${endpoint}?${params}`);
      const data = await response.json();

      if (!response.ok || (data && data.error)) {
        throw new Error(data.error || 'Failed to generate grid');
      }

      setCurrentResult({ ...data, backend });
      setStep(1);
      setRunning(false);
    } catch (err) {
      console.error('Error:', err);
      setError('Failed to generate grid. Check server is running.');
    } finally {
      setIsLoading(false);
    }
  };

  const status = currentResult.success
    ? 'Path found'
    : currentResult.error || 'No path exists';

  return (
    <main className="app-shell">
      <section className="workspace">
        <header className="topbar">
          <div>
            <h1>Functional Pathfinding Visualizer</h1>
            <p className={currentResult.success ? 'success' : 'failure'}>{status}</p>
          </div>
          <Controls
            running={running}
            canStep={canStep}
            onPlayPause={handlePlayPause}
            onNext={handleNext}
            onReset={handleReset}
          />
        </header>

        <div className="main-layout">
          <div className="grid-container">
            <Grid data={currentResult} step={step} />

            <div className="speed-control" aria-label="Playback speed">
              {PLAYBACK_SPEEDS.map((speed) => (
                <button
                  key={speed}
                  type="button"
                  className={playbackSpeed === speed ? 'active' : ''}
                  onClick={() => setPlaybackSpeed(speed)}
                  title={`${speed}x speed`}
                >
                  {speed}x
                </button>
              ))}
            </div>

            <footer className="metrics">
              <div>
                <span>Visited</span>
                <strong>
                  {Math.min(step, currentResult.visited.length)} / {currentResult.visited.length}
                </strong>
              </div>
              <div>
                <span>Path Length</span>
                <strong>{currentResult.path.length}</strong>
              </div>
              <div>
                <span>Grid Size</span>
                <strong>
                  {currentResult.grid.length}x{currentResult.grid[0]?.length || 0}
                </strong>
              </div>
              <div>
                <span>Algorithm</span>
                <strong>
                  {currentResult.backend === 'cpp' ? 'C++ Concurrent A*' : 'Racket Functional A*'}
                </strong>
              </div>
              <div>
                <span>Speed</span>
                <strong>{playbackSpeed}x</strong>
              </div>
            </footer>
          </div>

          <GridConfigurator onGenerate={handleGenerate} isLoading={isLoading} />
        </div>

        {error && <div className="error-message">{error}</div>}
      </section>
    </main>
  );
}
