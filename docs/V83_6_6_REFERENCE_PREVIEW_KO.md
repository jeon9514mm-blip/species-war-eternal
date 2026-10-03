# 세 맵 디자인 검토 시안 — v83-6.6 후보

**적용 전 검토용입니다.** 사용자가 모바일에서 시안을 먼저 보고 승인한 뒤 반영하도록 요청했습니다. 이 변경은 `preview/reference-map-design-v83-6.6`에만 보관하며 기존 작업 브랜치와 GitHub main에 합치거나 업로드하지 않았습니다. 기준 커밋은 `07f4b02`입니다.

사용자가 보낸 [유적](references/map-design-2026-10-02/sanctuary.jpg) · [협곡](references/map-design-2026-10-02/canyon.jpg) · [숲](references/map-design-2026-10-02/forest.jpg) 이미지를 구조·배치 참고로 사용했습니다. 이 파일들은 게임 텍스처에 포함하지 않습니다.

| 맵 | 검토용 실제 Godot 화면 | 반영한 구조 |
|---|---|---|
| 마법 유적 | [시안](../checks/v83-6-6-preview/captures/Arcane.png) | 중앙 문양의 범위를 줄인 돌바닥, 원형 아치 회랑, 기둥을 감싼 뿌리, 수정 받침대, 보라색 꽃 |
| 붉은 협곡 | [시안](../checks/v83-6-6-preview/captures/Crimson.png) | 원형 고원, 층진 사암 절벽, 광산 목조 시설, 굽은 철길, 외곽 등불 |
| 숲 | [시안](../checks/v83-6-6-preview/captures/Evergreen.png) | 열린 중앙 초원, 낮은 돌담, 굽은 개울과 바위 둑, 계단식 폭포, 고사리·꽃 |

화면은 Godot 4.7.2 Forward+ / Vulkan llvmpipe에서 1440×1000으로 렌더했습니다. 참고 이미지와 동일한 질감·식생 밀도를 달성했다는 의미는 아닙니다. 전면 아치는 유닛을 가리지 않도록 낮은 폐허로 처리하고 동쪽 진입부를 비웠습니다. 새로운 캐릭터 모델이나 별도 이미지 생성 배경은 포함하지 않았습니다.

## 보존되는 동작

32×20 전투 바닥, 실제 충돌과 이동·스폰 좌표, 기존 HP·레이드 경고 투영을 보존합니다. 협곡의 보이는 지면 메시만 원형 고원으로 바꾸고 기존 충돌 형상을 유지했습니다. 유적의 중앙 마법진 크기와 외곽 포장 재질은 시안에서 변경했습니다.

이전 장식은 비가시 상태로 보존하며, 런타임 묶음 렌더링이 숨긴 장식을 다시 표시하던 문제도 수정했습니다. 모든 새 장식은 충돌체를 추가하지 않습니다.

## 제작·검증

`tools/ReferenceMapArt.gd`가 세 맵의 구조를 만들고, 기존 `MapArtPolish.gd`에서 호출합니다. `ArtPolish/ReferenceScenery` 아래에 저장한 MultiMesh와 메시를 에디터에서 볼 수 있습니다.

장면 제작은 **실제 렌더러가 있는 실행**을 사용해야 합니다. `--headless`의 더미 렌더러에서 MultiMesh를 다시 저장하면 배치 버퍼가 누락되는 문제를 확인하여 제작 도구에 방지 장치를 추가했습니다. 버퍼는 실제 렌더러로 재생성했습니다. headless는 파서·게임 동작 검사에 계속 사용할 수 있습니다.

```sh
godot --audio-driver Dummy --path . --script tools/polish_3d_maps.gd
MAP_CAPTURE_THEMES=Arcane,Crimson,Evergreen MAP_CAPTURE_DIR=/tmp/map-preview godot --audio-driver Dummy --path . --script tools/capture_map_art.gd
godot --headless --path . --script scripts/V8366MapArtSmokeTest.gd
```

전체 스크립트372개 파서 검사, 선택 실행 검사7종의 총1,478개 조건, 정적 리소스·링크 검사 및 아키텍처 단위 검사12개가 통과했습니다. 새 검사173개에는 장식 배치 데이터의 저장, 숨긴 메시 유지, 바닥 모서리·중앙·진입부의 충돌 높이, 협곡의 보이는 바닥 면 방향이 포함됩니다. 실패했던 바닥 면 방향을 수정한 뒤 해당 검사를 다시 통과했습니다.

유적 바닥의 경계 샘플링에서 소프트웨어 Vulkan에 검은 사각형이 생긴 문제는 경계 바깥의 불필요한 샘플을 생략하고 명시적 텍스처 미분을 전달해 해결했습니다. 최종 시안3개를 눈으로 확인했으며 로그에 셰이더 오류가 없습니다.

근거는 `checks/v83-6-6-preview/`에 있습니다. Android 실기기의 성능·Mobile 렌더러 화면 일치는 아직 검증하지 않았습니다. 사용자가 휴대폰으로 시안을 검토한다는 것과 Android 실행 성능 검증은 별개입니다.
