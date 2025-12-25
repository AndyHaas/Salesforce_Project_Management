#!/usr/bin/env python3
"""
Seed Project Task data in milestoneDevOrg via Salesforce CLI.

What it does:
- Queries Accounts and their Projects.
- Creates Project__c records for accounts that don't have any (required for tasks).
- Randomly creates 10-20 Project_Task__c records per Account, guaranteeing at
  least one task in every status.
- Assigns developers across the current user ("me"), Kevin P, and a few for William
  Hank (only on William's Account).
- Adds subtasks and a handful of Project_Task_Relationship__c records to create
  variety (parent/child and dependency/related links).

Usage:
  python scripts/generate_project_tasks.py \
    --org milestoneDevOrg --min 10 --max 20

Flags:
  --org           Target org alias/username. Default: milestoneDevOrg
  --min/--max     Task count range per Account. Default: 10-20
  --dry-run       Only print what would happen.
  --owner-kevin   Name fragment for Kevin (default: "Kevin P")
  --owner-william Name fragment for William (default: "William Hank")

Requirements:
- Salesforce CLI (`sf`) authenticated to the org.
- Project__c records exist and are related to Accounts (master-detail requirement).
"""

import argparse
import datetime as dt
import json
import random
import subprocess
import sys
from typing import Dict, List, Optional, Tuple

STATUSES = [
    "Backlog",
    "Pending",
    "In Progress",
    "In Review",
    "Blocked",
    "Completed",
    "Removed",
    "Closed",
]

PRIORITIES = ["High", "Medium", "Low"]
REL_TYPES = ["Related", "Blocking Dependency", "Epic/Feature Parent"]


def run_sf(args: List[str], expect_json: bool = True) -> dict:
    """Run an sf CLI command and return parsed JSON."""
    cmd = ["sf"] + args
    result = subprocess.run(
        cmd, check=False, capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"sf command failed: {' '.join(cmd)}\nSTDERR: {result.stderr.strip()}\nSTDOUT: {result.stdout.strip()}"
        )
    if not expect_json:
        return {}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Could not parse sf JSON output: {result.stdout}") from exc


def soql(org: str, query: str) -> List[dict]:
    resp = run_sf(
        ["data", "query", "--target-org", org, "-q", query, "--json"]
    )
    return resp.get("result", {}).get("records", [])


def current_user(org: str) -> dict:
    resp = run_sf(["org", "display", "--target-org", org, "--json"])
    return resp.get("result", {})


def resolve_current_user_id(org: str) -> str:
    """Return the current authenticated user's Id."""
    me = current_user(org)
    user_id = me.get("userId")
    if user_id:
        return user_id
    username = me.get("username")
    if not username:
        raise RuntimeError("Could not determine current user username.")
    records = soql(
        org,
        f"SELECT Id FROM User WHERE Username = '{username}' LIMIT 1",
    )
    if not records:
        raise RuntimeError(f"Could not resolve user id for {username}")
    return records[0]["Id"]


def find_user(org: str, name_fragment: str) -> Optional[dict]:
    query = (
        "SELECT Id, Name, Username, ContactId, Contact.AccountId "
        f"FROM User WHERE Name LIKE '%{name_fragment}%' "
        "ORDER BY LastModifiedDate DESC LIMIT 1"
    )
    records = soql(org, query)
    return records[0] if records else None


def create_record(org: str, sobject: str, values: Dict[str, str]) -> str:
    value_str = " ".join([f"{k}='{v}'" for k, v in values.items()])
    resp = run_sf(
        [
            "data",
            "create",
            "record",
            "--target-org",
            org,
            "--sobject",
            sobject,
            "--values",
            value_str,
            "--json",
        ]
    )
    return resp.get("result", {}).get("id")


def has_field(org: str, sobject: str, field: str) -> bool:
    """Lightweight field existence check via a safe query."""
    try:
        soql(org, f"SELECT Id, {field} FROM {sobject} LIMIT 1")
        return True
    except Exception:
        return False


def date_offset(days: int) -> str:
    return (dt.date.today() + dt.timedelta(days=days)).isoformat()


