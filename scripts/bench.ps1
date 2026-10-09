# Perf benchmark (task 008, D-088): exports the release build, runs the benchmark scene in it
# (build/windows/WTD.exe, not the editor binary; started by the --bench user arg, since
# release templates refuse a scene path argument) and writes reports/perf_<date>.json. About 2.5 min.
. "$PSScriptRoot/_common.ps1"
& (Join-Path $PSScriptRoot 'export.ps1')
$exe = Join-Path $Root 'build/windows/WTD.exe'
$out = Join-Path $Root ("reports/perf_{0}.json" -f (Get-Date -Format 'yyyy-MM-dd'))
$commit = (git -C $Root rev-parse --short HEAD).Trim()
Remove-Item $out -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $exe -Wait -PassThru -ArgumentList @(
    '--resolution', '2560x1440', '--', '--bench', "--out=$out", "--commit=$commit")
if ($p.ExitCode -or -not (Test-Path $out)) { throw "Benchmark failed (exit $($p.ExitCode), report: $out)" }
foreach ($s in (Get-Content $out -Raw | ConvertFrom-Json).scenarios) {
    '{0,-18} avg {1,7:N1} fps  1%-low {2,6:N1}  frame {3,5:N2} ms  step {4,5:N2} ms  gpu {5,5:N2} ms' -f $s.name,
        $s.frame.avg_fps, $s.frame.low1_fps, $s.frame.frame_ms_avg, $s.sim.step_ms_avg, $s.cpu_gpu.gpu_ms_avg
}
Write-Host "Wrote $out" -ForegroundColor Green
