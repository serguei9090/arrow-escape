import React, { useEffect, useRef } from 'react';
import { ArrowDirection, type ArrowModel, GROUP_COLORS, type LevelModel, SnakeMechanic } from '../models/types';

interface LevelCanvasProps {
  level: LevelModel;
  selectedArrowId: string | null;
  onSelectArrow: (arrowId: string | null) => void;
  onCellClick: (row: number, col: number) => void;
}

export const LevelCanvas: React.FC<LevelCanvasProps> = ({
  level,
  selectedArrowId,
  onSelectArrow,
  onCellClick,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const size = canvas.width;
    const gridSize = level.gridSize;
    const cellSize = size / gridSize;

    // Clear background
    ctx.fillStyle = '#0F172A'; // Dark Slate background
    ctx.fillRect(0, 0, size, size);

    // 1. Draw Grid Dots & Mask Active Area
    for (let r = 0; r < gridSize; r++) {
      for (let c = 0; c < gridSize; c++) {
        const x = (c + 0.5) * cellSize;
        const y = (r + 0.5) * cellSize;

        // Grid dot
        ctx.fillStyle = '#334155';
        ctx.beginPath();
        ctx.arc(x, y, cellSize * 0.08, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // 2. Draw Arrows
    for (const arrow of level.arrows) {
      const isSelected = arrow.id === selectedArrowId;
      drawArrow(ctx, arrow, cellSize, isSelected);
    }

    // 3. Draw Deflector Dots
    if (level.orphanDots) {
      for (const dot of level.orphanDots) {
        const x = (dot.col + 0.5) * cellSize;
        const y = (dot.row + 0.5) * cellSize;

        ctx.strokeStyle = '#FFD700'; // Gold
        ctx.lineWidth = cellSize * 0.1;
        ctx.beginPath();
        ctx.arc(x, y, cellSize * 0.3, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
  }, [level, selectedArrowId]);

  const handleCanvasClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const cellSize = canvas.width / level.gridSize;
    const col = Math.floor(x / cellSize);
    const row = Math.floor(y / cellSize);

    // Check if clicked an arrow
    let clickedArrow: ArrowModel | null = null;
    for (const arrow of level.arrows) {
      for (const pt of arrow.path) {
        if (pt[0] === row && pt[1] === col) {
          clickedArrow = arrow;
          break;
        }
      }
      if (clickedArrow) break;
    }

    if (clickedArrow) {
      onSelectArrow(clickedArrow.id);
    } else {
      onSelectArrow(null);
      onCellClick(row, col);
    }
  };

  return (
    <div className="relative inline-block border-4 border-slate-700 rounded-2xl overflow-hidden shadow-2xl bg-slate-900">
      <canvas
        ref={canvasRef}
        width={600}
        height={600}
        onClick={handleCanvasClick}
        className="cursor-pointer block"
      />
    </div>
  );
};

function drawArrow(
  ctx: CanvasRenderingContext2D,
  arrow: ArrowModel,
  cellSize: number,
  isSelected: boolean
) {
  if (arrow.path.length === 0) return;

  const colorHex =
    arrow.colorGroup != null ? GROUP_COLORS[arrow.colorGroup % GROUP_COLORS.length] : '#38BDF8';

  const isPaired = arrow.mechanic === SnakeMechanic.colorLock || arrow.colorGroup != null;
  const sw = cellSize * 0.22;

  // 1. Draw Body Line
  ctx.strokeStyle = colorHex;
  ctx.lineWidth = isSelected ? sw * 1.4 : sw;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';

  ctx.beginPath();
  const first = arrow.path[0];
  ctx.moveTo((first[1] + 0.5) * cellSize, (first[0] + 0.5) * cellSize);

  for (let i = 1; i < arrow.path.length; i++) {
    const pt = arrow.path[i];
    ctx.lineTo((pt[1] + 0.5) * cellSize, (pt[0] + 0.5) * cellSize);
  }
  ctx.stroke();

  // 2. Draw Diagonal Stripes overlay for Paired arrows
  if (isPaired) {
    ctx.save();
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.75)';
    ctx.lineWidth = sw * 0.35;
    ctx.lineCap = 'square';

    // Stripe across path bounds
    const headX = (first[1] + 0.5) * cellSize;
    const headY = (first[0] + 0.5) * cellSize;

    for (let offset = -cellSize * 0.4; offset <= cellSize * 0.4; offset += sw * 0.8) {
      ctx.beginPath();
      ctx.moveTo(headX + offset - 8, headY - 8);
      ctx.lineTo(headX + offset + 8, headY + 8);
      ctx.stroke();
    }
    ctx.restore();
  }

  // 3. Draw Caret Arrowhead Tip
  const tipX = (first[1] + 0.5) * cellSize;
  const tipY = (first[0] + 0.5) * cellSize;

  ctx.fillStyle = colorHex;
  ctx.beginPath();

  const hw = cellSize * 0.28;
  const hd = cellSize * 0.35;

  if (arrow.direction === ArrowDirection.up) {
    ctx.moveTo(tipX, tipY - hd);
    ctx.lineTo(tipX - hw, tipY + hd * 0.5);
    ctx.lineTo(tipX + hw, tipY + hd * 0.5);
  } else if (arrow.direction === ArrowDirection.down) {
    ctx.moveTo(tipX, tipY + hd);
    ctx.lineTo(tipX - hw, tipY - hd * 0.5);
    ctx.lineTo(tipX + hw, tipY - hd * 0.5);
  } else if (arrow.direction === ArrowDirection.left) {
    ctx.moveTo(tipX - hd, tipY);
    ctx.lineTo(tipX + hd * 0.5, tipY - hw);
    ctx.lineTo(tipX + hd * 0.5, tipY + hw);
  } else {
    // ArrowDirection.right
    ctx.moveTo(tipX + hd, tipY);
    ctx.lineTo(tipX - hd * 0.5, tipY - hw);
    ctx.lineTo(tipX - hd * 0.5, tipY + hw);
  }
  ctx.closePath();
  ctx.fill();

  // 4. Draw Tail Ring Indicator for Paired Arrows
  if (isPaired && arrow.path.length > 0) {
    const tail = arrow.path[arrow.path.length - 1];
    const tailX = (tail[1] + 0.5) * cellSize;
    const tailY = (tail[0] + 0.5) * cellSize;

    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.arc(tailX, tailY, sw * 0.8, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = colorHex;
    ctx.beginPath();
    ctx.arc(tailX, tailY, sw * 0.5, 0, Math.PI * 2);
    ctx.fill();
  }

  // 5. Selection Glow
  if (isSelected) {
    ctx.strokeStyle = '#FFD700';
    ctx.lineWidth = 3;
    ctx.strokeRect(
      (first[1] + 0.1) * cellSize,
      (first[0] + 0.1) * cellSize,
      cellSize * 0.8,
      cellSize * 0.8
    );
  }
}
