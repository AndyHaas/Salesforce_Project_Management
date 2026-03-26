#!/usr/bin/env python3
"""
Parse sf package version create / promote CLI output and maintain scripts/package-release-state.json.

Used by scripts/package-version-release.sh — not intended for direct interactive use except status / get-id.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


STATE_NAME = "package-release-state.json"


def state_path() -> Path:
    return Path(__file__).resolve().parent / STATE_NAME


def load_state() -> dict:
    p = state_path()
    if not p.exists():
        return {"pendingRelease": None, "lastPromotedRelease": None, "history": []}
    with p.open(encoding="utf-8") as f:
        return json.load(f)


def save_state(data: dict) -> None:
    p = state_path()
    out = dict(data)
    if "_comment" not in out:
        out["_comment"] = (
            "Maintained by package-version-release.sh / package_release_state.py."
        )
    with p.open("w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")


def parse_create_log(text: str) -> tuple[str | None, str | None, str | None]:
    """Return (package_version_id 08c..., subscriber_id 04t..., production_install_url)."""
    sub = None
    pkg_ver = None
    url = None
    # Successfully created the package version [08cQm000000YfbpIAC]. Subscriber Package Version Id: 04tQm0000039aAbIAI
    m = re.search(
        r"Successfully created the package version \[([0-9a-zA-Z]{15,18})\]\.\s*Subscriber Package Version Id:\s*([0-9a-zA-Z]{15,18})",
        text,
    )
    if m:
        pkg_ver, sub = m.group(1), m.group(2)
    if not sub:
        m2 = re.search(r"Subscriber Package Version Id:\s*([0-9a-zA-Z]{15,18})", text)
        if m2:
            sub = m2.group(1)
    if not pkg_ver:
        m3 = re.search(
            r"Successfully created the package version \[([0-9a-zA-Z]{15,18})\]", text
        )
        if m3:
            pkg_ver = m3.group(1)
    murl = re.search(
        r"Package Installation URL:\s*(https://login\.salesforce\.com/packaging/installPackage\.apexp\?p0=[0-9a-zA-Z]{15,18})",
        text,
    )
    if murl:
        url = murl.group(1).strip()
    return pkg_ver, sub, url


def install_links(subscriber_id: str) -> dict[str, str]:
    return {
        "production": f"https://login.salesforce.com/packaging/installPackage.apexp?p0={subscriber_id}",
        "sandbox": f"https://test.salesforce.com/packaging/installPackage.apexp?p0={subscriber_id}",
    }


def cmd_ingest_create(args: argparse.Namespace) -> int:
    log_path = Path(args.log_file)
    text = log_path.read_text(encoding="utf-8", errors="replace")
    if "Create version status: Error" in text or "Create version status: Failed" in text:
        print("Package version create did not succeed (Error/Failed in log).", file=sys.stderr)
        return 1
    if "Create version status: Success" not in text:
        print(
            "Could not find 'Create version status: Success' in log; refusing to record.",
            file=sys.stderr,
        )
        return 1

    pkg_ver, sub, prod_url = parse_create_log(text)
    if not sub:
        print("Could not parse Subscriber Package Version Id from log.", file=sys.stderr)
        return 1

    state = load_state()
    pending = state.get("pendingRelease")
    if pending and not pending.get("promoted") and not args.force:
        print(
            "There is already a pendingRelease (not promoted). "
            "Run `./scripts/package-version-release.sh promote` or use create --force.",
            file=sys.stderr,
        )
        return 1

    links = install_links(sub)
    if prod_url and prod_url != links["production"]:
        # Trust parsed URL from CLI if present
        links["production"] = prod_url

    now = datetime.now(timezone.utc).isoformat()
    state["pendingRelease"] = {
        "subscriberPackageVersionId": sub,
        "packageVersionId": pkg_ver,
        "createdAt": now,
        "promoted": False,
        "promotedAt": None,
        "installLinks": links,
        "cliInstallHint": f'sf package install --package {sub} --target-org <alias>',
    }
    save_state(state)

    print("Recorded pending release:")
    print(f"  Subscriber package version Id: {sub}")
    if pkg_ver:
        print(f"  Package version Id:            {pkg_ver}")
    print(f"  Production: {links['production']}")
    print(f"  Sandbox:    {links['sandbox']}")
    print("Next: ./scripts/package-version-release.sh promote")
    return 0


def cmd_get_pending_subscriber_id(_: argparse.Namespace) -> int:
    state = load_state()
    p = state.get("pendingRelease")
    if not p or p.get("promoted"):
        print(
            "No unpromoted pendingRelease in scripts/package-release-state.json.",
            file=sys.stderr,
        )
        return 1
    sub = p.get("subscriberPackageVersionId")
    if not sub:
        print("pendingRelease missing subscriberPackageVersionId.", file=sys.stderr)
        return 1
    print(sub)
    return 0


def cmd_mark_promoted(args: argparse.Namespace) -> int:
    state = load_state()
    pending = state.get("pendingRelease")
    if not pending:
        print("No pendingRelease to mark promoted.", file=sys.stderr)
        return 1
    if pending.get("promoted"):
        print("pendingRelease already marked promoted.", file=sys.stderr)
        return 1
    sub = pending.get("subscriberPackageVersionId")
    if args.subscriber_id and args.subscriber_id != sub:
        print(
            f"Subscriber Id mismatch: pending={sub} argument={args.subscriber_id}",
            file=sys.stderr,
        )
        return 1

    now = datetime.now(timezone.utc).isoformat()
    promoted_record = {
        **pending,
        "promoted": True,
        "promotedAt": now,
    }
    state["lastPromotedRelease"] = promoted_record
    hist = state.setdefault("history", [])
    hist.append(
        {
            "subscriberPackageVersionId": sub,
            "promotedAt": now,
        }
    )
    state["history"] = hist[-20:]
    state["pendingRelease"] = None
    save_state(state)

    print("State updated: lastPromotedRelease set; pendingRelease cleared.")
    print(f"  Promoted: {sub}")
    print("Update README / wiki install links and sfdx-project.json packageAliases.")
    return 0


def cmd_status(_: argparse.Namespace) -> int:
    state = load_state()
    p = state.get("pendingRelease")
    lp = state.get("lastPromotedRelease")

    print("=== Package release state ===\n")
    if p:
        print("PENDING (created, not yet promoted in this workflow):")
        print(f"  subscriberPackageVersionId: {p.get('subscriberPackageVersionId')}")
        print(f"  packageVersionId:           {p.get('packageVersionId')}")
        print(f"  createdAt:                  {p.get('createdAt')}")
        print(f"  promoted:                   {p.get('promoted')}")
        il = p.get("installLinks") or {}
        print(f"  production: {il.get('production')}")
        print(f"  sandbox:    {il.get('sandbox')}")
        print()
    else:
        print("PENDING: (none)\n")

    if lp:
        print("LAST PROMOTED (via this script):")
        print(f"  subscriberPackageVersionId: {lp.get('subscriberPackageVersionId')}")
        print(f"  promotedAt:                 {lp.get('promotedAt')}")
        il = lp.get("installLinks") or {}
        print(f"  production: {il.get('production')}")
        print(f"  sandbox:    {il.get('sandbox')}")
    else:
        print("LAST PROMOTED: (none recorded)")

    print(f"\nState file: {state_path()}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Maintain package-release-state.json")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_ingest = sub.add_parser("ingest-create-log", help="Parse create log and set pendingRelease")
    p_ingest.add_argument("log_file", help="Path to captured sf package version create output")
    p_ingest.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing unpromoted pendingRelease",
    )
    p_ingest.set_defaults(func=cmd_ingest_create)

    p_get = sub.add_parser("get-pending-subscriber-id", help="Print 04t Id or exit 1")
    p_get.set_defaults(func=cmd_get_pending_subscriber_id)

    p_mark = sub.add_parser("mark-promoted", help="Move pending to lastPromotedRelease")
    p_mark.add_argument(
        "subscriber_id",
        nargs="?",
        help="Optional; must match pending if provided",
    )
    p_mark.set_defaults(func=cmd_mark_promoted)

    p_stat = sub.add_parser("status", help="Print human-readable state")
    p_stat.set_defaults(func=cmd_status)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
