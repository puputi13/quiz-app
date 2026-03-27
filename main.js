const COLS = 10;
const ROWS = 20;
const BLOCK = 30;

const canvas = document.getElementById('board');
const ctx = canvas.getContext('2d');

const scoreEl = document.getElementById('score');
const linesEl = document.getElementById('lines');
const levelEl = document.getElementById('level');
const statusEl = document.getElementById('status');

const COLORS = {
  0: '#020617',
  1: '#38bdf8',
  2: '#facc15',
  3: '#a78bfa',
  4: '#4ade80',
  5: '#fb7185',
  6: '#60a5fa',
  7: '#f97316'
};

const SHAPES = {
  I: { id: 1, cells: [[-1, 0], [0, 0], [1, 0], [2, 0]], rot: true },
  O: { id: 2, cells: [[0, 0], [1, 0], [0, 1], [1, 1]], rot: false },
  T: { id: 3, cells: [[-1, 0], [0, 0], [1, 0], [0, 1]], rot: true },
  S: { id: 4, cells: [[0, 0], [1, 0], [-1, 1], [0, 1]], rot: true },
  Z: { id: 5, cells: [[-1, 0], [0, 0], [0, 1], [1, 1]], rot: true },
  J: { id: 6, cells: [[-1, 0], [0, 0], [1, 0], [1, 1]], rot: true },
  L: { id: 7, cells: [[-1, 0], [0, 0], [1, 0], [-1, 1]], rot: true }
};

const TYPES = Object.keys(SHAPES);
const SCORE_TABLE = [0, 100, 300, 500, 800];

let board;
let piece;
let score;
let lines;
let level;
let running;
let paused;
let gameOver;
let lastTime;
let dropAcc;

function emptyBoard() {
  return Array.from({ length: ROWS }, () => Array(COLS).fill(0));
}

function randType() {
  return TYPES[(Math.random() * TYPES.length) | 0];
}

function newPiece() {
  const type = randType();
  return {
    type,
    id: SHAPES[type].id,
    x: 4,
    y: 0,
    r: 0
  };
}

function rotate([x, y], times) {
  let rx = x;
  let ry = y;
  for (let i = 0; i < times; i += 1) {
    [rx, ry] = [ry, -rx];
  }
  return [rx, ry];
}

function pieceCells(p = piece, ox = 0, oy = 0, dr = 0) {
  const def = SHAPES[p.type];
  const turns = ((p.r + dr) % 4 + 4) % 4;
  return def.cells.map(([x, y]) => {
    const [rx, ry] = def.rot ? rotate([x, y], turns) : [x, y];
    return { x: p.x + ox + rx, y: p.y + oy + ry };
  });
}

function collides(ox = 0, oy = 0, dr = 0) {
  return pieceCells(piece, ox, oy, dr).some(({ x, y }) => {
    if (x < 0 || x >= COLS || y >= ROWS) return true;
    if (y >= 0 && board[y][x] !== 0) return true;
    return false;
  });
}

function tryMove(dx, dy) {
  if (!collides(dx, dy, 0)) {
    piece.x += dx;
    piece.y += dy;
    return true;
  }
  return false;
}

function tryRotate(dir) {
  const kicks = [[0, 0], [-1, 0], [1, 0], [-2, 0], [2, 0], [0, -1]];
  for (const [kx, ky] of kicks) {
    if (!collides(kx, ky, dir)) {
      piece.x += kx;
      piece.y += ky;
      piece.r = ((piece.r + dir) % 4 + 4) % 4;
      return true;
    }
  }
  return false;
}

function lockPiece() {
  for (const { x, y } of pieceCells()) {
    if (y >= 0 && y < ROWS && x >= 0 && x < COLS) {
      board[y][x] = piece.id;
    }
  }
}

function clearLines() {
  let cleared = 0;
  board = board.filter((row) => {
    const full = row.every((v) => v !== 0);
    if (full) cleared += 1;
    return !full;
  });

  while (board.length < ROWS) {
    board.unshift(Array(COLS).fill(0));
  }

  if (cleared > 0) {
    lines += cleared;
    score += SCORE_TABLE[cleared];
    level = Math.floor(lines / 10) + 1;
  }
}

function spawnNext() {
  piece = newPiece();
  if (collides()) {
    gameOver = true;
    running = false;
    statusEl.textContent = 'Game Over - Press Enter to restart';
  }
}

function hardDrop() {
  let dist = 0;
  while (tryMove(0, 1)) {
    dist += 1;
  }
  score += dist * 2;
  settlePiece();
}

function settlePiece() {
  lockPiece();
  clearLines();
  spawnNext();
  updateHud();
}

function dropInterval() {
  const ms = 600 - (level - 1) * 40;
  return Math.max(120, ms);
}

function updateHud() {
  scoreEl.textContent = String(score);
  linesEl.textContent = String(lines);
  levelEl.textContent = String(level);
}

function drawCell(x, y, value) {
  ctx.fillStyle = COLORS[value] || '#ffffff';
  ctx.fillRect(x * BLOCK, y * BLOCK, BLOCK, BLOCK);
  ctx.strokeStyle = 'rgba(148, 163, 184, 0.24)';
  ctx.strokeRect(x * BLOCK + 0.5, y * BLOCK + 0.5, BLOCK - 1, BLOCK - 1);
}

function render() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  for (let y = 0; y < ROWS; y += 1) {
    for (let x = 0; x < COLS; x += 1) {
      drawCell(x, y, board[y][x]);
    }
  }

  for (const { x, y } of pieceCells()) {
    if (y >= 0) drawCell(x, y, piece.id);
  }
}

function startGame() {
  board = emptyBoard();
  piece = newPiece();
  score = 0;
  lines = 0;
  level = 1;
  running = true;
  paused = false;
  gameOver = false;
  dropAcc = 0;
  lastTime = performance.now();
  statusEl.textContent = 'Running';
  updateHud();
  render();
}

function tick(now) {
  const dt = now - lastTime;
  lastTime = now;

  if (running && !paused && !gameOver) {
    dropAcc += dt;

    if (dropAcc >= dropInterval()) {
      dropAcc = 0;
      if (!tryMove(0, 1)) {
        settlePiece();
      }
      updateHud();
    }
  }

  render();
  requestAnimationFrame(tick);
}

document.addEventListener('keydown', (e) => {
  const gameKeys = ['ArrowLeft', 'ArrowRight', 'ArrowDown', 'ArrowUp', 'Space'];
  if (gameKeys.includes(e.code)) {
    e.preventDefault();
  }

  if (e.code === 'Enter') {
    startGame();
    return;
  }

  if (!running || gameOver) return;

  if (e.code === 'KeyP') {
    paused = !paused;
    statusEl.textContent = paused ? 'Paused' : 'Running';
    return;
  }

  if (paused) return;

  switch (e.code) {
    case 'ArrowLeft':
      tryMove(-1, 0);
      break;
    case 'ArrowRight':
      tryMove(1, 0);
      break;
    case 'ArrowDown':
      if (tryMove(0, 1)) score += 1;
      break;
    case 'ArrowUp':
    case 'KeyX':
      tryRotate(1);
      break;
    case 'KeyZ':
      tryRotate(-1);
      break;
    case 'Space':
      hardDrop();
      break;
    default:
      return;
  }
  updateHud();
});

startGame();
statusEl.textContent = 'Running';
window.focus();
requestAnimationFrame(tick);
