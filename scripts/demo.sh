#!/bin/bash
# Demo mode launcher for ClaudeMeter (macOS)
# Builds and runs the app with selected demo mode

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="ClaudeMeter"

# Demo modes (from DemoMode.swift)
MODES=(
    "safeUsage|Low usage - safe state"
    "warningUsage|Medium usage - warning state"
    "criticalUsage|High usage - critical state"
    "exceededUsage|Over limit - exceeded state"
    "withSonnet|Shows Sonnet usage card"
    "loading|Loading spinner visible"
    "error|Error banner displayed"
    "setupWizard|First-time setup screen"
)

echo "=== ClaudeMeter Demo Mode Launcher ==="
echo ""
echo "Select a demo mode:"
echo ""

for i in "${!MODES[@]}"; do
    mode="${MODES[$i]%%|*}"
    desc="${MODES[$i]#*|}"
    printf "  %d) %-20s - %s\n" $((i+1)) "$mode" "$desc"
done

echo ""
read -p "Enter choice [1-${#MODES[@]}]: " choice

if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#MODES[@]} ]; then
    echo "Invalid choice"
    exit 1
fi

SELECTED="${MODES[$((choice-1))]}"
SELECTED_MODE="${SELECTED%%|*}"
echo ""
echo "Selected: $SELECTED_MODE"
echo ""

# Build the app
echo "Building $SCHEME..."
BUILD_DIR="$PROJECT_DIR/.build"
xcodebuild -project "$PROJECT_DIR/ClaudeMeter.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    build | xcbeautify 2>/dev/null || \
xcodebuild -project "$PROJECT_DIR/ClaudeMeter.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    build 2>&1 | tail -20

# Find the built app
APP_PATH=$(find "$BUILD_DIR/Build/Products" -name "ClaudeMeter.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built app in $BUILD_DIR/Build/Products"
    find "$BUILD_DIR" -name "*.app" -type d 2>/dev/null || echo "No .app bundles found"
    exit 1
fi

echo "Found app: $APP_PATH"

# Kill any existing instance
pkill -f "ClaudeMeter.app" 2>/dev/null || true
sleep 0.5

# Launch with demo argument
echo "Launching with --demo $SELECTED_MODE..."
open -a "$APP_PATH" --args --demo "$SELECTED_MODE"

echo ""
echo "Done! App launched with demo mode: $SELECTED_MODE"
