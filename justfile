# Wachesaw — Development Commands
# Usage: just <recipe>

# Default: list available recipes
default:
    @just --list

# ─── Project Setup ───────────────────────────────────────────────

# Create the directory structure per the spec
setup:
    mkdir -p core/ai
    mkdir -p presentation/ui
    mkdir -p presentation/particles
    mkdir -p presentation/themes/chess_classic
    mkdir -p presentation/themes/waccamaw
    mkdir -p presentation/audio
    mkdir -p network
    mkdir -p data/rules/variants
    mkdir -p data/maps/builtin
    mkdir -p data/maps/custom
    mkdir -p data/saves
    mkdir -p platform
    mkdir -p addons
    mkdir -p builds/web
    mkdir -p builds/android
    mkdir -p builds/ios
    mkdir -p builds/macos
    mkdir -p builds/linux
    mkdir -p builds/windows
    @echo "✓ Directory structure created"

# Import project resources (run after setup or adding new assets)
import:
    godot --headless --import 2>/dev/null || true
    @echo "✓ Project imported"

# ─── Development ─────────────────────────────────────────────────

# Open the Godot editor
editor:
    godot --editor &

# Run the game
run:
    godot --path . scenes/main.tscn

# Watch a map file for changes and hot-reload the puzzle on save.
# Builds web debug export, serves with live data, opens browser.
# Usage: just watch-map maps/custom/example_puzzle.json
watch-map path="maps/custom/example_puzzle.json" port="8000":
    just build-web-debug
    python3 tools/dev_server.py {{port}} --watch={{path}}

# Watch a story chapter file and hot-reload a specific puzzle on save.
# Builds web debug export, serves with live data, opens browser.
# Usage: just watch-story 1              (chapter 1, first puzzle)
#        just watch-story 1 ch1_p03      (chapter 1, puzzle ch1_p03)
#        just watch-story 2 3            (chapter 2, 3rd puzzle)
watch-story chapter="1" puzzle="" port="8000":
    just build-web-debug
    @if [ -n "{{puzzle}}" ]; then \
        python3 tools/dev_server.py {{port}} --watch=story/chapter_{{chapter}}.json --puzzle={{puzzle}}; \
    else \
        python3 tools/dev_server.py {{port}} --watch=story/chapter_{{chapter}}.json; \
    fi

# Start the dev server only (skip rebuild).
# Useful when you've already built and just want to restart the server.
# Usage: just serve-dev                  (port 8000)
#        just serve-dev 9000             (custom port)
serve-dev port="8000" watch="" puzzle="":
    @if [ -n "{{watch}}" ] && [ -n "{{puzzle}}" ]; then \
        python3 tools/dev_server.py {{port}} --watch={{watch}} --puzzle={{puzzle}}; \
    elif [ -n "{{watch}}" ]; then \
        python3 tools/dev_server.py {{port}} --watch={{watch}}; \
    else \
        python3 tools/dev_server.py {{port}}; \
    fi

# Open the GTK4 level editor (visual story/puzzle editor).
# Requires a display — uses X11 forwarding in the dev container.
# macOS host:  brew install xquartz && enable "Allow connections from network clients"
# Native macOS:  brew install gtk4 pygobject3 && python3 tools/level_editor.py
# Native Linux:  sudo apt-get install python3-gi gir1.2-gtk-4.0
# Usage: just level-editor                          (opens file chooser)
#        just level-editor data/story/chapter_1.json
level-editor path="":
    @if [ -n "{{path}}" ]; then \
        /usr/bin/python3 tools/level_editor.py {{path}}; \
    else \
        /usr/bin/python3 tools/level_editor.py; \
    fi

# Edit a story chapter in the GTK4 level editor.
# Usage: just edit-chapter 1
edit-chapter chapter="1":
    python3 tools/level_editor.py data/story/chapter_{{chapter}}.json

# ─── macOS Native ────────────────────────────────────────────────

# Godot version must match the project (see project.godot config/features).
GODOT_VERSION := "4.4"
GODOT_INSTALL_DIR := "/Applications/Godot_v" + GODOT_VERSION + ".app"
GODOT_BIN := GODOT_INSTALL_DIR + "/Contents/MacOS/Godot"

