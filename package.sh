#!/bin/bash

set -xe

ARCHIVE_VERSION='1.2'
MOD_VERSION="$( git describe --tags --abbrev=0 --match='v*' | sed s/^v// )"

BASE='./build'
ARTIFACT_DIR="./artifact"

ARCHIVE_TARGET="./$BASE/archive/pc/mod"
CET_TARGET="./$BASE/bin/x64/plugins/cyber_engine_tweaks/mods/BetterSleeves"

mkdir -p "$ARTIFACT_DIR"
mkdir -p "$ARCHIVE_TARGET"
mkdir -p "$CET_TARGET"

cp './archive/pc/mod/BetterSleeves - Archive Fixes.archive' "$ARCHIVE_TARGET/"

CET_FILES=( 'init.lua' 'BetterUI.lua' 'Scheduler.lua' 'README.md' 'LICENSE.md' )
for file in "${CET_FILES[@]}"; do
    cp "$file" "$CET_TARGET"
done

mkdir -p "$CET_TARGET/data"
echo 'Thank you.' > "$CET_TARGET/data/PLEASE_VORTEX_DONT_IGNORE_THIS_FOLDER"

7z a -mx9 -r -- "$ARTIFACT_DIR/BetterSleeves-$MOD_VERSION.zip"                  "./$BASE/archive" "./$BASE/bin"
7z a -mx9 -r -- "$ARTIFACT_DIR/BetterSleeves_CET_Only-$MOD_VERSION.zip"         "./$BASE/bin"
7z a -mx9 -r -- "$ARTIFACT_DIR/BetterSleeves_ArchiveFixes-$ARCHIVE_VERSION.zip" "./$BASE/archive"