def pick_owner(
    account_id: str,
    me: Dict[str, Optional[str]],
    kevin: Optional[Dict[str, Optional[str]]],
    william: Optional[Dict[str, Optional[str]]],
    max_william: Dict[str, int],
) -> Dict[str, Optional[str]]:
    """Return chosen owner info: user_id, contact_id, account_id."""
    candidates = []
    candidates.append({"weight": 0.55, **me})
    if kevin:
        candidates.append({"weight": 0.35, **kevin})
    if william and william.get("account_id") == account_id and max_william["remaining"] > 0:
        candidates.append({"weight": 0.10, **william})

    weights = [c["weight"] for c in candidates]
    total = sum(weights)
    weights = [w / total for w in weights]
    choice = random.choices(candidates, weights=weights, k=1)[0]
    if choice.get("user_id") == (william or {}).get("user_id"):
        max_william["remaining"] -= 1
    return choice


def generate_task_payload(
    account: dict,
    project_id: str,
    status: str,
    developer_id: str,
    name_suffix: str,
) -> Dict[str, str]:
    today = dt.date.today()
    due = today + dt.timedelta(days=random.randint(3, 45))
    start = today + dt.timedelta(days=random.randint(-3, 10))
    payload = {
        "Name": f"{account['Name']} Task {name_suffix}",
        "Account__c": account["Id"],
        "Project__c": project_id,
        "Status__c": status,
        "Priority__c": random.choice(PRIORITIES),
        "Start_Date__c": start.isoformat(),
        "Due_Date__c": due.isoformat(),
        "Description__c": "Auto-generated seed task for testing.",
    }
    if developer_id:
        payload["Developer__c"] = developer_id
    return payload


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--org", default="milestoneDevOrg")
    parser.add_argument("--min", dest="min_tasks", type=int, default=10)
    parser.add_argument("--max", dest="max_tasks", type=int, default=20)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--owner-kevin", default="Kevin P")
    parser.add_argument("--owner-william", default="William Hank")
    parser.add_argument("--skip-relationships", action="store_true")
    args = parser.parse_args()

    if args.min_tasks < 1 or args.max_tasks < args.min_tasks:
        sys.exit("Invalid min/max values.")

    org = args.org
    me_id = resolve_current_user_id(org)
    me_info = {"user_id": me_id, "contact_id": None, "account_id": None}

    kevin = find_user(org, args.owner_kevin)
    kevin_contact = kevin.get("Contact") if kevin else None
    kevin_account_id = kevin_contact.get("AccountId") if isinstance(kevin_contact, dict) else None
    kevin_info = (
        {"user_id": kevin["Id"], "contact_id": kevin.get("ContactId"), "account_id": kevin_account_id}
        if kevin
        else None
    )
    william = find_user(org, args.owner_william)
    william_contact = william.get("Contact") if william else None
    william_account_id = william_contact.get("AccountId") if isinstance(william_contact, dict) else None
    william_info = (
        {
            "user_id": william["Id"],
            "contact_id": william.get("ContactId"),
            "account_id": william_account_id,
        }
        if william
        else None
    )
    max_william = {"remaining": 4}  # keep William assignments small

    accounts = soql(org, "SELECT Id, Name FROM Account")
    projects = soql(org, "SELECT Id, Name, Account__c FROM Project__c")
    projects_by_account = {}
    for proj in projects:
        acct = proj.get("Account__c")
        if acct:
            projects_by_account.setdefault(acct, []).append(proj)

    # Create projects for accounts that don't have any
    # Note: Using API values from metadata (R&amp;D and Q&amp;A are stored as R&D and Q&A)
    PROJECT_STATUSES = ["Not Started", "R&D", "Proposal", "Development", "Q&A", "Deployed", "Cancelled"]
    projects_created = 0
    for acct in accounts:
        if acct["Id"] not in projects_by_account:
            # Create a project for this account
            project_name = f"{acct['Name']} Project - {dt.date.today().strftime('%Y%m%d')}"
            project_values = {
                "Name": project_name,
                "Account__c": acct["Id"],
                "Status__c": random.choice(PROJECT_STATUSES),
            }
            if args.dry_run:
                print(f"[dry-run] Would create project: {project_values}")
                fake_project_id = f"DRYPROJ{acct['Id'][-6:]}"
                projects_by_account[acct["Id"]] = [{"Id": fake_project_id, "Name": project_name, "Account__c": acct["Id"]}]
            else:
                project_id = create_record(org, "Project__c", project_values)
                projects_by_account[acct["Id"]] = [{"Id": project_id, "Name": project_name, "Account__c": acct["Id"]}]
                projects_created += 1
                print(f"Created project '{project_name}' for account '{acct['Name']}'")

    rel_field_available = has_field(org, "Project_Task_Relationship__c", "Relationship_Type__c")
    if not rel_field_available:
        print("Note: Project_Task_Relationship__c.Relationship_Type__c not available. Skipping relationship creation.")
    if args.skip_relationships:
        print("Note: Relationship creation skipped via --skip-relationships.")

    summary = {"projects": projects_created, "tasks": 0, "subtasks": 0, "relationships": 0}
    for acct in accounts:
        acct_projects = projects_by_account.get(acct["Id"], [])
        if not acct_projects:
            print(f"Warning: Account '{acct['Name']}' still has no projects after creation attempt. Skipping.")
            continue
        project_id = random.choice(acct_projects)["Id"]

        total_tasks = random.randint(args.min_tasks, args.max_tasks)
        statuses = STATUSES.copy()
        random.shuffle(statuses)
        tasks_to_create = statuses + [
            random.choice(STATUSES) for _ in range(total_tasks - len(STATUSES))
        ]

        created_tasks = []
        for idx, status in enumerate(tasks_to_create, start=1):
            owner_choice = pick_owner(acct["Id"], me_info, kevin_info, william_info, max_william)
            developer_id = owner_choice.get("contact_id")
            payload = generate_task_payload(acct, project_id, status, developer_id, f"#{idx}")
            if args.dry_run:
                print(f"[dry-run] Would create task: {payload}")
                fake_id = f"DRY{idx:04d}"
                created_tasks.append({"Id": fake_id, **payload})
                continue
            task_id = create_record(org, "Project_Task__c", payload)
            created_tasks.append({"Id": task_id, **payload})
            summary["tasks"] += 1

        # Subtasks (20% of tasks become parents, 1-3 subtasks each) for non-closed parents
        open_parents = [t for t in created_tasks if t.get("Status__c") not in ("Closed", "Completed", "Removed")]
        if open_parents:
            potential_parents = random.sample(open_parents, max(1, len(open_parents) // 5))
        else:
            potential_parents = []
        for parent in potential_parents:
            for n in range(random.randint(1, 3)):
                owner_choice = pick_owner(acct["Id"], me_info, kevin_info, william_info, max_william)
                developer_id = owner_choice.get("contact_id")
                payload = generate_task_payload(
                    acct, project_id, random.choice(STATUSES), developer_id, f"{parent['Id']}-sub{n+1}"
                )
                payload["Parent_Task__c"] = parent["Id"]
                if args.dry_run:
                    print(f"[dry-run] Would create subtask: {payload}")
                    sub_id = f"DRYS{len(created_tasks)+n}"
                else:
                    sub_id = create_record(org, "Project_Task__c", payload)
                    summary["tasks"] += 1
                    summary["subtasks"] += 1
                created_tasks.append({"Id": sub_id, **payload})

        # Relationships (3 random pairs per account)
        if len(created_tasks) > 1 and rel_field_available and not args.skip_relationships:
            for _ in range(3):
                a, b = random.sample(created_tasks, 2)
                rel_type = random.choice(REL_TYPES)
                values = {
                    "Task_A__c": a["Id"],
                    "Task_B__c": b["Id"],
                    "Relationship_Type__c": rel_type,
                }
                if args.dry_run:
                    print(f"[dry-run] Would relate {a['Id']} -> {b['Id']} ({rel_type})")
                else:
                    create_record(org, "Project_Task_Relationship__c", values)
                    summary["relationships"] += 1

    print("Done.")
    print(
        json.dumps(
            {
                "org": org,
                "projects_created": summary["projects"],
                "tasks_created": summary["tasks"],
                "subtasks_created": summary["subtasks"],
                "relationships_created": summary["relationships"],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()


