import express from 'express';
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const PORT = Number(process.env.PORT || 3001);

function racketCandidates() {
  return [
    process.env.RACKET_PATH,
    'racket',
    'racket.exe',
    'C:\\Program Files\\Racket\\Racket.exe',
    'C:\\Program Files\\Racket\\racket.exe',
    'C:\\Program Files (x86)\\Racket\\Racket.exe',
    'C:\\Program Files (x86)\\Racket\\racket.exe',
  ].filter(Boolean);
}

function resolveRacketCommand() {
  const candidates = racketCandidates();
  const fileCandidate = candidates.find((candidate) => {
    return candidate.includes('\\') || candidate.includes('/')
      ? fs.existsSync(candidate)
      : false;
  });

  return fileCandidate || candidates[0];
}

app.use(express.json());

// CORS middleware
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  next();
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Generate random grid and solve it
app.get('/api/generate', (req, res) => {
  const params = parseGenerationParams(req);
  if (params.error) {
    return res.status(400).json(params.error);
  }

  generateAndSolve(params.rows, params.cols, params.density, params.mode)
    .then((result) => res.json({ ...result, backend: 'racket' }))
    .catch((error) => {
      console.error('Generation error:', error);
      res.status(500).json({
        success: false,
        error: 'Error generating grid: ' + error.message,
      });
    });
});

app.get('/api/generate-cpp', (req, res) => {
  const params = parseGenerationParams(req);
  if (params.error) {
    return res.status(400).json(params.error);
  }

  generateAndSolveCpp(params.rows, params.cols, params.density, params.mode)
    .then((result) => res.json(result))
    .catch((error) => {
      console.error('C++ generation error:', error);
      res.status(500).json({
        success: false,
        error: 'Error generating grid with C++: ' + error.message,
      });
    });
});

function parseGenerationParams(req) {
  const rows = req.query.rows === undefined ? 10 : parseInt(req.query.rows);
  const cols = req.query.cols === undefined ? 10 : parseInt(req.query.cols);
  const density = req.query.density === undefined ? 0.3 : parseFloat(req.query.density);
  const mode = req.query.mode || 'random';

  // Validate inputs
  if (
    Number.isNaN(rows)
    || Number.isNaN(cols)
    || Number.isNaN(density)
    || rows < 5
    || rows > 50
    || cols < 5
    || cols > 50
    || density < 0
    || density > 1
    || !['random', 'solvable', 'blocked'].includes(mode)
  ) {
    return {
      error: {
        success: false,
        error: 'Invalid parameters: rows and cols must be 5-50, density 0-1, mode random/solvable/blocked',
      },
    };
  }

  return { rows, cols, density, mode };
}

// Generate grid using Racket
function generateAndSolve(rows, cols, density, mode) {
  return new Promise((resolve, reject) => {
    // Correct path: go up one level from visualizer to project root
    const projectRoot = dirname(__dirname);
    const racketScript = join(projectRoot, 'src', 'server-gen.rkt');

    console.log(`Generating grid ${rows}x${cols} with ${density} density and ${mode} mode...`);
    console.log(`Project root: ${projectRoot}`);
    console.log(`Using Racket script: ${racketScript}`);

    // Check if Racket file exists
    if (!fs.existsSync(racketScript)) {
      console.error(`Script not found at: ${racketScript}`);
      reject(new Error(`Racket script not found: ${racketScript}`));
      return;
    }

    const racketCommand = resolveRacketCommand();

    console.log(`Using Racket executable: ${racketCommand}`);

    const process = spawn(racketCommand, [racketScript, String(rows), String(cols), String(density), mode], {
      timeout: 15000,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let output = '';
    let errorOutput = '';

    process.stdout.on('data', (data) => {
      output += data.toString();
    });

    process.stderr.on('data', (data) => {
      errorOutput += data.toString();
      console.error('Racket stderr:', data.toString());
    });

    process.on('close', (code) => {
      if (code !== 0) {
        console.error(`Racket process exited with code ${code}`);
        console.error('Error output:', errorOutput);
        reject(new Error(`Racket process failed with code ${code}: ${errorOutput}`));
        return;
      }

      try {
        const result = JSON.parse(output);
        console.log('Grid generated successfully');
        resolve(result);
      } catch (error) {
        console.error('JSON parse error:', error);
        console.error('Raw output:', output);
        reject(new Error(`Invalid JSON output: ${error.message}`));
      }
    });

    process.on('error', (error) => {
      console.error('Process error:', error);
      reject(new Error(
        `Failed to start Racket. Add Racket to PATH or set RACKET_PATH to the full Racket.exe path. Details: ${error.message}`,
      ));
    });
  });
}

function runProcess(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const process = spawn(command, args, {
      timeout: options.timeout || 15000,
      stdio: ['ignore', 'pipe', 'pipe'],
      cwd: options.cwd,
    });

    let output = '';
    let errorOutput = '';

    process.stdout.on('data', (data) => {
      output += data.toString();
    });

    process.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });

    process.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`${command} failed with code ${code}: ${errorOutput}`));
        return;
      }

      resolve(output);
    });

    process.on('error', (error) => {
      reject(error);
    });
  });
}

async function ensureCppExecutable(projectRoot) {
  const sourcePath = join(projectRoot, 'cpp-concurrent', 'concurrent_astar.cpp');
  const corePath = join(projectRoot, 'cpp-concurrent', 'astar_core.cpp');
  const executablePath = join(projectRoot, 'cpp-concurrent', 'concurrent_astar.exe');

  if (!fs.existsSync(sourcePath)) {
    throw new Error(`C++ source not found: ${sourcePath}`);
  }
  if (!fs.existsSync(corePath)) {
    throw new Error(`C++ A* core not found: ${corePath}`);
  }

  const shouldCompile = !fs.existsSync(executablePath)
    || fs.statSync(sourcePath).mtimeMs > fs.statSync(executablePath).mtimeMs
    || fs.statSync(corePath).mtimeMs > fs.statSync(executablePath).mtimeMs;

  if (shouldCompile) {
    await runProcess('g++', [
      sourcePath,
      corePath,
      '-std=c++17',
      '-pthread',
      '-o',
      executablePath,
    ], { timeout: 30000 });
  }

  return executablePath;
}

async function generateAndSolveCpp(rows, cols, density, mode) {
  const projectRoot = dirname(__dirname);
  const executablePath = await ensureCppExecutable(projectRoot);
  const output = await runProcess(executablePath, [
    String(rows),
    String(cols),
    String(density),
    mode,
  ], { timeout: 15000 });

  try {
    return JSON.parse(output);
  } catch (error) {
    throw new Error(`Invalid C++ JSON output: ${error.message}`);
  }
}

const server = app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
  console.log('A* grid generation API ready...');
});

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use. Stop the existing API server or change PORT in server.mjs.`);
    process.exit(1);
  }

  console.error('Server error:', error);
  process.exit(1);
});
