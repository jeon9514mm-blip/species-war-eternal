# 레이드 입력·전환·저장 점검

실제 `PortraitMain → RaidPresentationV2 → PortraitRaid` 경로를 점검했다. 실행마다 임시 `APPDATA/XDG_DATA_HOME`을 사용했고 사용자 저장은 읽거나 변경하지 않았다. 아래 검사는 Headless 동작·기하 검증이며 GPU FPS 측정은 아니다.

| 점검 항목 | 근거 | 조치 / 검증 상태 |
| --- | --- | --- |
| 공략·설정 모달 뒤 버튼이 키보드로 실행됨 | 시작 버튼에 포커스를 둔 채 설정을 열고 실제 Space 입력을 보내면 레이드가 시작됐다. 두 진영에서 닫기 포커스·뒤 버튼 실행·Shift+Tab 이동 16개 조건이 실패했다. | 설정 안으로 포커스를 옮기고 Tab/Shift+Tab과 Escape를 처리한다. 외부에서 다시 포커스를 지정해도 `ui_accept`는 차단한다. 닫기·바깥 터치·Escape 뒤에는 원래 포커스를 복구한다. 신규 회귀 검사 통과. |
| 최신 버전 저장에 대한 레이드 진입 장벽 누락 | 수정 전 `_start_raid`는 연습·저장 대기만 검사하고 `_save_blocked_for_newer_version`을 검사하지 않았다. 이 항목은 수정 전 실행 재현 결과가 아니라 코드 점검 결과다. | 공통 `SaveSafety.allow_mutation`으로 진입 검사 통합. `blocked=true, pending=false`에서 직전 HP·위치·쿨다운·골드·난수와 레이드 serial을 보존하는 회귀 검사 통과. |
| 바닥 포인터 종료·취소 관리 | 기존 실제 바깥 mouse release는 Godot의 GUI 캡처로 정상 종료됐다. 따라서 이를 재현된 기존 오류로 분류하지 않는다. 설정 열기·다중 터치·기기 취소를 명시적으로 관리할 필요가 있었다. | 전역 release 관찰, 실제 mouse button mask 확인, 설정 열기·창 포커스 상실·앱 일시정지 시 held pointer 해제. 두 번째 손가락이 바닥 포인터를 교체하지 않는다. 기존 정상 입력 및 신규 취소 검사 통과. |
| 레이드 이동 중 큰 위치 보정 | 자연 역할 이동만 `.05초 × 120회` 실행했다. Aurelia/숲 Caelum은 step 24에서 `[320.91,290] → [680.66,290]`, combat-coordinate 359.75px / 고정 카메라 투영 566.24px 이동했다. 광산은 3초 후에도 한 step 221.21 combat-coordinate px 이동했다. 카메라 배율이나 전투 피해 없이 관측했다. | 목표 위치 분리와 실제 보행을 분리했다. 현재 발 위치에 최대 360px fallback을 직접 쓰지 않는다. 선두부터 안전한 보행 구간을 예약하고 막힐 때 옆으로 돌아간다. 최종 같은 조건에서 일반 보행은 한 step 최대 6.40003 combat-coordinate px, 10.07276 logical px이며 이동 예산 초과는 0회다. |
| 설정된 대열을 이동 명령이 교차시킴 | 원형의 실제 영웅 위치를 이동 명령 때 출전 인덱스의 5×2 격자로 재배정했다. 왼쪽 후열에게 오른쪽 목표가 생겨 앞 영웅과 길이 교차했다. 75px 후퇴 검사에서 Aurelia/광산은 8초 뒤에도 중심 이동이 0px였다. | 실제 `_raid_order_move`가 현재 대열의 상대 위치를 저장하고 그 대열을 함께 운반한다. 두 진영·세 레이드의 75px 후퇴는 8초 후 목표 오차 0~0.94px, 최대 step 10.25001px로 완료했다. |
| 원형 초기 배치의 x좌표 환산 오류 | 기존 원형 배치가 카메라 역변환의 x배율 `RAID_GROUND_STRETCH=2`를 빠뜨려 x폭이 두 배가 되고 중심이 왼쪽으로 밀렸다. 바닥 경계 clamp가 여러 영웅을 같은 가장자리에 놓았다. | 실제 `world_to_raid` 역변환을 사용하고 진입 커튼 안에서 한 번만 간격·공격 사거리에 맞게 초기 배치한다. 보행 중 배치를 즉시 고치지 않는다. |
| 보스 추격과 카메라 확대가 간격을 다시 바꿈 | 보스가 바닥 상단으로 추격하면 머리 여백을 맞추려고 `_rest_camera_size`가 계속 커졌다. 원화 크기는 고정이라 발 간격이 좁아지고 다시 분리 보정이 필요했다. 앞 영웅만 추격해 뒤 영웅의 335px 공격 사거리를 벗어나는 경우도 있었다. | 전용 맵의 보스 동선을 y≥380인 전용 라인으로 두고, 실제 화면과 같은 `(2,1)` 간격 측정을 쓴다. 정상 자동 공격 중 뒤 영웅의 공격 사거리를 벗어나게 멀어지는 보스 추격은 잠시 기다린다. 두 진영·세 맵에서 3초 이후 최저 발 간격 71.93px 이상, 최후 보스 간격 89.30px 이상, 전 영웅 공격 거리 335px 이내를 확인했다. |
| 메뉴에서 편성 교체 후 체력바 누적 | `BackgroundHunt._reconcile_party`가 Dictionary의 노드 값 대신 영웅 ID 키를 순회했다. 실제 10→9명 편성에서 기존 노드가 해제되지 않아 체력바 9개가 소유자를 잃고 제외된 영웅 키도 남았다. 두 진영·3회 교체의 신규 34조건 중 16조건이 실패했다. | 실제 `values()` 노드를 해제하고 참조 Dictionary를 비운 뒤 현재 편성만 만든다. 수정 후 34조건 전부 통과. 숨은 사냥 tick과 직접 Home 복귀 모두 검사했고 부상 체력 비율·같은 사냥 화면·일시정지·지갑을 보존했다. 기존 메뉴 사냥 회귀도 통과. |

