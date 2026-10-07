# v83-1 코드 모듈화 · 레거시 내비게이션 통합

**기준: v82-1 → v83-1. 실제 Godot 집중 검사 완료. 전체 게임 출시/Android 품질 인증 또는 v84~v85 완료가 아니다.**

## 1. 이번 범위

Main.gd에서 72개 함수의 책임을 8개 상태 없는 서비스로 분리했다. Main의 원래 메서드 이름·인자·반환 형식은 그대로 남기고 서비스로 위임한다. UI/테스트/기존 전투가 호출하던 API는 유지한다.

| 서비스 | 이동한 함수 | 역할 |
|---|---:|---|
| `GameSaveCoordinator` | 2 | 기존 저장 스냅샷 작성·복원과 실패 안내 |
| `OfflineRewardService` | 1 | 기존 방치 시간·보상·중복 계산 방지 |
| `HeroProgressionService` | 22 | 영웅 경험치·레벨·연구·승급·돌파 |
| `GuardianProgressionService` | 12 | 수호신 보유·장착·효과 및 기존 펫 성장 연결 |
| `SummonService` | 2 | 영웅·수호신 소환, 기존 확률·보장·난수 순서 |
| `LegacyQuestService` | 7 | 기존 목표 3종·튜토리얼 호환 (v81 목표 서비스 보존) |
| `RewardClaimService` | 3 | 출석·지원·쌓인 보상 수령 |
| `EquipmentCommandService` | 23 | 장비 장착·강화·옵션·작업장·기존 거래소 명령 |

`Main.gd`: **6,866 → 5,808줄**, 1,058줄 감소. 전체 프로젝트 코드량이나 처리 시간이 그만큼 줄었다는 의미가 아니다. 나뉜 파일은 프로젝트에 계속 존재한다. 이후 저장/보상/성장 수정을 해당 파일 단위로 검토할 수 있게 만든 것이다.

서비스는 호출마다 `main: Node`를 받는다. 지갑·영웅·저장 상태·난수 생성기는 Main 한 곳에서 소유하고, 서비스에 사본/장기 host 참조를 추가하지 않았다. 기존 `_method()` 호환 함수를 통해 가상 UI/런타임 호출도 유지한다. 본문을 옮기면서 owner 접두사와 동적 호스트의 지역 변수 선언만 조정했고, 수식/확률/보상/난수 정책은 바꾸지 않았다.

**완전한 분리 완료는 아니다.** Main에는 여전히 전투·레이드·화면 연결과 상태 소유가 남아 있으며 5,808줄이다. 이를 억지로 새 상태 객체로 한꺼번에 옮기지 않았다. 네트워크 계정 서비스나 서버 권한을 새로 구현한 작업도 아니다.

## 2. 구형/세로형 메뉴 정의 통합

`NavigationCatalog`가 하단 `홈 / 영웅 / 전투 / 가방 / 메뉴` 5개와 공용 바로가기 10개를 정의한다. 기존 `PortraitHud`, `PortraitMain`, `UiChrome`은 같은 정의를 읽고 자신들의 기존 스킨과 배치 방식으로 그린다. 반환 데이터는 깊은 복사여서 한 화면이 변경해 다른 화면 정의를 오염시키지 않는다.

구형 6탭은 5탭으로 정리하되 성장·종의전쟁은 메뉴 바로가기로 유지한다. 원정 캠프·성장/던전·사냥터·소환·종의전쟁·도감·보상·진영·훈련·시작 화면의 기능 경로를 삭제하지 않았다. 세로형 기존8개 바로가기와 소리/진동/성능·가이드는 기존 순서를 유지하고, 구형 호환 2개 항목은 아래에 배치한다. 구형 화면에서 메뉴 탭이 선택돼 있어도 메뉴 버튼은 다시 열 수 있다.

기존 화면을 모두 삭제한 것은 아니다. 호환 화면도 같은 메뉴 정의를 사용하게 하여 서로 다른 탭 목록을 유지하던 중복을 제거했다. 원래 맵·캐릭터·아이콘·색상 테마를 새로 디자인하지 않았다.

## 3. 실제 결과 동등성 비교

