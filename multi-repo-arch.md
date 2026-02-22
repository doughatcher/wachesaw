# Wachesaw — Multi-Repo Architecture

*Last updated: February 2026*

---

## Overview

Wachesaw is built across three repositories, each with a distinct role and deployment target. They share a common puzzle JSON schema and communicate through the central API.

```
┌─────────────────────────────────────────────────────────────────┐
│                         wachesaw.app                            │
│                  (Expo PWA — GitHub Pages)                      │
│  Level Editor · Daily Puzzles · Community · Login · Billing     │
└──────────────────────────┬──────────────────────────────────────┘
                           │ fetch()
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      api.wachesaw.app                           │
│              (Cloudflare Workers + D1 + R2)                     │
│  Auth · Progress Sync · Community Puzzles · Leaderboards        │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPRequest
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Wachesaw Godot Client                        │
│               (Desktop / Console / Web builds)                  │
│  Story Mode · AI Matches · Full Game Engine · Steam / itch.io   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Repositories

### 1. `doughatcher/wachesaw` — Godot Game (this repo)

**Identity:** wachesaw-godot
**Engine:** Godot 4.4 (GDScript, `gl_compatibility` renderer)
**Deployed to:** GitHub Pages (web build), GitHub Releases (desktop binaries), Steam/itch.io (future)

What it owns:
- Complete game engine: board logic, move generation, win checking, AI (minimax)
- Single-player story campaign (5 chapters, 30+ puzzles)
- Puzzle hot-reload system (MapWatcher)
- GTK4 desktop level editor (`tools/level_editor.py`)
- All Godot scenes, themes, assets
- CI/CD: web build → GitHub Pages, desktop builds → GitHub Releases

**Key paths:**
| Path | Purpose |
|------|---------|
| `core/` | Pure game logic (no Godot engine deps) |
| `core/ai/` | Minimax + evaluation |
| `presentation/` | Godot rendering, UI, controllers |
| `data/story/` | Chapter JSON files (shared schema) |
| `data/rules/` | Rule configs |
| `tools/` | Level editor, dev server |
| `.devcontainer/` | Full-stack dev environment (hub) |
| `apps/` | Cloned sub-repos (gitignored) |

### 2. `doughatcher/wachesaw-api` — Cloudflare Workers API

**URL:** `https://api.wachesaw.app`
**Stack:** Hono + Cloudflare Workers + D1 (SQLite) + R2 (backups) + Resend (email)
**Deployed via:** `wrangler deploy` (triggered by GitHub Actions)

What it owns:
- **Auth** — email/password registration, bcrypt hashing, session tokens, email verification via Resend with polling-based flow
- **Story progress sync** — puzzle completion tracking, resume position, offline-first merge
- **Community puzzles** — CRUD, likes, play counts, schema validation
- **Leaderboards** — per-puzzle scores (moves + time), ranking
- **Backups** — daily D1 export to R2, pre-migration snapshots, weekly restore verification

**D1 tables:** `users`, `sessions`, `story_progress`, `story_positions`, `community_puzzles`, `puzzle_likes`, `leaderboard`

**Auth flow (polling-based):**
```
Client                          API                         Resend
  │                              │                            │
  │─── POST /auth/register ─────▶│                            │
  │◀── { token, verified:false } │── Send verification email ─▶│
  │                              │                            │
  │─── GET /auth/status ────────▶│  (poll every 5-10s)        │
  │◀── { verified: false }       │                            │
  │                              │                            │
  │    (user clicks email link)  │                            │
  │                              │◀─ GET /auth/verify?code=── │
  │                              │   sets verified = true      │
  │                              │                            │
  │─── GET /auth/status ────────▶│                            │
  │◀── { verified: true } ✓      │                            │
```

Both Godot (`HTTPRequest`) and Expo (`fetch`) clients use this identical flow — no platform-specific auth code needed.

### 3. `doughatcher/wachesaw-express` — Expo PWA

**URL:** `https://wachesaw.app`
**Stack:** Expo (React Native for Web), TypeScript, static export
**Deployed to:** GitHub Pages via `npx expo export --platform web` + GitHub Actions

What it owns:
- **Level Editor** — React `<Board>` component for visual puzzle creation (port of GTK4 editor). Click cells to place pieces, edit metadata, save to API.
- **Daily Puzzles** — puzzle-of-the-day experience using the same `<Board>` component in play mode. Scores submit to the API leaderboard. Shareable links.
- **Community Browser** — browse, search, play, and like community-created puzzles
- **User Profiles** — login/registration (hitting the API), progress display, scores
- **Billing Placeholder** — subscription/IAP UI scaffolding for future monetization
- **Responsive design** — works on iPad, phone, and desktop browsers as a PWA

**Key shared component: `<Board>`**

The React `<Board>` component renders the 5×5 Wachesaw grid and operates in two modes:
- **Editor mode** — click to place/remove pieces, drag to rearrange (level editor)
- **Play mode** — click to select a piece, show valid moves, click to execute (daily puzzles)

Ported from the GTK4 `BoardGrid` widget and the `claude-prototype.jsx` React prototype. Contains the TypeScript port of core game logic (move generation, win checking) for client-side play.

---

## Shared Data Contract

The puzzle JSON schema is the lingua franca across all three repos. Both clients produce and consume this format, and the API validates and stores it.

