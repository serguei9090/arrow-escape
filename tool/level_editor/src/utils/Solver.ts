import { ArrowDirection, type ArrowModel, type LevelModel, OrphanDotType } from '../models/types';

export class Solver {
  static solve(level: LevelModel): number[] | null {
    const orphanMap = new Map<string, OrphanDotType>();
    if (level.orphanDots) {
      for (const dot of level.orphanDots) {
        orphanMap.set(`${dot.row},${dot.col}`, dot.type);
      }
    }

    return this.greedySolve(level.gridSize, level.arrows, orphanMap);
  }

  private static greedySolve(
    gridSize: number,
    arrows: ArrowModel[],
    orphanMap: Map<string, OrphanDotType>
  ): number[] | null {
    const active = arrows.map(() => true);
    const partnerOf = arrows.map(() => -1);

    // Build partner indices for colorLock pairs
    for (let i = 0; i < arrows.length; i++) {
      if (arrows[i].colorGroup != null && arrows[i].colorGroup !== undefined) {
        for (let j = i + 1; j < arrows.length; j++) {
          if (arrows[i].colorGroup === arrows[j].colorGroup) {
            partnerOf[i] = j;
            partnerOf[j] = i;
            break;
          }
        }
      }
    }

    const order: number[] = [];
    const orphanActive = new Map<string, boolean>();
    for (const key of orphanMap.keys()) {
      orphanActive.set(key, true);
    }

    let remaining = arrows.length;
    let madeProgress = true;

    const tryExit = (arrowIdx: number, ignoreIdx: number): Set<string> | null => {
      const arrow = arrows[arrowIdx];
      const head = arrow.path[0];
      let currentDir = arrow.direction;

      let d = this.getDelta(currentDir);
      let nr = head[0] + d[0];
      let nc = head[1] + d[1];

      const consumedOrphans = new Set<string>();
      const visitedCells = new Set<string>();

      while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
        const key = `${nr},${nc}`;
        if (visitedCells.has(key)) return null; // Loop detected
        visitedCells.add(key);

        // Check collision with remaining active arrows
        for (let o = 0; o < arrows.length; o++) {
          if (!active[o] || o === arrowIdx || o === ignoreIdx) continue;
          for (const pt of arrows[o].path) {
            if (pt[0] === nr && pt[1] === nc) return null; // Blocked!
          }
        }

        // Deflector dot handling
        if (orphanMap.has(key) && orphanActive.get(key)) {
          consumedOrphans.add(key);
          const type = orphanMap.get(key)!;
          if (type === OrphanDotType.up) currentDir = ArrowDirection.up;
          else if (type === OrphanDotType.down) currentDir = ArrowDirection.down;
          else if (type === OrphanDotType.left) currentDir = ArrowDirection.left;
          else if (type === OrphanDotType.right) currentDir = ArrowDirection.right;
        }

        d = this.getDelta(currentDir);
        nr += d[0];
        nc += d[1];
      }

      return consumedOrphans;
    };

    while (remaining > 0 && madeProgress) {
      madeProgress = false;
      const seenGroups = new Set<number>();

      // 1. Check paired colorLock arrows (must exit together)
      for (let i = 0; i < arrows.length; i++) {
        if (!active[i]) continue;
        const g = arrows[i].colorGroup;
        const p = partnerOf[i];
        if (g == null || p === -1) continue;

        if (seenGroups.has(g)) continue;
        seenGroups.add(g);
        if (!active[p]) continue;

        const c1 = tryExit(i, p);
        const c2 = tryExit(p, i);

        if (c1 != null && c2 != null) {
          c1.forEach((k) => orphanActive.set(k, false));
          c2.forEach((k) => orphanActive.set(k, false));
          active[i] = false;
          active[p] = false;
          order.push(i);
          order.push(p);
          remaining -= 2;
          madeProgress = true;
        }
      }

      // 2. Check standard single arrows
      for (let i = 0; i < arrows.length; i++) {
        if (!active[i] || partnerOf[i] !== -1) continue;
        const c = tryExit(i, -1);
        if (c != null) {
          c.forEach((k) => orphanActive.set(k, false));
          active[i] = false;
          order.push(i);
          remaining -= 1;
          madeProgress = true;
        }
      }
    }

    return remaining === 0 ? order : null;
  }

  private static getDelta(dir: ArrowDirection): [number, number] {
    switch (dir) {
      case ArrowDirection.up:    return [-1, 0];
      case ArrowDirection.down:  return [1, 0];
      case ArrowDirection.left:  return [0, -1];
      case ArrowDirection.right: return [0, 1];
    }
  }
}
