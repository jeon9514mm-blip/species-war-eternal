# 종의전쟁: 이터널

가로형 자동사냥 RPG이며 **Unity 6000.6.4f1 / URP로 엔진 전환 작업 중**입니다. Unity에서 `Unity/` 폴더를 열고 `Assets/Scenes/Eternal.unity`를 Play하면 진영 선택부터 시작합니다. 진영별 자동 저장, 스테이지 구간에 따라 분위기·몬스터가 바뀌는 통합 사냥터, 장비 획득·보관함·성장·소환·편성 저장·스킬 연계·세 지역 레이드를 연결했습니다. 기존 Godot 기록은 시작 화면에서 파일 경로를 지정해 별도 Unity 기록으로 가져올 수 있습니다. 전체 콘텐츠·그래픽 마감·최종 최적화는 진행 중입니다. [검증 범위와 남은 작업](docs/unity-migration/STATUS.md)을 확인하세요.

기존 Godot **4.7.2** 프로젝트와 저장 기록은 전환 검증을 위해 보존합니다. 기존 게임은 `project.godot`를 가져온 뒤 **F5**로 실행하며, 시작 장면은 `scenes/PortraitMain.tscn`, 기준 화면은 **1280×720**입니다. 아래 기존 구현 설명은 Godot 버전을 기준으로 합니다.

최신 UI 방향(2026-10-09): 사용자 요청에 따라 **Godot 영웅 화면과 전체 메뉴 구성을 Unity UI Toolkit으로 이식**했습니다. 원본 영웅 그림을 사용하는 목록·대형 초상·성장/스킬/장비/승급 탭, 10인 편성, 사냥 HUD와 하단 메뉴, 공통 창·진영 선택 화면을 개편했습니다. [변경 범위와 검증 기록](docs/unity-migration/UI_OVERHAUL_2026_10_09_KO.md)과 [이미지 미리보기](checks/unity-ui-overhaul-2026-10-09/README.md)를 확인하세요. 이번 변경은 C# 구문 검사까지 완료했으며 **Unity 컴파일·실행 검증은 아직 하지 못했습니다. 미리보기는 실제 Unity 캡처가 아닙니다.**

이전 체크포인트의 [기본 원거리 화면](checks/unity-migration-2026-10-08/hunt-meadow-cp14.png), [×3 확대](checks/unity-migration-2026-10-08/hunt-zoom-3-cp14.png), [500 스테이지 광맥](checks/unity-migration-2026-10-08/hunt-stage-500-cp14.png), [1000 스테이지 숲](checks/unity-migration-2026-10-08/hunt-stage-1000-cp14.png), [레이드 대응 안내](checks/unity-migration-2026-10-08/raid-response-counter-native.png)는 당시 실제 실행본 캡처이며 이번 UI 개편의 실행 증거는 아닙니다. 마지막 화면은 명시적인 카운터 연습입니다.

## 시작과 개발

Unity에는 8종 원화 스킬 형태, 차징·투사체·타격·여운, 실제 대상의 회복·보호막, 궁극기 원화 컷인, 직접 누르는 6칸 스킬 연계, 영웅 상태 표시·도감 검색, 전용 맵·보스 레이드 카드와 결과·재도전 화면을 적용했습니다. 기능·디자인을 큰 단위로 개발한 뒤 종합 점검하며 프레임 최적화는 마지막에 진행합니다. [Unity 실행과 저장 안내](docs/unity-migration/NATIVE_PLAY_KO.md)를 확인하세요.

이번 제작 묶음은 맵을 가로·세로 2배로 넓히고 기본 ×1 원거리 보기와 원형 ×1.5·×2·×3 버튼을 넣었습니다. 드래그는 없습니다. 타락한 엘프·드워프·뱀파이어·늑대인간 원화와 스테이지별 디버프·스킬을 추가하고, 비슷했던 오르윈·카엘룸·카이렌의 원화를 각자 다른 스타일로 바꿨습니다. 진형별 실제 대열·편성 3개 저장·분산 등장·장비 보상을 연결했습니다. [상세 변경과 남은 범위](docs/unity-migration/HUNT_WORLD_CP14_KO.md), [몬스터 도감](checks/unity-migration-2026-10-08/fallen-monsters-cp14.png), [원정대 편성](checks/unity-migration-2026-10-08/party-formation-cp14.png)을 확인하세요.

