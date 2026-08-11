import { ArrowDirection, type ArrowModel, type LevelModel, SnakeMechanic } from '../models/types';
import { Solver } from './Solver';

export class MaskLevelGenerator {
  /**
   * Generates a puzzle level inside a 2D boolean grid mask (true = active shape cell).
   */
  static generateFromMask(
    levelNumber: number,
    gridSize: number,
    mask: boolean[][],
    targetArrowCount = 30,
    pairCount = 2
  ): LevelModel {
    const activeCells: [number, number][] = [];
    for (let r = 0; r < gridSize; r++) {
      for (let c = 0; c < gridSize; c++) {
        if (mask[r][c]) activeCells.push([r, c]);
      }
    }

    if (activeCells.length < 5) {
      throw new Error('Mask contains too few active cells to generate a puzzle');
    }

    const maxAttempts = 10;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      const level = this.attemptGenerate(
        levelNumber,
        gridSize,
        mask,
        activeCells,
        targetArrowCount,
        pairCount
      );
      if (level) {
        const solution = Solver.solve(level);
        if (solution) {
          level.solutionOrder = solution;
          return level;
        }
      }
    }

    // Fallback: simple guaranteed solvable layout
    return this.createFallbackLevel(levelNumber, gridSize, mask, activeCells);
  }

  private static attemptGenerate(
    levelNumber: number,
    gridSize: number,
    mask: boolean[][],
    activeCells: [number, number][],
    targetArrowCount: number,
    pairCount: number
  ): LevelModel | null {
    const occupied = new Set<string>();
    const arrows: ArrowModel[] = [];

    // Shuffle active cells
    const pool = [...activeCells].sort(() => Math.random() - 0.5);

    let colorGroupIdx = 0;
    let createdPairs = 0;

    for (const cell of pool) {
      if (arrows.length >= targetArrowCount) break;
      const [r, c] = cell;
      const key = `${r},${c}`;
      if (occupied.has(key)) continue;

      const dirs = [
        ArrowDirection.up,
        ArrowDirection.down,
        ArrowDirection.left,
        ArrowDirection.right,
      ].sort(() => Math.random() - 0.5);

      let placedDir: ArrowDirection | null = null;
      let path: [number, number][] = [];

      for (const d of dirs) {
        const p = this.growPath(r, c, d, gridSize, mask, occupied);
        if (p.length >= 2) {
          placedDir = d;
          path = p;
          break;
        }
      }

      if (placedDir && path.length >= 2) {
        for (const pt of path) {
          occupied.add(`${pt[0]},${pt[1]}`);
        }

        const isPair = createdPairs < pairCount;
        const arrow: ArrowModel = {
          id: `arrow_${arrows.length}`,
          row: r,
          col: c,
          direction: placedDir,
          path,
          mechanic: isPair ? SnakeMechanic.colorLock : SnakeMechanic.standard,
          colorGroup: isPair ? colorGroupIdx : null,
        };

        arrows.push(arrow);

        if (isPair) {
          createdPairs++;
          if (createdPairs % 2 === 0) colorGroupIdx++;
        }
      }
    }

    if (arrows.length === 0) return null;

    // Convert boolean mask to bitmask Uint8Array
    const bitmaskBytes = Math.ceil((gridSize * gridSize) / 8);
    const maskBitmask = new Uint8Array(bitmaskBytes);
    for (let r = 0; r < gridSize; r++) {
      for (let c = 0; c < gridSize; c++) {
        if (mask[r][c]) {
          const idx = r * gridSize + c;
          const byteIdx = Math.floor(idx / 8);
          const bitIdx = 7 - (idx % 8);
          maskBitmask[byteIdx] |= 1 << bitIdx;
        }
      }
    }

    return {
      levelNumber,
      gridSize,
      arrows,
      maskBitmask,
      patternName: 'Custom PNG Mask Shape',
    };
  }

  private static growPath(
    r: number,
    c: number,
    dir: ArrowDirection,
    gridSize: number,
    mask: boolean[][],
    occupied: Set<string>
  ): [number, number][] {
    const path: [number, number][] = [[r, c]];
    let dr = 0, dc = 0;
    if (dir === ArrowDirection.up) dr = -1;
    else if (dir === ArrowDirection.down) dr = 1;
    else if (dir === ArrowDirection.left) dc = -1;
    else if (dir === ArrowDirection.right) dc = 1;

    // Max length 2 to 5 cells
    const len = 2 + Math.floor(Math.random() * 4);
    let currR = r;
    let currC = c;

    for (let step = 1; step < len; step++) {
      const nr = currR + dr;
      const nc = currC + dc;
      if (nr < 0 || nr >= gridSize || nc < 0 || nc >= gridSize) break;
      if (!mask[nr][nc]) break;
      if (occupied.has(`${nr},${nc}`)) break;

      path.push([nr, nc]);
      currR = nr;
      currC = nc;
    }

    return path;
  }

  private static createFallbackLevel(
    levelNumber: number,
    gridSize: number,
    mask: boolean[][],
    activeCells: [number, number][]
  ): LevelModel {
    const arrows: ArrowModel[] = [];
    let idCounter = 0;

    for (const [r, c] of activeCells.slice(0, 10)) {
      arrows.push({
        id: `arrow_${idCounter++}`,
        row: r,
        col: c,
        direction: ArrowDirection.right,
        path: [[r, c]],
        mechanic: SnakeMechanic.standard,
        colorGroup: null,
      });
    }

    return {
      levelNumber,
      gridSize,
      arrows,
      patternName: 'Fallback Shape Level',
    };
  }
}
