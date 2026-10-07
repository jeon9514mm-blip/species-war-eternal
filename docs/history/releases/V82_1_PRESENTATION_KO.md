# v82-1 사운드 · 햅틱 · 표현 성능 — 작업 및 실행 기록

기록 시각: 2026-09-30T17:53:08.788879+00:00

**기준: v81-1. 이번 범위는 표현 계층 1차 구현과 집중 엔진 검사다. Android 출시 성능·음질·진동 체감 검증 완료가 아니다. v83~v85는 미구현이다.**

## 1. 입력과 보존

v79 분할 입력을 CRC 확인하여 복원하고 마지막 v81-1 누적 패치를 적용했다. 서로 다른 과거 동명 패치를 혼합하지 않았다. 새 게임 배포 ZIP은 만들지 않았다.

- 부모 v81-1 누적 패치 SHA-256: `d294358a21583c4e42b702f8026e6be139742b57a1a103c744fb8c601679e46e`.
- 사용자 제공 엔진 ZIP SHA-256: `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
- 이번 실행 버전: `4.7.2.stable.official.ed1daf0bf`.
- 기존 `assets/` **602개 모두 SHA-256 동일**. 그림·맵·초상화·기존 폰트·그래픽 테마 변경 없음.
- 영웅 전투/로스터, 장비, 수호신, 레이드 설계/전장, 자동사냥 컨트롤러, 기존 일일/주간 전투 규칙, SaveStore/SaveValidation, project.godot은 부모와 동일.
- **게임 저장 버전35 유지**. 별도 장치 설정 `user://ui-preferences.cfg`에 표현 옵션을 저장한다. 기존 게임 세이브/재화/드롭률/미션 목표/도감 효과를 변경하지 않았다.
- Main, HUD, 전투 FX와 일부 보상 성공 지점은 실제 연결을 위해 수정했다. 전체 전투 파일이 byte-identical하다고 주장하지 않는다.

## 2. 사운드

`audio/v82/`에 BGM4곡(초원·광산·숲·보스), 환경음3종, 효과음17종, 합계 **24개 / 1,230,630 bytes**를 추가했다. BGM과 환경음은 Vorbis 루프, 짧은 효과음은 WAV다. `manifest.json`에 실제 해시·길이·피크·RMS가 있고 `tools/generate_v82_audio.py`로 생성 과정을 남겼다.

**독자적인 절차 생성 음악과 합성 효과음 초안**이다. 다른 게임 음원을 복사하지 않았지만, 전문 음원 녹음/청취 믹싱을 끝낸 상용 사운드 팩은 아니다. 작업 환경에서 실제 스피커 청취 평가는 하지 않았다. 사용자가 나중에 별도 제작 음원으로 교체할 수 있도록 파일 기반으로 분리했다.

생성 파일: `meadow/mine/forest/boss.ogg`, `ambient_meadow/ambient_mine/ambient_forest.ogg`, UI클릭·장착·강화·보상·소환·승리·패배·검·활·마법·방어·회복·제어·궁극기·치명타·보스경고·보호막파괴 WAV. 파일이 있다는 것과 모든 화면의 모든 이벤트에 연결되었다는 것은 다르다. 이번에는 기본 공격/역할 스킬/궁극기/치명타/보스 경고, 장비 조작/소환/목표 수령/일일 정산 등 확인한 경로에 연결했다. 패배 등 추가 상황별 청취/연결 검토는 남아 있다.

새 `GameAudioDirector`는 2개 BGM 플레이어로 0.65초 교차 전환, 환경음1개, 효과음8개 고정 풀을 사용한다. 사운드 종류별 재사용 대기시간과 일반 효과음 초당18회 제한, 우선순위로 중첩을 제한하며 같은 지역 반복 갱신 때 음악을 다시 읽거나 시작하지 않는다. PCM 합성은 게임 플레이 때 하지 않는다. 배경 전환 때는 효과음을 정지하고 루프를 일시정지하며 재개 때 과거 음을 몰아 재생하지 않는다. 게임의 난수 상태는 소비하지 않는다.

사운드 재생은 Godot 실제 AudioStream 자원/플레이어를 실행해 검사했다. Headless/Dummy 출력은 물리 스피커와 헤드폰 테스트가 아니다.

## 3. 설정·햅틱

