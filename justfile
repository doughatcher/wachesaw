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

# Run headless (for testing core logic)
run-headless:
    godot --headless --script tests/run_tests.gd

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
