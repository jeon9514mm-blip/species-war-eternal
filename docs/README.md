# 개발 문서

처음 실행할 때는 [실행 안내](../START_HERE_KO.md), 작업을 이어갈 때는 [현재 상태](../CURRENT_DEVELOPMENT.md)와 [폴더 구조](PROJECT_STRUCTURE_KO.md)를 먼저 확인합니다.

| 주제 | 문서 |
| --- | --- |
| 실행·플레이 저장 | [START_HERE_KO](../START_HERE_KO.md) |
| 코드 위치·정리 규칙 | [프로젝트 구조](PROJECT_STRUCTURE_KO.md) |
| 검사·실제 화면 캡처 | [검사 재현](../ENGINE_TESTING_KO.md) |
| 다른 PC·GitHub 동기화 | [작업 이어가기](WORK_ANYWHERE_KO.md) |
| 현재 돌바닥·발광 룬 | [맵 구성](../MAPS_3D_README.md), [참조·구현·검증](RUNE_STONE_MAPS_KO.md) |
| 영웅 원화·부위·관절 | [아우렐리아 영웅 제작](AURELIA_HERO_ART_KO.md) |
| 사냥·게임플레이 안정성 | [사냥 홈](HUNTING_HOME_KO.md), [게임플레이](GAMEPLAY_RELIABILITY_KO.md), [사냥 AI](HUNT_AI_AND_BACKGROUND_KO.md) |
| 영웅·전체 메뉴 | [영웅 메뉴](HERO_MENU_UX_KO.md), [터치 스크롤](TOUCH_SCROLL_KO.md) |
| 장비·보관함·메일 | [가로 장비 UI](LANDSCAPE_EQUIPMENT_KO.md), [장비 메일](EQUIPMENT_MAIL_KO.md) |
| 레이드 규칙·강화 기록 | [레이드 강화](RAID_STRENGTH_QUALITY_KO.md) |
| 이전 버전·시안·검사 | [개발 이력](history/README.md), [선별 검증 자료](../checks/README.md) |

기능별 작업 문서는 작성 당시의 변경과 검증을 설명합니다. 현재 동작과 충돌하는 오래된 맵·세로 화면·전장 보기 설명은 [현재 개발 상태](../CURRENT_DEVELOPMENT.md)를 우선합니다. `V*` 문서와 날짜가 있는 보고서는 누적 개발 기록입니다.

`hero-roster-v29.json` 등 일부 JSON은 제작·검사 도구의 입력이므로 보고서처럼 일괄 삭제하지 않습니다. `docs/.gdignore`는 문서와 검토 이미지를 Godot의 게임 리소스 스캔에서 제외하며 Git 보관에는 영향을 주지 않습니다.