기존 메뉴의 `소리 · 진동 · 성능`에서 배경음 사용, 효과음/UI/환경음 사용, 네 종류 볼륨, 미리 듣기, 진동 끔/약하게/보통, 기본/절전 설정을 제공한다. 기존 스킨과 위젯을 재사용했고 패널 내부 스크롤로 닫기/아래 항목이 접근 가능하도록 했다. 기존 합산 음소거 설정을 읽고, 설정 파일 교체 전 임시 파일 검증·백업을 수행한다. 쓰기 실패는 안내와 재저장으로 표시한다.

진동은 **기본 꺼짐**이며 이벤트별 12~55ms, 제한된 세기, 전역 200~500ms 쿨다운을 사용한다. 앱 중단 때 진동을 차단하고 자동전투 반복 진동을 제한한다. CI는 진동 요청을 가짜 수신 함수로 검사했으며 실제 모터를 울리지 않았다.

**현재 Android export preset/SDK/APK는 준비하거나 변경하지 않았다.** Android의 VIBRATE 권한과 실기기 검증이 남아 있다. `tools/configure_android_haptics.py --preset Android`는 기존 프리셋을 읽기만 하며, 명시적 `--enable`일 때 해당 기존 Android 프리셋의 `permissions/vibrate`만 수정하고 백업한다. 패키지 이름·서명·SDK를 임의 생성하지 않는다. 프리셋이 없으면 필요한 상태를 보고하고 실패한다.

## 4. 표현 성능

| 항목 | 기본 | 절전 |
|---|---:|---:|
| 화면 FPS 상한 요청 | 60 | 30 |
| HUD 갱신 간격 | 0.10초 | 0.20초 |
| 파티 전투력 표시 재계산 간격 | 0.50초 | 1.00초 |
| 선택적 FX 노드 예산 | 96 | 48 |
| 피해 숫자 표시 상한 | 16 | 10 |

물리 갱신 주기·전투 배속·시간 배율·공격/이동/회피 판정은 이 설정으로 변경하지 않는다. Headless에는 화면 FPS 상한을 강제하지 않아 시뮬레이션 검사 속도를 왜곡하지 않는다. 보스 위험 범위 표시는 선택적 FX 제한에서 제외한다. 모든 엔진 노드 수를 48로 제한한다는 뜻은 아니다.

몬스터 AtlasTexture를 이름/포즈별로 재사용하도록 했다. **10,001회 요청에서 새 포즈 자원4개**를 만들고 재사용하는 검사를 수행했다. 이것은 다른 모든 게임 자원이 생성되지 않는다는 의미가 아니다.

같은 2초 상당 HUD 호출 시험에서 기본은 HUD18회/전투력3회, 절전은 HUD10회/전투력2회였다. 입력 호출 패턴에 따른 실측 호출 수이며 **FPS 상승률/발열 감소율/배터리 절감률은 아니다**. 이미지 리사이즈·압축이나 3~5MB PNG 교체는 하지 않았으며 Android VRAM·로딩·APK 용량 최적화는 남아 있다.

## 5. 실제 엔진 결과

- 새 임시 프로젝트에서 리소스 임포트 통과. 기존 `.godot` 캐시를 복사하지 않고 새로 가져왔다.
- 전체 GDScript 엔진 검사 **280/280**. 처음280개를 검사한 뒤 종료 대기/격리 조건을 수정한 테스트12개를 다시 컴파일했다. 나머지268개와 게임 실행 코드는 동일 SHA임을 확인해 기존 실행 결과를 유지했다. 한 번에 처음부터 모두 성공한 검사라는 뜻은 아니다.
- 집중 실행 **29/29** 스크립트 통과. 신규 v82 5개는 합계 **197조건**. 등록된 과거 SmokeTest158개 전체 실행을 뜻하지 않는다.
- 최종 선택된 Headless 컴파일/테스트 로그 및 최초 깨끗한 임포트의 경고 수: **0**. 오류·종료 코드·완료 표식을 검사한다. 수정 후 일부 재검사는 동일 엔진 캐시를 재사용했고 누락 UID를 재생성하는 임포트 경고가 나왔다. 해당 경고는 결과 JSON의 retry_import_warnings와 원래 로그에 그대로 남겼으며 전체 작업 로그가 경고0이라고 주장하지 않는다.
- 사운드 스트레스 검사 추가6회 모두 통과(2개씩 병렬, 별도 완료/종료 로그 검사). 이 반복6회를 새로운6종 테스트로 합산하지 않는다.
- Python 도구 테스트: 설정 권한 편집 도구9개 + 실행 결과 판정 도구13개 통과. 게임 테스트 수에 합산하지 않는다.
- 보조 구조·경로 검사: GDScript280개/SmokeTest등록158개, API 문자열 검사 통과.
- 음원24개를 실제 디코딩하여 유한한 샘플/최대 피크0.99미만/0이 아닌 RMS/길이/해시를 확인했다. 청취 품질 검사는 아니다.

