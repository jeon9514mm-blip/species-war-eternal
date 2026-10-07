# 종의전쟁: 이터널

Godot **4.7.2** 기반 가로형 자동사냥 RPG입니다. `project.godot`를 가져온 뒤 첫 임포트가 끝나면 **F5**로 실행합니다. 시작 장면은 `scenes/PortraitMain.tscn`, 기준 화면은 **1280×720**입니다.

## 시작과 개발

- [실행·조작·플레이 저장](START_HERE_KO.md)
- [현재 구현과 남은 작업](CURRENT_DEVELOPMENT.md)
- [전체 문제 점검과 수정 기록](docs/PROJECT_AUDIT_2026_10_07_KO.md)
- [폴더 구조·코드 정리 규칙](docs/PROJECT_STRUCTURE_KO.md)
- [검사와 실제 화면 재현](ENGINE_TESTING_KO.md)
- [다른 컴퓨터에서 이어가기](docs/WORK_ANYWHERE_KO.md)
- [기능별 문서 목록](docs/README.md)

## 현재 게임

다방향으로 등장하는 적 부대를 자동으로 상대하며 영웅 성장·진형·장비·레이드를 연결합니다. 가로 전용 UI, 장비 가방 200칸, 레이드 3종의 10배 강화 기준을 사용합니다.

기본 사냥터 3곳에는 회화풍 돌바닥과 청록·호박·연보라 발광 룬을 적용했습니다. 실제 영웅·몬스터 위에 이동·공격·피격·먼지·잔상 연출을 연결합니다. [맵 구성과 실제 실행 화면](MAPS_3D_README.md)을 확인하세요. 레이드의 새 배경 디자인과 Android 실기기 성능 검증은 남아 있습니다.

아우렐리아 15명의 원화·부위 조립은 [영웅 제작 문서](docs/AURELIA_HERO_ART_KO.md)와 `scenes/art/HeroPartsStudy.tscn`에서 검토합니다. 목표 비율은 긴 다리의 4.5~5등신이며 최종 시각 검수 상태는 영웅별 자산에 기록합니다.

## 저장소 구성

`scenes/`는 실행 장면, `scripts/`는 기능별 게임 코드, `tests/`는 회귀 검사, `tools/`는 제작·검사 도구, `assets/`·`audio/`·`shaders/`는 게임 리소스입니다. `checks/`에는 선별한 검증 결과, `docs/`에는 개발 문서를 보관합니다.

과거 버전의 문서와 정리 전 안내는 [개발 이력](docs/history/README.md)에 보존합니다. 옛 기록의 화면·맵·명령은 당시 버전을 설명하며 현재 실행 안내는 위 문서를 따릅니다.
