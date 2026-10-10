# M3 balance runner (task 041, D-164): headless bot runs of run_m3 (strategies passive, spread, maze
# x profiles fresh, full x each Guardian of the offer x seeds 1..Runs), writes reports/balance_<date>.md.
param([int]$Runs = 2, [string]$Profiles = 'fresh,full')
. "$PSScriptRoot/_common.ps1"
$godot = Get-Godot

& $godot --headless --path $GameDir --import
if ($LASTEXITCODE) { throw 'Godot import failed' }
$out = Join-Path $Root ('reports/balance_{0:yyyy-MM-dd}.md' -f (Get-Date))
$commit = (git -C $Root rev-parse --short HEAD).Trim()
$sw = [Diagnostics.Stopwatch]::StartNew()
& $godot --headless --path $GameDir -s res://balance/balance_runner.gd -- --runs $Runs --out $out --commit $commit --profiles $Profiles
if ($LASTEXITCODE) { throw 'Balance runner failed' }
Write-Host ("Report: $out (total wall time {0:N0} s)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Green
