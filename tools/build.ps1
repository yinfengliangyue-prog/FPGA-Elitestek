$ErrorActionPreference='Stop'
$finalProject=Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $finalProject
try {
 & python -X utf8 tools/build_project.py
 if($LASTEXITCODE -ne 0){throw "Build failed: $LASTEXITCODE"}
} finally {Pop-Location}
