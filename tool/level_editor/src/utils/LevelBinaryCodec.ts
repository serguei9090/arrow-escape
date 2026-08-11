import {
  ArrowDirection,
  type ArrowModel,
  LevelDifficulty,
  type LevelModel,
  MaskShape,
  type OrphanDotModel,
  OrphanDotType,
  SnakeMechanic,
} from '../models/types';

const MAGIC = [0x4c, 0x56, 0x4c, 0x42]; // 'LVLB'
const VERSION = 2;

// ─── Encoder Class ────────────────────────────────────────────────────────────

class ByteWriter {
  private buffer: number[] = [];

  writeUint8(val: number) {
    this.buffer.push(val & 0xff);
  }

  writeUint16(val: number) {
    this.buffer.push(val & 0xff);
    this.buffer.push((val >> 8) & 0xff); // Little endian
  }

  writeUint32(val: number) {
    this.buffer.push(val & 0xff);
    this.buffer.push((val >> 8) & 0xff);
    this.buffer.push((val >> 16) & 0xff);
    this.buffer.push((val >> 24) & 0xff);
  }

  writeString(str: string) {
    const bytes = new TextEncoder().encode(str);
    this.writeUint8(bytes.length);
    for (let i = 0; i < bytes.length; i++) {
      this.buffer.push(bytes[i]);
    }
  }

  writeBytes(bytes: Uint8Array | number[]) {
    for (let i = 0; i < bytes.length; i++) {
      this.buffer.push(bytes[i]);
    }
  }

  getBytes(): Uint8Array {
    return new Uint8Array(this.buffer);
  }

  get length(): number {
    return this.buffer.length;
  }
}

class ByteReader {
  private view: DataView;
  private offset = 0;

  constructor(private buffer: Uint8Array) {
    this.view = new DataView(
      buffer.buffer,
      buffer.byteOffset,
      buffer.byteLength
    );
  }

  get position(): number {
    return this.offset;
  }

  set position(pos: number) {
    this.offset = pos;
  }

  readUint8(): number {
    const val = this.view.getUint8(this.offset);
    this.offset += 1;
    return val;
  }

  readUint16(): number {
    const val = this.view.getUint16(this.offset, true); // Little endian
    this.offset += 2;
    return val;
  }

  readUint32(): number {
    const val = this.view.getUint32(this.offset, true);
    this.offset += 4;
    return val;
  }

  readString(): string {
    const len = this.readUint8();
    const bytes = this.buffer.subarray(this.offset, this.offset + len);
    this.offset += len;
    return new TextDecoder().decode(bytes);
  }

  readBytes(count: number): Uint8Array {
    const bytes = this.buffer.subarray(this.offset, this.offset + count);
    this.offset += count;
    return bytes;
  }
}

// ─── Encode Levels to Uint8Array ──────────────────────────────────────────────

export function encodeLevelsToBinary(levels: LevelModel[]): Uint8Array {
  const encodedLevels = levels.map((l) => encodeSingleLevel(l));

  const headerSize = 8;
  const indexSize = levels.length * 4;
  let dataSize = 0;
  for (const b of encodedLevels) dataSize += b.length;

  const totalSize = headerSize + indexSize + dataSize;
  const out = new ByteWriter();

  // Header
  for (const b of MAGIC) out.writeUint8(b);
  out.writeUint16(VERSION);
  out.writeUint16(levels.length);

  // Index table
  let dataOffset = 0;
  for (const encoded of encodedLevels) {
    out.writeUint32(dataOffset);
    dataOffset += encoded.length;
  }

  // Data Section
  for (const encoded of encodedLevels) {
    out.writeBytes(encoded);
  }

  return out.getBytes();
}

function encodeSingleLevel(level: LevelModel): Uint8Array {
  const buf = new ByteWriter();

  buf.writeUint16(level.levelNumber);
  buf.writeUint8(level.gridSize);
  buf.writeUint8(level.maskShape ?? MaskShape.fullGrid);
  buf.writeUint8(level.difficulty ?? LevelDifficulty.medium);
  buf.writeString(level.patternName ?? '');
  buf.writeUint16(level.arrows.length);

  for (const arrow of level.arrows) {
    buf.writeUint8(arrow.row);
    buf.writeUint8(arrow.col);

    let dirVal = 0;
    switch (arrow.direction) {
      case ArrowDirection.up:    dirVal = 0; break;
      case ArrowDirection.down:  dirVal = 1; break;
      case ArrowDirection.left:  dirVal = 2; break;
      case ArrowDirection.right: dirVal = 3; break;
    }

    const mechVal = arrow.mechanic & 0x03;
    const patVal = arrow.isPartOfPattern ? 1 : 0;
    const packed = (dirVal & 0x03) | ((mechVal & 0x03) << 2) | ((patVal & 0x01) << 4);
    buf.writeUint8(packed);

    buf.writeUint8(arrow.colorGroup ?? 0xff);

    // Path steps (steps AFTER head)
    const stepCount = Math.max(0, arrow.path.length - 1);
    buf.writeUint8(stepCount);

    for (let i = 0; i < stepCount; i++) {
      const curr = arrow.path[i];
      const next = arrow.path[i + 1];
      const dr = next[0] - curr[0];
      const dc = next[1] - curr[1];

      let stepCode = 3; // right
      if (dr === -1 && dc === 0) stepCode = 0;      // up
      else if (dr === 1 && dc === 0) stepCode = 1;  // down
      else if (dr === 0 && dc === -1) stepCode = 2; // left
      else if (dr === 0 && dc === 1) stepCode = 3;  // right
      buf.writeUint8(stepCode);
    }
  }

  const sol = level.solutionOrder ?? [];
  buf.writeUint16(sol.length);
  for (const idx of sol) buf.writeUint8(idx);

  // Bitmask
  const totalCells = level.gridSize * level.gridSize;
  const bitmaskBytes = Math.ceil(totalCells / 8);
  if (level.maskBitmask && level.maskBitmask.length === bitmaskBytes) {
    buf.writeBytes(level.maskBitmask);
  } else {
    // Fill all 1s (full grid active)
    const fill = new Uint8Array(bitmaskBytes);
    fill.fill(0xff);
    buf.writeBytes(fill);
  }

  // Orphan dots
  const dots = level.orphanDots ?? [];
  buf.writeUint16(dots.length);
  for (const d of dots) {
    buf.writeUint8(d.row);
    buf.writeUint8(d.col);
    let typeCode = 0;
    switch (d.type) {
      case OrphanDotType.up:    typeCode = 0; break;
      case OrphanDotType.down:  typeCode = 1; break;
      case OrphanDotType.left:  typeCode = 2; break;
      case OrphanDotType.right: typeCode = 3; break;
    }
    buf.writeUint8(typeCode);
  }

  return buf.getBytes();
}

