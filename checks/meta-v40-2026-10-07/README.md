# Meta v40 실제 적용 검수

2026-10-07 Windows Godot 4.7.2 / NVIDIA GeForce GTX 1050에서 기존 게임 코드를 수정하고 실행했습니다. [두 자료와 구현 범위](../../assets/art-direction/meta-v40-reference/README.md)에 항목별로 설명합니다.

작은 이끼·브론즈 룬, 돌 재질·조명 절제, 1.5배 3D 슈퍼샘플링·이방성 필터, 공식 Outfit ExtraBold 숫자, 실제 접촉 전신 그림 잔상 2개, 피격 섬광, 몸 전체의 미세 호흡을 확인합니다. 앞선 30명·몬스터·보스 전신 원화와 높이 통일·이동 분리를 유지합니다. 기본 게임 장면에서 양 진영 10인 사냥과 레이드 3종을 캡처했고 영웅 체력·공격력은 덮어쓰지 않았습니다.

| 실제 장면 | Mobile | Forward+ |
| --- | --- | --- |
| 아우렐리아 10인 사냥 | [화면](captures-mobile/aurelia-ten-hero-hunt.png) | [화면](captures-forward-plus/aurelia-ten-hero-hunt.png) |
| 녹스페라 10인 사냥 | [화면](captures-mobile/noxfera-ten-hero-hunt.png) | [화면](captures-forward-plus/noxfera-ten-hero-hunt.png) |
| 그룬 레이드 | [화면](captures-mobile/gray_meadow-raid.png) | [화면](captures-forward-plus/gray_meadow-raid.png) |
| 모르굴 레이드 | [화면](captures-mobile/forgotten_mine-raid.png) | [화면](captures-forward-plus/forgotten_mine-raid.png) |
| 셀레네 레이드 | [화면](captures-mobile/moonrest_forest-raid.png) | [화면](captures-forward-plus/moonrest_forest-raid.png) |

각 렌더러 5개 화면에서 이동 몸체 영역 겹침 0건과 영웅 10명 동일 표시 배율을 검사했습니다. 공격 무기·타격·경고·숫자는 몸체 영역 검사와 구분합니다. [Mobile 배율·동작](captures-mobile/captures.json) / [Forward+ 배율·동작](captures-forward-plus/captures.json). 이전 큰 발광 룬은 [직전 화면](../full-body-rollout-2026-10-07/captures/aurelia-ten-hero-hunt.png)에서 비교할 수 있습니다.

전신 30명·몬스터/보스 갤러리는 균일 높이와 원화 연결을 별도로 확인하는 배치입니다. 자연 사냥 화면은 위 표에 있습니다.

- [30명 같은 높이](captures-mobile/thirty-heroes-same-height.png)
- [30명 전신 공격](captures-mobile/thirty-heroes-original-attack.png)
- [몬스터13종·보스3종](captures-mobile/original-monsters-and-bosses.png)
- [전체 구문과 선택 회귀](tests.json)
- [최종 이끼·브론즈 색상과 효과 검사](quality-effects.json)
- [최종 바닥 대비·원화 테두리 변경 후 재검사](visual-final.json)
- [종합 결과](validation.json)

추가 튜토리얼 조사 후 사냥 원화의 실제 방향광 그림자를 돌바닥에 연결했습니다. 절전·이펙트 끄기에서는 비활성화합니다. 최종 `visual-final.json`과 두 렌더러 캡처에 포함하며 레이드 배경 그림을 입체 지형으로 바꾼 것은 아닙니다.

QualityV40 검사는 실제 게임의 렌더 프로필을 balanced→battery→balanced로 변경해 터치 투영·체력·위치·RNG·경제 상태를 확인합니다. 실제 원화 접촉 그림 잔상·회수 중 그림 고정·정지·만료·피격 섬광·효과 끄기도 검사합니다. CombatReadability 검사는 정확한 대미지·120ms 합산·다중 숫자 예약 영역·레이드 적용을 확인합니다. 모바일 렌더러 검사는 Windows GPU에서 실행한 것이며 Android 실기기 성능 검사는 아닙니다.

전체 구문 검사 485개 중 병렬 실행한 V43 검사 프로세스 하나가 진단 없이 종료됐고, 동일 파일의 단독 `--check-only` 실행은 종료 코드 0으로 통과했습니다. [원래 결과와 재확인](full-parser.json)을 보존합니다. 선택 회귀 7종 중 숫자 가독성 검사가 새 글꼴의 밀집 표시 부족을 발견했고, 겹침 없이 표시할 수 있는 추가 가로 배치 칸을 확보한 뒤 다시 통과했습니다. [원래 실행](regression-tests.json)과 [수정 후 실행](readability-final.json), 각 검사의 최종 통과 결과를 모은 `tests.json`을 구분합니다.

재현:

```powershell
python tools/run_tests.py --godot <Godot 4.7.2> --jobs 4 --tests QualityV40SmokeTest.gd FullBodyRolloutSmokeTest.gd HuntFramePilotSmokeTest.gd CombatReadabilitySmokeTest.gd V16PresentationIntegrationSmokeTest.gd HuntCoordinationSmokeTest.gd V8364CombatViewSmokeTest.gd --output checks/meta-v40-2026-10-07/tests.json
python tools/render_full_body_rollout.py --godot <Godot 4.7.2> --output checks/meta-v40-2026-10-07/captures-mobile
python tools/render_full_body_rollout.py --godot <Godot 4.7.2> --renderer forward_plus --output checks/meta-v40-2026-10-07/captures-forward-plus
python -m unittest discover -s tools -p 'test_*.py'
python tools/static_validate.py
```

캡처와 회귀 검사는 임시 플레이 저장 경로를 사용합니다. 슈퍼샘플링은 추가 GPU 비용이 있으며 절전 설정을 유지합니다. 장치별 FPS·메모리·발열과 화면 품질의 정량 점수는 이번 검증 범위에 포함하지 않습니다.
