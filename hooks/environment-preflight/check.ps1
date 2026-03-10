# Environment Preflight Hook
# Validates environment prerequisites at session start
$checks = @()
if ($env:SDXROOT) { $checks += "[OK] Razzle active: $env:SDXROOT" }
else { $checks += "[--] Razzle not active (some skills will be unavailable)" }

if (Get-Command "node" -ErrorAction SilentlyContinue) { $checks += "[OK] Node.js available" }
else { $checks += "[--] Node.js not found" }

if (Get-Command "git" -ErrorAction SilentlyContinue) { $checks += "[OK] Git available" }

$checks | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
