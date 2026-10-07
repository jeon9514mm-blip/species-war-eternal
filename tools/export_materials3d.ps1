param([Parameter(Mandatory=$true)][string]$MaterialMakerExe)
$ErrorActionPreference='Stop'
$repoRoot=Split-Path -Parent $PSScriptRoot
$materialRoot=Join-Path $repoRoot 'assets/models3d-v1/materials'
$graph=Join-Path $materialRoot 'eternal_stone.ptex'
$process=Start-Process -FilePath $MaterialMakerExe -ArgumentList @('--export-material','--target','"Godot/Godot 4 Standard"','--size','1024','-o',('"'+$materialRoot+'"'),('"'+$graph+'"')) -WindowStyle Hidden -PassThru -Wait
if ($process.ExitCode -ne 0) {throw "Material Maker failed: $($process.ExitCode)"}
foreach ($channel in @('albedo','normal','orm')) {
 if (-not (Test-Path -LiteralPath (Join-Path $materialRoot "eternal_stone_$channel.png"))) {throw "Missing PBR output: $channel"}
}
Write-Output 'PBR_EXPORT_OK'
