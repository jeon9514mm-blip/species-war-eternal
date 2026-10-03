# v83-6.2 검사 재현

검증 엔진은 Linux x86_64 Godot4.6.3입니다. 다른 엔진 버전의 통과를 의미하지 않습니다.

```sh
python3 tools/run_v83_6_2_runtime_checks.py --godot /path/to/godot --expected-version 4.6.3 --workers 3 --timeout 600 --output /tmp/v8362-results.json
python3 tools/validate_v83_architecture.py
python3 -m unittest discover -s tools -p test_v83_architecture.py
```

러너는 임시 프로젝트와 테스트별 XDG 데이터를 사용해 플레이어 저장을 격리합니다.
모든 GDScript의 파싱과 등록된 회귀 검사를 실행합니다. 모든 역사적 SmokeTest 파일을 실행하는 것은 아닙니다.
`--test`로 집중 검사를 선택하며 `--skip-compile`은 전체 파싱을 생략했다고 결과에 명시합니다.

`validate_v83_architecture.py` 기본 검사는 현재 호환 파사드·상태 소유권·사냥 분리·명칭 단일화를 검사합니다.
`--historical-v82`는 초기 v82 추출 당시의 불변 해시 비교입니다. 이후 의도적 게임 규칙 변경에도 실패하므로 현재 릴리스 합격 기준으로 사용하지 않습니다.

실제 화면 캡처는 X11 디스플레이에서 다음과 같이 재현합니다.

```sh
V8362_CAPTURE_DIR=/tmp/captures godot --audio-driver Dummy --path . --script res://scripts/V8362LayoutSmokeTest.gd
```

캡처 폴더를 먼저 만드세요. 이 검사는 사냥·진형·설정·레이드·메뉴 화면을 렌더링하고,
진행 중 레이드의 화면 전환에서도 체력을 보존하는지 검사합니다.
소프트웨어 OpenGL 렌더링은 Android 실기기 터치·회전 센서·발열·GPU 성능 검사를 대신하지 않습니다.