같은 `V83DomainParitySmokeTest.gd`를 v82-1 복사본과 v83-1에 넣고 **각각 실제 Godot에서 실행**했다. UI 알림/이동만 시험용 host로 대체하고 성장·소환·장비·SaveStore는 실제 함수를 호출했다. 두 진영·10인 편성 상태·30명 영웅의 성장·재화/XP 분배·시드 고정 소환·수호신·장비·중복 수령·파일 저장/복원·방치 보상 경계를 검사했다.

- 각 엔진 실행 **144조건 통과**.
- 비교한 **128개 상태/결과 스냅샷 모두 동일**.
- 비교에서 매번 달라지는 암호학적 장비 ID `gear_<32hex>`만 정규화했다. 실제 장비 수치·효과·소환 RNG 상태는 비교했다. 벽시계 타임스탬프는 스냅샷에서 제외하고 복원 host의 RNG도 같은 seed로 설정했다.
- 이 검사는 대표 입력의 결과 동등성이지, 모든 입력/모든 10인 전투 조합의 수학적 증명은 아니다.

별도 구조 검사도 72개 분리 함수 본문, 72개 호환 위임 함수, **분리하지 않은 Main 함수327개**와 보호 파일645개를 확인한다. 주석/공백, owner 접두사, `:=`/`=` 차이만 정규화하고 수식/문자열 변화는 검출한다. 구조 검사기는 게임 실행 검사를 대체하지 않는다.

## 4. 실제 Godot 검사

엔진: **4.7.2.stable.official.ed1daf0bf**, 사용자 제공 Linux x86_64. 검사는 원본 프로젝트 및 사용자의 저장 파일 대신 임시 프로젝트와 별도의 사용자 저장 경로에서 실행했다.

| 검사 | 최종 결과 | 범위 |
|---|---|---|
| 리소스 임포트 | 통과 | 최초 깨끗한 임포트 후, 최종 전체 재실행은 동일 엔진 캐시로 임포트 재확인 |
| 전체 GDScript 엔진 검사 | **291/291** | 수정 후 전체 재실행 |
| 집중 실제 실행 | **37/37** | 과거 등록160개 전체 실행이 아님 |
| 신규 v83 검사 | **2종 / 226조건** | 도메인144 + 내비게이션82 |
| 부모/현재 결과 비교 | **128/128 동일** | 동일 시험을 두 실제 프로젝트에서 실행 |
| 보호 검사 | **645개 파일 동일** | 기존 assets602·audio25(음원24+manifest)·핵심 규칙18 |
| Python 도구 단위 시험 | **8+13 통과** | 구조 검사기 및 실행 결과 판정기, 게임 테스트 수에 합산하지 않음 |
| 최종 임포트/컴파일/집중 로그 경고 | **0줄** | 초기 실패 로그와 구별 |
| Android / 이번 GPU 화면 검사 | **0회 / 0회** | 실기기/가상 GPU 렌더링 인증 아님 |

