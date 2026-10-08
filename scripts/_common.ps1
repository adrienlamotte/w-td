# Shared helpers, dot-sourced by the other scripts.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$GameDir = Join-Path $Root 'game'
$GodotVersion = (Get-Content (Join-Path $Root 'tools/godot_version.txt') -Raw).Trim()

# Godot executable: $env:GODOT if set, else `godot` on PATH. Must match tools/godot_version.txt (D-036).
function Get-Godot {
    $exe = if ($env:GODOT) { $env:GODOT } else { (Get-Command godot -ErrorAction SilentlyContinue).Source }
    if (-not $exe -or -not (Test-Path $exe)) {
        throw "Godot not found. Set GODOT to the Godot $GodotVersion console exe (see CLAUDE.md, Commands)."
    }
    $v = (& $exe --version | Out-String).Trim()
    if (-not $v.StartsWith($GodotVersion)) { throw "Godot at $exe is '$v', expected $GodotVersion (tools/godot_version.txt)." }
    return $exe
}

# Python for tools/: a local venv with pinned deps, created on first use.
function Get-ToolsPython {
    $py = Join-Path $Root 'tools/.venv/Scripts/python.exe'
    if (-not (Test-Path $py)) {
        python -m venv (Join-Path $Root 'tools/.venv')
        if ($LASTEXITCODE) { throw 'Could not create tools/.venv (is Python 3.10+ on PATH?)' }
        & $py -m pip install -q -r (Join-Path $Root 'tools/requirements.txt')
        if ($LASTEXITCODE) { throw 'pip install failed' }
    }
    return $py
}
