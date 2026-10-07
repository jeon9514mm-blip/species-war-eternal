# 프로젝트 구조와 유지 규칙

현재 실행 기준은 Godot **4.7.2**, 시작 장면은 `scenes/PortraitMain.tscn`입니다. 코드 위치는 기능을 기준으로 정하고, 게임 코드·검사·개발 기록을 분리합니다.

## 폴더별 역할

| 위치 | 역할·주요 시작점 |
| --- | --- |
| `scenes/` | 기본 게임, 맵 갤러리, 독립 영웅 검토 장면 |
| `scripts/app/` | 게임 상태와 서비스 연결; `Main.gd` |
| `scripts/portrait/` | 현재 가로 게임의 화면 조립·흐름; `PortraitMain.gd` |
| `scripts/hunting/` | 자동사냥 진행·이동·적 부대·목표 선택 |
| `scripts/combat/` | 공통 공격·피해·진형·전투 효과 |
| `scripts/heroes/`, `scripts/monsters/` | 로스터·영웅 골격·몬스터 표현 |
| `scripts/equipment/` | 장비 규칙·가방·비교·공방·보관함·메일 |
| `scripts/progression/` | 성장·보상·연구·일일 콘텐츠 |
| `scripts/raid/`, `scripts/world/` | 레이드와 월드·진영전 |
| `scripts/persistence/` | 저장 검증·저장 처리·오프라인 사냥 |
| `scripts/ui/`, `scripts/presentation/` | 공통 UI·오디오·표시 서비스 |
| `scripts/maps/`, `scripts/maps3d/` | 현재 바닥·맵 로더·카메라·전장 렌더링 |
| `scripts/art/`, `scripts/sd/`, 진영별 아트 폴더 | 원화·스프라이트·골격 제작과 검토 |
| `tests/regression/` | 실행 가능한 회귀 검사 |
| `tests/support/` | 공통 검사 기반·도우미 |
| `tools/` | 검사 러너·캡처·아트 제작·분석 도구 |
| `tools/diagnostics/` | 검증 출력 폴더에서 옮긴 진단 스크립트 |
| `assets/`, `audio/`, `shaders/`, `ui/` | 실제 게임 이미지·음원·셰이더·테마 |
| `checks/` | 선별한 결과 JSON·실제 화면·검토 영상 |
| `docs/` | 현재 안내·기능별 기록·제작 명세 |
| `docs/history/` | 이전 안내문·버전별 릴리스·복구 기록 |

`portrait`·`aurelia-4head`처럼 오래된 이름이 일부 남아 있어도 화면 방향이나 현재 신체 비율을 의미하지 않습니다. 기존 저장·자산 ID와 연결되는 이름은 동작 확인 없이 일괄 바꾸지 않습니다.

## 변경할 때

1. 기존 서비스의 책임에 맞는 폴더에서 수정합니다. 루트 `scripts/`에 새 게임 파일이나 검사를 쌓지 않습니다.
2. `.gd` 파일을 이동할 때 `.uid`도 함께 이동합니다. `preload`, `load`, `extends`, 씬 경로, Python 도구, 문서의 참조를 함께 갱신합니다.
3. 검사 코드는 `tests/regression/`, 공통 기반은 `tests/support/`에 둡니다. 파일 이름으로 선택하려면 테스트 이름이 중복되지 않아야 합니다.
4. 새 출력은 `checks/<작업명>/` 또는 프로젝트 밖 임시 폴더에 기록합니다. 실행 가능한 진단 코드를 `checks/`에 넣지 않습니다.
5. [검사 안내](../ENGINE_TESTING_KO.md)의 정적 검사와 변경 관련 회귀 검사를 실행하고, 화면 변경이면 실제 렌더를 확인합니다.
6. Git 변경 목록에서 실제 소스·자산과 선별 검증 자료를 확인한 뒤 커밋합니다.

버전별 `run_v*_runtime_checks.py`는 서로 가져오는 역사적 검사 체계입니다. 파일 이름에 옛 버전이 있다는 이유만으로 하나씩 삭제하면 다른 러너가 깨질 수 있습니다. 현재 검사는 `tools/run_tests.py`를 사용합니다.

## 생성 파일·내보내기

`.godot/`, Python 캐시, 개인 인증·기기 설정, 빌드 출력은 `.gitignore`로 제외합니다. 게임 자산의 `.import`와 스크립트 `.uid`는 소스 메타데이터이므로 보관합니다. 검토 캡처의 `.import`, 원시 로그·프레임·임시 렌더는 보관 대상과 구분합니다.

`docs/.gdignore`와 `checks/.gdignore`는 문서·검토 이미지를 Godot에서 임포트하지 않도록 합니다. `tests/`와 `tools/`에는 실제 실행해야 하는 GDScript가 있으므로 같은 방식으로 숨기지 않습니다. 일부 제작 도구는 `docs/hero-roster-v29.json`, `tools/hero-anatomy/`, `tools/v83_extraction_map.json`을 입력으로 사용합니다.

현재 저장소에는 배포용 `export_presets.cfg`가 없습니다. 배포 프리셋을 만들 때는 게임이 참조하는 리소스를 포함하고 `tests/*`, `tools/*`, `checks/*`, `docs/*`가 배포 파일에 들어가지 않는지 확인해야 합니다. 실제 배포 검사 전에는 APK 크기나 내보내기 완료를 주장하지 않습니다.

## 다음 구조 개선

이번 정리는 경로·진입점·출력·문서를 분류합니다. `scripts/app/Main.gd`와 화면 조립 파일에는 여전히 큰 메서드와 많은 책임이 남아 있습니다. 다음 단계에서는 저장·장비 명령·전투 흐름 등 한 책임씩 서비스로 옮기고, 실제 게임 결과와 저장 호환을 검사하며 진행합니다.
