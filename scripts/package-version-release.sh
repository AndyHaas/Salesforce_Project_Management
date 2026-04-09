#!/usr/bin/env bash
# Create a 2GP package version (with code coverage), record Ids + install links in
# scripts/package-release-state.json, then optionally promote with --no-prompt.
#
# Package validation runs in a scratch-shaped org that does not use your Dev Hub's
# manual Setup toggles. Lightning email template folders (EmailTemplateFolder, nested
# SFX templates) require Folders and Enhanced Sharing in that validation org—see
# config/package-version-scratch-def.json. Add scratch "features" or other settings
# there only if validation errors point to them (e.g. SharingSet, CDC).
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

# Long-running `sf package version create --wait` polls Tooling API from Node. On some
# networks (IPv6 advertised but not routable), Node can fail with EADDRNOTAVAIL; prefer IPv4.
export NODE_OPTIONS="${NODE_OPTIONS:+${NODE_OPTIONS} }--dns-result-order=ipv4first"

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

# `sf package version create` instantiates ScratchOrgSettingsGenerator without passing
# `capitalizeRecordTypes` from ConfigAggregator (unlike `sf org create scratch`), so the
# CLI always emits a deprecation warning even when `.sf/config.json` sets
# `org-capitalize-record-types=true`. Behavior already matches capitalization-on; strip the
# two-line warning from create output only. Remove this if packaging passes the config.
filter_spurious_pkg_record_type_warning() {
  awk '
    /^Warning: Record types defined in the scratch org definition file will stop being capitalized/ {
      getline
      next
    }
    { print }
  '
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
    --definition-file "${REPO_ROOT}/config/package-version-scratch-def.json" \
    2>&1 | tee "${log}" | filter_spurious_pkg_record_type_warning
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
