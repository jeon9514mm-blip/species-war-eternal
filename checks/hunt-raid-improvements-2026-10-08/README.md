# 사냥 대열·이동과 레이드 전용 맵 개선

선택한 진형이 전투 중 동일한 좁은 배치로 덮어써지고, 영웅들이 같은 적을 향해 몰리던 문제를 수정했습니다. 레이드의 큰 위치 보정도 실제로 재현하고 제거했습니다. 기존 86.4px 영웅 원화와 2.5D 표현을 유지합니다.

## 실제 화면

- [아우렐리아 사냥](spacing-native-final/hunt-aurelia.png) · [녹스페라 사냥](spacing-native-final/hunt-noxfera.png)
- [균형](spacing-native-final/formation-balanced-peak-zoom.png) · [돌격](spacing-native-final/formation-assault-peak-zoom.png) · [방벽](spacing-native-final/formation-bulwark-peak-zoom.png) · [사격](spacing-native-final/formation-volley-peak-zoom.png)
- [천공 수호 유적](../combat-improvements-2026-10-08/raids/gray_meadow-running.png) · [호박빛 심층 광산](../combat-improvements-2026-10-08/raids/forgotten_mine-running.png) · [월광의 성소](../combat-improvements-2026-10-08/raids/moonrest_forest-running.png)

모두 실제 Godot Mobile 캡처입니다. 레이드 맵 검수는 전투 0.60초 시점에서 효과를 끈 상태이며, [성능 측정 화면](after/raid.png)은 실제 자동 전투와 효과를 사용합니다.

## 수정과 검증

| 문제 | 변경 / 확인 |
| --- | --- |
| 선택 진형이 같은 좁은 두 줄 또는 원형으로 덮어써짐 | 4개 진형을 실제 전투와 미리보기에 함께 사용. 최대 3행, 미완성 열도 중앙 정렬. 이동·몸통·목적지 예약에 같은 투영 간격 적용. |
| 적 하나를 향해 영웅이 몰리고 시전 중에도 걸음 | 역할별 추격 영역과 안정된 사격 자리 유지. 적 압력 방향으로 천천히 대열 회전. 화면 크기가 변해도 위치를 순간 재배치하지 않음. 사거리 밖 실제 피해는 0. |
| 좌표가 아직 없는 영웅 처리 중 실행 오류 | 위치·속도·누적 이동값을 복구하고 부활한 영웅도 고정 시전자에게 양보. HP·보상 난수 보존 검사. |
| 레이드 이동 중 순간이동 | 자연 보행 0.05초 최대 359.75px를 재현. 목표만 분리하고 실제 발은 속도 예산 안에서 움직이도록 변경. 최종 일반 보행 최대 6.40003px, 속도 초과 0. 직접 회피의 의도된 대시는 별도 동작. |
| 이동 명령이 대열을 가로질러 막힘 | 현재 대열의 상대 위치를 함께 운반. 평행·교차 경로와 실제 75px 후퇴 명령 검사 통과. 초기 배치의 가로 배율 역변환도 수정. |
| 레이드 카메라가 계속 멀어져 간격이 줄어듦 | 보스의 이동 라인과 원화 전체 여백을 기준으로 안정된 카메라. 실제 45도 투영 간격 사용. 보스 추격으로 뒤 영웅이 사거리에서 이탈하는 경우 잠시 대기. |
| 레이드 20Hz 이동의 표시 끊김 | 표시용 위치만 프레임 사이 보간. 원화 발·그림자·선택 표시·바닥 인장 동기화. 게임 위치·HP·난수·경고 판정 유지. |
| 레이드 맵 구분과 소품 가림 | 보스별 유적·광산·월광 성소 제작. 기존 1024 PBR 텍스처 재사용. 장식은 이동 영역 밖, 맵당 정적 메시 45개 이내, 추가 동적 조명 0개. |
| 설정 창 뒤 버튼이 Space/Tab으로 실행됨 | 실제 입력으로 두 진영에서 16개 실패 재현. 모달 내부 포커스·복귀·취소 관리 후 54조건 통과. |
| 편성 변경 뒤 이전 체력바가 남음 | Dictionary의 키 대신 실제 bar 노드를 해제하고 목록 초기화. 두 진영의 반복 편성 교체·메뉴 사냥·부상 HP 보존 34조건 통과. |
| 슬로모션 중 표시 FPS가 잘못 높아짐 | 프레임 기록에 실제 벽시계 시간 사용. 앱 중지·복귀 시 첫 프레임 시간 초기화. |
| 새 버전의 읽기 전용 저장에도 레이드 진입 가능 | 공통 저장 보호 가드 사용. 상태 보존 회귀 통과. 수정 전 실행 재현이 아닌 코드 점검 항목. |
| 이전 이동 방식으로 측정한 오프라인 보상 속도를 재사용 | 이동 정책 fingerprint 변경. 새 표본 12무리로 다시 측정하며 기존 보상 공식과 저장 버전은 유지. |