| 실제 테스트 스크립트 | 결과 | 보고된 조건 수 | 실행 초 |
|---|---|---:|---:|
| `V80ChallengeSessionSmokeTest.gd` | 통과 | 45 | 0.34 |
| `V80DailyBattleSmokeTest.gd` | 통과 | 18 | 22.54 |
| `V80DailyModesSmokeTest.gd` | 통과 | 109 | 0.64 |
| `V80DailySweepSmokeTest.gd` | 통과 | 35 | 0.64 |
| `V80DailyModesBattleSmokeTest.gd` | 통과 | 30 | 60.32 |
| `V80TowerRulesSmokeTest.gd` | 통과 | 451 | 0.82 |
| `V80TowerSettlementSmokeTest.gd` | 통과 | 50 | 0.63 |
| `V80TowerBattleSmokeTest.gd` | 통과 | 42 | 54.53 |
| `V80AbyssRulesSmokeTest.gd` | 통과 | 59 | 0.36 |
| `V80AbyssSettlementSmokeTest.gd` | 통과 | 57 | 0.43 |
| `V80AbyssSaveSmokeTest.gd` | 통과 | 15 | 0.62 |
| `V80AbyssBattleSmokeTest.gd` | 통과 | 16 | 57.59 |
| `V80EngineRewardRegressionSmokeTest.gd` | 통과 | 12 | 7.93 |
| `V74BossRaidBehaviorSmokeTest.gd` | 통과 | 34 | 3.51 |
| `V78ConvenienceUiSmokeTest.gd` | 통과 | 23 | 4.49 |
| `V79ConvenienceFlowSmokeTest.gd` | 통과 | 17 | 5.60 |
| `V81GoalRulesSmokeTest.gd` | 통과 | 512 | 0.54 |
| `V81GoalSaveSmokeTest.gd` | 통과 | 16 | 0.82 |
| `V81GoalClaimSmokeTest.gd` | 통과 | 22 | 0.44 |
| `V81GoalBattleSmokeTest.gd` | 통과 | 29 | 102.01 |
| `V81GoalUiSmokeTest.gd` | 통과 | 33 | 15.73 |
| `V82SettingsSmokeTest.gd` | 통과 | 20 | 0.28 |
| `V82AudioSmokeTest.gd` | 통과 | 71 | 1.02 |
| `V82PresentationUiSmokeTest.gd` | 통과 | 20 | 4.20 |
| `V82PerformanceSmokeTest.gd` | 통과 | 11 | 6.59 |
| `V82LifecycleSmokeTest.gd` | 통과 | 75 | 26.85 |
| `V51FxLifecycleSmokeTest.gd` | 통과 | 15 | 0.67 |
| `V31HeroFxSmokeTest.gd` | 통과 | 740 | 19.09 |
| `V57QualityPassSmokeTest.gd` | 통과 | 0 | 19.68 |

기존 v80/v81 전투 시험은 레벨을 설정한 3영웅 편성과 시뮬레이션 시간을 사용한다. 100단계 신규 유저 장기 성장·모든 10인 조합·실제 휴대폰90초 영상을 검증했다는 뜻이 아니다. 새 v82의 500개 음원 이벤트도 짧은 버스트/합성 경과 시간을 주입하고 실제 오디오 스레드가 정리할 프레임을 허용한 부하 시험이다.

### 별도 실제 창/설정 검사

Linux Xvfb + Mesa llvmpipe OpenGL 소프트웨어 렌더링으로 설정 화면을 실제로 그렸다. 7조건 통과: 실제 X11창, 30/60 프레임 상한 설정, 물리 주기 보존, 패널 배치, 닫기 버튼 화면 안, 하단 성능 옵션 접근. `v82-settings-render.png`는 그 실행 캡처다. **Android GPU/터치가 아니라 가상 디스플레이의 소프트웨어 렌더링**이다.

