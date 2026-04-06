<#
.SYNOPSIS
  Deploy exactly one Flow file from this repo — no full-package deploy.

.DESCRIPTION
  Runs from the repo root and passes the absolute path to the single
  `*.flow-meta.xml` file as `sf project deploy start --source-dir <file>`.
  That deploys only that Flow (see Deploy Options / numberComponentsTotal in the report).

  `sf project deploy report` cannot run from this repo root because unrelated
  `objectTranslations` fail metadata resolution; after deploy, this script runs
  the report from `scripts/sf-deploy-report-stub/` (minimal empty project).

.PARAMETER FlowApiName
  Flow API name (filename without .flow-meta.xml).

.PARAMETER TargetOrg
  Salesforce CLI alias or username. If omitted, uses `sf config get target-org`.

.PARAMETER SkipReport
  Do not run `sf project deploy report` after deploy.

.EXAMPLE
  .\scripts\deploy-single-flow.ps1 -FlowApiName Record_Trigger_Project_Task_Sync_Approver_And_Developer_Users -TargetOrg milestonedev
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $FlowApiName,

    [Parameter(Mandatory = $false)]
    [string] $TargetOrg,

    [switch] $SkipReport
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$flowPath = Join-Path $repoRoot "force-app\main\default\flows\$FlowApiName.flow-meta.xml"

if (-not (Test-Path -LiteralPath $flowPath)) {
    throw "Flow file not found: $flowPath"
}

if (-not $TargetOrg) {
    $cfg = sf config get target-org --json 2>$null | ConvertFrom-Json
    if ($cfg.result -and $cfg.result[0].value) {
        $TargetOrg = $cfg.result[0].value
    }
}
if (-not $TargetOrg) {
    throw 'No target org. Pass -TargetOrg or run: sf config set target-org <alias>'
}

$reportStub = Resolve-Path (Join-Path $PSScriptRoot 'sf-deploy-report-stub')

function Get-DeployJson {
    param([string[]] $Arguments)
    # Suppress stderr so CLI progress / locale bugs do not corrupt JSON on stdout
    $output = & sf @Arguments --json 2>$null
    if (-not $output) { return $null }
    try {
        return ($output | ConvertFrom-Json)
    } catch {
        return $null
    }
}

Push-Location $repoRoot
try {
    Write-Host "Deploying single file: $flowPath" -ForegroundColor Cyan
    Write-Host "Target org: $TargetOrg" -ForegroundColor Cyan

    $deployJson = Get-DeployJson -Arguments @(
        'project', 'deploy', 'start',
        '--source-dir', $flowPath,
        '--target-org', $TargetOrg,
        '--ignore-conflicts'
    )

    $jobId = $null
    if ($deployJson -and $deployJson.data -and $deployJson.data.id) {
        $jobId = $deployJson.data.id
    }

    if (-not $jobId) {
        Write-Warning 'Could not parse deploy job id from CLI output. Check deployment status in the org.'
        return
    }

    Write-Host "Deploy job id: $jobId" -ForegroundColor DarkGray

    if ($SkipReport) {
        Write-Host "Skipping report (use stub folder manually): cd scripts/sf-deploy-report-stub" -ForegroundColor DarkYellow
        return
    }

    Push-Location $reportStub
    try {
        Write-Host "`nDeploy report (from minimal stub project):" -ForegroundColor Cyan
        sf project deploy report --job-id $jobId
    } finally {
        Pop-Location
    }
} finally {
    Pop-Location
}
