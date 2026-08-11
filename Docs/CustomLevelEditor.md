# Architectural Specification: Flutter Web Level Editor & Generator

## Executive Summary & Product Vision
The goal of this project is to develop a comprehensive, web-based Level Editor and Generator tool for the puzzle game **Arrow Escape (Vector Escape)**. 

### Target Platform & Technology Stack
- **Framework**: Flutter for Web (Dart).
- **Location**: `lib/main_editor.dart` & `lib/editor/`.
- **Key Advantage**: 100% logic parity with the game client. All data models (`LevelModel`, `ArrowModel`), binary codecs (`LevelBinaryCodec`), level generators (`LevelGeneratorV2`, `MaskGeneratorV2`), and solver validation (`Solver`) are natively reused without duplicated logic or interop layers.

---

## Core Objectives
1. **Binary Parity**: Seamless loading, parsing, editing, and saving of binary `.bin` level files (`levels.bin`).
2. **Visual Level Gallery**: Grid-based gallery displaying level thumbnails, dimensions, arrow counts, difficulty, mask shape, and solvability status.
3. **Interactive Level Editor**: Visual grid canvas for adding, moving, rotating arrows, configuring colors, mechanics, and editing snake/path steps.
4. **PNG Mask Importer**: Convert black/colored PNG pixel masks directly into game grid cells and generate solvable level layouts.
5. **Interactive Real-Time Solver**: Step-by-step solver validation directly within the browser, showing clear paths and execution sequences.
6. **Bulk Generator Pipeline**: Mass level generation (e.g. 500 levels) combining custom PNG masks and procedural fallback generators with live progress tracking and binary compilation download.

---

## Architecture & Code Re-use Map

```
lib/
├── data/
│   ├── level_binary_codec.dart     <-- Shares encode/decode for .bin files
│   ├── level_generator/
│   │   ├── level_generator_v2.dart <-- Procedural level generator
│   │   ├── mask_generator_v2.dart  <-- PNG / shape-based mask generator
│   │   └── solver.dart             <-- Solvability validator & step tracer
│   └── models/                     <-- Core level, arrow, & dot models
│
├── editor/
│   ├── level_editor_app.dart       <-- Level Editor app state & UI layout
│   ├── components/
│   │   ├── editor_sidebar.dart     <-- File I/O, search, filter, bulk controls
│   │   ├── level_gallery_view.dart <-- Thumbnail grid list of levels
│   │   └── interactive_level_canvas.dart <-- Interactive visual grid canvas
│   └── dialogs/
│       ├── single_level_editor_dialog.dart <-- Modal editor & PNG importer
│       └── bulk_generator_dialog.dart      <-- Mass generation & binary exporter
│
└── main_editor.dart                <-- Web tool entrypoint
```

---

## How to Run & Build the Web Tool

### Launch in Browser (Dev Mode)
```bash
flutter run -d chrome -t lib/main_editor.dart
```

### Build Production Web Release
```bash
flutter build web -t lib/main_editor.dart --output build/web_editor
```

---

## User Interface Specification

### Main Interface Layout
- **Left Sidebar**:
  - **File Operations**: Open `.bin` file from local disk or load bundled `assets/levels.bin`; Export / Save `.bin`.
  - **Level Management**: Add new level, search level index, filter by difficulty / grid size.
  - **Bulk Generation trigger**: Launch bulk generator modal.
- **Right Main Workspace**:
  - **Header Bar**: Displays summary (total level count, solvable ratio, active filters).
  - **Level Gallery Grid**: Cards for each level showing level number, grid dimensions, arrow count, difficulty tag, solvability indicator badge, and action buttons (`Edit`, `Duplicate`, `Delete`).

### Interactive Single Level Editor
- **Header**: Level #, Grid WxH inputs, Solvability status badge, PNG Importer button, Interactive Solve button.
- **Center Canvas**: Interactive grid board rendering cell masks, arrows, directions, color groups, and path lines.
- **Cell Actions**: Click grid cell to toggle mask active/inactive.
- **Arrow Tools**: Click cell to add arrow, change direction (Up/Down/Left/Right), change mechanic (Normal/Snake/Freeze/Paired), change color group (0-7), or trace snake path steps.
- **Interactive Solver**: Executes `Solver.solveLevel()` step-by-step, highlighting arrows in the order they exit the board.

### Bulk Level Generator
- **Configurations**:
  - Target total level count (e.g. 500 levels).
  - Difficulty distribution slider (Normal vs Boss vs God).
  - PNG mask batch upload.
  - Fallback to procedural generator toggle.
- **Execution**: Asynchronous chunked generation loop to keep UI smooth and responsive.
- **Output**: Generates `levels.bin` and offers immediate browser file download.
