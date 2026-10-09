param([int]$TimeoutSeconds=130,[int]$Width=1920,[int]$Height=1080,[string]$BuildDirectory='WindowsPlay',[switch]$RaidMechanics,[switch]$SkipBandBoundaries,[switch]$FeatureFocus)
$ErrorActionPreference='Stop'
$gameRepo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
if($BuildDirectory -notmatch '^WindowsPlay[A-Za-z0-9]*$'){throw 'Expected a WindowsPlay build folder name.'}
$gameBuild=(Resolve-Path -LiteralPath (Join-Path $gameRepo ('Unity/Builds/'+$BuildDirectory))).Path
$gameExe=Join-Path $gameBuild 'EternalUnity.exe'
$gameReport=Join-Path $gameBuild 'native-game-input.json'
$gamePhases=if($FeatureFocus){@('feature-focus')}elseif($RaidMechanics){@('raid-mechanics')}elseif($SkipBandBoundaries){@('first','resume')}else{@('first','resume','band499','band999')}
foreach($gamePhase in $gamePhases) {
    $gameStarted=[DateTime]::UtcNow
    $gameLog=Join-Path $gameBuild ('player-game-'+$gamePhase+'.log')
    $gameArguments=@('--eternal-game-qa',"`"$gameReport`"",'-screen-width',$Width,'-screen-height',$Height,'-screen-fullscreen','0','-logFile',"`"$gameLog`"")
    if($gamePhase -eq 'resume'){$gameArguments+= '--qa-resume'}
    if($gamePhase -eq 'raid-mechanics'){$gameArguments+= '--qa-raid-mechanics'}
    if($gamePhase -eq 'feature-focus'){$gameArguments+= '--qa-feature-focus'}
    if($gamePhase -eq 'band499'){$gameArguments+= @('--qa-band-start','499')}
    if($gamePhase -eq 'band999'){$gameArguments+= @('--qa-band-start','999')}
    # Visible interactive player is required for actual rendered captures.
    $gameProcess=Start-Process -FilePath $gameExe -WorkingDirectory $gameBuild -WindowStyle Normal -ArgumentList $gameArguments -PassThru
    while(-not $gameProcess.HasExited){
        if(([DateTime]::UtcNow-$gameStarted).TotalSeconds -gt $TimeoutSeconds){throw 'Native game acceptance exceeded its budget; inspect the launched process before retrying.'}
        Start-Sleep -Milliseconds 500
    }
    if((Get-Item -LiteralPath $gameReport).LastWriteTimeUtc -lt $gameStarted){throw 'Native game did not write a fresh report.'}
    $gameData=Get-Content -LiteralPath $gameReport -Raw | ConvertFrom-Json
    $gameData | Select-Object passed,phase,error,comparisons,elapsed_seconds | ConvertTo-Json
    if($gameProcess.ExitCode -ne 0 -or -not $gameData.passed){throw 'Native game acceptance failed; see the reported action.'}
    if($gamePhase -eq 'first'){Copy-Item -LiteralPath $gameReport -Destination (Join-Path $gameBuild 'native-game-first-process.json')}
    if($gamePhase -eq 'resume'){Copy-Item -LiteralPath $gameReport -Destination (Join-Path $gameBuild 'native-game-reload-process.json')}
    if($gamePhase.StartsWith('band')){Copy-Item -LiteralPath $gameReport -Destination (Join-Path $gameBuild ('native-game-'+$gamePhase+'-process.json'))}
    if($gamePhase -eq 'raid-mechanics'){Copy-Item -LiteralPath $gameReport -Destination (Join-Path $gameBuild 'native-game-raid-mechanics-process.json')}
    if($gamePhase -eq 'feature-focus'){Copy-Item -LiteralPath $gameReport -Destination (Join-Path $gameBuild 'native-game-feature-focus-process.json')}
}
