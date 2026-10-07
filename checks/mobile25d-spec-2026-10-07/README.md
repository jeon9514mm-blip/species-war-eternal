# 사용자 지정 2.5D 사양과 실제 검수

2026-10-07 요청, 2026-10-08 검수. [사용자 품질 기준](user-quality-reference.jpg)을 보존했습니다. 아래 화면은 Godot 게임을 실행한 캡처입니다. 참고 이미지 수준에 도달했다는 판정은 하지 않습니다. 캐릭터 명암·원형 발광·타격 순간의 밀도는 추가 시각 검수가 필요합니다.

## 실제 반영 범위

| 영역 | 구현 |
|---|---|
| 영웅30명 | **86.4 논리px**(48×1.5×1.2, 사용자 최종 확인). 발 기준 높이·원화 비율 유지,45° camera billboard,16자세, 실제 이동/공격 대상을 따른 좌우 시선 |
| 원형 배치 | 10명 입장/이동 대기 반지름120px/36°. 교전에는 독립 추격·몸체 충돌 해결. 항상 원형에 묶지 않음 |
| 메시 | 영웅 몸체6000+hair cards300개/600triangles=6600. 몬스터/보스 몸체3000+런타임 털4겹/8triangles. 얕은 원화 relief이며 완전한 해부학적 리깅 모델은 아님 |
| 보조 움직임 | 영웅 호흡1.5px/2초, 망토3점, hair card 바람. 걷기/호흡으로 키를 늘였다 줄이지 않음 |
| 석판 |1024 albedo+AO alpha/normal, moss12%는 균열 띠 안에만, patina18%는 균열에, wear.5/dust.15/AO.4/roughness.58/metallic.32 |
| 문양 | Moss#A8B89E/Bronze#C4A484,glow.35/inner.25,4개 주요 룬,.15rad/s,입자8개. 투명 문양 에셋+실제 돌출 메시 방향 화살표/sin |
| 몬스터 | 분리20px/정렬.10/응집.05/회피30px. 겁쟁이·호기심·게으름·장난을 별도 RNG로2–6초마다 갱신. 기존 타격거리/시전/기절 유지. 멧돼지2.2초/.04,들개1.2초/.08,까마귀1.5초/.06,털4겹/wind.08,소리 추첨30% |
| 숫자 | Outfit ExtraBold800/14px/검정80%2px outline,일반#D8D5CC/치명#C4A484,scale1.2/발 위32px/.60초. 치명입자8개/shake4px/chromatic.01 |
| 타격 | trail.15초/잔상1개/flash.04초/입자10개. 실제 접촉에 Engine.time_scale .1을60ms 적용/복구. shake2px(치명4px),zoom punch1.05/.1초 |
| 카메라 |45°/zoom1.3/y−20px,6초주기2px 이동 호흡,Perlin shake,먼지12군집×4개/parallax. 줌 타격에도 영웅 높이 보정 |
| 레이드 | 보스166.4px(128×1.3),호흡2px/1.8초,Moss/Bronze 위험 표시/glow.5/pulse1.2,실제 경고·타이머·화면 섬광. 보스 실제 머리 위치에 따른 여백 보정 |
| 보상 | 확인된 금화/보석 증가에만 Outfit12px popup,Bronze beam/입자6개/소리. 아이템도 실제 획득 이벤트. 시각 효과에서 보상이나 추첨을 만들지 않음 |

삭제했던 영웅별 스킬 문양·궁극기 컷인은 복원하지 않았습니다. 최신 요청의 공통 타격·잔상을 추가했습니다. 효과 끄기·정지·화면 전환 시 보조 움직임·히트스톱·카메라·보상을 정리하고 전역 배율을 복구합니다.

## 렌더러와 성능

기본 **Mobile**. Directional.85/PBR/rim18%/사전 제작 접지 그림자alpha.4. 접지 마스크는5tap이며 환경 그림자는 Godot Soft Medium PCF입니다. Godot 설정을 'PCF5'라고 바꾸어 부르지 않습니다. 전장 전체 LightmapGI를 베이크한 상태도 아닙니다. [그림자 API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html).

Mobile bloom.35/vignette.65는 전장 화면 셰이더입니다. Forward+는 native bloom.35/strength.8,SSS.15,SDFGI(추가 bounce feedback0). Mobile의 따뜻한 투과색은 SSS 근사입니다. [렌더러 구조](https://github.com/godotengine/godot-docs/blob/master/engine_details/architecture/internal_rendering_architecture.rst), [재질 지원](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/standard_material_3d.rst).

[실측 JSON](review-mobile/performance.json)의 assets는 실제 압축 텍스처/mipmap과 메시 배열입니다. 영웅당 약1.68MB/몬스터당 약1.51MB. PNG 파일 크기와 GPU 메모리를 혼동하지 않습니다. 10영웅50MB/12몬스터36MB는 해당 에셋 예산이며 UI·기존 에셋·렌더 버퍼까지 포함한 게임 전체 VRAM 보장이 아닙니다.

**GTX1050/Windows 측정이며 Android 실기기 측정은 없습니다. 60fps는 목표이고 통과로 표시하지 않습니다.** 프로필별 평균FPS·95백분위 프레임시간·실제 적 수는 위 JSON을 기준으로 합니다. 일반 전경 사냥의 시뮬레이션은 누적 시간20Hz로 처리하며 렌더링·입력은 계속 갱신합니다. 피해/보상/저장 계산식은 유지하지만 접촉 slow motion과 최대50ms의 공격 판정 간격은 이번 변경의 실제 동작 차이입니다.

## 검수와 재현

양 진영의 [실제 타격 숫자](captures/damage-noxfera.png)와 [실제 획득 순간](captures/loot-noxfera.png)을 기록했습니다. 타격·획득 정지 캡처에서는 이미 발생한 대미지의 트윈만 두 렌더 프레임 동안 정지해 숫자를 읽을 수 있게 했습니다. 피해·보상·전투 배치를 합성하거나 새로 만들지 않았습니다. 대미지의 표시 유지.32초+퇴장.28초=총.60초는 실제 트윈 시간 검사도 통과합니다.

- [실제 사냥](review-mobile/hunt-review.png), [10명 원형 입장](review-mobile/circle-10-heroes.png), [실제 레이드](review-mobile/raid-balanced.png).
- [동작 MP4](review-mobile/hunt-motion.mp4): 별도 .05초 고정 스텝,20fps/8초 게임 기록. 실시간FPS 측정 영상은 아님. 녹화 fixture의 전역 hitstop만 꺼서 프레임 순서를 재현 가능하게 함.
- [집중 회귀](final-focused-regressions.json), [전체 점검](../game-audit-2026-10-07/README.md), [제작 원본](../../assets/mobile25d/README.md).

명령: `python tools/diagnostics/game-audit-2026-10-07/run_mobile_review.py --renderer mobile`. Forward+는 `--renderer forward_plus`. 임시 APPDATA/XDG를 사용하여 실제 사용자 저장을 읽거나 수정하지 않습니다.