# Install macOS dependencies for the level editor and native Godot playback.
# Requires Homebrew (https://brew.sh). Run once after cloning.
# Installs Godot 4.4 specifically (brew cask installs latest which may be incompatible).
mac-setup:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Installing macOS dependencies via Homebrew…"
    brew install gtk4 pygobject3 gobject-introspection adwaita-icon-theme

    GODOT_VERSION="{{GODOT_VERSION}}"
    GODOT_FULL="Godot_v${GODOT_VERSION}-stable"
    INSTALL_DIR="{{GODOT_INSTALL_DIR}}"
    GODOT_BIN="${INSTALL_DIR}/Contents/MacOS/Godot"

    if [ -x "$GODOT_BIN" ]; then
        INSTALLED=$("$GODOT_BIN" --version 2>/dev/null | cut -d. -f1-2 || echo "")
        if [ "$INSTALLED" = "${GODOT_VERSION}" ]; then
            echo "✓ Godot ${GODOT_VERSION} already installed at ${INSTALL_DIR}"
        else
            echo "⚠ Godot at ${INSTALL_DIR} is version ${INSTALLED}, expected ${GODOT_VERSION}"
            echo "  Reinstalling…"
            rm -rf "$INSTALL_DIR"
        fi
    fi

    if [ ! -x "$GODOT_BIN" ]; then
        echo "Installing Godot ${GODOT_VERSION} for macOS…"
        URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${GODOT_FULL}_macos.universal.zip"
        TMPZIP="$(mktemp /tmp/godot-XXXX.zip)"
        echo "  Downloading from ${URL}…"
        curl -L -o "$TMPZIP" "$URL"
        echo "  Extracting to ${INSTALL_DIR}…"
        TMPDIR_EXTRACT="$(mktemp -d /tmp/godot-extract-XXXX)"
        unzip -q "$TMPZIP" -d "$TMPDIR_EXTRACT"
        # The zip contains a Godot.app folder — rename to include the version
        mv "$TMPDIR_EXTRACT/Godot.app" "$INSTALL_DIR"
        rm -rf "$TMPZIP" "$TMPDIR_EXTRACT"
        # Remove quarantine attribute so macOS doesn't block it
        xattr -rd com.apple.quarantine "$INSTALL_DIR" 2>/dev/null || true
        echo "✓ Godot ${GODOT_VERSION} installed at ${INSTALL_DIR}"
    fi

    echo ""
    echo "Verifying GTK4 Python bindings…"
    "$(brew --prefix)/bin/python3" -c \
        "import gi; gi.require_version('Gtk', '4.0'); from gi.repository import Gtk; print('✓ GTK4 bindings OK')"

    echo ""
    echo "Verifying Godot…"
    "$GODOT_BIN" --version

    echo ""
    echo "Importing project resources…"
    "$GODOT_BIN" --headless --import 2>/dev/null || true

    # ── Create Spotlight-launchable .app shortcuts ──────────────────
    PROJECT_DIR="$(pwd)"
    BREW_PYTHON="$(brew --prefix)/bin/python3"
    APPS_DIR="$HOME/Applications"
    mkdir -p "$APPS_DIR"

    # — Wachesaw.app (launches the game) —
    GAME_APP="$APPS_DIR/Wachesaw.app"
    rm -rf "$GAME_APP"
    mkdir -p "$GAME_APP/Contents/MacOS"
    cat > "$GAME_APP/Contents/Info.plist" << PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleName</key>
        <string>Wachesaw</string>
        <key>CFBundleIdentifier</key>
        <string>com.wachesaw.game</string>
        <key>CFBundleExecutable</key>
        <string>launch</string>
        <key>CFBundleVersion</key>
        <string>1.0</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
    </dict>
    </plist>
    PLIST
    # Strip leading whitespace from heredoc (justfile indents it)
    sed -i '' 's/^    //' "$GAME_APP/Contents/Info.plist"

    cat > "$GAME_APP/Contents/MacOS/launch" << 'LAUNCH'
    #!/usr/bin/env bash
    LAUNCH
    # Write the script body with resolved paths
    cat >> "$GAME_APP/Contents/MacOS/launch" << LAUNCH
    exec "$GODOT_BIN" --path "$PROJECT_DIR"
    LAUNCH
    sed -i '' 's/^    //' "$GAME_APP/Contents/MacOS/launch"
    chmod +x "$GAME_APP/Contents/MacOS/launch"
    echo "✓ Created $GAME_APP"

    # — Wachesaw Level Editor.app —
    EDITOR_APP="$APPS_DIR/Wachesaw Level Editor.app"
    rm -rf "$EDITOR_APP"
    mkdir -p "$EDITOR_APP/Contents/MacOS"
    cat > "$EDITOR_APP/Contents/Info.plist" << PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleName</key>
        <string>Wachesaw Level Editor</string>
        <key>CFBundleIdentifier</key>
        <string>com.wachesaw.level-editor</string>
        <key>CFBundleExecutable</key>
        <string>launch</string>
        <key>CFBundleVersion</key>
        <string>1.0</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
    </dict>
    </plist>
    PLIST
    sed -i '' 's/^    //' "$EDITOR_APP/Contents/Info.plist"

    cat > "$EDITOR_APP/Contents/MacOS/launch" << 'LAUNCH'
    #!/usr/bin/env bash
    LAUNCH
    cat >> "$EDITOR_APP/Contents/MacOS/launch" << LAUNCH
    exec "$BREW_PYTHON" "$PROJECT_DIR/tools/level_editor.py" --native --godot-path="$GODOT_BIN"
    LAUNCH
    sed -i '' 's/^    //' "$EDITOR_APP/Contents/MacOS/launch"
    chmod +x "$EDITOR_APP/Contents/MacOS/launch"
    echo "✓ Created $EDITOR_APP"

    echo ""
    echo "✓ macOS setup complete."
    echo "  Spotlight shortcuts installed in ~/Applications/:"
    echo "    • Wachesaw             — launches the game"
    echo "    • Wachesaw Level Editor — opens the level editor"
    echo "  Run: just mac-level-editor"

