# v18 검증 상태

## 기준
- Godot 4.7 프로젝트
- 권장 실행: Godot 4.7.2-stable
- 저장 버전: 18
- Authority version: 4
- Gateway version: 4

## 신규 테스트
- `AutoCombatTacticsSmokeTest.gd`
  - 저체력 힐
  - 잡몹 방어기 보존
  - 보스 예고 방어 대응
  - 정예 컨트롤 궁극기
  - 빈사 잡몹 딜러 궁극기 보존
- `V18CombatAISmokeTest.gd`
  - 정예 지원형 우선 타깃
  - 일반 전투 탱커 스킬 보존
  - 레이드 위험 예고 대응
  - 힐러 궁극기 조건
- `WorldSeasonStateSmokeTest.gd`
  - 점령 점수
  - 개인 공헌
  - 정산 단계
  - 다음 시즌 월드/군량/피로 초기화
- `V18SeasonSyncSmokeTest.gd`
  - snapshot digest
  - 변조 snapshot 거부
  - 시즌 스냅샷
  - 정산 중 점령 차단
  - 큰 client delta 행군 가속 차단

## 정적 검증
- GDScript 구조 검사 통과
- 리소스 참조 검사 통과
- README/문서 링크 검사 통과
- Godot 4.7 마이그레이션 API 스캔 통과
- 중복 함수/기본 괄호 균형 검사 통과

현재 작업 환경에는 Godot 4.7.2 실행파일이 설치되어 있지 않으므로 네이티브 parser/headless 테스트는 여기서 실행하지 못했습니다.
Godot 4.7.2가 설치된 환경에서:

```bash
python tools/run_tests.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --output docs/v18-runtime-results.json
```

으로 전체 스모크 테스트를 실행할 수 있습니다.