가상 디스플레이에서 `Could not set V-Sync mode` 경고1개가 발생했다. 드라이버가 VSync전환을 지원하지 않는 경고이며 별도 기록했다. 창 검사를 포함한 모든 로그가 경고0이라고 주장하지 않는다. 실제 FPS/발열/음향/기기 진동 검증은 여전히 미실시다.

## 6. 초기 실패와 수정

1. Main의 화면 정리 루프가 새 영구 PresentationRuntime까지 제거해 화면 전환 후 옵션이 적용되지 않았다. 화면 전용 노드만 지우고 런타임을 보존하도록 수정했다.
2. 메뉴 버튼의 신호가 실행되는 중 메뉴를 즉시 free하여 엔진 오류가 발생했다. 트리에서 분리한 뒤 queue_free하도록 수정했다.
3. 버튼 재연결 때 새 WeakRef로 인해 같은 UI 이벤트가 여러 번 연결될 여지가 있었다. 소유자 메타데이터로 중복 연결을 차단하고 재연결 수를 검사했다.
4. 빠른 음원 시작/중단 후 오디오 스레드가 정리되기 전에 시험을 종료하면 잔여 자원 오류가 간헐적으로 나왔다. 명시적 shutdown 경로와 스트림 참조 해제, 버스트 사이 실제 프레임/종료 대기를 추가한 뒤 재실행했다. 초기 실패 로그를 숨기거나 에러 필터를 제거하지 않았다. 반복6회 성공은 무한 시간 메모리 누수 검증이 아니다.

5. 기존 전투/UI 시험12개의 즉시 종료를 오디오 스레드가 정리될 때까지 기다리도록 바꿨다. 기존 성공 조건은 제거하지 않았다. 특히 V31은 프레임 진행 없이270회 이상 이펙트를 만들어 예산을 포화시키던 픽스처여서 각 독립 사례의 잔여 파편을 비웠다. v75에서 추가된 짧은 기절 차단 게이지도 on/off 비교 사이에 초기화하지 않아 울릭 비교2개가 서로 다른 초기 상태를 사용하고 있었다. 같은 초기 상태로 분리하고 차단 게이지/면역까지 비교에 추가한 뒤740조건을 통과했다. 이 변경은 시험의 격리 문제를 고친 것이지 영웅 피해 계수를 바꾼 것이 아니다.

## 7. 재현·적용

```sh
python3 tools/run_v82_runtime_checks.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --output /tmp/v82-results.json
python3 tools/static_validate.py
python3 tools/test_v82_android_haptics.py
python3 tools/test_runtime_check_runner.py
# 읽기 전용 권한 확인. 프리셋이 없으면 필요한 상태를 보고한다.
python3 tools/configure_android_haptics.py --preset Android
```

배포 패치는 WAV/OGG 바이트를 포함한 **Git binary patch**다. 이전의 일반 GNU patch명령 대신 **git apply**를 사용한다. 누적 패치는 깨끗한 v79, 증분 패치는 정확한 v81-1용이며 중복 적용하지 않는다.

```sh
# 적용할 기준 폴더에서, 먼저 백업 후:
git apply --check /path/to/species-war-eternal-v79-to-v82-1-presentation.patch
git apply /path/to/species-war-eternal-v79-to-v82-1-presentation.patch
```

게임 실행에 음원 생성기의 Python 패키지는 필요 없다. 음원을 재생성할 때만 numpy/scipy/soundfile/ffmpeg가 필요하며, Vorbis 컨테이너 때문에 재생성 파일 해시가 달라질 수 있다. 선택 리소스 내보내기를 쓰면 동적 로드 폴더 `audio/v82`가 APK에 포함되는지도 확인해야 한다.

## 8. 남은 검증과 다음 단계

실기기 음량 밸런스/음악 루프 청취, Android VIBRATE 권한과 실제 진동, 터치/스크롤, 중저사양 FPS·발열·메모리·장시간 플레이, 텍스처 임포트/APK 및 패키징 검증은 남아 있다. 이 항목은 단순 FPS상한 설정으로 완료 처리하지 않는다. 다음 신규 개발은 승인한 **v83 코드 구조 모듈화/레거시 UI 정리**이며 v84계정·서버, v85길드·소셜은 아직 구현하지 않았다.

## 공식 API 근거

- AudioStreamPlayer/볼륨·재생: https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html
- 진동/기기·권한 제약: https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-vibrate-handheld
- 화면 상한과 물리 주기: https://docs.godotengine.org/en/stable/classes/class_engine.html
- 실제 성능 측정 원칙: https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html
