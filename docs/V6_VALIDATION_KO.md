# v6 검증 상태

## 완료한 정적 검증

- `scripts/app/Main.gd`를 포함한 GDScript 파일의 문자열/주석 구간을 제외한 괄호 짝 검사
- 파일별 `func` 이름 중복 검사
- v6 핵심 함수와 테스트 파일 존재 여부 검사
- `tools/run_tests.py` Python 구문 컴파일 검사
- 최종 ZIP 무결성 검사

## 런타임 검증 안내

현재 제작 환경에는 Godot 4.5.1 실행 바이너리가 없어 이번 세션에서는 엔진 자체의 headless 실행을 완료하지 못했습니다. 따라서 v6는 **정적 검증 완료 / Godot 런타임 검증 대기** 상태로 표기합니다.

Godot 4.5.1이 설치된 환경에서는 전체 테스트 러너로 v6를 포함한 모든 `*SmokeTest.gd`와 `AutoHuntRegressionTest.gd`를 한 번에 실행할 수 있습니다.

```bash
python tools/run_tests.py --godot /path/to/Godot_v4.5.1-stable_linux.x86_64 --output docs/v6-test-results.json
```

또는 v6 전투만 빠르게 확인하려면:

```bash
godot --headless --path . --script res://tests/regression/V6CombatSmokeTest.gd
```

검증 항목은 10인 전투 상태·HP 바, 5마리 웨이브, 탱커 도발, 최저 HP 회복, 광역 공격입니다.
