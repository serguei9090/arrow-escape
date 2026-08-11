<div align="center">

<img src="assets/images/logo.png" alt="Vector Escape Logo" width="120" height="120" />

# Vector Escape

**A casual grid puzzle game — slide arrows out of the grid. Built with Flutter & Flame.**  
*Forked & Enhanced from [gtxPrime/arrow-escape](https://github.com/gtxPrime/arrow-escape).*

  <p>
    <a href="https://github.com/serguei9090/arrow-escape/stargazers">
      <img src="https://img.shields.io/github/stars/serguei9090/arrow-escape?style=for-the-badge&color=yellow" alt="Stars" />
    </a>
    <a href="https://github.com/serguei9090/arrow-escape/network/members">
      <img src="https://img.shields.io/github/forks/serguei9090/arrow-escape?style=for-the-badge&color=orange" alt="Forks" />
    </a>
    <a href="https://github.com/serguei9090/arrow-escape/issues">
      <img src="https://img.shields.io/github/issues/serguei9090/arrow-escape?style=for-the-badge&color=blue" alt="Issues" />
    </a>
    <a href="https://github.com/serguei9090/arrow-escape/blob/main/LICENSE">
      <img src="https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge" alt="License" />
    </a>
    <a href="#">
      <img src="https://img.shields.io/badge/Platform-Flutter_|_Android_|_iOS_|_Web-3DDC84?logo=flutter&logoColor=white&style=for-the-badge" alt="Platform" />
    </a>
  </p>

</div>

---

## About Vector Escape

**Vector Escape** is an enhanced, customized fork of [Arrow Escape](https://github.com/gtxPrime/arrow-escape). It features a refined **Nordic Minimalist theme**, enhanced AdMob environment integration, and expanded game power-ups including **Hint & Auto-Solve items** earned through gameplay or rewarded ads.

The game ships with **500 pre-generated, 100% verified solvable levels** across 7 difficulty bands, powered by **LevelGeneratorV2** with tutorial, Boss, and God level variants.

---

## What's New in this Fork?

| Feature | Description |
|---|---|
| **🎨 Nordic Minimalist Theme** | Modernized visual theme with Ice Cyan and Midnight Ocean color palettes |
| **💡 Hints & Auto-Solvers** | Built-in Hint & Auto-Solve power-ups redeemable via coins or rewarded ads |
| **🔐 Secure `.env` Ad Configuration** | Decoupled AdMob IDs using `flutter_dotenv` for environment-driven configuration |
| **⚡ Upstream Engine Sync** | Built on top of `LevelGeneratorV2` and Firebase Crashlytics stability fixes |

---

## Features

| Feature | Description |
|---|---|
| **Slide Mechanics** | Tap an arrow — if its exit path to the canvas edge is clear, it slides out smoothly |
| **500 Pregenerated Levels** | Fully verified, zero-deadlock levels precompiled into `assets/levels.bin` |
| **LevelGeneratorV2** | Reverse-placement generator + DFS graph solver validation |
| **Direction Deflector Dots** | Directional orphan dots (Up, Down, Left, Right, Neutral) that redirect exiting arrows |
| **Color-Paired Arrows** | Matched color arrow pairs that must be cleared together |
| **Clean Vector Arrows** | Border-stroke-free sleek arrow paths styled dynamically per theme |
| **Dense Silhouette Boss/God Shapes** | Large, thick filled silhouettes (27×27 to 40×40 grids) |
| **Level Timers** | Timed God levels (Level > 100) and Timed Boss levels (Level > 200) |
| **Pinch-to-Zoom & Pan** | Smooth `InteractiveViewer` with hit-test margin scaling for edge arrows |
| **Lives & Star System** | 3 hearts per level; star ratings based on remaining lives |

---

## Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Framework | Flutter | SDK >=3.0.0 <4.0.0 |
| Game Engine | Flame | ^1.18.0 |
| Audio | Flame Audio | ^2.10.0 |
| State | Provider | ^6.1.2 |
| Animations | Flutter Animate | ^4.5.0 |
| Storage | Shared Preferences | ^2.3.2 |
| Config | Flutter DotEnv | ^6.0.1 |
| Crashlytics | Firebase Crashlytics | ^4.3.10 |
| Ads | Google Mobile Ads + Unity Ads | ^5.1.0 / ^0.4.0 |

---

## Installation

### Prerequisites

- Flutter SDK >= 3.0.0 — [flutter.dev/get-started](https://docs.flutter.dev/get-started/install)
- Run `flutter doctor` to verify setup

### Build & Run

```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build Android APK
flutter build apk --release
```

---

## Monetization & Environment Configuration

Secrets and Ad Unit IDs are loaded securely from `.env` using `flutter_dotenv`.
Copy `.env.example` to `.env` for local development or production releases:

```env
ADMOB_APP_ID_ANDROID=ca-app-pub-3940256099942544~3347511713
ADMOB_BANNER_ID=ca-app-pub-3940256099942544/6300978111
ADMOB_INTERSTITIAL_ID=ca-app-pub-3940256099942544/1033173712
ADMOB_REWARDED_ID=ca-app-pub-3940256099942544/5224354917
```

---

## Acknowledgments & Credits

This project is an MIT-licensed fork of the original [Arrow Escape](https://github.com/gtxPrime/arrow-escape) created by [gtxPrime](https://github.com/gtxPrime).
