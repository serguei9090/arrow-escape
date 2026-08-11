import React, { useState } from 'react';
import {
  ArrowDirection,
  type ArrowModel,
  type LevelModel,
  SnakeMechanic,
} from './models/types';
import { decodeBinaryToLevels, encodeLevelsToBinary } from './utils/LevelBinaryCodec';
import { MaskLevelGenerator } from './utils/MaskLevelGenerator';
import { Solver } from './utils/Solver';
import { LevelCanvas } from './components/LevelCanvas';

export function App() {
  const [levels, setLevels] = useState<LevelModel[]>([]);
  const [activeLevelIdx, setActiveLevelIdx] = useState<number>(0);
  const [selectedArrowId, setSelectedArrowId] = useState<string | null>(null);
  const [validationStatus, setValidationStatus] = useState<string | null>(null);

  // Mask generator options
  const [maskGridSize, setMaskGridSize] = useState<number>(20);
  const [targetArrowCount, setTargetArrowCount] = useState<number>(25);
  const [pairCount, setPairCount] = useState<number>(2);

  const activeLevel = levels[activeLevelIdx] || null;

  // Load levels.bin file
  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      try {
        const buffer = new Uint8Array(evt.target?.result as ArrayBuffer);
        const parsed = decodeBinaryToLevels(buffer);
        setLevels(parsed);
        setActiveLevelIdx(0);
        setSelectedArrowId(null);
        setValidationStatus(`Loaded ${parsed.length} levels from levels.bin`);
      } catch (err: any) {
        alert(`Failed to parse binary level file: ${err.message}`);
      }
    };
    reader.readAsArrayBuffer(file);
  };

  // Export levels.bin file
  const handleExportBinary = () => {
    if (levels.length === 0) return;
    try {
      const binaryData = encodeLevelsToBinary(levels);
      const blob = new Blob([binaryData.buffer as ArrayBuffer], { type: 'application/octet-stream' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'levels.bin';
      a.click();
      URL.revokeObjectURL(url);
    } catch (err: any) {
      alert(`Export failed: ${err.message}`);
    }
  };

  // Upload PNG Mask Image and generate shape level
  const handlePNGMaskUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = maskGridSize;
      canvas.height = maskGridSize;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      ctx.drawImage(img, 0, 0, maskGridSize, maskGridSize);
      const imgData = ctx.getImageData(0, 0, maskGridSize, maskGridSize);
      const mask: boolean[][] = [];

      for (let r = 0; r < maskGridSize; r++) {
        mask[r] = [];
        for (let c = 0; c < maskGridSize; c++) {
          const idx = (r * maskGridSize + c) * 4;
          const rVal = imgData.data[idx];
          const gVal = imgData.data[idx + 1];
          const bVal = imgData.data[idx + 2];
          const alpha = imgData.data[idx + 3];

          // Black pixel threshold (active shape cell)
          const isBlack = alpha > 128 && (rVal + gVal + bVal) / 3 < 128;
          mask[r][c] = isBlack;
        }
      }

      try {
        const newLevel = MaskLevelGenerator.generateFromMask(
          levels.length + 1,
          maskGridSize,
          mask,
          targetArrowCount,
          pairCount
        );
        setLevels([...levels, newLevel]);
        setActiveLevelIdx(levels.length);
        setValidationStatus(`Generated level #${newLevel.levelNumber} from PNG mask!`);
      } catch (err: any) {
        alert(`Generation failed: ${err.message}`);
      }
    };

    img.src = URL.createObjectURL(file);
  };

  // Validate active level
  const handleValidateLevel = () => {
    if (!activeLevel) return;
    const solution = Solver.solve(activeLevel);
    if (solution) {
      setValidationStatus(`SOLVABLE! ✅ Clean solution sequence: [${solution.join(', ')}]`);
    } else {
      setValidationStatus(`DEADLOCK DETECTED! ❌ This level setup cannot be solved.`);
    }
  };

  // Add new arrow to active level
  const handleAddArrow = () => {
    if (!activeLevel) return;
    const newArrow: ArrowModel = {
      id: `arrow_${Date.now()}`,
      row: 0,
      col: 0,
      direction: ArrowDirection.right,
      path: [
        [0, 0],
        [0, 1],
      ],
      mechanic: SnakeMechanic.standard,
      colorGroup: null,
    };

    const updated = {
      ...activeLevel,
      arrows: [...activeLevel.arrows, newArrow],
    };
    updateActiveLevel(updated);
    setSelectedArrowId(newArrow.id);
  };

  // Toggle paired colorLock mechanic on selected arrow
  const handleTogglePaired = () => {
    if (!activeLevel || !selectedArrowId) return;
    const updatedArrows = activeLevel.arrows.map((a: ArrowModel) => {
      if (a.id === selectedArrowId) {
        const isCurrentlyPaired = a.mechanic === SnakeMechanic.colorLock;
        return {
          ...a,
          mechanic: isCurrentlyPaired ? SnakeMechanic.standard : SnakeMechanic.colorLock,
          colorGroup: isCurrentlyPaired ? null : 0,
        };
      }
      return a;
    });

    updateActiveLevel({ ...activeLevel, arrows: updatedArrows });
  };

  const updateActiveLevel = (level: LevelModel) => {
    const next = [...levels];
    next[activeLevelIdx] = level;
    setLevels(next);
  };

  return (
    <div className="flex h-screen bg-slate-950 text-slate-100 font-sans overflow-hidden">
      {/* ── SIDEBAR ────────────────────────────────────────────────────────── */}
      <div className="w-96 bg-slate-900 border-r border-slate-800 p-6 flex flex-col gap-6 overflow-y-auto">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-sky-400">
            Vector Escape Level Editor
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Standalone binary level editor & PNG mask generator
          </p>
        </div>

        {/* Binary File I/O */}
        <div className="flex flex-col gap-3 bg-slate-800/60 p-4 rounded-xl border border-slate-700">
          <h2 className="text-sm font-bold text-slate-200">1. Binary File (levels.bin)</h2>
          <label className="bg-sky-600 hover:bg-sky-500 text-white font-bold py-2 px-4 rounded-lg cursor-pointer text-center text-sm transition">
            📁 Load levels.bin
            <input type="file" accept=".bin" onChange={handleFileUpload} className="hidden" />
          </label>

          <button
            onClick={handleExportBinary}
            disabled={levels.length === 0}
            className="bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-bold py-2 px-4 rounded-lg text-sm transition"
          >
            💾 Save & Export levels.bin
          </button>
        </div>

        {/* PNG Mask Importer */}
        <div className="flex flex-col gap-3 bg-slate-800/60 p-4 rounded-xl border border-slate-700">
          <h2 className="text-sm font-bold text-slate-200">2. PNG Shape Mask Generator</h2>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <div>
              <label className="text-slate-400">Grid Size</label>
              <input
                type="number"
                value={maskGridSize}
                onChange={(e) => setMaskGridSize(Number(e.target.value))}
                className="w-full bg-slate-900 border border-slate-700 rounded p-1 text-white font-mono mt-1"
              />
            </div>
            <div>
              <label className="text-slate-400">Arrow Count</label>
              <input
                type="number"
                value={targetArrowCount}
                onChange={(e) => setTargetArrowCount(Number(e.target.value))}
                className="w-full bg-slate-900 border border-slate-700 rounded p-1 text-white font-mono mt-1"
              />
            </div>
          </div>

          <label className="bg-purple-600 hover:bg-purple-500 text-white font-bold py-2 px-4 rounded-lg cursor-pointer text-center text-sm transition">
            🖼️ Upload PNG Mask & Generate
            <input type="file" accept="image/png" onChange={handlePNGMaskUpload} className="hidden" />
          </label>
        </div>

        {/* Level List */}
        <div className="flex-1 flex flex-col gap-2 overflow-hidden">
          <h2 className="text-sm font-bold text-slate-200">
            Level List ({levels.length} levels)
          </h2>
          <div className="flex-1 overflow-y-auto flex flex-col gap-1 pr-1">
            {levels.map((l, idx) => (
              <button
                key={idx}
                onClick={() => {
                  setActiveLevelIdx(idx);
                  setSelectedArrowId(null);
                }}
                className={`text-left text-xs font-semibold p-2.5 rounded-lg border transition ${
                  idx === activeLevelIdx
                    ? 'bg-sky-500/20 border-sky-400 text-sky-300'
                    : 'bg-slate-800/40 border-slate-800 hover:bg-slate-800 text-slate-300'
                }`}
              >
                Level #{l.levelNumber} ({l.gridSize}x{l.gridSize}) - {l.arrows.length} arrows
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* ── MAIN BOARD CANVAS ──────────────────────────────────────────────── */}
      <div className="flex-1 flex flex-col p-8 bg-slate-950 overflow-y-auto">
        {activeLevel ? (
          <div className="flex flex-col gap-6 items-center">
            {/* Header info bar */}
            <div className="flex justify-between items-center w-full max-w-2xl bg-slate-900 p-4 rounded-2xl border border-slate-800">
              <div>
                <h2 className="text-xl font-bold text-white">
                  Level #{activeLevel.levelNumber}
                </h2>
                <p className="text-xs text-slate-400">
                  Grid Size: {activeLevel.gridSize}x{activeLevel.gridSize} | Arrows:{' '}
                  {activeLevel.arrows.length}
                </p>
              </div>

              <div className="flex gap-2">
                <button
                  onClick={handleAddArrow}
                  className="bg-sky-600 hover:bg-sky-500 text-white font-bold py-1.5 px-3 rounded-lg text-xs"
                >
                  + Add Arrow
                </button>

                <button
                  onClick={handleValidateLevel}
                  className="bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-1.5 px-3 rounded-lg text-xs"
                >
                  ⚡ Validate Solvability
                </button>
              </div>
            </div>

            {/* Validation Banner */}
            {validationStatus && (
              <div className="w-full max-w-2xl bg-slate-800 p-3 rounded-xl border border-slate-700 text-xs font-bold text-center">
                {validationStatus}
              </div>
            )}

            {/* Canvas */}
            <LevelCanvas
              level={activeLevel}
              selectedArrowId={selectedArrowId}
              onSelectArrow={setSelectedArrowId}
              onCellClick={(r, c) => console.log('Cell clicked:', r, c)}
            />

            {/* Selected Arrow Inspector Controls */}
            {selectedArrowId && (
              <div className="w-full max-w-2xl bg-slate-900 p-4 rounded-2xl border border-slate-800 flex flex-col gap-3">
                <h3 className="text-sm font-bold text-sky-400">
                  Selected Arrow Inspector ({selectedArrowId})
                </h3>
                <div className="flex items-center gap-4 text-xs">
                  <button
                    onClick={handleTogglePaired}
                    className="bg-purple-600 hover:bg-purple-500 text-white font-bold py-1.5 px-3 rounded-lg"
                  >
                    Toggle Striped Color-Pair
                  </button>

                  <span className="text-slate-400">
                    Mechanic:{' '}
                    <strong className="text-white">
                      {activeLevel.arrows.find((a: ArrowModel) => a.id === selectedArrowId)?.mechanic ===
                      SnakeMechanic.colorLock
                        ? 'Striped Color Lock'
                        : 'Standard'}
                    </strong>
                  </span>
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-slate-500">
            <p className="text-lg font-bold">No binary level file loaded</p>
            <p className="text-xs mt-1">Load assets/levels.bin or generate a level from a PNG mask</p>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;
