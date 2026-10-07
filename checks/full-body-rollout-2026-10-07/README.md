# 전원 전신 원화와 사냥·레이드 영웅 확대

2026-10-07, Windows Godot 4.7.2 / NVIDIA GTX 1050에서 실제 Mobile·Forward+ 화면을 검수했습니다.

영웅 30명 전원(레온하르트 포함)과 추가 몬스터·보스 15종에 신규 16자세 원화 시트를 제작했습니다. 승인된 고블린까지 총46종이 공격8·대기2·보행4·피격1·사망1 전신 그림을 사용합니다. 팔다리를 따로 분리하지 않으며 기존 SD 프레임으로 되돌아가지 않는지 검사합니다. 생성 모드·프롬프트·원본 해시는 [제작 기록](../../assets/art-direction/full-body-v2/ART_SOURCE.json)과 [프롬프트](../../assets/art-direction/full-body-v2/generation-prompts.json)에 있습니다.

영웅은 실제 서 있는 그림 높이를 기준으로 정규화하며, 모든 영웅에 같은 혼잡 배율을 사용합니다. 공격 무기 궤적을 몸체 자리 예약에서 제외했습니다. 사냥 기본 높이는 영웅2.05 / 몬스터1.20, 레이드는 영웅4.20 / 보스5.10입니다. 사냥 카메라는 영웅 전원과 현재 타깃을 따라가며 실제 몸체 높이에 맞춰 여백을 줄이고, 레이드는 영웅 목적지뿐 아니라 실제 발 좌표도 분리합니다. 실제 이동을 다시 보간해서 몸이 겹치던 부분과, 기존 2D 보스가 다시 표시되던 부분도 수정했습니다.

이번 추가 확대 직전과 같은 기본 수치·진영·단계·시드의 기록을 비교했습니다. 아래 높이는 논리 뷰포트 기준 서 있는 원화의 높이이며 공격·사망 자세의 전체 외곽 높이는 달라질 수 있습니다. 실제 표시 크기는 전장 밀집도에 따라 달라집니다.

| 기본 전투 장면 | 확대 전 | 확대 후 | 변화 |
|---|---:|---:|---:|
| 아우렐리아 10인 사냥 | 29.3px | 43.6px | +49% |
| 녹스페라 10인 사냥 | 27.5px | 45.4px | +65% |
| 그룬 레이드 | 46.2px | 59.3px | +28% |
| 모르굴 레이드 | 47.0px | 54.7px | +17% |
| 셀레네 레이드 | 23.4px | 61.1px | +162% |

위5개 실제 화면에서 몸체 영역 겹침0, 각 화면 영웅10명 동일 배율을 확인했습니다. 공격 무기·피해 숫자·스킬 효과·경고의 접촉은 전투 표현에 포함됩니다. 전투 수치·보상·피해 범위는 바꾸지 않았으나 대열과 이동 배치 변경으로 전투 결과가 달라질 수 있습니다.

- [아우렐리아 사냥](captures/aurelia-ten-hero-hunt.png) / [녹스페라 사냥](captures/noxfera-ten-hero-hunt.png)
- [그룬](captures/gray_meadow-raid.png) / [모르굴](captures/forgotten_mine-raid.png) / [셀레네](captures/moonrest_forest-raid.png)
- [30명 같은 높이](captures/thirty-heroes-same-height.png) / [30명 원화 공격](captures/thirty-heroes-original-attack.png)
- [몬스터13종·보스3종](captures/original-monsters-and-bosses.png)
- [Forward+ 실제 화면·배율](captures-forward-plus/captures.json)
- [Mobile 동작·배율·겹침](captures/captures.json) / [확대 전 기록](size-before.json)
- [종합 검증](validation.json) / [최종 회귀 검사](final-tests.json) / [장시간 이동 검사](movement-final-tests.json) / [전체 구문 검사](full-parser.json)

전체483개 GDScript 구문 검사 후 최종 변경 소스를 실제 회귀에서 다시 실행했습니다. Python50개와 서로 다른 전투 회귀8개도 통과했습니다. 양 진영 10인 각각180초 사냥에서 모든 영웅의 공격·연속 처치·보상·전멸 후 복귀를 검사했습니다. 검사는 전신46종의 원화 연결·반전·공격 시점·정지·사망·부활, 영웅 기본 높이와 공통 배율, 밀집50배치 분리, 사냥 경로·공격 진행·화면 방향별 카메라·레이드 조작·경고와 터치 좌표를 포함합니다. 과거 검사의 장애물500개 접근 조건 및3마리 무리 가정은 현재 개방형 맵·2마리 무리 규칙에 맞춰 갱신했습니다.

Meta 링크3개와 원본 ZIP2개를 보존하고, 실제 돌 디테일 맵·Forward+ SSIL/SSAO·부드러운 그림자·원화 테두리 조명·머리와 털 셸·숫자 색광을 연결했습니다. [자료별 적용 범위](../../assets/art-direction/meta-v33-reference/README.md)에 한계를 기록했습니다. 학습된 NeRF 모델·실제32K 텍스처·가닥 물리는 제작하지 않았습니다. Android 실기기 FPS·메모리·발열은 미검증입니다.

재현:

```powershell
python tools/run_tests.py --godot <Godot 4.7.2> --tests FullBodyRolloutSmokeTest.gd HuntFramePilotSmokeTest.gd V8364CombatViewSmokeTest.gd RaidCombatQualitySmokeTest.gd V53HuntNavigationSmokeTest.gd V71HuntFlowSmokeTest.gd --jobs 4
python tools/render_full_body_rollout.py --godot <Godot 4.7.2> --output checks/full-body-rollout-2026-10-07/captures
python tools/render_full_body_rollout.py --godot <Godot 4.7.2> --renderer forward_plus --output checks/full-body-rollout-2026-10-07/captures-forward-plus
```

캡처는 임시 플레이 저장 경로를 사용하며 체력·공격력 수치를 덮어쓰지 않습니다. 비교 표는 같은 조건의 Mobile 캡처이며 렌더러별 기록에는 자연 실행 시계의 작은 차이가 있을 수 있습니다.