# Open the level editor with native Godot playback (macOS).
# When you hit Play, Godot launches natively instead of using a web browser.
# Usage: just mac-level-editor                            (opens file chooser)
#        just mac-level-editor data/story/chapter_1.json
mac-level-editor path="":
    #!/usr/bin/env bash
    set -euo pipefail
    BREW_PYTHON="$(brew --prefix)/bin/python3"
    GODOT="${GODOT_PATH:-{{GODOT_BIN}}}"
    if [ ! -x "$GODOT" ]; then
        echo "✗ Godot not found at $GODOT"
        echo "  Run: just mac-setup"
        echo "  Or set GODOT_PATH to your Godot 4.4 binary"
        exit 1
    fi
    if [ -n "{{path}}" ]; then
        "$BREW_PYTHON" tools/level_editor.py --native --godot-path="$GODOT" {{path}}
    else
        "$BREW_PYTHON" tools/level_editor.py --native --godot-path="$GODOT"
    fi

# Edit a story chapter with native Godot playback (macOS).
# Usage: just mac-edit-chapter 1
mac-edit-chapter chapter="1":
    just mac-level-editor data/story/chapter_{{chapter}}.json

# Run headless (for testing core logic)
run-headless:
    godot --headless --script tests/run_tests.gd

# ─── Multi-Repo (API + Express) ─────────────────────────────────

# Clone or update the API and Express repos into apps/
clone-apps:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p apps
    if [ -d apps/wachesaw-api ]; then
        echo "Pulling wachesaw-api…"
        cd apps/wachesaw-api && git pull && cd ../..
    else
        echo "Cloning wachesaw-api…"
        gh repo clone doughatcher/wachesaw-api apps/wachesaw-api
    fi
    if [ -d apps/wachesaw-express ]; then
        echo "Pulling wachesaw-express…"
        cd apps/wachesaw-express && git pull && cd ../..
    else
        echo "Cloning wachesaw-express…"
        gh repo clone doughatcher/wachesaw-express apps/wachesaw-express
    fi
    cd apps/wachesaw-api && npm install
    cd ../wachesaw-express && npm install
    echo "✓ All app repos ready"

# Start the Cloudflare Workers API locally (port 8787)
api-dev:
    cd apps/wachesaw-api && npx wrangler dev

# Deploy the API to Cloudflare Workers (production)
api-deploy:
    cd apps/wachesaw-api && npx wrangler deploy

# Deploy the API to staging
api-deploy-staging:
    cd apps/wachesaw-api && npx wrangler deploy --env staging

# Apply D1 database migrations
api-migrate env="production":
    cd apps/wachesaw-api && npx wrangler d1 migrations apply WACHESAW_DB --env {{env}}

