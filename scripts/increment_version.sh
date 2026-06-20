#!/bin/bash

# Script to increment app version in pubspec.yaml
# Usage: ./scripts/increment_version.sh [major|minor|patch|build]
# Default: build (increments build number/version code)
#
# The version is written explicitly into every platform file (like NatureOnTrail),
# so each build picks it up no matter how it is built:
#   - pubspec.yaml                       -> version: x.y.z+build
#   - android/app/build.gradle.kts       -> versionCode / versionName (literal values)
#   - ios/Runner/Info.plist              -> CFBundleShortVersionString / CFBundleVersion
#   - ios/Runner.xcodeproj/project.pbxproj -> MARKETING_VERSION / CURRENT_PROJECT_VERSION

set -e

# Always operate from the project root (this script's parent directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

PUBSPEC_FILE="pubspec.yaml"

if [ ! -f "$PUBSPEC_FILE" ]; then
    echo "Error: $PUBSPEC_FILE not found"
    exit 1
fi

# Read current version from pubspec.yaml
# Format: version: 1.0.0+3 (versionName+buildNumber)
CURRENT_VERSION_LINE=$(grep "^version: " "$PUBSPEC_FILE" | head -1)
if [ -z "$CURRENT_VERSION_LINE" ]; then
    echo "Error: Could not find version line in $PUBSPEC_FILE"
    exit 1
fi

# Extract version string (e.g., "1.0.0+3")
CURRENT_VERSION=$(echo "$CURRENT_VERSION_LINE" | sed 's/version: //' | tr -d ' ')

# Parse version name and build number
VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)

if [ -z "$VERSION_NAME" ] || [ -z "$BUILD_NUMBER" ]; then
    echo "Error: Invalid version format in $PUBSPEC_FILE. Expected format: 1.0.0+3"
    exit 1
fi

# Parse version name (format: major.minor.patch)
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_NAME"

# Determine what to increment
INCREMENT_TYPE=${1:-build}

case $INCREMENT_TYPE in
    major)
        # Increment major version and reset minor/patch, bump build number
        MAJOR=$((MAJOR + 1))
        NEW_VERSION_NAME="$MAJOR.0.0"
        NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
        ;;
    minor)
        # Increment minor version and reset patch, bump build number
        MINOR=$((MINOR + 1))
        NEW_VERSION_NAME="$MAJOR.$MINOR.0"
        NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
        ;;
    patch)
        # Increment patch version, bump build number
        PATCH=$((PATCH + 1))
        NEW_VERSION_NAME="$MAJOR.$MINOR.$PATCH"
        NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
        ;;
    build)
        # Increment build number (version code) and patch version - default
        PATCH=$((PATCH + 1))
        NEW_VERSION_NAME="$MAJOR.$MINOR.$PATCH"
        NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
        ;;
    *)
        echo "Usage: $0 [major|minor|patch|build]"
        echo "  major  - Increment major version (1.0.0+3 -> 2.0.0+4)"
        echo "  minor  - Increment minor version (1.0.0+3 -> 1.1.0+4)"
        echo "  patch  - Increment patch version (1.0.0+3 -> 1.0.1+4)"
        echo "  build  - Increment patch + build number/version code (1.0.0+3 -> 1.0.1+4) [default]"
        echo ""
        echo "Note: Flutter uses pubspec.yaml for version management."
        echo "      versionName = first part (e.g., 1.0.0)"
        echo "      versionCode = number after + (e.g., 3)"
        exit 1
        ;;
esac

NEW_VERSION="$NEW_VERSION_NAME+$NEW_BUILD_NUMBER"

# Update pubspec.yaml
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC_FILE"
else
    # Linux
    sed -i "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC_FILE"
fi

# Update iOS Info.plist
INFO_PLIST="ios/Runner/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        plutil -replace CFBundleShortVersionString -string "$NEW_VERSION_NAME" "$INFO_PLIST"
        plutil -replace CFBundleVersion -string "$NEW_BUILD_NUMBER" "$INFO_PLIST"
    else
        # Linux
        sed -i "/CFBundleShortVersionString/{n;s|<string>.*</string>|<string>$NEW_VERSION_NAME</string>|;}" "$INFO_PLIST"
        sed -i "/CFBundleVersion/{n;s|<string>.*</string>|<string>$NEW_BUILD_NUMBER</string>|;}" "$INFO_PLIST"
    fi
    echo "✓ Version updated in $INFO_PLIST"
fi

# Update project.pbxproj
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
if [ -f "$PBXPROJ" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $NEW_VERSION_NAME;/" "$PBXPROJ"
        sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD_NUMBER;/" "$PBXPROJ"
    else
        sed -i "s/MARKETING_VERSION = .*/MARKETING_VERSION = $NEW_VERSION_NAME;/" "$PBXPROJ"
        sed -i "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD_NUMBER;/" "$PBXPROJ"
    fi
    echo "✓ Version updated in $PBXPROJ"
fi

# Update Android build.gradle.kts (literal versionCode / versionName), like NatureOnTrail.
GRADLE_FILE="android/app/build.gradle.kts"
if [ -f "$GRADLE_FILE" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/versionCode = [0-9]*/versionCode = $NEW_BUILD_NUMBER/" "$GRADLE_FILE"
        sed -i '' "s/versionName = \".*\"/versionName = \"$NEW_VERSION_NAME\"/" "$GRADLE_FILE"
    else
        # Linux
        sed -i "s/versionCode = [0-9]*/versionCode = $NEW_BUILD_NUMBER/" "$GRADLE_FILE"
        sed -i "s/versionName = \".*\"/versionName = \"$NEW_VERSION_NAME\"/" "$GRADLE_FILE"
    fi
    echo "✓ Version updated in $GRADLE_FILE"
fi

echo "✓ Version updated in $PUBSPEC_FILE"
echo "  Version name: $VERSION_NAME -> $NEW_VERSION_NAME"
echo "  Version code (build): $BUILD_NUMBER -> $NEW_BUILD_NUMBER"
echo "  Full version: $CURRENT_VERSION -> $NEW_VERSION"
echo ""
echo "Remember: Google Play uses versionCode (the number after +) to determine updates."
echo "          Always increment the build number (+X) for each new release upload."
