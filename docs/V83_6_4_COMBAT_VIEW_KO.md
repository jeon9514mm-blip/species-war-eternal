# v83-6.4 — 전투 중심 카메라와 화면 가독성

기준 소스는 GitHub `1591f80d2533ebfdf11b8ff6fde192b0bc7e6a9e`의 v83-6.3입니다. 사용자가 지정한 Godot **4.7.2**를 개발·검증 기준으로 사용합니다.

## 플레이 화면

기존 카메라는 넓은 배경을 고정으로 보여주어 열 명의 영웅과 적 부대가 화면 중앙에 작게 겹쳤습니다. 이제 살아 있는 영웅·적의 발과 머리 범위를 계산해 전투 중심으로 확대합니다. 카메라 이동과 안쪽 확대는 부드럽게 처리하고, 바깥쪽 적이 새로 들어오면 먼저 시야를 확보합니다. 최소 시야를 두어 한두 유닛만 남았을 때 지나치게 확대하지 않습니다.

화면 오른쪽 위 **전장 보기**는 맵 전체를 보여줍니다. **전투 보기**를 누르면 부대 중심 시점으로 돌아옵니다. 전투 중 화면 회전이나 보기 전환은 HP·타이머·진형·전투 위치를 바꾸지 않습니다.

영웅 표시 높이를 1.95에서 2.25 월드 단위로 조정하고 카메라를 조금 더 위에서 보도록 배치했습니다. 청록/주황 발밑 링과 기존 피격색으로 피아를 구분합니다. 캐릭터는 여전히 원본 2D 프레임을 Sprite3D로 보여주며 새로운 3D 모델이나 스켈레탈 리그를 제작한 것은 아닙니다. 가독성을 위해 실제 전투 좌표나 이동 간격을 임의로 옮기지 않습니다. 밀집한 부대의 캐릭터 겹침은 일부 남습니다.

체력이 가득 찬 유닛의 막대는 숨기고 피해를 입었거나 선택된 유닛만 표시합니다. 아군의 전체 체력은 기존 파티창에서 항상 확인할 수 있습니다. 선택 대상·위급 상태·아군을 우선하며, 막대가 겹치면 가까운 표시 칸으로 옮겨 연결선을 표시합니다. 여섯 칸을 모두 사용할 수 없으면 낮은 우선순위의 막대를 숨깁니다.

레이드는 회피 가능한 바닥과 캐릭터 높이를 고려한 고정 구도를 사용합니다. 가로 화면의 보상 설명을 오른쪽 정보창으로 옮겨 전투 영역을 넓혔습니다. 경고 문양과 터치는 기존 전투 좌표를 공유합니다.

전투에 사용한 바닥 재질만 복제해 중앙 문양의 밝기·발광을 낮춥니다. `MapGallery`에서 보는 원본 맵 재질은 그대로 유지합니다. 이미지·음원 원본과 저장 버전37, 전투 피해·보상·성장 규칙은 변경하지 않습니다.

## 검증과 재현

Godot `4.7.2.stable.official.ed1daf0bf`에서 전체 GDScript **367/367**개가 컴파일되고 선택 회귀 **10/10**종의 **1,722개 조건**이 통과했습니다. 그중 새 카메라·체력 표시 검사는 1,106개 조건입니다. 정적 리소스·링크 검사와 아키텍처 단위 검사12개도 통과했습니다. 모든 과거 SmokeTest를 실행했다는 뜻은 아닙니다.

동일한 Godot 4.7.2와 Forward+/Vulkan llvmpipe에서 이전 소스의 화면3개, 변경 후 화면11개를 캡처했습니다. 변경 후 화면 캡처 검사2종은 오류 없이 통과했습니다. GPU 성능 수치는 이 결과에 포함하지 않습니다.

| 화면 | 변경 전 | 변경 후 |
|---|---|---|
| 세로 사냥 | [이전](../checks/v83-6-4/captures/before/ice-hunt-portrait.png) | [현재](../checks/v83-6-4/captures/after/ice-hunt-portrait.png) |
| 가로 사냥 | [이전](../checks/v83-6-4/captures/before/ice-hunt-landscape.png) | [현재](../checks/v83-6-4/captures/after/ice-hunt-landscape.png) |
| 가로 레이드 | [이전](../checks/v83-6-4/captures/before/ice-raid-landscape.png) | [현재](../checks/v83-6-4/captures/after/ice-raid-landscape.png) |

[전장 전체 보기](../checks/v83-6-4/captures/after/ice-overview-portrait.png) · [부상 유닛 표시](../checks/v83-6-4/captures/after/injured-labels-landscape.png) · [레이드 공격 경고](../checks/v83-6-4/captures/after/raid-warning-portrait.png)

실행 로그·결과·화면은 `checks/v83-6-4/`에 보관합니다. `V8364CombatViewSmokeTest.gd`는 양 진영과 여러 화면 비율에서 시야, 터치 역투영, 보기 전환, HP 막대, 전투 상태 보존을 검사합니다. `V8364VisualSmokeTest.gd`는 부상 유닛과 공격 경고를 재현 가능한 검증용 상태로 설정해 실제 엔진 화면을 캡처합니다. 부상·경고 캡처는 자연 전투 녹화나 밸런스 검증을 뜻하지 않습니다.

```sh
python tools/run_tests.py --godot /path/to/Godot_v4.7.2 --jobs 3 --output /tmp/combat-view-results.json --tests V8364CombatViewSmokeTest.gd V8363IceMapSmokeTest.gd V8363MapLoaderSmokeTest.gd V8362LayoutSmokeTest.gd V8362InvasionSmokeTest.gd V8362FormationDisplaySmokeTest.gd V8362FieldSafetySmokeTest.gd V836RaidBattleSmokeTest.gd V836RaidLedgerSmokeTest.gd V82PresentationUiSmokeTest.gd
```

## 남은 확인

Android 기기의 실제 FPS·메모리·발열·터치 감각은 별도 확인이 필요합니다. Linux의 소프트웨어 Vulkan 렌더링 결과를 기기 성능으로 해석하지 않습니다. 긴 플레이의 카메라 추적 선호도와 다양한 전투 이펙트의 가독성은 후속 플레이테스트 대상으로 남습니다.