- [실행·조작·플레이 저장](START_HERE_KO.md)
- [현재 구현과 남은 작업](CURRENT_DEVELOPMENT.md)
- [전체 문제 점검과 수정 기록](docs/PROJECT_AUDIT_2026_10_07_KO.md)
- [폴더 구조·코드 정리 규칙](docs/PROJECT_STRUCTURE_KO.md)
- [검사와 실제 화면 재현](ENGINE_TESTING_KO.md)
- [다른 컴퓨터에서 이어가기](docs/WORK_ANYWHERE_KO.md)
- [기능별 문서 목록](docs/README.md)
- [Godot 그래픽 튜토리얼·추가 제작 프로그램 조사](docs/GODOT_GRAPHICS_WORKFLOW_2026_10_07_KO.md)

## 현재 게임

다방향으로 등장하는 적 부대를 자동으로 상대하며 영웅 성장·진형·장비·레이드를 연결합니다. 가로 전용 UI, 장비 가방 200칸, 레이드 3종의 10배 강화 기준을 사용합니다.

기본 사냥터 3곳에는 회화풍 돌바닥과 청록·호박·연보라 발광 룬을 적용했습니다. 실제 영웅·몬스터 위에 이동·공격·피격·먼지·잔상 연출을 연결합니다. [맵 구성과 실제 실행 화면](MAPS_3D_README.md)을 확인하세요. 레이드의 새 배경 디자인과 Android 실기기 성능 검증은 남아 있습니다.

아우렐리아 15명의 원화·부위 조립은 [영웅 제작 문서](docs/AURELIA_HERO_ART_KO.md)와 `scenes/art/HeroPartsStudy.tscn`에서 검토합니다. 목표 비율은 긴 다리의 4.5~5등신이며 최종 시각 검수 상태는 영웅별 자산에 기록합니다.

영웅 30명 전원과 몬스터·보스 15종에 신규 전신 원화 동작 시트를 제작했습니다. 승인된 고블린 원화까지 총 46종이 공격8·대기2·보행4·피격·사망 그림으로 표시됩니다. 팔다리를 따로 분리하지 않습니다. 영웅 높이를 통일하고 양쪽에 같은 혼잡 배율을 적용하며, 무기 궤적 때문에 영웅 전체가 작아지는 문제를 고쳤습니다. 사냥 기본 높이는 영웅 2.05 / 일반 몬스터 1.20이며 전투 카메라도 가까워졌습니다. 레이드는 영웅4.20 / 보스5.10으로 맞추고 실제 이동 대열을 넓혔습니다. [전체 원화·실제 전투 검수](checks/full-body-rollout-2026-10-07/README.md)를 확인하세요.

사용자가 제공한 Meta 자료의 바닥 디테일 맵, 부드러운 그림자, Forward+ 간접광, 머리·동물 털의 셸 표현, 숫자 색광을 실제 전장에 연결했습니다. [자료별 반영 범위](assets/art-direction/meta-v33-reference/README.md)에 원본 ZIP과 구현 내용을 보존합니다. NeRF 학습 모델이나 실제 32K 텍스처가 들어 있다는 의미는 아닙니다.

추가 Meta v40 자료의 이끼·브론즈 룬, 전투 1.5배 슈퍼샘플링, Outfit ExtraBold 숫자, 실제 전신 접촉 자세의 짧은 잔상·피격 섬광·미세 호흡을 사냥·레이드에 적용했습니다. [자료별 반영 범위](assets/art-direction/meta-v40-reference/README.md)와 [실제 화면·검증](checks/meta-v40-2026-10-07/README.md)을 확인하세요.

YouTube 캐릭터 튜토리얼 자막과 공식 문서를 대조해 사냥 전신 원화가 돌바닥에 실제 방향광 그림자를 드리우도록 연결했습니다. 절전에서는 기존 접지 그림자를 사용합니다. 추가 제작 도구인 Blender·Material Maker·Krita·Substance Painter의 연결 방식은 위 그래픽 조사 문서에 있습니다.

## 저장소 구성

`scenes/`는 실행 장면, `scripts/`는 기능별 게임 코드, `tests/`는 회귀 검사, `tools/`는 제작·검사 도구, `assets/`·`audio/`·`shaders/`는 게임 리소스입니다. `checks/`에는 선별한 검증 결과, `docs/`에는 개발 문서를 보관합니다.

과거 버전의 문서와 정리 전 안내는 [개발 이력](docs/history/README.md)에 보존합니다. 옛 기록의 화면·맵·명령은 당시 버전을 설명하며 현재 실행 안내는 위 문서를 따릅니다.