## 최종 검사

- [실제 Mobile 통합](delivery-validation.json) **14/14**, [체력바 수명·메뉴 사냥 Mobile](lifetime-mobile-final.json) **2/2** 통과.
- [변경한 GDScript 파서](parser.json) **36/36** 통과. 검수한 소스의 SHA256을 최종 파일과 대조했습니다.
- [장시간 사냥 검사](hunt-spacing-final-v2.json)의 `HuntCrowdFlowSmokeTest`: 두 진영 × 3사냥터, 각 120초. 전부 10명 참여·생존, 실제 치유·다음 무리 진행 유지, 몸통 겹침 0. 해당 파일에는 중간 V53 실패도 남아 있으며 V53 최종 결과는 [수정한 유효 fixture](hunt-support-valid-fixtures.json)와 Mobile 통합에 있습니다.
- [실제 렌더 관측](spacing-native-final/observations.json): 102샘플과 최대 줌의 4진형에서 몸통 겹침·보간 몸통 겹침·원화 프레임 잘림 0. 망토·무기 끝의 일부 교차는 허용합니다.
- [레이드 입력·이동·수명 상세](../gameplay-field-2026-10-08/AUDIT_LIFECYCLE.md) · [전용 맵 기하 검수](../combat-improvements-2026-10-08/raids/README.md).
- 정적 리소스/링크 검사와 현재 아키텍처 계약 검사 통과. 이번 범위는 관련 회귀 검사이며 전체 저장소의 모든 테스트를 실행한 결과는 아닙니다.

중간 실패 기록은 보존했습니다. V53의 겹친 시작 좌표·옛 진입 시계·멀리 떨어진 적을 현행 경로의 유효 fixture로 수정했으며 기존 치유·탱커·중복 시계 조건과 실제 사거리 검사를 유지했습니다. 첫 보간 검사는 새 레이드 serial 초기화가 첫 snapshot을 지우는 문제를 드러냈고, snapshot 초기화 후 최종 검사를 통과했습니다. native 캡처의 얇은 검은 선은 원인을 확정하지 못했습니다. 동일 실제 경로의 영웅 체력바 값·녹색 스타일·숨김 상태는 GPU probe에서 정상이며 임의 스타일 수정은 하지 않았습니다.

## 실제 성능

NVIDIA GeForce GTX 1050 / Godot 4.7.2-stable (official) / Mobile / balanced. 단독 실행, 별도 검수 저장, 실제 자동 전투·접촉 효과 포함. 사냥 각 8초, 레이드 6초 표본입니다.

| 화면 | 평균 FPS | p95 프레임 ms | 걷는 표시 중 동일 위치 비율 |
| --- | ---: | ---: | ---: |
| 사냥 · 아우렐리아 | 50.06 | 35.11 | 0.19% |
| 사냥 · 녹스페라 | 50.44 | 36.95 | 0.19% |
| 레이드 | 59.34 | 24.59 | 1.79% |

[측정 원문](after/performance.json) · [검수 요약](summary.json). 사냥은 안정된 60fps를 아직 달성하지 못했습니다. Android 실기기나 전체 메모리는 이번에 측정하지 않았습니다. [수정 전 기록](before/performance.json)은 일부 headless 작업의 CPU 사용과 겹쳤을 수 있어 FPS 개선 폭의 통제된 비교로 사용하지 않습니다. 이동 중 큰 좌표 보정의 재현/해결은 별도 고정 조건 검사로 확인했습니다.

재현 도구: `tools/diagnostics/hunt-raid-improvements-2026-10-08/`의 파서, native 사냥 캡처, 실제 성능 측정 runner. 레이드 맵은 `tools/diagnostics/combat-improvements-2026-10-08/run_raid_review.py --capture-only`. 실제 GPU 실행은 직렬로 수행합니다.
