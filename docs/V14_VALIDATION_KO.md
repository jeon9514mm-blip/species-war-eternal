# v14 검증 상태

## 기준 엔진
- 프로젝트 기능 기준: Godot 4.7
- 권장 실행 버전: Godot 4.7.2-stable
- 렌더러: GL Compatibility

## 이번 패키지에서 확인한 항목
- 프로젝트 정적 검사: 통과
- Godot 4.7 마이그레이션 주의 API 스캔: 통과
- GDScript 함수 중복 검사: 통과
- 괄호/대괄호/중괄호 기본 균형 검사: 통과
- res:// 리소스 참조 검사: 통과
- README/문서 링크 검사: 통과
- ZIP CRC 무결성: 패키징 시 검사

## 새 테스트
- `WorldBattleResolverSmokeTest.gd`
  - 10vs10 역할 기반 전투
  - 결정론적 결과
  - 수비대 10인 생성
- `V14AsyncPvpSmokeTest.gd`
  - 적 영토 공격 행군
  - 전투 전 조기 점령 방지
  - 승리 후 타일 점령
  - 피로도
  - 전투 리포트
  - 실제 영웅 월드전 스냅샷 전달

## 런타임 검증 상태
현재 작업 컨테이너에는 Godot 네이티브 실행 파일이 기본 설치되어 있지 않습니다.
Godot 4.7.2 공식 Linux 바이너리를 가져와 실제 headless 테스트를 실행하려 했지만, 이 작업 환경의 외부 바이너리 다운로드 제한 때문에 네이티브 실행 단계까지는 완료하지 못했습니다.

Godot 4.7.2가 설치된 PC에서:

```bash
python tools/run_tests.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --output docs/v14-test-results.json
```

으로 전체 스모크 테스트를 실행할 수 있습니다.
