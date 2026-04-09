"""Parse sf apex run test JSON output; print per-class coverage for repo classes."""
import json
import sys

REPO_CLASSES = frozenset(
    {
        "CreateReleaseNoteQuickActionController",
        "CreateReleaseNoteQAControllerTest",
        "DisplayDensityController",
        "DisplayDensityControllerTest",
        "MessagingController",
        "MessagingControllerTest",
        "MessagingControllerSeeAllDataTest",
        "PortalTaskController",
        "PortalTaskControllerTest",
        "ProjectTaskContextController",
        "ProjectTaskContextControllerTest",
        "ProjectTaskDashboardController",
        "ProjectTaskDashboardControllerTest",
        "StatusColorController",
        "StatusColorControllerTest",
        "TaskContextController",
        "TaskContextControllerTest",
        "MessageFilesLinkWorker",
        "MessageFilesLinkWorkerTest",
        "MessageFilesSupport",
        "MessageFilesSupportTest",
        "MessageNotificationScheduler",
        "MessageNotificationSchedulerTest",
        "MessageVisibilitySupport",
        "MessageVisibilitySupportTest",
        "MessagingPinnedSupport",
        "MessagingPinnedSupportTest",
        "ProjectTaskApprovalNotificationSender",
        "TaskApprovalNotificationSenderTest",
        "ProjectTaskApproverUserHelper",
        "ProjectTaskApproverUserHelperTest",
        "ProjectTaskDashboardFieldSetHelper",
        "ProjectTaskDashboardFieldSetHelperTest",
        "TaskDependencyHelper",
        "TaskDependencyHelperTest",
        "TaskProgressCalculator",
        "TaskProgressCalculatorTest",
        "TaskSubtaskHelper",
        "TaskSubtaskHelperTest",
    }
)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else None
    if not path:
        print("Usage: python parse_apex_coverage.py <test-result.json>", file=sys.stderr)
        sys.exit(1)
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    rows = []
    for item in data["result"]["coverage"]["coverage"]:
        name = item["name"]
        if name not in REPO_CLASSES:
            continue
        lines = item.get("lines") or {}
        if lines:
            covered = sum(1 for v in lines.values() if v)
            total = len(lines)
            pct = 100.0 * covered / total
        else:
            covered = total = 0
            pct = 0.0
        rows.append((name, pct, covered, total, item.get("totalLines")))
    rows.sort(key=lambda x: x[0])
    for r in rows:
        print(f"{r[0]:45} {r[1]:6.1f}%  covered {r[2]}/{r[3]} line entries  (totalLines={r[4]})")
    s = data["result"]["summary"]
    print("---")
    print(
        f"Run: {s['outcome']}, {s['passing']}/{s['testsRan']} tests passed, "
        f"testRunCoverage={s.get('testRunCoverage')}, orgWideCoverage={s.get('orgWideCoverage')}"
    )
    missing = REPO_CLASSES - {r[0] for r in rows}
    if missing:
        print("---")
        print("No coverage record in this run for:", ", ".join(sorted(missing)))


if __name__ == "__main__":
    main()
