#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
RELEASE_DIR="$ROOT_DIR/.release"
ADDON_DIR="$RELEASE_DIR/TalentPlanner"
VERSION="$(awk '/^## Version:/ { print $3; exit }' "$ROOT_DIR/TalentPlanner_Vanilla.toc")"
BRANCH="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
SAFE_BRANCH="$(printf '%s' "$BRANCH" | tr '/' '-')"
ZIP_NAME="TalentPlanner-${VERSION}-${SAFE_BRANCH}.zip"

rm -rf "$RELEASE_DIR"
mkdir -p "$ADDON_DIR"

cp "$ROOT_DIR"/*.lua "$ADDON_DIR"/
cp "$ROOT_DIR"/*.toc "$ADDON_DIR"/
cp "$ROOT_DIR"/README.MD "$ADDON_DIR"/
cp "$ROOT_DIR"/LICENSE "$ADDON_DIR"/
cp "$ROOT_DIR"/changes.log "$ADDON_DIR"/

for subdir in Core Importers Localization UI; do
    mkdir -p "$ADDON_DIR/$subdir"
    cp "$ROOT_DIR/$subdir"/*.lua "$ADDON_DIR/$subdir"/
    # Copy XML files if present (e.g. Localization loader)
    for f in "$ROOT_DIR/$subdir"/*.xml; do
        [ -e "$f" ] && cp "$f" "$ADDON_DIR/$subdir"/
    done
done

(
    cd "$RELEASE_DIR"
    zip -r "$ZIP_NAME" TalentPlanner -x ".*" -x "__MACOSX"
)

echo "Created $RELEASE_DIR/$ZIP_NAME"