```typescript
// Shared puzzle schema — used by Godot, API, and Express
interface Puzzle {
  id: string;                    // "ch1_p01" or ULID for community puzzles
  title: string;
  description: string;
  hint: string;
  player: "white" | "black";
  board: (PieceCell | null)[][];  // 5×5
  win_condition: {
    type: "capture_chief" | "cross_piece";
    max_moves: number;
  };
  opponent_moves: string[];       // Algebraic notation: "Kd4", "Rxb3"
}

interface PieceCell {
  type: "CHIEF" | "KEEPER" | "HUNTER" | "RIVER_RUNNER" | "TRADER";
  player: "white" | "black";
}
```

---

## Devcontainer (Hub)

This repo's `.devcontainer/` serves as the **full-stack development environment**. It includes:

- **Godot 4.4** + export templates (game development)
- **Node.js 22** + npm (API and Express development)
- **Wrangler CLI** (Cloudflare Workers deployment)
- **Expo CLI** (PWA development)
- **GitHub CLI** (repo management, deployments)
- **Python 3.12** + GTK4 bindings (desktop level editor)
- **just** (task runner)

On container creation, the other two repos are cloned into `apps/`:

```
/workspaces/wachesaw/              ← this repo (Godot game)
├── core/                          ← game logic
├── data/story/                    ← chapter JSONs
├── tools/                         ← GTK4 level editor
├── apps/                          ← gitignored
│   ├── wachesaw-api/              ← cloned from doughatcher/wachesaw-api
│   └── wachesaw-express/          ← cloned from doughatcher/wachesaw-express
├── .devcontainer/                 ← full-stack container config
└── justfile                       ← recipes for all three repos
```

### Useful commands from the hub

| Command | What it does |
|---------|-------------|
| `just clone-apps` | Clone or pull the API and Express repos into `apps/` |
| `just api-dev` | Start Wrangler local dev server (port 8787) |
| `just api-deploy` | Deploy API to Cloudflare Workers (production) |
| `just api-deploy-staging` | Deploy API to staging environment |
| `just api-migrate` | Apply D1 database migrations |
| `just api-backup` | Manual D1 backup to R2 |
| `just express-dev` | Start Expo web dev server (port 8081) |
| `just express-build` | Static export of the Expo PWA |
| `just setup-cloudflare` | Interactive `wrangler login` |
| `just setup-gh` | Interactive `gh auth login` |

---

## Domain Plan

| Domain | Target | Hosting |
|--------|--------|---------|
| `wachesaw.app` | Expo PWA (level editor, daily puzzles, community) | GitHub Pages |
| `api.wachesaw.app` | Cloudflare Workers API | Cloudflare |
| `play.wachesaw.app` | Godot web build (full game) | GitHub Pages (this repo) |

---

## CI/CD

### wachesaw (this repo)
- **Push to `main`** → build Godot web export → deploy to GitHub Pages
- **GitHub Release** → build Linux/Windows/macOS/Web → attach to release

### wachesaw-api
- **Push to `main`** → lint + type-check + test → `wrangler deploy` (production)
- **Push to `develop` / PR** → lint + type-check + test → `wrangler deploy --env staging`
- **Pre-deploy** → D1 backup to R2, then apply migrations
- **Daily cron** → D1 backup to R2 (30 daily, 12 weekly, 12 monthly retention)
- **Weekly cron** → download latest backup, restore to temp D1, run integrity checks

### wachesaw-express
- **Push to `main`** → lint + type-check + test → `npx expo export --platform web` → deploy to GitHub Pages
- **PR** → lint + type-check + test → preview URL (optional)

---

## Sequence: New Feature Development

Example: adding a "favorite puzzles" feature.

1. **API** (`wachesaw-api`): Add `favorites` table, `POST/DELETE /puzzles/:id/favorite`, `GET /puzzles/favorites` endpoints. Deploy to staging.
2. **Express** (`wachesaw-express`): Add heart icon to puzzle cards, call the favorite endpoints, display favorites list. Test against staging API.
3. **Godot** (`wachesaw`): Add favorites menu in the community browser scene. Use `api_client.gd` to call the same endpoints. Test against staging API.
4. **Deploy**: Merge API → main (auto-deploys). Merge Express → main (auto-deploys). Merge Godot → main (web auto-deploys, desktop on next release).

---

## Technology Choices

| Choice | Why |
|--------|-----|
| **Separate repos** over monorepo | Each project has its own deploy lifecycle, dependencies, and CI. No coupling between Godot, Workers, and Expo toolchains. |
| **Clone into `apps/`** over git submodules | Submodules are brittle (detached HEAD, forgotten `--recurse`). Plain clones in a gitignored dir work with normal git workflows. |
| **Hub devcontainer** in Godot repo | This is the primary workspace. One container can develop and deploy all three projects. Other repos can have lightweight standalone configs. |
| **D1** over KV/Durable Objects | Relational data (foreign keys, joins for leaderboards, unique constraints). SQLite on the edge — fast reads, good enough writes. |
| **Resend** over SES/Mailgun | Simple API, Workers-friendly, generous free tier. |
| **Polling auth** over OAuth/deep links | Identical flow from Godot `HTTPRequest` and Expo `fetch`. No platform-specific auth code. |
| **Expo Web static export** over SSR | No server needed. Deploy to GitHub Pages like the Godot web build. |
| **Session tokens** over JWT | Stored in D1 — can be revoked on logout/account deletion. |
| **Keep repo named `wachesaw`** | Renaming breaks clones, bookmarks, CI URLs. Label as "wachesaw-godot" conceptually. |
