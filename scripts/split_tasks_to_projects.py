#!/usr/bin/env python3
"""
Split tasks from one project across multiple projects.

Usage:
  python scripts/split_tasks_to_projects.py \
    --org milestoneDevOrg \
    --project-id a01Ec00001LSKIkIAP \
    --num-projects 4
"""

import argparse
import datetime as dt
import json
import random
import subprocess
import sys
from typing import Dict, List

PROJECT_STATUSES = ["Not Started", "R&D", "Proposal", "Development", "Q&A", "Deployed", "Cancelled"]


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


def update_record(org: str, sobject: str, record_id: str, values: Dict[str, str]) -> None:
    """Update a record using sf CLI."""
    value_str = " ".join([f"{k}='{v}'" for k, v in values.items()])
    resp = run_sf(
        [
            "data",
            "update",
            "record",
            "--target-org",
            org,
            "--sobject",
            sobject,
            "--record-id",
            record_id,
            "--values",
            value_str,
            "--json",
        ]
    )
    if resp.get("status") != 0:
        raise RuntimeError(f"Update failed: {resp}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--org", default="milestoneDevOrg")
    parser.add_argument("--project-id", required=True, help="Project ID to split tasks from")
    parser.add_argument("--num-projects", type=int, default=4, help="Total number of projects to distribute across")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    org = args.org

    # Get the original project info
    projects = soql(org, f"SELECT Id, Name, Account__c FROM Project__c WHERE Id = '{args.project_id}'")
    if not projects:
        sys.exit(f"Project {args.project_id} not found.")
    
    original_project = projects[0]
    account_id = original_project["Account__c"]
    account_name = soql(org, f"SELECT Name FROM Account WHERE Id = '{account_id}'")[0]["Name"]
    
    print(f"Original project: {original_project['Name']} (Account: {account_name})")

    # Get all tasks for this project
    tasks = soql(org, f"SELECT Id, Name, Project__c FROM Project_Task__c WHERE Project__c = '{args.project_id}'")
    print(f"Found {len(tasks)} tasks to redistribute")

    if len(tasks) == 0:
        print("No tasks to redistribute.")
        return

    # Create additional projects if needed
    existing_projects = soql(org, f"SELECT Id, Name FROM Project__c WHERE Account__c = '{account_id}'")
    existing_project_ids = {p["Id"] for p in existing_projects}
    
    projects_to_use = [args.project_id]  # Start with original project
    
    # Create new projects if we need more
    projects_needed = args.num_projects - len(existing_projects)
    if projects_needed > 0:
        print(f"Creating {projects_needed} additional projects...")
        for i in range(projects_needed):
            project_name = f"{account_name} Project {dt.date.today().strftime('%Y%m%d')} - {i+2}"
            project_values = {
                "Name": project_name,
                "Account__c": account_id,
                "Status__c": random.choice(PROJECT_STATUSES),
            }
            if args.dry_run:
                print(f"[dry-run] Would create project: {project_values}")
                fake_id = f"DRYPROJ{i+2}"
                projects_to_use.append(fake_id)
            else:
                project_id = create_record(org, "Project__c", project_values)
                projects_to_use.append(project_id)
                print(f"Created project '{project_name}' ({project_id})")
    else:
        # Use existing projects
        for proj in existing_projects:
            if proj["Id"] != args.project_id:
                projects_to_use.append(proj["Id"])
        # If we still need more, create them
        while len(projects_to_use) < args.num_projects:
            i = len(projects_to_use)
            project_name = f"{account_name} Project {dt.date.today().strftime('%Y%m%d')} - {i+1}"
            project_values = {
                "Name": project_name,
                "Account__c": account_id,
                "Status__c": random.choice(PROJECT_STATUSES),
            }
            if args.dry_run:
                print(f"[dry-run] Would create project: {project_values}")
                fake_id = f"DRYPROJ{i+1}"
                projects_to_use.append(fake_id)
            else:
                project_id = create_record(org, "Project__c", project_values)
                projects_to_use.append(project_id)
                print(f"Created project '{project_name}' ({project_id})")

    print(f"\nDistributing {len(tasks)} tasks across {len(projects_to_use)} projects...")

    # Randomly distribute tasks across projects
    random.shuffle(tasks)
    tasks_per_project = len(tasks) // len(projects_to_use)
    remainder = len(tasks) % len(projects_to_use)

    distribution = {}
    task_idx = 0
    for i, project_id in enumerate(projects_to_use):
        count = tasks_per_project + (1 if i < remainder else 0)
        distribution[project_id] = tasks[task_idx:task_idx + count]
        task_idx += count
        print(f"  Project {i+1}: {count} tasks")

    # Update tasks to new projects
    updates_made = 0
    for project_id, project_tasks in distribution.items():
        if project_id == args.project_id:
            continue  # Skip original project
        for task in project_tasks:
            if args.dry_run:
                print(f"[dry-run] Would move task {task['Id']} ({task['Name']}) to project {project_id}")
            else:
                update_record(org, "Project_Task__c", task["Id"], {"Project__c": project_id})
                updates_made += 1

    if not args.dry_run:
        print(f"\nDone. Moved {updates_made} tasks across {len(projects_to_use)} projects.")
        print(json.dumps({
            "original_project": args.project_id,
            "total_projects": len(projects_to_use),
            "tasks_moved": updates_made,
            "tasks_remaining_in_original": len(distribution.get(args.project_id, []))
        }, indent=2))
    else:
        print("\n[dry-run] No changes made.")


if __name__ == "__main__":
    main()
