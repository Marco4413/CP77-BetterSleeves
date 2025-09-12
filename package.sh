#!/bin/bash

set -xe

ARCHIVE_VERSION='1.2'
MOD_VERSION="$( git describe --tags --abbrev=0 --match='v*' | sed s/^v// )"

BASE='./build'
ARCHIVE_TARGET="./$BASE/archive/pc/mod"
CET_TARGET="./$BASE/bin/x64/plugins/cyber_engine_tweaks/mods"

mkdir -p "$ARCHIVE_TARGET"
mkdir -p "$CET_TARGET"

cp './archive/pc/mod/BetterSleeves - Archive Fixes.archive' "$ARCHIVE_TARGET/"

CET_FILES=( 'init.lua' 'BetterUI.lua' 'Scheduler.lua' 'README.md' 'LICENSE.md' )
for file in "${CET_FILES[@]}"; do
    cp "$file" "$CET_TARGET"
done

mkdir -p "$CET_TARGET/data"
echo 'Thank you.' > "$CET_TARGET/data/PLEASE_VORTEX_DONT_IGNORE_THIS_FOLDER"

WORKING_DIR="$( pwd )"
cd "$BASE"

ARTIFACT_DIR="$WORKING_DIR/artifact"
mkdir -p "$ARTIFACT_DIR"

zip -9 -r "$ARTIFACT_DIR/BetterSleeves-$MOD_VERSION.zip" archive bin
zip -9 -r "$ARTIFACT_DIR/BetterSleeves_CET_Only-$MOD_VERSION.zip" bin
zip -9 -r "$ARTIFACT_DIR/BetterSleeves_ArchiveFixes-$ARCHIVE_VERSION.zip" archive

cd "$WORKING_DIR"
