# Arrow Escape - Project Q&A and Customization Guide

This document provides detailed technical explanations and recommendations for creating your own customized version of **Arrow Escape**.

---

## 1. Modify vs. Migrate: What is the Best Approach?
**Recommendation**: **Modify the existing codebase.**

* **Why Modify**:
  * The repo already includes a production-ready game engine built on **Flutter & Flame**.
  * It features a deterministic level generator, deadlock detection, reverse-placement solver, binary level encoder/decoder, sound manager, streak system, and multi-tier difficulty pipeline.
  * Rebuilding or migrating from scratch would require rewriting complex grid collision math, Flame component lifecycle handling, and path-tracing algorithms.
* **When to Migrate**: Only migrate if you plan to switch to a completely different game engine like Unity or Godot.

---

## 2. Changing Arrow Shapes and Visuals
Arrow visuals are rendered using Flame vector operations inside **[`ArrowComponent`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/game/components/arrow_component.dart)**.

### Key Locations:
* **Arrow Body & Head Drawing**: [`ArrowComponent.render()`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/game/components/arrow_component.dart)
  * Defines path calculations (`Path`), stroke widths, arrow head size (`headSize`), body rounding, and dot circles.
* **Arrow Colors & Themes**: [`AppColors`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/core/app_colors.dart)
  * Line 28–31 defines direction colors (`arrowUp`, `arrowDown`, `arrowLeft`, `arrowRight`).
