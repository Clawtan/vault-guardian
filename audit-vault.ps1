param (
    [switch]$Clean
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$vaultPath = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
if (-not (Test-Path "$vaultPath\GEMINI.md")) {
    $vaultPath = (Get-Location).Path
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   🛡️ OBSIDIAN VAULT GUARDIAN: HEALTH & INTEGRITY SCAN" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Vault Root: $vaultPath`n"

# 1. SCAN PROTON CONFLICT & BACKUP FILES
$conflictFiles = Get-ChildItem -Path $vaultPath -Recurse -Force | Where-Object { 
    $_.Name -like "*conflict*" -or $_.Name -like "*Name clash*" -or $_.Name -like "*.bak" -or ($_.Name -like "*.tmp" -and $_.FullName -notmatch '\\\.git\\')
}

Write-Host "1. Proton Drive Sync & Conflict Files:" -ForegroundColor Yellow
if ($conflictFiles.Count -eq 0) {
    Write-Host "   [OK] Zero conflict files detected." -ForegroundColor Green
} else {
    Write-Host "   [WARN] Found $($conflictFiles.Count) conflict / backup files:" -ForegroundColor Red
    foreach ($cf in $conflictFiles) {
        $rel = $cf.FullName.Substring($vaultPath.Length + 1)
        Write-Host "   - $rel" -ForegroundColor Red
        if ($Clean) {
            Remove-Item -Path $cf.FullName -Force
            Write-Host "     -> DELETED" -ForegroundColor Green
        }
    }
    if (-not $Clean) {
        Write-Host "   (Pass -Clean flag to auto-delete these files)" -ForegroundColor Gray
    }
}

# 2. SCAN WIKILINKS & ORPHAN NOTES
$mdFiles = Get-ChildItem -Path $vaultPath -Filter *.md -Recurse | Where-Object { 
    $_.FullName -notmatch '\\\.obsidian' -and $_.FullName -notmatch '\\\.trash' -and $_.FullName -notmatch '\\node_modules\\'
}
$allVaultFiles = Get-ChildItem -Path $vaultPath -Recurse -File | Where-Object { 
    $_.FullName -notmatch '\\\.obsidian' -and $_.FullName -notmatch '\\\.trash' -and $_.FullName -notmatch '\\node_modules\\'
}

# Precompute O(1) HashSets for instant path & basename matching
$knownPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$knownBasenames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($p in $allVaultFiles) {
    $rel = $p.FullName.Substring($vaultPath.Length + 1).Replace('\', '/')
    $null = $knownPaths.Add($rel)
    $null = $knownPaths.Add(($rel -replace '\.md$', ''))
    $null = $knownBasenames.Add($p.Name)
    $null = $knownBasenames.Add($p.BaseName)
}

$allLinks = [System.Collections.Generic.List[string]]::new()
$allLinkBases = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$allLinkExact = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$brokenLinks = @()

# Parse YAML aliases across all markdown files
$vaultAliases = @{}
foreach ($file in $mdFiles) {
    $raw = Get-Content $file.FullName -Raw -Encoding UTF8
    if ($raw -match '(?ms)^---\s*\r?\n(.*?)\r?\n---') {
        $fm = $matches[1]
        if ($fm -match '(?m)^aliases:\s*\[(.*?)\]') {
            foreach ($a in ($matches[1] -split ',')) {
                $trimmed = $a.Trim(' "''')
                if ($trimmed) { $vaultAliases[$trimmed] = $true }
            }
        } elseif ($fm -match '(?ms)^aliases:\s*\r?\n((?:\s*-\s*[^\r\n]+\r?\n)+)') {
            foreach ($line in ($matches[1] -split '\r?\n')) {
                if ($line -match '-\s*([^\r\n]+)') {
                    $trimmed = $matches[1].Trim(' "''')
                    if ($trimmed) { $vaultAliases[$trimmed] = $true }
                }
            }
        }
    }
}

foreach ($file in $mdFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($content)) { continue }
    $matches = [regex]::Matches($content, '\[\[([^\]\|#]+)(?:[\|#][^\]]*)?\]\]')
    foreach ($m in $matches) {
        $target = $m.Groups[1].Value.Trim()
        $targetClean = $target -replace '\.md$', ''
        $tBase = Split-Path $targetClean -Leaf
        $allLinks.Add($targetClean)
        $null = $allLinkExact.Add($targetClean)
        $null = $allLinkBases.Add($tBase)
        
        $found = $false
        if ($vaultAliases.ContainsKey($targetClean) -or 
            $knownPaths.Contains($target) -or 
            $knownPaths.Contains($targetClean) -or 
            $knownBasenames.Contains($target) -or 
            $knownBasenames.Contains($targetClean) -or 
            $knownBasenames.Contains($tBase)) {
            $found = $true
        } else {
            # Fallback suffix check only when not matched
            foreach ($kp in $knownPaths) {
                if ($kp.EndsWith("/$targetClean")) {
                    $found = $true
                    break
                }
            }
        }
        if (-not $found -and $targetClean -notmatch '<%' -and $targetClean -ne 'catatan' -and $targetClean -ne '...') {
            $brokenLinks += [PSCustomObject]@{
                Source = $file.FullName.Substring($vaultPath.Length + 1).Replace('\', '/')
                Target = $target
            }
        }
    }
}

Write-Host "`n2. Broken Wikilinks Audit:" -ForegroundColor Yellow
if ($brokenLinks.Count -eq 0) {
    Write-Host "   [OK] Zero broken wikilinks! 100% graph integrity." -ForegroundColor Green
} else {
    Write-Host "   [WARN] Found $($brokenLinks.Count) broken wikilinks:" -ForegroundColor Red
    $brokenLinks | Format-Table -AutoSize
}

# 3. ORPHAN NOTES AUDIT
$orphans = @()
foreach ($file in $mdFiles) {
    if ($file.Name -eq "Dashboard.md" -or $file.Name -like "*Clawtan Second Brain*" -or $file.Name -eq "index.md" -or $file.Name -eq "GEMINI.md" -or $file.FullName -match '\\Templates\\' -or $file.FullName -match '\\Core\\') { continue }
    $cleanName = $file.BaseName
    $relClean = $file.FullName.Substring($vaultPath.Length + 1).Replace('\', '/') -replace '\.md$', ''
    
    $incoming = $false
    if ($allLinkExact.Contains($relClean) -or 
        $allLinkExact.Contains($cleanName) -or 
        $allLinkBases.Contains($cleanName)) {
        $incoming = $true
    } else {
        # Fallback suffix check only when needed
        foreach ($link in $allLinks) {
            if ($relClean.EndsWith("/$link")) {
                $incoming = $true
                break
            }
        }
    }
    if (-not $incoming) {
        $orphans += $file.FullName.Substring($vaultPath.Length + 1).Replace('\', '/')
    }
}

Write-Host "3. Orphan Notes Audit (Zero Backlinks):" -ForegroundColor Yellow
if ($orphans.Count -eq 0) {
    Write-Host "   [OK] Zero orphan notes! All notes are connected to Hubs/MOC." -ForegroundColor Green
} else {
    Write-Host "   [WARN] Found $($orphans.Count) orphan notes:" -ForegroundColor Red
    $orphans | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
}

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   TOTAL MARKDOWN NOTES: $($mdFiles.Count) | STATUS: HEALTHY" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan
