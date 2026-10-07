# 검사와 화면 재현

Godot **4.7.2** 실행 파일을 `--godot`으로 지정하고 저장소 루트에서 실행합니다. 검사 스크립트는 `tests/regression/`, 공통 기반은 `tests/support/`에 있습니다. `--tests`에는 파일 이름을 지정합니다.

## 정적 검사

```sh
python tools/static_validate.py
python tools/validate_v83_architecture.py
python -m unittest discover -s tools -p 'test_*.py'
```

## 현재 맵·사냥 집중 검사

```sh
python tools/run_tests.py --godot /path/to/Godot_v4.7.2 --jobs 2 --output /tmp/hunt-regression.json --tests MeadowAppliedSmokeTest.gd V8364CombatViewSmokeTest.gd HuntCoordinationSmokeTest.gd V16PresentationIntegrationSmokeTest.gd V52RoleMovementSmokeTest.gd RoamingHuntDirectorSmokeTest.gd HuntAttackQualitySmokeTest.gd
```

러너는 별도 사용자 데이터 경로에서 리소스를 임포트하고 GDScript 구문을 확인한 뒤 선택 검사를 실행합니다. 플레이 저장을 검사 입력으로 사용하지 않습니다. `--tests`를 생략하면 발견한 회귀 검사 전체를 실행하므로 오래 걸릴 수 있고, 과거 화면을 기대하는 검사도 포함됩니다. 전체 실행과 선택 검사 결과는 구분해서 기록하세요.

파일 이름의 `MeadowApplied`는 기존 검사 이름이며 현재 돌바닥·발광 룬을 검사합니다. 과거 `run_v*_runtime_checks.py`는 버전별 재현 도구입니다. 현재 진입점은 `tools/run_tests.py`입니다.

## 실제 화면

그래픽 디스플레이와 Vulkan 드라이버가 필요합니다. `--headless` 실행은 렌더링 품질 검증을 대신하지 않습니다. Linux 예시는 사용자 저장을 임시 경로로 격리합니다.

```sh
XDG_DATA_HOME="$(mktemp -d)" /path/to/Godot_v4.7.2 --path . --rendering-method mobile --audio-driver Dummy --script res://tools/capture_rune_stone.gd
```

위 캡처는 사냥터 3곳의 준비·전투 화면을 `checks/rune-stone-applied/captures/`에 기록합니다. Forward+ 화면은 `MAP_CAPTURE_RENDERER=forward_plus`와 `--rendering-method forward_plus`를 함께 지정합니다. `tools/render_rune_stone.py --help`에서 `--godot`, `--renderer`, `--zone`, `--output` 옵션을 확인하세요. 일반 PC는 이미 열린 그래픽 디스플레이를 사용하며, 디스플레이 없는 Linux 환경에서만 선택적으로 `--xorg-config`와 `--display`를 지정합니다.

테스트 결과 JSON·선별 스틸은 변경 근거로 보존할 수 있습니다. 재생성 가능한 원시 로그·프레임은 로컬에 남기며 `.gitignore` 규칙을 따릅니다. 실제 Android 기기의 터치·FPS·발열 검증은 데스크톱 캡처와 별도입니다.

과거 명령과 당시 결과는 [개발 이력](docs/history/README.md)에 보존합니다.
