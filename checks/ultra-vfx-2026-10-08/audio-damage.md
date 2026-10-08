# Ultra 스킬 사운드·진동·피해 숫자

요청 7번과 14번의 사운드/진동 부분을 실제 게임의 30명 × 4슬롯에 연결할 수 있도록 구현했다. 등록된 `HeroRosterCatalog` 스킬 ID/슬롯을 사용하며 피해 계산·명중·치명 확률·경제·게임 RNG를 변경하지 않는다.

## 피해 숫자

- Outfit ExtraBold 18px, 검정 3px 외곽선, 최종 1.5배, 대상 발 기준 Y −48px, 벽시계 0.80초.
- 첫 90ms에 숫자를 부드럽게 카운트/변형하고 이후 정확한 값을 유지한다. 접근성/합산을 위한 `Label.text`와 `amount`는 처음부터 실제 확정 합계다. 여러 타격의 정확한 합산과 120ms 묶음 한도는 유지한다.
- 금색 `#FFD700` CRITICAL와 20개 소형 파티클, 얇은 색 분리 0.05, 고정 비용 빛/그림자 가장자리. 숫자 풀 최대 50개이며 현재 설정의 화면별 동시 표시 한도와 겹침 방지 예약 범위를 유지한다.
- Diamond `#00FFFF`는 `kind=critical` + 실제 확정 이벤트의 `ultimate_critical=true`가 있어야만 표시한다. 현재 게임에 새 스킬 치명 확률을 만들지 않았다. `overkill` 역시 실제 원피해와 타격 전 HP로 계산해 전달된 메타데이터만 표시한다. 메타데이터가 없으면 CRITICAL/일반 피해로 표시한다.
- `CombatTextPresenter.emit/raid`와 숫자 풀의 마지막 선택 인자로 맥락을 전달한다. 사냥 이벤트는 `damage_context`를 사용한다. 서로 다른 맥락의 숫자는 합산하지 않는다.

## 120개 사운드

`audio/ultra-skills/<hero>__<passive|a1|a2|ultimate>.wav`에 원본 PCM 120개를 만들었다. 30명마다 독립된 주파수/시그니처/공명/잔향, 네 슬롯마다 충전·발사·충격·여운과 길이를 다르게 합성했다. 네 속성의 음색은 기존 시각 팔레트에 맞추며 Tessa 액티브 2는 얼음 음색이다. 속성 이름은 오디오 연출 분류이고 새 피해/저항 규칙이 아니다.

전체 2,069,160bytes (디코딩 PCM 2,063,880bytes), mono 22,050Hz 16-bit, 0.16/0.28/0.40/0.72초. 외부 음원·복제 음성·유료 에셋을 사용하지 않았다. 최대 피크 0.719993, DC 오프셋 0.000000337 이하. 120개 파형의 SHA-256이 모두 다르고 같은 생성기를 다시 실행한 바이트가 모두 일치한다. [원본 검사 결과](audio-source-validation.json).

`GameAudioDirector.play_hero_skill(hero_id, slot, field, world_point, ultimate=false)`가 실제 배틀 World3D의 4개 `AudioStreamPlayer3D`를 재사용한다. UI와 전투 공유 동시 8보이스, 일반 이벤트 초당 18개 한도, 저우선순위 교체, 슬롯별 중복 억제를 유지한다. 음원은 사용 때 로드해 캐시하고 게임 난수와 별개인 기존 피드백 RNG로 피치/볼륨만 미세 조절한다. 음소거·볼륨 0·일시 정지·백그라운드에서는 실제 재생을 거부하고 기존 목소리를 멈춘다.

## 120개 진동 패턴

`HapticDirector.pulse_hero_skill(hero_id, slot)`은 30명 × 4슬롯별로 지속 시간/강도/간격이 다른 패턴을 사용한다. 패시브 1펄스, 액티브 2펄스, 궁극기 3펄스다. 모든 스킬/접촉이 공통 500–800ms 재생 간격을 공유하고, 한 펄스는 80ms/강도 0.75를 넘지 않는다. light 설정은 강도를 절반으로 낮춘다. 궁극기 꼬리에는 최대 두 타이머만 있고, 일시 정지·백그라운드·off 전환은 남은 펄스를 취소한다.

저장 설정의 기본값은 계속 off다. Android/iOS에서는 `Input.vibrate_handheld`를 호출하고 PC에서는 테스트 sink가 없으면 진동을 하지 않는다. 실제 휴대전화 진동 강도/촉감 및 사람이 들은 사운드 품질 승인은 아직 검증하지 않았다.

## 검증

- `tools/generate_ultra_skill_audio.py`: 기존 등록 데이터에 기반한 반복 가능한 음원/피드백 카탈로그 생성.
- `tools/validate_ultra_skill_audio.py`: 등록 ID 120개 정확한 대응, PCM 규격/파형 고유성/헤드룸/바이트 재현성 검사를 통과했다.
- `UltraDamageAudioSmokeTest.gd`: 120개 native 디코딩·진짜 슬롯별 3D 재생, 공유 보이스 한도, 음소거/정지, 전역 RNG 불변, 진동 패턴 취소, 숫자 합산/일생/맥락 재사용을 실제 Mobile GPU에서 검사해 통과했다. 해당 성공 레코드는 [gpu-regressions.json](gpu-regressions.json)에 있으며 이 초기 보고서의 다른 실패 항목은 후속 검사에서 수리했다. 숫자 가독성의 [최종 통합 GPU 검사 4/4](gpu-final-integration.json)도 통과했다.
- `CombatReadabilitySmokeTest.gd`의 이전 0.65초 기대값을 요청된 0.80초로 갱신했다.
- `HeroSkillPresentationRouter.gd`가 확정된 시전/패시브/궁극기 알림을 실제 슬롯별 사운드·진동·필드 컷인에 전달한다. 기존 64개 시전 토큰 중복 억제와 레거시 궁극기 이벤트를 유지한다. 패시브 피해는 실제 적 대상으로, 아군/회복/버프는 실제 최저 HP 아군 또는 자신에게만 전달한다.
- `UltraSkillRouterSmokeTest.gd`는 120개 등록 슬롯 전달, 상태/RNG 불변, 중복·정지 억제, 사냥/레이드 좌표, 컷인, 실제 `HeroKitRuntime.event`의 조건 실패·확정 발동·내부 쿨타임을 검사한다.

`UltraSkillRouterSmokeTest.gd`도 [초기 GPU 보고서의 해당 성공 레코드](gpu-regressions.json)로 확인된다. [30명 쇼케이스](showcase/showcase-fixture.json)는 실제 액티브/궁극기 시전 90개와 명시적 패시브 연출 fixture 30개, 컷인/연출 네이티브 PNG 28장을 기록했다. 패시브 30개를 자연 발동으로 주장하지 않는다. 전체 실제 성능과 메모리·마지막 수정 후 통합 결과는 [최종 검수](README.md)에 정리했다. 60fps/200MB나 물리 휴대전화 진동·청음 승인을 달성했다는 뜻은 아니다.