// ─── Decode Binary to LevelModel[] ───────────────────────────────────────────

export function decodeBinaryToLevels(data: Uint8Array): LevelModel[] {
  const reader = new ByteReader(data);

  for (let i = 0; i < 4; i++) {
    if (reader.readUint8() !== MAGIC[i]) {
      throw new Error('Invalid magic header — not a LVLB level file');
    }
  }

  const ver = reader.readUint16();
  if (ver !== VERSION) {
    throw new Error(`Unsupported LVLB version: ${ver}`);
  }

  const levelCount = reader.readUint16();
  const offsets: number[] = [];
  for (let i = 0; i < levelCount; i++) {
    offsets.push(reader.readUint32());
  }

  const dataStart = reader.position;
  const levels: LevelModel[] = [];

  for (let i = 0; i < levelCount; i++) {
    reader.position = dataStart + offsets[i];
    levels.push(decodeSingleLevel(reader, i + 1));
  }

  return levels;
}

function decodeSingleLevel(reader: ByteReader, index: number): LevelModel {
  const levelNumber = reader.readUint16();
  const gridSize = reader.readUint8();
  const maskShape = reader.readUint8() as MaskShape;
  const difficulty = reader.readUint8() as LevelDifficulty;
  const patternName = reader.readString();
  const arrowCount = reader.readUint16();

  const arrows: ArrowModel[] = [];

  for (let i = 0; i < arrowCount; i++) {
    const headRow = reader.readUint8();
    const headCol = reader.readUint8();
    const packed = reader.readUint8();

    const dirCode = packed & 0x03;
    const mechCode = (packed >> 2) & 0x03;
    const isPartOfPattern = ((packed >> 4) & 0x01) === 1;

    let dir = ArrowDirection.up;
    if (dirCode === 0) dir = ArrowDirection.up;
    else if (dirCode === 1) dir = ArrowDirection.down;
    else if (dirCode === 2) dir = ArrowDirection.left;
    else if (dirCode === 3) dir = ArrowDirection.right;

    const rawColor = reader.readUint8();
    const colorGroup = rawColor === 0xff ? null : rawColor;
    const stepCount = reader.readUint8();

    const path: [number, number][] = [[headRow, headCol]];
    let currRow = headRow;
    let currCol = headCol;

    for (let s = 0; s < stepCount; s++) {
      const stepCode = reader.readUint8();
      if (stepCode === 0) currRow -= 1;      // up
      else if (stepCode === 1) currRow += 1; // down
      else if (stepCode === 2) currCol -= 1; // left
      else if (stepCode === 3) currCol += 1; // right
      path.push([currRow, currCol]);
    }

    arrows.push({
      id: `arrow_${index}_${i}`,
      row: headRow,
      col: headCol,
      direction: dir,
      isPartOfPattern,
      mechanic: mechCode as SnakeMechanic,
      colorGroup,
      path,
    });
  }

  const solCount = reader.readUint16();
  const solutionOrder: number[] = [];
  for (let i = 0; i < solCount; i++) {
    solutionOrder.push(reader.readUint8());
  }

  const totalCells = gridSize * gridSize;
  const bitmaskBytes = Math.ceil(totalCells / 8);
  const maskBitmask = reader.readBytes(bitmaskBytes);

  const dotCount = reader.readUint16();
  const orphanDots: OrphanDotModel[] = [];

  for (let i = 0; i < dotCount; i++) {
    const row = reader.readUint8();
    const col = reader.readUint8();
    const typeCode = reader.readUint8();
    let type = OrphanDotType.up;
    if (typeCode === 0) type = OrphanDotType.up;
    else if (typeCode === 1) type = OrphanDotType.down;
    else if (typeCode === 2) type = OrphanDotType.left;
    else if (typeCode === 3) type = OrphanDotType.right;

    orphanDots.push({ row, col, type });
  }

  return {
    levelNumber,
    gridSize,
    maskShape,
    difficulty,
    patternName,
    arrows,
    solutionOrder,
    maskBitmask,
    orphanDots,
  };
}
