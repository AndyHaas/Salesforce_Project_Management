#!/usr/bin/env bash
# Create a 2GP package version (with code coverage), record Ids + install links in
# scripts/package-release-state.json, then optionally promote with --no-prompt.
#
# Package validation runs in a scratch-shaped org that does not use your Dev Hub's
# manual Setup toggles. Lightning email template folders (EmailTemplateFolder, nested
# SFX templates) require Folders and Enhanced Sharing in that validation org—see
# scratch-defs/package-version-scratch-def.json (not under config/ — that path is
# gitignored). Add scratch "features" or other settings there only if validation
# errors point to them (e.g. SharingSet, CDC).
#
# Usage:
#   ./scripts/package-version-release.sh create [--force]
#   ./scripts/package-version-release.sh promote
#   ./scripts/package-version-release.sh status
#
# Environment (optional):
#   TARGET_DEV_HUB   default: milestoneDevHub
#   PACKAGE_NAME     default: Milestone Project Management Core

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

DEV_HUB="${TARGET_DEV_HUB:-milestoneDevHub}"
PACKAGE_NAME="${PACKAGE_NAME:-Milestone Project Management Core}"
PY="${PYTHON:-python3}"

usage() {
  echo "Usage: $0 {create [--force]|promote|status}" >&2
  exit 1
}

cmd_create() {
  local force_flag=()
  if [[ "${1:-}" == "--force" ]]; then
    force_flag=(--force)
  fi

  local log
  log="$(mktemp -t pkg-version-create.XXXXXX)"
  trap 'rm -f "${log}"' RETURN

  set +e
  sf package version create \
    --package "${PACKAGE_NAME}" \
    --installation-key-bypass \
    --code-coverage \
    --wait 120 \
    --target-dev-hub "${DEV_HUB}" \
    --definition-file "${REPO_ROOT}/scratch-defs/package-version-scratch-def.json" \
    2>&1 | tee "${log}"
  local pstat=("${PIPESTATUS[@]}")
  set -e
  if [[ "${pstat[0]}" -ne 0 ]]; then
    echo "sf package version create failed (exit ${pstat[0]})." >&2
    rm -f "${log}"
    return "${pstat[0]}"
  fi

  "${PY}" "${SCRIPT_DIR}/package_release_state.py" ingest-create-log "${log}" "${force_flag[@]}"
}

cmd_promote() {
  local sub
  if ! sub="$("${PY}" "${SCRIPT_DIR}/package_release_state.py" get-pending-subscriber-id)"; then
    echo "No pending subscriber package version Id. Run create first (see status)." >&2
    exit 1
  fi

  echo "Promoting ${sub} on Dev Hub ${DEV_HUB} (--no-prompt)..."
  sf package version promote \
    --package "${sub}" \
    --target-dev-hub "${DEV_HUB}" \
    --no-prompt

  "${PY}" "${SCRIPT_DIR}/package_release_state.py" mark-promoted "${sub}"
}

cmd_status() {
  "${PY}" "${SCRIPT_DIR}/package_release_state.py" status
}

case "${1:-}" in
  create)
    shift || true
    cmd_create "${@:-}"
    ;;
  promote)
    cmd_promote
    ;;
  status)
    cmd_status
    ;;
  *)
    usage
    ;;
esac
