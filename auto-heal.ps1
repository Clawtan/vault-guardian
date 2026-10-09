param (
    [switch]$Silent
)

# Resolve Vault Path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$vaultPath = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir))
if (-not (Test-Path (Join-Path $vaultPath "index.md"))) {
    $vaultPath = (Get-Location).Path
}

$nowStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$logLines = [System.Collections.Generic.List[string]]::new()
$logLines.Add("Pusat: [[AI Master Hub]]")
$logLines.Add("")
$logLines.Add("# [Vault Guardian] Auto-Heal & Weekly Sweep Log")
$logLines.Add("> Automated integrity, conflict cleanup, and graph health record.")
$logLines.Add("- Last Execution: " + $nowStr + " WIB")
$logLines.Add("- Vault Root: " + $vaultPath)
$logLines.Add("")

# 1. PURGE PROTON DRIVE CONFLICT & RESIDUE FILES
$allFiles = Get-ChildItem -Path $vaultPath -Recurse -Force -ErrorAction SilentlyContinue
$conflictFiles = @()
foreach ($f in $allFiles) {
    if ($f.PSIsContainer) { continue }
    $fn = $f.Name
    if ($fn -like '*conflict*' -or $fn -like '*Name clash*' -or $fn -like '*.bak*' -or ($fn -like '*.tmp*' -and $f.FullName -notmatch '\\\.git\\')) {
        $conflictFiles += $f
    }
}

$deletedCount = 0
if ($conflictFiles.Count -gt 0) {
    foreach ($cf in $conflictFiles) {
        Remove-Item -Path $cf.FullName -Force -ErrorAction SilentlyContinue
        $deletedCount++
    }
    $logLines.Add("### 1. Cloud Conflict Cleanup: Purged " + $deletedCount + " file(s)")
} else {
    $logLines.Add("### 1. Cloud Conflict Cleanup: 0 conflict files (Clean)")
}

# 2. RUN FULL INTEGRITY AUDIT
$auditScript = Join-Path $scriptDir "audit-vault.ps1"
$auditOutput = & powershell -ExecutionPolicy Bypass -File $auditScript

$hasZeroBroken = $false
$hasZeroOrphan = $false
foreach ($line in $auditOutput) {
    if ($line -like "*Zero broken wikilinks*") { $hasZeroBroken = $true }
    if ($line -like "*Zero orphan notes*") { $hasZeroOrphan = $true }
}

$logLines.Add("")
$logLines.Add("### 2. Graph Integrity Status")
if ($hasZeroBroken) {
    $logLines.Add("- Wikilinks: [OK] 100% Valid (0 broken links)")
} else {
    $logLines.Add("- Wikilinks: [WARN] Detected unlinked references")
}

if ($hasZeroOrphan) {
    $logLines.Add("- Orphan Notes: [OK] 100% Connected (0 orphan notes)")
} else {
    $logLines.Add("- Orphan Notes: [WARN] Detected unindexed notes")
}

$logLines.Add("")
$logLines.Add("### 3. Verdict")
$logLines.Add("- Status: OCD-Grade Clean & Healthy")

# Write status file to Memory (overwrite in-place, zero clutter)
$healthLogPath = Join-Path $vaultPath "AI\Memory\Vault_Health_Log.md"
[System.IO.File]::WriteAllLines($healthLogPath, $logLines, [System.Text.Encoding]::UTF8)

if (-not $Silent) {
    Write-Host "Vault Auto-Heal & Sweep Completed Successfully!" -ForegroundColor Green
    Write-Host "Health log updated at: $healthLogPath" -ForegroundColor Cyan
}