# Manual D1 backup to R2
api-backup:
    #!/usr/bin/env bash
    set -euo pipefail
    cd apps/wachesaw-api
    TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
    npx wrangler d1 export WACHESAW_DB --output="/tmp/wachesaw-db-${TIMESTAMP}.sql"
    gzip "/tmp/wachesaw-db-${TIMESTAMP}.sql"
    npx wrangler r2 object put "wachesaw-backups/daily/wachesaw-db-${TIMESTAMP}.sql.gz" \
        --file="/tmp/wachesaw-db-${TIMESTAMP}.sql.gz"
    rm "/tmp/wachesaw-db-${TIMESTAMP}.sql.gz"
    echo "✓ Backup uploaded: daily/wachesaw-db-${TIMESTAMP}.sql.gz"

# Start the Expo web dev server (port 8081)
express-dev:
    cd apps/wachesaw-express && npx expo start --web --port 8081

# Build the Expo PWA static export
express-build:
    cd apps/wachesaw-express && npx expo export --platform web

# Interactive Cloudflare login
setup-cloudflare:
    npx wrangler login

# Interactive GitHub CLI login
setup-gh:
    gh auth login

# ─── Builds ──────────────────────────────────────────────────────

# Build for web (works on Linux — test on any device via browser)
build-web:
    git rev-parse --short HEAD > core/git_sha.txt
    mkdir -p builds/web
    godot --headless --export-release "Web" builds/web/index.html
    @echo "✓ Web build complete: builds/web/"

# Build for web (debug)
build-web-debug:
    git rev-parse --short HEAD > core/git_sha.txt
    mkdir -p builds/web
    godot --headless --export-debug "Web" builds/web/index.html
    @echo "✓ Web debug build complete: builds/web/"

# Build for Linux
build-linux:
    mkdir -p builds/linux
    godot --headless --export-release "Linux/X11" builds/linux/wachesaw.x86_64
    @echo "✓ Linux build complete: builds/linux/"

# Build for macOS (export from Linux, notarize on Mac)
build-macos:
    mkdir -p builds/macos
    godot --headless --export-release "macOS" builds/macos/wachesaw.zip
    @echo "✓ macOS build complete: builds/macos/"

# Build for Windows
build-windows:
    mkdir -p builds/windows
    godot --headless --export-release "Windows Desktop" builds/windows/wachesaw.exe
    @echo "✓ Windows build complete: builds/windows/"

# Build for Android (debug APK)
build-android-debug:
    mkdir -p builds/android
    godot --headless --export-debug "Android" builds/android/wachesaw.apk
    @echo "✓ Android debug build: builds/android/wachesaw.apk"

# Build for Android (release AAB)
build-android:
    mkdir -p builds/android
    godot --headless --export-release "Android" builds/android/wachesaw.aab
    @echo "✓ Android release build: builds/android/wachesaw.aab"

# Build for iOS (generates Xcode project — open on Mac)
build-ios:
    mkdir -p builds/ios
    godot --headless --export-release "iOS" builds/ios/wachesaw.xcodeproj
    @echo "✓ iOS export: builds/ios/wachesaw.xcodeproj (open in Xcode on Mac)"

# Build all desktop + web
build-all: build-web build-linux build-macos build-windows
    @echo "✓ All builds complete"

# ─── Serve & Test ────────────────────────────────────────────────

# Serve web build on LAN (test on phone at http://<your-ip>:8000)
serve port="8000":
    @echo "Serving web build at http://$(hostname -I | awk '{print $1}'):{{port}}"
    @echo "Open this URL on your phone/tablet to test"
    cd builds/web && python3 -m http.server {{port}} --bind 0.0.0.0

# Serve with CORS/COOP headers (needed if threads enabled)
serve-coop port="8000":
    @echo "Serving with Cross-Origin-Isolation headers at http://$(hostname -I | awk '{print $1}'):{{port}}"
    cd builds/web && python3 -c "\
    from http.server import HTTPServer, SimpleHTTPRequestHandler; \
    class H(SimpleHTTPRequestHandler): \
        def end_headers(self): \
            self.send_header('Cross-Origin-Opener-Policy', 'same-origin'); \
            self.send_header('Cross-Origin-Embedder-Policy', 'require-corp'); \
            super().end_headers(); \
    HTTPServer(('0.0.0.0', {{port}}), H).serve_forever()"

# Install debug APK on connected Android device
install-android:
    adb install builds/android/wachesaw.apk

# ─── Clean ───────────────────────────────────────────────────────

