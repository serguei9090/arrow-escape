// ─── Direction Enum & Helpers ──────────────────────────────────────────────────

export enum ArrowDirection {
  up = 'up',
  down = 'down',
  left = 'left',
  right = 'right',
}

export function getDirectionDelta(dir: ArrowDirection): [number, number] {
  switch (dir) {
    case ArrowDirection.up:    return [-1, 0];
    case ArrowDirection.down:  return [1, 0];
    case ArrowDirection.left:  return [0, -1];
    case ArrowDirection.right: return [0, 1];
  }
}

export function getDirectionSymbol(dir: ArrowDirection): string {
  switch (dir) {
    case ArrowDirection.up:    return '↑';
    case ArrowDirection.down:  return '↓';
    case ArrowDirection.left:  return '←';
    case ArrowDirection.right: return '→';
  }
}

export function getDirectionRotation(dir: ArrowDirection): number {
  switch (dir) {
    case ArrowDirection.right: return 0;
    case ArrowDirection.down:  return Math.PI / 2;
    case ArrowDirection.left:  return Math.PI;
    case ArrowDirection.up:    return -Math.PI / 2;
  }
}

// ─── Snake Mechanic Enum ──────────────────────────────────────────────────────

export enum SnakeMechanic {
  standard = 0,
  colorLock = 1, // Color-paired arrows with diagonal stripes
}

// ─── Arrow State ──────────────────────────────────────────────────────────────

export enum ArrowState {
  idle = 'idle',
  sliding = 'sliding',
  blocked = 'blocked',
  exited = 'exited',
  locked = 'locked',
}

// ─── Arrow Model ─────────────────────────────────────────────────────────────

export interface ArrowModel {
  id: string;
  row: number;
  col: number;
  direction: ArrowDirection;
  state?: ArrowState;
  isPartOfPattern?: boolean;
  path: [number, number][]; // [[row, col], ...]
  mechanic: SnakeMechanic;
  colorGroup?: number | null; // 0-11
}

// ─── Orphan Dot Type ──────────────────────────────────────────────────────────

export enum OrphanDotType {
  up = 'up',
  down = 'down',
  left = 'left',
  right = 'right',
}

export interface OrphanDotModel {
  row: number;
  col: number;
  type: OrphanDotType;
}

// ─── Mask Shape & Difficulty ─────────────────────────────────────────────────

export enum MaskShape {
  fullGrid = 0,
  cross = 1,
  frame = 2,
  diamond = 3,
  heart = 4,
  custom = 5,
}

export enum LevelDifficulty {
  easy = 0,
  medium = 1,
  hard = 2,
  expert = 3,
  master = 4,
}

// ─── Level Model ──────────────────────────────────────────────────────────────

export interface LevelModel {
  levelNumber: number;
  gridSize: number;
  arrows: ArrowModel[];
  solutionOrder?: number[];
  maskShape?: MaskShape;
  difficulty?: LevelDifficulty;
  patternName?: string;
  maskBitmask?: Uint8Array;
  orphanDots?: OrphanDotModel[];
}

// ─── 12 Group Palette (Matching AppColors Dart system) ──────────────────────

export const GROUP_COLORS = [
  '#FF2A4B', // 0: Pure Crimson Red
  '#2979FF', // 1: Electric Cobalt Blue
  '#00E676', // 2: Emerald Mint Green
  '#D500F9', // 3: Deep Royal Purple
  '#FF8B00', // 4: Pure Tangerine Orange
  '#00E5FF', // 5: Bright Aqua Cyan
  '#FF52A1', // 6: Hot Bubblegum Pink
  '#FFD600', // 7: Bright Sunflower Yellow
  '#AEEA00', // 8: Neon Lime Green
  '#1DE9B6', // 9: Vibrant Teal
  '#7575FF', // 10: Deep Indigo Periwinkle
  '#FF4081', // 11: Rose Magenta
];
