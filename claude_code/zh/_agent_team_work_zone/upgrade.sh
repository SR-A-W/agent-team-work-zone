#!/usr/bin/env bash
#
# upgrade.sh — one-button upgrade for _agent_team_work_zone.
#
# Run from anywhere inside your project (or directly from the framework dir):
#
#   bash _agent_team_work_zone/upgrade.sh
#
# No arguments. Paths are derived from $0:
#   SCRIPT_DIR  = the _agent_team_work_zone/ directory this file lives in
#   TARGET_DIR  = SCRIPT_DIR  (this install upgrades itself)
#   PROJECT_ROOT = parent of SCRIPT_DIR
#
# What it does:
#   1. Creates a temp dir + EXIT trap so $TMP is always cleaned up.
#   2. Downloads the latest framework from GitHub (main branch) via curl+tar.
#   3. Verifies the download contains a VERSION file.
#   4. Copies the downloaded template into .upgrade/ staging.
#   5. Invokes the migration-chain dispatcher: .upgrade/resources/scripts/upgrade.sh
#   6. $TMP auto-cleaned by EXIT trap.
#
# The dispatcher (step 5) owns bootstrap, staging cleanup, and version writes.
# Any failure in the dispatcher is passed through verbatim — do not suppress it.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

REPO_ARCHIVE_URL="${UPGRADE_REPO_URL:-https://github.com/SR-A-W/agent-team-work-zone/archive/refs/heads/main.tar.gz}"
TEMPLATE_PATH_IN_ARCHIVE="agent-team-work-zone-main/claude_code/zh/_agent_team_work_zone"

# -------- Minimal inline print helpers (common.sh is in staged source, not here) --------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    _R=$'\033[0m'; _B=$'\033[1m'; _RED=$'\033[31m'; _GRN=$'\033[32m'; _YLW=$'\033[33m'; _CYN=$'\033[36m'
else
    _R=""; _B=""; _RED=""; _GRN=""; _YLW=""; _CYN=""
fi
_header() { printf '%s==================================================%s\n%s  %s%s\n%s==================================================%s\n' "$_B" "$_R" "$_B$_CYN" "$1" "$_R" "$_B" "$_R"; }
_ok()     { printf '%s✓%s %s\n' "$_GRN" "$_R" "$1"; }
_warn()   { printf '%s⚠%s %s\n' "$_YLW" "$_R" "$1"; }
_err()    { printf '%s✗%s %s\n' "$_RED" "$_R" "$1"; }
_step()   { printf '  → %s\n' "$1"; }

# -------- Temp dir + guaranteed cleanup --------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

_header "_agent_team_work_zone one-button upgrade"
printf 'Target:       %s\n' "$TARGET_DIR"
printf 'Project root: %s\n' "$PROJECT_ROOT"
echo ""

# -------- Step 1: Download latest framework --------
_header "Downloading latest framework"
_step "GET $REPO_ARCHIVE_URL"

if ! curl -fsSL "$REPO_ARCHIVE_URL" | tar xz -C "$TMP"; then
    _err "Download or extraction failed."
    _err "Check your internet connection and that the repo URL is reachable:"
    _err "  $REPO_ARCHIVE_URL"
    exit 1
fi

_ok "Downloaded and extracted to $TMP"
echo ""

# -------- Step 2: Verify the extract looks like a valid framework --------
EXTRACTED_DIR="$TMP/$TEMPLATE_PATH_IN_ARCHIVE"
EXTRACTED_VERSION_FILE="$EXTRACTED_DIR/VERSION"

if [ ! -f "$EXTRACTED_VERSION_FILE" ]; then
    _err "Extracted archive does not contain expected VERSION file."
    _err "  Expected: $EXTRACTED_VERSION_FILE"
    _err "Archive layout may have changed; cannot proceed."
    exit 1
fi

NEW_VERSION="$(tr -d '[:space:]' < "$EXTRACTED_VERSION_FILE")"
_ok "Verified framework $NEW_VERSION at $EXTRACTED_DIR"
echo ""

# -------- Step 3: Populate .upgrade/ staging --------
_header "Staging new framework"
UPGRADE_DIR="$TARGET_DIR/.upgrade"
mkdir -p "$UPGRADE_DIR"
_step "Copying $EXTRACTED_DIR → $UPGRADE_DIR"

if ! cp -r "$EXTRACTED_DIR/." "$UPGRADE_DIR/"; then
    _err "Failed to copy extracted framework into $UPGRADE_DIR"
    _err "Cleaning up partial staging area."
    find "$UPGRADE_DIR" -mindepth 1 ! -name README.md -exec rm -rf {} + 2>/dev/null || true
    exit 1
fi

_ok "Staged $NEW_VERSION into $UPGRADE_DIR"
echo ""

# -------- Step 4: Hand off to migration-chain dispatcher --------
DISPATCHER="$UPGRADE_DIR/resources/scripts/upgrade.sh"

if [ ! -f "$DISPATCHER" ]; then
    _err "Migration dispatcher not found at expected path:"
    _err "  $DISPATCHER"
    _err "The staged archive may be incomplete. Staging area preserved for inspection."
    exit 1
fi

_header "Invoking migration dispatcher"
_step "bash $DISPATCHER"
echo ""

# Dispatcher owns its own output, cleanup, bootstrap, and exit code.
# Exported in case dispatcher or bootstrap reads it from env; dispatcher also re-derives it.
export PROJECT_ROOT
bash "$DISPATCHER"
# $TMP cleaned by EXIT trap after dispatcher returns (or fails).