# Remove all builds
clean:
    rm -rf builds/web/* builds/android/* builds/ios/* builds/macos/* builds/linux/* builds/windows/*
    @echo "✓ Builds cleaned"

# Remove Godot import cache
clean-cache:
    rm -rf .godot/
    @echo "✓ Cache cleaned"

# Full clean
clean-all: clean clean-cache

# ─── Release ─────────────────────────────────────────────────────

# Create a GitHub release with auto-generated notes.
# Usage: just release        (auto-bumps patch: 0.1.0 → 0.1.1)
#        just release patch   (same as above)
#        just release minor   (0.1.1 → 0.2.0)
#        just release major   (0.2.0 → 1.0.0)
release bump="patch":
    #!/usr/bin/env bash
    set -euo pipefail

    # Ensure working tree is clean
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "✗ Working tree is dirty. Commit or stash changes first."
        exit 1
    fi

    # Read current version from project.godot
    CURRENT=$(grep 'config/version=' project.godot | sed 's/config\/version="//' | sed 's/"//')
    if [[ -z "$CURRENT" ]]; then
        echo "✗ Could not read version from project.godot"
        exit 1
    fi

    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
    BUMP="{{bump}}"

    case "$BUMP" in
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        patch)
            PATCH=$((PATCH + 1))
            ;;
        *)
            echo "✗ Invalid bump type '$BUMP'. Use: major, minor, or patch"
            exit 1
            ;;
    esac

    VERSION="${MAJOR}.${MINOR}.${PATCH}"
    TAG="v${VERSION}"

    echo "Bumping version: $CURRENT → $VERSION"

    # Update version in project.godot
    sed -i "s/config\/version=\"$CURRENT\"/config\/version=\"$VERSION\"/" project.godot

    # Update version in export_presets.cfg
    sed -i "s/short_version=\"$CURRENT\"/short_version=\"$VERSION\"/g" export_presets.cfg
    sed -i "s/version\/name=\"$CURRENT\"/version\/name=\"$VERSION\"/g" export_presets.cfg
    sed -i "s|application/version=\"$CURRENT\"|application/version=\"$VERSION\"|g" export_presets.cfg

    # Update version in build_info.gd
    sed -i "s/const VERSION := \"$CURRENT\"/const VERSION := \"$VERSION\"/" core/build_info.gd

    # Commit the version bump
    git add project.godot export_presets.cfg core/build_info.gd
    git commit -m "bump version to $VERSION"
    git push origin HEAD

    # Get the previous tag for changelog range
    PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    # Build release notes
    NOTES="## Wachesaw $TAG\n\n"
    NOTES+="**Released:** $(date +%Y-%m-%d)\n\n"

    if [[ -n "$PREV_TAG" ]]; then
        NOTES+="### Changes since $PREV_TAG\n\n"
        NOTES+="$(git log ${PREV_TAG}..HEAD --pretty=format:'- %s (%h)' --no-merges)\n\n"
    else
        NOTES+="### Changes\n\n"
        NOTES+="$(git log --pretty=format:'- %s (%h)' --no-merges -20)\n\n"
    fi

    NOTES+="### Downloads\n\n"
    NOTES+="| Platform | File |\n"
    NOTES+="|----------|------|\n"
    NOTES+="| Linux x86_64 | \`wachesaw-linux-x86_64.zip\` |\n"
    NOTES+="| Windows x86_64 | \`wachesaw-windows-x86_64.zip\` |\n"
    NOTES+="| macOS | \`wachesaw-macos.zip\` |\n"
    NOTES+="| Web | \`wachesaw-web.zip\` |\n\n"
    NOTES+="### Build Info\n\n"
    NOTES+="- Godot 4.4\n"
    NOTES+="- Commit: $(git rev-parse --short HEAD)\n"

    echo -e "$NOTES"
    echo ""
    echo "Creating release $TAG..."

    # Tag and push
    git tag -a "$TAG" -m "Release $TAG"
    git push origin "$TAG"

    # Create GitHub release (triggers the CI build + upload)
    echo -e "$NOTES" | gh release create "$TAG" \
        --title "Wachesaw $TAG" \
        --notes-file - \
        --latest

    echo ""
    echo "✓ Release $TAG created!"
    echo "  GitHub Actions will now build and attach desktop binaries."
    echo "  Monitor at: https://github.com/doughatcher/wachesaw/actions"