## 검증 자료

- [raid-input-before.json](raid-input-before.json): 최초 신규 입력 검사 46조건 중 16실패. 레이드 공략·설정의 키보드 문제를 실제 이벤트로 재현했다.
- [raid-input-after.json](raid-input-after.json): 첫 수정 뒤 46조건 통과. 이후 외부 포커스·설정 중 held touch·창 포커스 상실·중복 결과 콜백 검사를 추가했다.
- [raid-lifecycle-final.json](raid-lifecycle-final.json): 입력 검사와 `CompactRaidUiSmokeTest`, `RaidTouchLayoutSmokeTest`, `V82LifecycleSmokeTest`, `V836RaidLedgerSmokeTest` 5/5 통과.
- [raid-delivery-final.json](raid-delivery-final.json): 최종 소스의 `RaidContinuousMovement` 50조건, `RaidProjectedSpacing` 342조건, `RaidCombatQuality` 35조건, `RaidInputLifecycle` 54조건 통과. 직접 교차 목표는 두 영웅 모두 도착했고 모든 중간 보간 구간의 간격도 유지했다. 이미 유효한 공격 자리에 배치되어 있으면 발을 움직이지 않고 유지할 수 있다. 이동 진척은 실제 이동 명령과 별도 평행·교차 이동으로 검증했다.
- [lifecycle-baseline.json](lifecycle-baseline.json): 경제·저장 복구·메뉴 중 사냥 3검사 통과. `V82Lifecycle`은 제작 중 새 레이드 shader가 아직 없는 시점의 parse error로 실행 판정에 실패했다. 제작 완료 후 위 최종 실행에서 오류 없이 통과했으며 게임 자체의 별도 버그로 분류하지 않았다.
- [raid-movement-pacing-before.json](raid-movement-pacing-before.json): 두 진영·세 레이드의 실제 이동·투영 수치. 재현 도구는 [run_raid_pacing_probe.py](../../tools/diagnostics/gameplay-field-2026-10-08/run_raid_pacing_probe.py).
- [raid-movement-pacing-delivered.json](raid-movement-pacing-delivered.json): 같은 조건의 최종 위치·속도·공격 거리. 원래 큰 위치 보정은 없어졌고 두 진영·세 맵의 마지막 발 간격은 모두 71.94px 이상이다.
- [hunt-health-lifetime-before.json](hunt-health-lifetime-before.json), [hunt-health-lifetime-final.json](hunt-health-lifetime-final.json): 체력바 수명 34조건의 16실패→0실패와 기존 메뉴 사냥 동작의 2/2 통과.
- [hunt-native-health-native.json](hunt-native-health-native.json): 검수 캡처와 같은 `PortraitMain`·10명 Lv60·154스테이지 fixture를 실제 Mobile GPU에서 검사했다. 두 진영의 준비 화면 4연속 frame 및 1초 사냥에서 소유한 영웅 체력바는 `value=max_value=100`, `visible=false`, 녹색 fill `#328263`, `draw_center=true`, 최소 크기 1×1이었다. 이전 검수 이미지의 검은 선은 이 수명 버그나 스타일 오류 때문이라고 확정하지 않았다. 원인 없이 스타일을 변경하지 않았으며 해당 관측은 미확정으로 남긴다.

기존 저장 복구·보상 중복 방지·메뉴 중 사냥 상태 유지의 정상 동작을 확인했다. 각 중간 실패 로그는 수정 과정의 재현 자료로 남겼으며 최종 통과 자료는 `raid-delivery-final.json`과 `raid-movement-pacing-delivered.json`이다.
