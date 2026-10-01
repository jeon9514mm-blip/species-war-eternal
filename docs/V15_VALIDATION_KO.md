# v15 검증 상태

## 기준
- Godot 4.7 프로젝트 형식
- 권장 실행: Godot 4.7.2-stable
- GL Compatibility
- 저장 버전 15

## 통과한 검사
- GDScript 정적 구조 검사
- 중복 함수 검사
- 괄호/대괄호/중괄호 기본 균형
- `res://` 리소스 참조
- README/문서 링크
- Godot 4.7 마이그레이션 주의 API 스캔
- WorldWarScreen 구형 setup 호출 잔존 여부
- ZIP CRC 무결성

## v15 신규 스모크 테스트
- `WorldSupplyNetworkSmokeTest.gd`
  - 수도 보급 연결
  - 고립 영토 판정
  - 자원/방어 패널티
  - 재연결
  - 긴급 후퇴
- `WorldConflictStateSmokeTest.gd`
  - 타일 주둔 한도
  - 다중 수비대
  - 연속 전투
  - 점령
  - 집결 최대 5부대
  - 공격 FIFO
- `V15FrontlineSmokeTest.gd`
  - Main/전선 상태 연결
  - 보급망 UI
  - 지원/집결 버튼
  - 피로도 공격 제한
  - 저장/복원

## 제한
현재 작업 컨테이너에는 Godot 4.7.2 네이티브 실행파일이 설치되어 있지 않아 실제 엔진 파싱/헤드리스 실행은 여기서 수행하지 못했습니다.

Godot 4.7.2가 설치된 환경에서는:

```bash
python tools/run_tests.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --output docs/v15-runtime-results.json
```

으로 전체 테스트를 실행할 수 있습니다.
