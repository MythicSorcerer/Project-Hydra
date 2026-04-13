#!/bin/bash
set -e

VERSION="${1:-$(git describe --tags --abbrev=0 | sed 's/^v//')}"
APP_NAME="Project Hydra"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
STAGING_DIR="${PROJECT_DIR}/dmg-staging"
DMG_NAME="Project-Hydra-v${VERSION}.dmg"

echo "🔨 Building ${APP_NAME} v${VERSION}..."

# Build the app
xcodebuild -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    CONFIGURATION_BUILD_DIR="${BUILD_DIR}" \
    clean build

# Create staging directory with Applications symlink
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# Create DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO -fs HFS+ \
    "${PROJECT_DIR}/${DMG_NAME}"

# Cleanup
rm -rf "${STAGING_DIR}"

echo "✅ DMG created: ${DMG_NAME}"
