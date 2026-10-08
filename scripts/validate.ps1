# Validates game/data against tools/schemas (D-034).
. "$PSScriptRoot/_common.ps1"
& (Get-ToolsPython) (Join-Path $Root 'tools/validate_data.py')
exit $LASTEXITCODE
