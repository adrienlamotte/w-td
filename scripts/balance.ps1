# M2 balance bot (task 022, D-126): headless bot runs of run_m2, writes reports/balance_m2.md.
param([int]$Runs = 5)
. "$PSScriptRoot/_common.ps1"
$godot = Get-Godot

& $godot --headless --path $GameDir --import
if ($LASTEXITCODE) { throw 'Godot import failed' }
$out = Join-Path $Root 'reports/balance_m2.md'
$commit = (git -C $Root rev-parse --short HEAD).Trim()
$sw = [Diagnostics.Stopwatch]::StartNew()
& $godot --headless --path $GameDir -s res://balance/balance_runner.gd -- --runs $Runs --out $out --commit $commit
if ($LASTEXITCODE) { throw 'Balance runner failed' }
Write-Host ("Report: $out (total wall time {0:N0} s)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
