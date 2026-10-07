# 전투 AI 학습 도구

Stable-Baselines3 PPO, Gymnasium, PyTorch CPU를 프로젝트 학습 도구로 등록했다. 등록 정보는 `registry.json`, 재설치 버전은 `requirements.txt`에 있다. 이 PC에서는 `../validation/combat-ai-env/Scripts/python.exe` 환경에 설치하고 실제 연동을 검증했다. Windows Visual C++ x64 런타임도 Microsoft 공식 14.51.36247로 업데이트하여 PyTorch DLL 문제를 해결했다.

## 연결된 범위

- 전용 Godot 프로세스가 실제 `PortraitMain`, `PartyMovementDirector`, `CombatDecisionEngine`과 사냥 전투를 실행한다. 레온하르트·미라·엘리시아의 레벨 3 사냥이 첫 학습 환경이다.
- 관측 28개: 영웅 체력/준비 상태, 가까운 적 4명의 체력/거리/공격력/지원형 여부/정예 여부, 경과 시간, 적 수.
- 선택 5개: 기존 AI, 약해진 적 마무리, 높은 위협 우선, 적 지원형 우선, 정예 우선. 실제 사거리·행동 가능 조건·피해·피격 처리는 게임 코드를 그대로 사용한다.
- 보상은 실제 피해, 처치, 받은 피해, 경과 시간으로 계산한다. 점수는 대상 선택만 조정한다.
- 학습은 localhost와 격리된 임시 저장 폴더를 사용한다. 앱에서 실제 사용 중인 저장 데이터를 열지 않는다. 학습 종료 시 Godot 프로세스와 임시 파일을 정리한다.

현재 게임에 학습 정책을 기본 AI로 교체하지 않았다. 128스텝은 설치·환경 규격·실제 학습·모델 저장/재로드·예측 확인을 위한 연동 검사다. 승률이나 전투 효율이 개선되었다는 근거가 아니다. 레이드 회피·스킬 타이밍·몬스터 정책은 아직 학습 행동에 포함되지 않았다.

## 재설치 / 학습

저장소 루트의 PowerShell에서:

```powershell
./tools/combat_ai/setup.ps1 -Python python
./.venv-ai/Scripts/python.exe tools/combat_ai/train.py --godot "C:/path/to/godot_console.exe" --steps 100000 --output checks/combat-ai-candidate
```

이 PC에서 설치된 환경을 바로 사용할 때:

```powershell
../validation/combat-ai-env/Scripts/python.exe tools/combat_ai/train.py --godot ../validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --steps 128 --output checks/combat-ai-smoke
```

저장한 `tactic-policy.zip`은 `--resume <경로>`로 이어 학습할 수 있다. 충분히 학습한 정책도 다른 시드·종족·지역·파티 수의 기존 AI와 비교한 뒤 게임에 적용해야 한다.

## 공식 자료와 선택 이유

[Stable-Baselines3 공식 사용자 환경 규격](https://stable-baselines3.readthedocs.io/en/master/guide/custom_env.html), [공식 설치 문서](https://stable-baselines3.readthedocs.io/en/master/guide/install.html)를 따랐다. [Godot RL Agents](https://github.com/edbeeching/godot_rl_agents)도 조사했다. Godot/Python 학습 연결 및 2D/3D를 지원하지만, 문서의 Godot 내부 ONNX 실행 경로는 .NET 엔진을 사용한다. 현재 GDScript 게임에 맞춰 기존 전투를 호출하는 Gymnasium 연결을 구현했고, Godot RL Agents 애드온이나 .NET 엔진은 설치하지 않았다.

Windows 런타임 자료: [Microsoft 공식 VC++ 다운로드](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist/).