* **Dot Mechanics Visuals**: [`ArrowColor`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/data/models/arrow.dart#L7-L15)
  * Enum defining colors for color-paired arrows and deflector dots.

---

## 3. PNG Image Level Generation & Custom Mechanics

### A. Generating Levels from PNG Images
Yes! [`MaskGenerator`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/data/level_generator/mask_generator.dart) already handles non-square grid masks (such as hearts, animals, and geometric shapes).
* **How to implement image masks**:
  1. Load a transparent PNG image into a Dart/Python script.
  2. Map non-transparent pixels to `true` (valid cell) and transparent pixels to `false` (void cell).
  3. Pass this boolean matrix `List<List<bool>>` as `gridMask` into `LevelGenerator.generateLevel()`.

### B. Multicolor Arrows, Arrow Pairs & Deflector (Redirect) Points
* **Arrow Pairs & Deflectors**: Already supported in the engine!
  * **Color-Paired Arrows**: Found in [`ArrowModel.colorGroup`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/data/models/arrow.dart). Both arrows of the same color must be cleared simultaneously.
  * **Deflector Points (Orphan Dots)**: Found in [`OrphanDot`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/data/models/arrow.dart). When an arrow slides over a dot, it turns 90 degrees or changes color dynamically.
* **Multicolor Arrows**: Can be added by extending [`ArrowModel`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/data/models/arrow.dart) with a list of colors `List<ArrowColor> colors` rather than a single color.

---

## 4. How Grid and Canvas Bounds are Defined

Grid sizing is dynamically calculated based on screen dimensions and level type:

1. **Canvas & Component Placement**:
   * Defined in **[`ArrowPuzzleGame.onLoad()`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/game/arrow_puzzle_game.dart#L33-L53)**.
   * Calculates grid pixel size from screen dimensions: `final minDim = size.x < size.y ? size.x : size.y;`
2. **Grid Layout & Cell Dimensions**:
   * Defined in **[`GridComponent`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/game/components/grid_component.dart)**.
   * Cell size formula: `cellSize = gridPixelSize / level.gridSize;`
3. **Level Grid Size Scaling**:
   * Defined in **[`AppConstants.gridSizeForLevel(levelNumber)`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/core/constants.dart)**.
   * Scales from $10 \times 10$ (tutorials) up to $40 \times 40$ (God/Boss levels).

---

## 5. Adding Hint and Solve Buttons

### A. Hint Button
* **Mechanism**: Use [`Solver`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/data/level_generator/solver.dart).
* **Implementation**:
  1. Call `Solver.findSolution(gameState.arrows, gameState.level.gridSize, ...)` to retrieve the optimal sequence of moves.
  2. Highlight the first removable arrow returned by the solver on screen (e.g., pulse animation or outline glow).

### B. Auto-Solve Button
* **Mechanism**: Iterate through the step-by-step solution returned by `Solver.findSolution()`.
* **Implementation**: Trigger `gameState.handleArrowTap(nextArrowId)` with a `Future.delayed()` interval (e.g., 300ms) until all arrows exit.

---

## 6. License, Monetization & Custom Ads

* **License**: **MIT License** (as stated in the GitHub repository tags).
  * You are **legally allowed** to modify, rebrand, distribute, and monetize this project commercially.
* **Replacing Ads**:
  * Ad management is centralized in **[`lib/ads/ad_manager.dart`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/ads/ad_manager.dart)** and [`UnifiedBannerAd`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/widgets/unified_banner_ad.dart).
  * Replace the AdMob and Unity Ads Unit IDs with your own publisher IDs in `AdManager`.

---

## 7. Level Design, Engagement & Running on Web

### Engagement & Level Balancing
* The current design uses a 7-level repeating cycle:
  `Normal -> Normal -> Normal -> BOSS -> Normal -> Normal -> GOD`
* Mixing **random/procedural puzzles** with **shaped mask levels** keeps players engaged by alternating between standard challenge and visual variety.

### Engine Reliability
* The level generator is highly robust with guaranteed reverse-placement solvability and double verification via BFS.

### Web Preview & Selection
* Flutter Web is fully supported by this codebase.
* You can run `flutter run -d chrome` to test, inspect components, and tune level generation live in a browser.

---

## 8. Extending Level Generation to Build New `.bin` Files

Yes! The repository already includes a CLI build pipeline to pre-generate and compress levels into `levels.bin`.

### Steps to generate new levels:
1. Update generation parameters in [`LevelGenerator`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/data/level_generator/level_generator.dart).
2. Run the verification pipeline script:
   ```powershell
   .\run_verify.ps1
   ```
3. Compile the JSON progress chunks into a binary asset:
   ```bash
   flutter test test/build_levels_bin_test.dart
   ```
   This updates `assets/levels.bin`.

---

## 9. Coins and Currency Usage
Currently in the codebase:
* **Earning Coins**: Player earns coins when completing levels ([`ProgressRepository.recordLevelComplete`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/data/repositories/progress_repository.dart#L210-L223)).
* **Current Status**: Coins are stored in `SharedPreferences`, but there is currently no active shop.
* **Suggested Enhancement**: Use coins to purchase **Hints**, **Extra Lives**, or **Custom Arrow Themes**.

---

## 10. Privacy Policy, Play Store URLs & Store Ratings

### A. Privacy Policy URL
* Found in **[`SettingsScreen._privacyPolicyUrl`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/screens/settings/settings_screen.dart#L14-L15)**.
* Replace `https://gxdevs.blogspot.com/...` with your hosted Privacy Policy URL.

### B. Play Store & App Store Ratings
* Package ID is defined in [`AppConstants.packageId`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/core/constants.dart).
* Play Store URL template in [`SettingsScreen._playStoreUrl`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/screens/settings/settings_screen.dart#L16-L17).
* Update `packageId` in `pubspec.yaml` and `AppConstants` to point to your Android package name.

---

## 11. Changing Logos & Backgrounds

* **App Logo**: Replace `assets/images/logo.png` and update launcher icons via `flutter_launcher_icons`.
* **Game Backgrounds**:
  * Background colors and gradients are defined in [`AppColors.bgGradient`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/core/app_colors.dart#L70-L76).
  * Background widget is located in [`MazeBackground`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/widgets/maze_background.dart). You can swap this with custom static images or dynamic shaders.

---

## 12. Unlocking Levels with Rewarded Ads

Yes, this can be seamlessly added:

1. In [`LevelSelectScreen`](file:///i:/01-Master_Code/Apps/arrow-escape/lib/screens/level_select/level_select_screen.dart), check if a locked level tile is tapped.
2. Trigger `AdManager.showRewardedAd(...)`.
3. Upon ad completion callback, call `progressRepository.setCurrentLevel(lockedLevelNum)` or update `highestUnlockedLevel`.