| 테스트 | 결과 | 보고된 조건 수 | 실행 초 |
|---|---|---:|---:|
| `V80ChallengeSessionSmokeTest.gd` | 통과 | 45 | 0.156 |
| `V80DailyBattleSmokeTest.gd` | 통과 | 18 | 16.197 |
| `V80DailyModesSmokeTest.gd` | 통과 | 109 | 0.248 |
| `V80DailySweepSmokeTest.gd` | 통과 | 35 | 0.366 |
| `V80DailyModesBattleSmokeTest.gd` | 통과 | 30 | 38.822 |
| `V80TowerRulesSmokeTest.gd` | 통과 | 451 | 0.257 |
| `V80TowerSettlementSmokeTest.gd` | 통과 | 50 | 0.252 |
| `V80TowerBattleSmokeTest.gd` | 통과 | 42 | 30.078 |
| `V80AbyssRulesSmokeTest.gd` | 통과 | 59 | 0.169 |
| `V80AbyssSettlementSmokeTest.gd` | 통과 | 57 | 0.265 |
| `V80AbyssSaveSmokeTest.gd` | 통과 | 15 | 0.249 |
| `V80AbyssBattleSmokeTest.gd` | 통과 | 16 | 37.933 |
| `V80EngineRewardRegressionSmokeTest.gd` | 통과 | 12 | 5.570 |
| `V74BossRaidBehaviorSmokeTest.gd` | 통과 | 34 | 2.695 |
| `V78ConvenienceUiSmokeTest.gd` | 통과 | 23 | 3.233 |
| `V79ConvenienceFlowSmokeTest.gd` | 통과 | 17 | 4.067 |
| `V81GoalRulesSmokeTest.gd` | 통과 | 512 | 0.252 |
| `V81GoalSaveSmokeTest.gd` | 통과 | 16 | 0.266 |
| `V81GoalClaimSmokeTest.gd` | 통과 | 22 | 0.172 |
| `V81GoalBattleSmokeTest.gd` | 통과 | 29 | 64.745 |
| `V81GoalUiSmokeTest.gd` | 통과 | 33 | 10.970 |
| `V82SettingsSmokeTest.gd` | 통과 | 20 | 0.156 |
| `V82AudioSmokeTest.gd` | 통과 | 71 | 0.995 |
| `V82PresentationUiSmokeTest.gd` | 통과 | 20 | 3.246 |
| `V82PerformanceSmokeTest.gd` | 통과 | 11 | 3.613 |
| `V82LifecycleSmokeTest.gd` | 통과 | 75 | 15.664 |
| `V51FxLifecycleSmokeTest.gd` | 통과 | 15 | 0.438 |
| `V31HeroFxSmokeTest.gd` | 통과 | 740 | 10.234 |
| `V57QualityPassSmokeTest.gd` | 통과 | 완료 표식 확인 | 15.280 |
| `V83DomainParitySmokeTest.gd` | 통과 | 144 | 12.973 |
| `V83NavigationSmokeTest.gd` | 통과 | 82 | 7.163 |
| `V27GrowthEconomySmokeTest.gd` | 통과 | 40 | 4.084 |
| `V27PersistenceIntegrationSmokeTest.gd` | 통과 | 18 | 9.208 |
| `V27SaveRecoverySmokeTest.gd` | 통과 | 80 | 4.737 |
| `V54EquipmentIntegrationSmokeTest.gd` | 통과 | 359 | 10.611 |
| `V54EquipmentPersistenceSmokeTest.gd` | 통과 | 84 | 6.690 |
| `V65GuardianSmokeTest.gd` | 통과 | 완료 표식 확인 | 3.803 |

`V57`은 다른 형식의 결과 출력을 쓰므로 공용 실행기의 조건수 필드는0이고 완료 표식·종료코드·오류 로그로 판정했다. 0을 게임 테스트를 안 했다는 뜻이나 조건 총합으로 사용하지 않는다. 기존 전투 검사는 레벨을 설정한 3영웅 시험 편성이며 실제 신규 유저100단계 장기 플레이를 대신하지 않는다.

## 5. 초기 실패와 수정 기록

첫 전체 실행은 컴파일291개가 통과했으나 집중37종 중31개만 통과했고, 두 번째 전체 실행은33개 통과였다. 아래 UI 및 시험 격리/종료 문제를 바로잡고 실패 로그를 보존한 뒤 **전체291개+37종을 다시 실행**했다. 최종 결과만을 처음부터 모두 성공한 것처럼 표현하지 않는다.

1. 메뉴를 빠르게 재개방할 때 지연 포커스 콜백이 트리에서 분리된 버튼을 참조했다. WeakRef와 트리/삭제 상태 확인을 추가했다.
2. 공용 메뉴10개를 모두 위쪽에 표시해 기존 가이드가 입력 가능한 범위 아래로 밀렸다. 실제 입력을 사용하는 `V57` 회귀에서 발견했고 기존8항목/설정/가이드를 먼저 유지하도록 수정했다. 입력 시험은 축소하지 않았다.
3. 과거 장비 저장 시험2조건이 버전31을 고정으로 기대하고 있었다. 현재 SaveStore.VERSION(35)을 검사하도록 고쳤다. **제품 저장 버전을 올리거나 기록을 초기화하지 않았다.**
4. 오디오가 추가되기 전의 일부 성장/저장/장비 시험이 호스트 해제 직후 프로세스를 종료해 잔여 자원 경고가 발생했다. 오디오 스레드/노드 정리 대기를 시험 종료에 추가했다. 일일 전투 시험은 음원 명시적 shutdown과 취소 세션 참조 해제도 넣었다. 전투 성공 조건이나 오류 필터를 제거하지 않았다. 보스 Ogg 스트림은 verbose 로그에서 OggPacketSequencePlayback/AudioStreamPlaybackOggVorbis가 남는 것을 확인했고, 재생 노드가 살아 있는 동안 shutdown한 뒤 믹서가 정리를 마칠 시간을 주었다.
5. 새 내비게이션 시험이 구형 Chrome을 PortraitMain 위에 그린 뒤 구형 오버레이를 기대했다. 실제 구형 Main과 세로형 PortraitMain을 별도로 생성해 각자의 원래 디스패처/메뉴를 검사하도록 수정했다.
6. 과거 저장 왕복 시험은 시작 화면이 새로 경과한 방치 시간까지 자동 정산한 뒤에도 이전 파일과 완전히 같은 재화를 기대했다. 파일 복원과 새 시간 정산을 각각 검사하도록 시험용 host에서 자동 정산을 일시 보류했다. 원래 Main의 파일 복원과 방치 보상 함수는 그대로 실행했고, 소비된60초를 재사용하지 않는 조건도 유지했다. 실제 제품의 초기 보상 처리를 끄거나 저장 수식을 바꾸지 않았다.

