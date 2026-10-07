param([string]$Python='python')
$ErrorActionPreference='Stop'
$projectRoot=Resolve-Path (Join-Path $PSScriptRoot '../..')
$trainingEnv=Join-Path $projectRoot '.venv-ai'
& $Python -m venv $trainingEnv
if ($LASTEXITCODE -ne 0) { throw 'Could not create AI training environment' }
$trainingPython=Join-Path $trainingEnv 'Scripts/python.exe'
& $trainingPython -m pip install -r (Join-Path $PSScriptRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'Could not install AI training dependencies' }
& $trainingPython -c "import torch,gymnasium,stable_baselines3; print('COMBAT_AI_INSTALLED',torch.__version__,gymnasium.__version__,stable_baselines3.__version__)"
if ($LASTEXITCODE -ne 0) { throw 'AI runtime could not start. Check the Microsoft Visual C++ x64 runtime; see README.md.' }
