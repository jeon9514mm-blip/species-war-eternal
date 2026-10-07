# 전투 이동 끊김 수정 — 2026-10-08

일반 공격 때 반복되던 전역 시간 감소와 전체 원화 정지를 제거했습니다. 사냥의 20Hz 계산은 유지하고 영웅·몬스터 표시 위치를 매 렌더 프레임에 연결합니다. 같은 표시 위치를 그림자·HP/숫자 기준점·대상 시선·카메라·원형 문양·공격 예고에 사용합니다. 생성·죽음·순간이동은 즉시 맞추고, 일시정지 후에는 마지막 표시 위치에서 이어집니다. 치명타 카메라 피드백의 최소 간격은 0.75초이며 일반 공격은 화면을 흔들지 않습니다. 개별 피격 반응·플래시·파티클은 유지합니다.

레이드는 0.25초마다 다섯 계산을 한 프레임에서 실행하던 구조에서, 같은 50ms 계산을 물리 프레임에 분산합니다. HUD 타이머는 중복 전투 계산을 하지 않습니다. 직접 호출하는 headless/검사 경로는 기존 고정 간격을 지원합니다.

충돌 쌍 반경·원화 자세/털 메시·일정한 shader uniform을 재사용하고, 장애물 없는 바닥의 불필요한 탐색과 대상/공격 우선순위의 반복 스캔을 줄였습니다. 크기 86.4px·1024 텍스처·메시·머리카락·털4겹을 낮추지 않았습니다. 피해/보상 계산과 AI 선택 결과는 원본 함수와 비교했습니다.

## 실제 GPU 전후 측정

Windows Godot 4.7.2 Mobile, GTX 1050, 1120×630 창/1280×720 논리 크기, balanced/x1, 10인 Lv60/스테이지154. 효과 켜짐, 음악/음향 꺼짐, 2초 준비 후 양 진영 사냥 각각8초·레이드6초. 실제 게임 루프를 실행했고 측정 중 다른 벤치마크를 실행하지 않았습니다. 화면 읽기/PNG 저장은 각 측정이 끝난 후에 수행했습니다.

| 장면 | 평균 FPS | 프레임 간격 p95 | 걷기 중 위치 유지 샘플 비율 |
|---|---|---|---|
| hunt-aurelia | 35.49 → 39.74 | 58.48 → 46.20ms | 56.44% → 2.66% |
| hunt-noxfera | 36.22 → 40.17 | 54.82 → 46.07ms | 53.98% → 1.73% |
| raid | 50.58 → 59.21 | 59.68 → 35.99ms | 0.00% → 0.00% |

걷기 비율은 `state == walk`인 영웅의 연속 렌더 발 위치가 같았던 비율입니다. 목표 도착/충돌 대기 샘플도 포함하므로 모든 유지 샘플이 엔진 렉이라는 뜻은 아닙니다. 전후 동작 시간이 달라 자연 전투의 적 수·전투 단계가 완전히 같은 것은 아닙니다. FPS와 p95는 단일 짧은 측정이며 모든 기기에서의 보장이 아닙니다. 사냥60fps와 Android 실기기는 아직 확인하지 않았습니다. 이전의 전역 슬로모션을 제거한 직후 CPU 부담이 드러난 중간 측정도 보존했습니다.

- [수정 전](before/performance.json), [최종 수정 후](after/performance.json), [중간 결과](intermediate-performance.json)
- [아우렐리아 실제 화면](after/hunt-aurelia.png), [녹스페라](after/hunt-noxfera.png), [레이드](after/raid.png)
- [원화/털 캐시 CPU](render-cache.json), [충돌 원본 대조](collision-cost.json), [탐색 대조](navigation-cost.json), [AI/스킬 원본6,681개 대조](../stutter-fix-2026-10-08/decision-equivalence.json)

## 검증 범위

변경 GDScript 30/30, 최신 집중 회귀 12/12, 실제 GPU 회귀 3/3 통과. 정적 리소스/링크와 구조 검사 통과. 이동 매프레임 연결·정지/재개·생성/죽음·연속피격 정상시간·레이드 계산분산/타이머중복방지·통일 크기·레이드 터치를 검사했습니다. [종합 결과](validation.json).

충돌 경계75,000쌍과120개 crowded solver 상황에서 원본 좌표/속도/이동거리와 일치했습니다. 표적/스킬6,681개도 원본과 같았습니다. 추가 V29RosterKit는885개 동작 검사와180개 시전은 통과했지만 종료 자원 정리 경고로 runner 실패를 보존했습니다. 전체 과거237개 검사를 이번에 다시 실행한 것은 아닙니다. 이전 전체 검사에서 남은 실패들은 이 수정으로 해결했다고 표시하지 않습니다.

일부 sandbox 실행은 Windows 인증서 저장소 시작 오류를 출력했습니다. 게임 오류와 구별해 원본 로그에 보존하고, 최종 parser/GPU 회귀는 sandbox 밖의 격리 저장 데이터로 재검사했습니다. 로그는 재생성 자료여서 Git에는 올리지 않습니다.

## 재현

```powershell
python tools/diagnostics/game-audit-2026-10-07/run_movement_pacing.py --phase after
python tools/run_tests.py --godot ../validation/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe --gpu --skip-syntax --jobs 1 --tests MovementPacingSmokeTest.gd Mobile25dSpecSmokeTest.gd RaidTouchLayoutSmokeTest.gd
```

사용한 보간 원리는 [Godot 공식 fixed-step interpolation 설명](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)을 따릅니다. 실제 사냥 계산이 엔진60Hz 물리보다 낮은20Hz이므로 사냥 스냅샷을 별도로 연결하며 입력/판정에는 실제 시뮬레이션 위치를 사용합니다.