초기 일일 시험에서 게임 조건18개는 통과했지만 자원 경고 때문에 실패로 집계했다. 진단 반복3회는 별도이며 새로운 테스트3종으로 합산하지 않았다. 최종37종의 정리 후 성공이 무한 시간 누수 부재를 보장하는 것은 아니다.

## 6. 보존 및 남은 검증

- **게임 저장 버전35, SaveStore/SaveValidation 및 기존 영웅·장비·수호신·레이드/도전 규칙 유지**.
- 기존 그래픽/폰트 assets602개, 음원24개·음원manifest의 SHA-256 동일. 자동 임포트로 추가된 `.import`/`.uid`는 메타데이터이며 새로운 작화/음원이 아니다.
- 게임 내 드롭·소환 확률·피해량·성장비·미션 보상 수치는 바꾸지 않았다.
- 이번 변경의 성과는 책임 분리·경로 일관성·수정 전후 결과 비교이며 FPS 개선율/배터리 절감률을 측정한 것이 아니다.
- Android FPS/발열/터치/메모리, 음원 실제 청취/물리 진동, 장시간 플레이, 모든10인 조합, 신규 유저 속도 검증은 남아 있다.
- **다음 신규 개발은 v84 계정·클라우드·온라인 권한 기반, 그 다음 v85 길드·소셜이다. 아직 구현하지 않았다.**

## 7. 재현과 적용

```sh
python3 tools/run_v83_runtime_checks.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --output /tmp/v83-results.json
python3 tools/validate_v83_architecture.py
python3 tools/test_v83_architecture.py
python3 tools/test_runtime_check_runner.py
python3 tools/static_validate.py
```

실행 도구는 v82의 격리 실행기를 재사용하고 v83 테스트 선택만 확장한다. 테스트별 로그·종료 코드·완료 표식·소스 해시를 남기고 오류/시간 초과를 실패로 처리한다. 부모 동등성 증거는 별도 `domain-parity-comparison.json` 및 양쪽 원본 로그에 있다.

새 ZIP은 생성하지 않았다. **누적 Git binary 패치는 깨끗한 v79**, **증분 패치는 정확한 v82-1**용이다. 둘을 같은 기준에 중복 적용하지 않는다. 원본 코드와 세이브를 먼저 보관한다.

```sh
# 정확한 기준 프로젝트 폴더에서 실행
# 깨끗한 v79를 갖고 있는 경우:
git apply --check /path/to/species-war-eternal-v79-to-v83-1-modularization.patch
git apply /path/to/species-war-eternal-v79-to-v83-1-modularization.patch
# v82-1을 쓰는 경우에는 v82-1-to-v83-1 증분 파일 하나만 사용
```

이번 기준 부모 v82-1 패치 SHA-256: `d34ce157afde253a864bdd25c2c33768f22a8a6ef411923ed372a9474be020ac`.
엔진 ZIP SHA-256: `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.

공식 참고: Godot scene organization/명시적 의존성, command-line/headless, RefCounted 문서. 참조한 패턴이 프로젝트 전체 설계 검증을 대신하지 않는다.
- https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html
- https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- https://docs.godotengine.org/en/stable/classes/class_refcounted.html
