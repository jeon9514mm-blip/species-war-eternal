# 현재 맵 구성

기본 사냥터 3곳은 새 회화풍 돌 원화와 월드 좌표 셰이더를 사용합니다. 청록·호박·연보라 룬과 서로 다른 돌·광원 색으로 구분하며 실제 영웅·몬스터가 기존 32×20 좌표에서 전투합니다.

| 위치 | 역할 |
| --- | --- |
| `scripts/maps/RuneStoneGround.gd` | 돌바닥 메시·재질·시각용 시간 |
| `shaders/RuneStoneGround.gdshader` | 균열·이끼·물웅덩이·룬·요철 |
| `assets/maps/rune-stone/` | 현재 돌 원화·출처 기록 |
| `scripts/maps3d/Battlefield3DView.gd` | 실제 전투 카메라·배치·화면 투영 |
| `scripts/maps/FieldArtCatalog.gd` | 사냥터 팔레트·광원·아트 경로 |
| `scenes/MapGallery.tscn` | F6 맵 재질 검토 |
| `tools/capture_rune_stone.gd` | 실제 게임 준비·전투 캡처 |

전장 보기 전환은 제거했으며 전투 카메라를 사용합니다. 갤러리에는 사냥터 3종과 레이드 디자인 대기 항목이 있습니다. 기존 조형물·맵 아트·PBR 실험은 폐기 상태이고 레이드 새 디자인은 아직 적용하지 않았습니다.

[참조·구현 범위·실제 화면 검증](docs/RUNE_STONE_MAPS_KO.md)과 [재현 명령](ENGINE_TESTING_KO.md)을 확인하세요. 과거 맵 설명은 [이력](docs/history/README.md)에서 확인합니다.
