# Wachesaw — Complete Build Specification

*Version 0.2 — February 15, 2026*
*A Waccamaw-themed strategy game built in Godot 4*

---

## 1. Project Summary

**Name:** Wachesaw
**Tagline:** "Happy Hunting… or Place of Great Weeping?"
**Genre:** Abstract strategy / digital board game
**Theme:** Waccamaw Indian heritage (initially chess-styled for mechanics validation; Native American theme applied later)
**Business model:** Freemium
**Engine:** Godot 4.4+ (GDScript primary, C# optional for performance-critical systems)

---

## 2. Game Rules (Final)

### 2.1 Board

- 5×5 grid
- Center column (c-file) is thematically "The River" — no gameplay effect in v1, reserved for future map variants
- Coordinate system: columns a–e (left to right), rows 1–5 (bottom to top from White's perspective)

### 2.2 Starting Layout

```
     a        b        c        d        e
5  [B♞]    [B♛]    [B♚]    [B♝]    [B♜]    ← Black home row
4    .        .        .        .        .
3    .        .        .        .        .
2    .        .        .        .        .
1  [W♖]    [W♗]    [W♔]    [W♕]    [W♘]    ← White home row
```

White is always at the bottom (rows 1–2), Black at the top (rows 4–5). The layout is mirrored so identical piece types face each other diagonally, not directly.

### 2.3 Pieces

| Piece | Chess Symbol (W/B) | Movement | Special Rules |
|-------|--------------------|----------|---------------|
| **Chief** | ♔ / ♚ | 1 square in any direction (king) | Lose this = lose the game. Cannot win by crossing. |
| **Keeper** | ♕ / ♛ | 1 square in any direction (queen, range-limited) | Most versatile piece. Bodyguard role. |
| **Hunter** | ♖ / ♜ | 1 square orthogonal only (rook, range-limited) | Controls files and ranks. |
| **River Runner** | ♗ / ♝ | 1 square diagonal only (bishop, range-limited) | Controls diagonals. |
| **Trader** | ♘ / ♞ | L-shape jump, can leap over pieces (knight) | Cannot win by crossing to back row. Can only win by capturing. |

### 2.4 Turn Actions (exactly one per turn)

A player must do exactly one of the following on their turn:

1. **Move** — Move one of your pieces to an empty square following its movement pattern.
2. **Capture** — Move one of your pieces onto a square occupied by an opponent's piece. The opponent's piece is removed from the board. Follows normal movement pattern.
3. **Swap** — Choose any two of your own pieces that are adjacent (orthogonally or diagonally). They exchange positions. This counts as your entire turn. A swap is always legal if two friendly pieces are adjacent.

### 2.5 Win Conditions

The game ends immediately when either condition is met:

1. **Chief Capture** — If you capture the opponent's Chief (♔/♚), you win.
2. **Back Row Crossing** — If you move one of your pieces onto the opponent's home row (row 5 for White, row 1 for Black), you win. **Exception:** The Chief and the Trader cannot trigger this win condition. Only the Keeper, Hunter, and River Runner can win by crossing.

### 2.6 Draw Prevention

- **Three-fold repetition:** If the same board position occurs 3 times, the player with more total piece value remaining wins. If equal, the player who most recently made a capture wins.
- **No stalemate:** The swap mechanic ensures a legal move is virtually always available. In the extremely rare case a player has no legal move (isolated single piece with no movement squares), that player loses.
- **No draw offers:** There is no draw. Every game produces a winner.

### 2.7 Design Rationale

- **Trader back-row exclusion:** Without this rule, the Trader can reach the opponent's home row in exactly 2 moves from its starting position, creating an unstoppable rush. Excluding it forces the Trader into an assassin/disruptor role instead.
- **Chief back-row exclusion:** The Chief is meant to be protected, not used as an offensive runner. This also prevents a degenerate strategy of just marching the Chief forward.
- **Swap mechanic:** Borrowed from Monsiv. Ensures pieces are never "stuck" and creates a layer of repositioning tactics unique to this game.
- **First-move advantage:** Not yet mitigated. Requires extensive playtesting. Potential future solutions include a pie rule (second player may choose to swap sides after the first move) or a bid system. Decision deferred.

---

## 3. AI System

### 3.1 Algorithm

Minimax search with alpha-beta pruning. Pure game tree search — no neural networks or ML required for a 5×5 board.

### 3.2 Evaluation Function

The static board evaluation scores from Black's perspective (positive = good for Black):

```
score = Σ (for each piece on board):
    sign × material_value
  + sign × advancement_bonus
  + sign × center_control_bonus

where sign = +1 if piece is Black, -1 if piece is White
```

**Material values:**

| Piece | Value |
|-------|-------|
| Chief | 0 (infinite implicit value — losing it loses the game) |
| Keeper | 900 |
| Trader | 700 |
| Hunter | 500 |
| River Runner | 400 |

**Advancement bonus:** For pieces that can win by crossing (Keeper, Hunter, River Runner): `advancement = distance_toward_opponent_back_row × 18`. Rewards pushing pieces forward.

**Center control bonus:** `(4 - manhattan_distance_from_center) × 6`. Rewards occupying the center of the board.

**Terminal states:**
- White Chief captured → +100,000
- Black Chief captured → −100,000
- Depth bonus added to terminal scores to prefer faster wins

### 3.3 Difficulty Levels

| Level | Name | Search Depth (plies) | Random Move % | Description |
|-------|------|---------------------|---------------|-------------|
| 1 | Beginner | 1 | 40% | Makes random legal moves frequently. Safe for children/new players. |
| 2 | Easy | 2 | 20% | Sees 1 move ahead. Occasionally blunders. |
| 3 | Medium | 3 | 8% | Default. Sees threats and basic tactics. Beatable with thought. |
| 4 | Hard | 4 | 2% | Strong tactical play. Rarely blunders. |
| 5 | Expert | 5 | 0% | Full-depth search. No random moves. Very difficult to beat. |

**Random move chance:** At each AI turn, roll against the random threshold. If triggered, the AI plays a uniformly random legal move instead of the minimax result. This creates natural-feeling mistakes at lower difficulties.

### 3.4 Performance Notes

On a 5×5 board with 10 pieces and an average branching factor of ~25–35 (moves + swaps), depth 5 search examines roughly 15–50 million nodes worst case before pruning. Alpha-beta pruning typically reduces this by 90%+. On modern hardware, depth 5 should complete in under 1 second. If performance is an issue at depth 5, add iterative deepening with a time cutoff (e.g., 800ms).

---

## 4. Visual Style (Current Phase)

### 4.1 Phase 1: Chess Style (Current)

Standard chess piece symbols on a classic brown/tan chessboard. This is intentional — the goal is to validate mechanics before investing in custom art.

- Board: Alternating light (#f0d9b5) and dark (#b58863) squares
- Pieces: Unicode chess symbols at large size for readability
- UI: Dark panel theme (#312e2b background), minimal chrome
- Selected piece: Blue highlight
- Valid moves: Green dots (empty squares), red border (captures), blue highlight (swaps)
- Last move: Yellow highlight on from/to squares
- Move notation: Chess-style in sidebar (piece symbol + destination, × for captures, ⇄ for swaps)

### 4.2 Phase 2: Native American Theme (Future)

When mechanics are validated, transition to:

- Stylized 3D low-poly board (carved wood/stone slab)
- Totem-style 3D piece models with distinct silhouettes
- Particle effects system (embers, water, light trails) — "Tetris Forever" aesthetic
- Warm earth-tone palette with river blue accents
- Southeastern Woodlands visual identity (avoid stereotypes — focus on landscape and geometric patterns)
- Camera: Isometric with subtle orbit, zoom
- Sound: Wood/stone placement, water ambient, drum-based stings

### 4.3 Particle Effects Spec (Phase 2)

| Event | Effect | Priority |
|-------|--------|----------|
| Piece selected | Soft glow pulse, rising ember particles | P0 |
| Valid moves | Gentle shimmer/ripple on target squares | P0 |
| Piece moved | Light trail along movement path | P0 |
| Capture | Burst scatter from captured piece position | P0 |
| Swap | Swirling exchange particles between pieces | P1 |
| Win (back row) | River of particles flowing across board | P1 |
| Win (Chief captured) | Radial burst, screen flash, falling embers | P1 |
| Game start | Pieces materialize with particle flourish | P2 |

---

## 5. Configurable Rules System

All game rules must be data-driven. No rule should be hardcoded such that changing it requires modifying game logic source code.

### 5.1 Rule Configuration Schema

Rules are defined in a JSON or Godot Resource file. The game logic layer reads this config at startup and uses it for all validation.

```json
{
  "board": {
    "width": 5,
    "height": 5,
    "terrain": [
      [0,0,1,0,0],
      [0,0,1,0,0],
      [0,0,1,0,0],
      [0,0,1,0,0],
      [0,0,1,0,0]
    ]
  },
  "terrain_types": {
    "0": { "name": "normal", "effect": "none" },
    "1": { "name": "river", "effect": "none", "visual": "water" }
  },
  "pieces": {
    "CHIEF": {
      "name": "Chief",
      "moves": [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]],
      "can_jump": false,
      "can_cross_win": false,
      "material_value": 0,
      "is_leader": true
    },
    "KEEPER": {
      "name": "Keeper",
      "moves": [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]],
      "can_jump": false,
      "can_cross_win": true,
      "material_value": 900,
      "is_leader": false
    },
    "HUNTER": {
      "name": "Hunter",
      "moves": [[1,0],[-1,0],[0,1],[0,-1]],
      "can_jump": false,
      "can_cross_win": true,
      "material_value": 500,
      "is_leader": false
    },
    "RIVER_RUNNER": {
      "name": "River Runner",
      "moves": [[1,1],[1,-1],[-1,1],[-1,-1]],
      "can_jump": false,
      "can_cross_win": true,
      "material_value": 400,
      "is_leader": false
    },
    "TRADER": {
      "name": "Trader",
      "moves": [[2,1],[2,-1],[-2,1],[-2,-1],[1,2],[1,-2],[-1,2],[-1,-2]],
      "can_jump": true,
      "can_cross_win": false,
      "material_value": 700,
      "is_leader": false
    }
  },
  "layout": {
    "white": {
      "row": 0,
      "pieces": ["HUNTER","RIVER_RUNNER","CHIEF","KEEPER","TRADER"]
    },
    "black": {
      "row": 4,
      "pieces": ["TRADER","KEEPER","CHIEF","RIVER_RUNNER","HUNTER"]
    }
  },
  "rules": {
    "swap_enabled": true,
    "swap_range": 1,
    "swap_directions": "all_adjacent",
    "win_conditions": ["capture_leader", "cross_back_row"],
    "repetition_limit": 3,
    "turn_timer_seconds": 0
  }
}
```

### 5.2 What This Enables

- Change board size without code changes
- Add/remove/modify piece types and their movement
- Create asymmetric piece sets
- Add terrain types with gameplay effects
- Modify win conditions
- Toggle or extend the swap mechanic
- Support the map editor (maps are just rule configs)
- A/B test balance changes by swapping config files

---

## 6. Architecture

### 6.1 Layer Separation

```
project/
├── core/                    # Pure game logic — NO engine dependencies
│   ├── board.gd             # Board state representation
│   ├── rules.gd             # Rule config loader and validator
│   ├── move_generator.gd    # Legal move generation
│   ├── win_checker.gd       # Win condition evaluation
│   ├── ai/
│   │   ├── evaluator.gd     # Board evaluation function
│   │   └── minimax.gd       # Search with alpha-beta pruning
│   └── types.gd             # Enums, data structures
│
├── presentation/            # Godot-specific rendering
│   ├── board_view.gd        # 3D/2D board rendering
│   ├── piece_view.gd        # Piece rendering and animation
│   ├── particles/           # Particle effect scenes
│   ├── ui/                  # Menus, HUD, move log
│   │   ├── main_menu.tscn
│   │   ├── game_hud.tscn
│   │   ├── difficulty_selector.tscn
│   │   └── settings.tscn
│   ├── audio/               # Sound effects and music
│   └── themes/              # Visual theme resources
│       ├── chess_classic/   # Phase 1 chess style
│       └── waccamaw/        # Phase 2 native theme
│
├── network/                 # Future multiplayer layer
│   ├── matchmaker.gd
│   ├── state_sync.gd
│   └── lobby.gd
│
├── data/                    # Configuration and content
│   ├── rules/
│   │   ├── classic.json     # Default 5x5 ruleset
│   │   └── variants/        # Alternate rule configs
│   ├── maps/
│   │   ├── builtin/         # Shipped maps
│   │   └── custom/          # User-created maps
│   └── saves/
│
├── platform/                # Platform-specific code
│   ├── mobile_input.gd      # Touch controls
│   ├── desktop_input.gd     # Mouse/keyboard
│   ├── console_input.gd     # Gamepad
│   └── web_bridge.gd        # Web-specific APIs
│
├── project.godot            # Godot project file
├── export_presets.cfg        # Export configurations
└── addons/                  # Third-party Godot plugins
```

### 6.2 Key Principle

The `core/` directory has **zero imports from Godot engine APIs**. It uses only GDScript language features (or C# if preferred). This means:

- Game logic is unit-testable without running the engine
- Rules can be validated in headless mode
- Future server-side validation (for multiplayer anti-cheat) can reuse the same code
- Porting to a different engine (unlikely but possible) only requires replacing `presentation/`

### 6.3 Game Flow

```
MainMenu
  → select mode (AI / Local / Online*)
  → select difficulty (if AI)
  → load rule config
  → instantiate Board (core)
  → instantiate BoardView (presentation)
  → game loop:
      1. BoardView renders current state
      2. Wait for input (human) or compute (AI)
      3. Validate move via core/move_generator
      4. Apply move to Board state
      5. Check win via core/win_checker
      6. Animate move in BoardView
      7. Switch turn, goto 1
  → game over → show result → return to menu or rematch
```

---

## 7. Platform Targets & Build Instructions

### 7.1 Prerequisites

Install the following:

```bash
# 1. Godot 4.4+ (standard or .NET build if using C#)
# Download from https://godotengine.org/download
# Or via package manager:
# macOS:
brew install godot

# Linux (Flatpak):
flatpak install flathub org.godotengine.Godot

# Or download the binary and add to PATH

# 2. Export templates (required for building)
# In Godot: Editor → Manage Export Templates → Download

# 3. For web builds: No additional dependencies

# 4. For Android builds:
# - Android SDK (API 33+)
# - Android NDK r25+
# - OpenJDK 17
# - Set paths in Editor → Editor Settings → Export → Android

# 5. For iOS builds:
# - macOS with Xcode 15+
# - Apple Developer account
# - Set up signing in export preset

# 6. For console builds:
# - Register with platform holders (Nintendo, Microsoft, Sony)
# - Purchase W4 Consoles subscription (https://www.w4games.com/w4consoles)
# - Follow W4 integration docs
```

### 7.2 Project Setup

```bash
# Create project
mkdir wachesaw && cd wachesaw

# Initialize Godot project (or create via Godot editor: Project → New Project)
# Project settings to configure:
#   Display → Window → Size → 1280×720 (landscape)
#   Display → Window → Stretch → Mode: canvas_items
#   Display → Window → Stretch → Aspect: expand
#   Rendering → Renderer → Forward+ (desktop/console) or Compatibility (web/mobile)
#   Application → Config → Name: "Wachesaw"

# Directory structure
mkdir -p core core/ai presentation presentation/ui presentation/particles presentation/themes
mkdir -p presentation/themes/chess_classic presentation/themes/waccamaw
mkdir -p network data/rules data/rules/variants data/maps/builtin data/maps/custom
mkdir -p data/saves platform addons

# Place the classic.json rule config in data/rules/classic.json
```

### 7.3 Build Commands

Godot supports command-line exports. After configuring export presets in the editor (Project → Export), you can build from CLI:

```bash
# =====================
# WEB (HTML5) — P0
# =====================
# Export preset name: "Web"
# Renderer: Compatibility (OpenGL ES 3.0 / WebGL 2)
godot --headless --export-release "Web" builds/web/wachesaw.html

# Serve locally for testing:
cd builds/web
python3 -m http.server 8000
# Open http://localhost:8000/wachesaw.html

# NOTE: Godot web exports require being served over HTTP (not file://),
# and need the correct MIME types for .wasm and .pck files.
# For production, deploy to any static hosting (Netlify, Vercel, S3, itch.io).


# =====================
# ANDROID — P0
# =====================
# Export preset name: "Android"
# Requires: Android SDK, NDK, JDK configured in Editor Settings
# Renderer: Compatibility (for broad device support) or Forward+

# Debug APK (for testing):
godot --headless --export-debug "Android" builds/android/wachesaw.apk

# Release AAB (for Google Play):
godot --headless --export-release "Android" builds/android/wachesaw.aab

# Install debug APK on connected device:
adb install builds/android/wachesaw.apk


# =====================
# iOS — P0
# =====================
# Export preset name: "iOS"
# Requires: macOS, Xcode 15+, Apple Developer account
# Renderer: Forward+ or Compatibility
godot --headless --export-release "iOS" builds/ios/wachesaw.xcodeproj

# Then open in Xcode, configure signing, and build/archive:
open builds/ios/wachesaw.xcodeproj
# In Xcode: Product → Archive → Distribute App


# =====================
# WINDOWS (Steam) — P1
# =====================
# Export preset name: "Windows Desktop"
godot --headless --export-release "Windows Desktop" builds/windows/wachesaw.exe

# For Steam, use Steamworks SDK integration:
# - Create app on Steamworks partner site
# - Use GodotSteam addon (https://github.com/GodotSteam/GodotSteam)
# - Configure depot and build in Steamworks


# =====================
# macOS — P1
# =====================
# Export preset name: "macOS"
godot --headless --export-release "macOS" builds/macos/wachesaw.dmg

# For notarization:
# xcrun notarytool submit builds/macos/wachesaw.dmg --apple-id $APPLE_ID --team-id $TEAM_ID


# =====================
# LINUX — P1
# =====================
# Export preset name: "Linux/X11"
godot --headless --export-release "Linux/X11" builds/linux/wachesaw.x86_64


# =====================
# NINTENDO SWITCH — P2
# =====================
# Requires: Nintendo Developer account + W4 Consoles subscription
# W4 provides Godot export templates for Switch
# Follow W4 Consoles documentation for setup
# Build with W4's custom export preset after integration


# =====================
# XBOX SERIES X|S — P2
# =====================
# Requires: ID@Xbox developer account + W4 Consoles subscription
# W4 provides Godot export templates for Xbox
# Follow W4 Consoles documentation for setup


# =====================
# PLAYSTATION 5 — P3
# =====================
# Requires: PlayStation Partners account + W4 Consoles subscription
# W4 provides Godot export templates for PS5
# Evaluate after Xbox launch
```

### 7.4 Renderer Selection by Platform

| Platform | Renderer | Why |
|----------|----------|-----|
| Web | Compatibility | WebGL 2 required; Forward+ not supported in browsers |
| Android | Compatibility | Broad device support; Forward+ only for high-end |
| iOS | Forward+ or Compatibility | Forward+ for newer iPads/iPhones, Compatibility for broader support |
| Windows/macOS/Linux | Forward+ | Full visual quality on desktop |
| Consoles | Forward+ | Console hardware supports it well |

### 7.5 Quick Start: Get POC Running

The fastest path to a playable POC on web and phone:

```bash
# 1. Install Godot 4.4
# 2. Create new project in Godot Editor
# 3. Build core/ game logic first (board state, moves, win check)
# 4. Build a simple 2D board view using Godot's Control nodes or Sprite2D
#    (3D comes later — 2D is faster for POC)
# 5. Export to Web:
#    - Project → Export → Add Preset → Web
#    - Set Renderer to Compatibility
#    - Export
#    - Serve with local HTTP server and open on phone browser
# 6. Export to Android:
#    - Project → Export → Add Preset → Android
#    - Configure SDK paths
#    - Export debug APK
#    - adb install on phone

# For the absolute fastest iteration loop:
# - Use Godot's built-in "Remote Debug" to run on phone via WiFi
# - Editor → Run → Deploy → Remote Debug → enable
# - Set your phone's IP in Project Settings → Network → Remote Debug
```

### 7.6 CI/CD Pipeline (Recommended)

```yaml
# .github/workflows/build.yml (GitHub Actions example)
name: Build Wachesaw
on: [push, pull_request]

jobs:
  build-web:
    runs-on: ubuntu-latest
    container: barichello/godot-ci:4.4
    steps:
      - uses: actions/checkout@v4
      - run: mkdir -p builds/web
      - run: godot --headless --export-release "Web" builds/web/index.html
      - uses: actions/upload-artifact@v4
        with:
          name: web-build
          path: builds/web/

  build-android:
    runs-on: ubuntu-latest
    container: barichello/godot-ci:4.4
    steps:
      - uses: actions/checkout@v4
      - run: mkdir -p builds/android
      - run: godot --headless --export-debug "Android" builds/android/wachesaw.apk
      - uses: actions/upload-artifact@v4
        with:
          name: android-build
          path: builds/android/

  build-windows:
    runs-on: ubuntu-latest
    container: barichello/godot-ci:4.4
    steps:
      - uses: actions/checkout@v4
      - run: mkdir -p builds/windows
      - run: godot --headless --export-release "Windows Desktop" builds/windows/wachesaw.exe
      - uses: actions/upload-artifact@v4
        with:
          name: windows-build
          path: builds/windows/
```

---

## 8. Social Features (Future Phases)

### Phase 1 (Ship with base game)
- Online 1v1 matchmaking (ranked + casual)
- Friend list and match invites
- Match history
- Player profiles (name, avatar, W/L record, rank)

### Phase 2
- Spectator mode
- In-game emotes (pre-set, not free text)
- Leaderboards (global and regional)
- Daily/weekly puzzle challenges

### Phase 3
- Clans/tribes
- Tournaments (bracket-style)
- Replay sharing
- Community maps (share and rate)

### Backend Options
- **Nakama** (open source, self-hostable) — best for indie with full control
- **PlayFab** (Microsoft) — free tier, good for Xbox integration
- **Firebase** (Google) — fastest to prototype, good for mobile

---

## 9. Map System (Future Phase)

### What is a Map?

A map is a complete game configuration file that overrides the default rules:

- Board dimensions
- Terrain tiles (normal, river, bluff, marsh, fire)
- Starting positions
- Piece set per side (can be asymmetric)
- Rule overrides (custom win conditions, etc.)
- Visual theme

### Terrain Types (Planned)

| Terrain | Effect |
|---------|--------|
| Normal | None |
| River | Only River Runner can stop here (others must cross in one move) |
| Bluff | Piece on bluff immune to non-jumping captures |
| Marsh | Piece entering marsh skips next turn |
| Fire | Piece on fire is destroyed after 2 turns if not moved |

### Map Editor (Planned)

- Visual drag-and-drop in-game editor
- Set board size, place terrain, position starting pieces
- Custom rules per map
- Save/load as JSON
- Share via community system

### Default Maps

| Name | Size | Notes |
|------|------|-------|
| Wachesaw Classic | 5×5 | Base game, no terrain |
| River Crossing | 5×5 | Center column is River terrain |
| The Bluffs | 7×7 | Larger board with elevation |
| Marshlands | 6×6 | Marsh chokepoints |
| The Great Hunt | 5×7 | Rectangular, asymmetric starts |

---

## 10. Monetization Plan

### Free
- Full base game (Wachesaw Classic)
- Online multiplayer (casual)
- 2–3 default maps
- Basic piece skins

### Paid
- Cosmetic piece sets (carved wood, river stone, shell, bone)
- Board skins (different environments)
- Particle effect packs
- Map packs (5–10 curated maps with terrain)
- Campaign mode (single-player puzzles/tactics)
- Battle pass (seasonal cosmetics)

**No pay-to-win.** Gameplay rules are identical regardless of purchases.

---

## 11. Development Roadmap

### Phase 1: POC / Core Game (Weeks 1–6)
- [ ] Godot project setup with directory structure above
- [ ] `core/` — Board state, move generation, win checking, rule config loading
- [ ] `core/ai/` — Minimax with alpha-beta, evaluation function, difficulty levels
- [ ] `presentation/` — 2D board view with chess piece sprites
- [ ] Menu screen (Play vs AI, Local 2P, difficulty selection)
- [ ] Basic game HUD (turn indicator, move log, captured pieces)
- [ ] Input handling (mouse + touch)
- [ ] Web export working and playable
- [ ] Android APK working and playable
- [ ] iOS build working (if on macOS)

### Phase 2: Polish (Weeks 6–10)
- [ ] Move animations (piece slides, capture effects)
- [ ] Sound effects (placement, capture, win/loss)
- [ ] Settings screen (volume, difficulty, rules display)
- [ ] Touch UX polish (drag vs tap, confirmation, undo)
- [ ] Desktop builds (Windows, macOS, Linux)
- [ ] Steam integration (GodotSteam addon)

### Phase 3: Online (Weeks 10–16)
- [ ] Backend selection and setup
- [ ] Account system
- [ ] Online matchmaking
- [ ] Server-authoritative game validation
- [ ] Friend system, profiles
- [ ] Ranked mode

### Phase 4: Content (Weeks 16–22)
- [ ] Map system + terrain effects
- [ ] Map editor
- [ ] Campaign mode (puzzle challenges)
- [ ] Cosmetics system
- [ ] Native American visual theme (3D pieces, board, particles)

### Phase 5: Console + Growth (Weeks 22+)
- [ ] W4 Consoles integration
- [ ] Switch submission
- [ ] Xbox submission
- [ ] Tournament system
- [ ] Community features
- [ ] PlayStation evaluation

---

## 12. Open Decisions (Deferred)

| Decision | Status | Notes |
|----------|--------|-------|
| First-move advantage mitigation | Deferred | Needs playtesting. Pie rule is leading candidate. |
| River column gameplay effect | Deferred | No effect in v1. May add in map variants. |
| Game name trademark | TODO | Search "Wachesaw" for conflicts with Wachesaw Plantation. |
| Cultural consultation | After POC | Bring a working game to the Waccamaw tribal council. |
| Exact piece 3D models | Phase 4 | Chess symbols for now. |
| Backend provider | Phase 3 | Nakama, PlayFab, or Firebase. Evaluate when needed. |

---

## 13. Reference: Prototype Code

The React prototype built during design (wachesaw.jsx) contains a working implementation of:

- Board state management
- Move generation for all 5 piece types
- Swap mechanic
- Win condition checking (Chief capture + back-row crossing with exclusions)
- AI with minimax + alpha-beta + difficulty levels 1–5
- Chess-style UI and move notation

This prototype validates the rules and AI. The Godot implementation should replicate this logic in `core/` and build the presentation layer on top.

---

*End of specification.*
