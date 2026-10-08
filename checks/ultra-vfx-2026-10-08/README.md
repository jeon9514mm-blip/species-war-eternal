# Ultra 스킬·화면 적용 및 검수 — 2026-10-08

등록된 **30명 × 4슬롯 = 120개**에 영웅별 문양·색·궤적·충격·사운드·진동과 궁극기 컷인을 연결했다. 기존 원화와 실제 전투 스킬을 사용하며, 공용 셰이더와 제한된 풀을 재사용한다. 요청의 숫자와 표현을 최대한 반영했지만 **사냥 60fps·전체 메모리 200MB는 달성하지 못했다.**

## 15개 요청의 실제 적용 범위

| 요청 | 적용 내용과 제한 |
|---|---|
| 1. PBR 마이크로 디테일 | 알베도/AO·노멀·마이크로 노멀·Height/Cavity/Curvature/Wetness 4맵. Triplanar와 4/8단계 POM, Height 0.08. 기본 1024, 품질 옵션 실제 4096 마이크로 노멀. |
| 2. 헤어 600 | 30명 실제 GLB에 600카드/1200삼각형, Wind 0.15·Clump 0.3·Frizz 0.1·Anisotropy. 거리 LOD는 300카드. 헤어 광원 그림자는 품질 모드에서 사용. |
| 3. 망토 5점 | 고정 뿌리 포함 5점 체인, Wind 0.12·Stiffness 0.12·Damping 0.88, 몸통/비인접 점 충돌. 제한된 2.5D 스트립이며 완전한 천 표면·찢김 시뮬레이션은 아님. |
| 4. 잔상 0.40초 | 실제 타격 원화 잔상 최대 5개를 한 MultiMesh 드로우로 재사용. 밝은 중심/어두운 밑선과 색 분리·왜곡 적용. Motion-vector blur는 잔상/궤적으로 근사. |
| 5. 입자 40+20 | 스킬 GPU 버스트 최대 6개, 각각 주/보조 40/20개, 실제 바닥 충돌·Turbulence·수명별 크기/색. 일반 타격은 캔버스 배치. 입자마다 광원·그림자를 추가하지 않음. |
| 6. 충격 1.8 | 궁극기 Power 1.8·Sigil Glow 0.9, 짧은 가로/세로 플레어와 2탭 방사 블러. 궁극기 180ms/0.08배 슬로우와 Flash 0.18은 3초 간격. 일반 타격마다 전역 정지를 반복하지 않음. |
| 7. 피해 숫자 | Outfit 18px·Outline 3px·Scale 1.5·Y −48·0.80초·치명 입자 20개. 90ms 숫자 변형/카운트. 금색 치명·실제 궁극기 치명 맥락의 청록색·실제 Overkill 정보만 표시. |
| 8. 조명 | Directional 1.0·Bloom 0.60·Vignette 0.75·Shafts 0.25. Forward+에서 SSAO/SSIL/SSR/SDFGI/체적 안개, Mobile은 제작 AO·반사 하늘·일반 안개·분석식 광선. |
| 9. 바닥 | 측정 이끼 18.00003%·균열 밖 0px·균열 녹 24.99932%, 2단계 Wear 0.8·AO 0.7·Moss Glow 0.25. 웅덩이/젖음의 재질 반사, 발자국 50개 풀. |
| 10. 원형 | 3중 링·룬 12개·잎/먼지 각 20개·꽃잎·균열 발광·왜곡/에너지 펄스, Glow 0.7·Inner 0.55. 사냥의 실제 이끼 광원 0.9, 그림자 추가 패스 없음. |
| 11. 영웅 | 최종 키 86.4px 유지, Outline 3px·호흡 2.5px·접촉 그림자 0.7/Y 16·레벨업 입자 20개. SSS 0.25는 Forward+ 네이티브, Mobile은 따뜻한 방출광 근사. Rim 25%. |
| 12. 몬스터 | 분리 25px·정렬 15%·응집 8%·회피 40px·성격 1–8초·음성 확률 50%, 실제 6층 MultiMesh 털/LOD·상처 표식·기존 사망 원화. 물리 털·별도 털 그림자 없음. |
| 13. 카메라 | 호흡 10초/3px·Perlin 5/10px·Zoom Punch 1.15·보스 포커스·색 분리/왜곡/그레인. DOF/보케는 Forward+ 품질 모드 전용. 실제 3° roll은 레이드/터치 좌표 안정성을 위해 제외. |
| 14. 120개 스킬 | 120개 영웅/슬롯 시그니처, 30문양 아틀라스와 공유 셰이더의 차징→발사→충격→잔상→여운, 궁극기 원화 컷인. 원본 음원 120개와 120개 진동 패턴, 3D 재생/공유 보이스 제한. |
| 15. 최적화 | 실제 7200/3600 삼각형 영웅 LOD, 300/500/800px 보조 LOD·Frustum·MultiMesh·배치/풀·캐시. 균형 모드 0.85 해상도/MSAA 2x, 품질 1.0/MSAA 4x. 모든 엔진 기법을 동시에 켰다는 의미는 아님. |

Mobile과 Forward+는 선택하는 렌더러이며 동시에 사용하지 않는다. `PCF13`과 정수형 `SDFGI 2 bounces`는 Godot 4의 실제 속성이 아니다. 그림자 필터는 품질/균형/절전 4/3/1, SDFGI는 Forward+의 Bounce Feedback 0.65로 대응했다. 새 HLOD 트리·Occluder·베이크된 Lightmap/Probe·Texture Streaming·전용 Job System/Compute·FXAA+TAA 동시 적용을 완료했다고 주장하지 않는다. GPU 입자와 캔버스 플레어는 그림자 달린 입자별 광원/물리 렌즈와 구별한다. 세부 구현: [환경](environment.md), [영웅·몬스터](secondary.md), [숫자·사운드·진동](audio-damage.md).

## 실제 실행 성능

Godot **4.7.2**, **GTX 1050**, **Mobile 균형 모드**, 1024 마이크로 노멀/4단계 POM, 3D 해상도 0.85/MSAA 2x. 실제 게임 루프를 측정한 뒤 PNG를 저장했다. 쇼케이스의 수동 연출 시간은 이 성능 측정에 포함하지 않는다.

| 실제 조건 | 평균 fps | 95% 프레임 시간 |
|---|---:|---:|
| 아우렐리아 사냥 | 37.27 | 49.50ms |
| 녹스페라 사냥 | 39.13 | 44.50ms |
| 레이드 | 59.33 | 26.90ms |
| 자연 크리티컬 사냥 | 40.14 | 43.09ms |

[performance.json](review/performance.json)에 측정 시간·프레임·실제 시전·입자·리소스 사용을 기록했다. 자연 크리티컬 조건은 실제 확률 8.4%의 고정 시드 검수이며 느려진 프레임 비율은 약 2.99%다. 사냥은 여전히 60fps에 미달하고 긴 프레임도 남아 있다.

Windows에서 Godot 실행 프로세스와 콘솔 래퍼를 합산한 **최대 샘플 Working Set(상주 RAM)은 768,192,512 bytes(약 768.2MB)**, **최대 Private Bytes(할당된 전용 메모리)는 1,079,685,120 bytes(약 1080MB)**다. 768MB를 전체 할당량으로 표현하지 않으며, 별도의 공유 GPU 메모리까지 합산한 전체값도 아니다. 엔진의 Static/Texture 메모리 지표만으로 전체 200MB라고 판단하지 않았다. [process-memory.json](review/process-memory.json). Android 실제 기기 성능·열·진동 촉감과 사람이 들은 음질은 미검증이다.

## 네이티브 화면과 30명 스킬 검수

현재 게임 화면: [사냥](review/hunt-final-review.png), [레이드](review/raid-final-review.png), [Fire/Ice/Light/Dark 실제 시전](review/skill-elements-review.png). 레이드 입장 커튼이 끝난 뒤 촬영했으며 원화 흰색 플래시/이전 중복 피드백을 화면 자체로 확인했다. [검수 조건](review/review-fixture.json).

별도 쇼케이스는 4개 진영/대기조 편성으로 **영웅 30명·등록 연출 120개**, **실제 액티브/궁극기 시전 90개**와 **명시적 패시브 연출 fixture 30개**를 검수했다. 차징·발사·충격·잔상·여운·소멸·패시브 7단계 × 4편성 = **네이티브 PNG 28장**이다. 패시브 30개를 자연 발동으로 표현하지 않는다. Level 60·준비된 쿨타임/게이지·사거리 내 고HP 적·부상 아군은 검수 조건이며 플레이어 저장 파일은 사용하지 않았다. [전체 시전/캡처 증거](showcase/showcase-fixture.json).

- 아우렐리아: [주력 10명 충격](showcase/aurelia-core10-impact.png), [대기 5명 잔상](showcase/aurelia-reserve5-trail.png), [패시브 fixture](showcase/aurelia-core10-passive-fixture.png)
- 녹스페라: [주력 10명 충격](showcase/noxfera-core10-impact.png), [대기 5명 발사](showcase/noxfera-reserve5-flight.png), [패시브 fixture](showcase/noxfera-reserve5-passive-fixture.png)

이미지는 실제 Godot 렌더러 픽셀이며 별도 AI 생성/합성 검수 이미지가 아니다. 28장은 편성별 동시 연출 검수로, 120개 스킬 각각의 개별 PNG 120장을 뜻하지 않는다.

## 검사와 수정 이력

각 테스트의 마지막 결과와 파서 소스 해시를 대조한 [최종 검증 요약](delivery-validation.json)은 **중복을 제외한 Mobile 검사 15/15·Forward+ 1/1·파서 58/58** 통과를 기록한다. 상세 보고서는 [Mobile 인스턴싱/원화 검사 8/8](gpu-instancing-final.json), [최종 Mobile 통합 검사 4/4](gpu-final-integration.json), [Forward+ 환경 검사](forward-environment.json), [최종 파서](parser.json)에 있다. 같은 테스트의 반복 실행을 별개 완료 항목으로 합산하지 않는다. 정적 검사도 GDScript 551개·Smoke 250개 및 리소스/링크 연결, Main 예산 5684 아키텍처 검사를 통과했다. [원화/메시 보존](actor-assets.json), [120개 음원 원본 검사](audio-source-validation.json)도 별도 기록했다.

사냥 Planner 캐시는 **결정 1600개 + 궤적 480단계 = 2080개 비교**에서 이전 동작과 상태가 정확히 일치했다. [planner-equivalence.json](planner-equivalence.json). 전투 RNG·피해 규칙·경제를 시각 연출과 구분해 검증했다.

초기 [gpu-regressions.json](gpu-regressions.json), [gpu-instancing.json](gpu-instancing.json)과 중간 성능/실패 기록은 그대로 보존했다. 실패 항목은 후속 보고서의 같은 테스트가 통과하는지 확인해야 한다. 특히 가변 캔버스 배치의 활성 개수/배열 길이 불일치로 발생한 Windows 힙 손상을 실제 엔진 소스에서 확인해 고쳤고, 최신 전체 캡처가 정상 종료했다. [원인·수정 증거](native-batch-buffer-fix.md), [활성 개수 변화 GPU 검사와 출력](gpu-final-integration.json). 원시 실행 로그는 저장소의 기존 제외 규칙을 따른다.

## 두 Meta 참조의 실제 내용

[첫 링크](https://www.meta.ai/share/a/977ee1f5-a5b5-4d19-ac9d-38d01b1e6d8d)의 HTML와 [둘째 링크](https://www.meta.ai/share/a/f24ae156-1d35-4db7-a404-c3cc193d8f8a)의 ZIP를 모두 읽었다. ZIP는 브라우저 재시도 실패 후 직접 HTTP로 받았으며 32개 파일의 CRC/SHA와 UTF-8 본문을 데이터로 검수했다. 영웅 30개 파일의 스킬 이름 **120/120개가 현재 등록 내용과 일치**한다.

ZIP에는 원화·셰이더·모델·음원 에셋이 없고, 공용 생성 함수 3개는 `pass`다. Boolean/숫자 상수만으로 완성 이펙트나 성능을 증명할 수 없다. 제공 코드의 0.08배 시간/0.18초 scaled timer는 명목상 벽시계 2.25초까지 이어질 수 있어 그대로 실행하지 않았다. 게임은 최대 180ms 벽시계·쿨타임·이전 시간 복원 방식으로 구현했다.

[ZIP 감사](reference-zip-audit.md), [32개 파일 해시/120개 이름 대조](../../assets/art-direction/meta-ultra-reference/inventory.json), [96개 상수 전체 구현 대응/제한](../../assets/art-direction/meta-ultra-reference/parameter-coverage.json), [원본 ZIP](../../assets/art-direction/meta-ultra-reference/ultra-v46-reference.zip), [출처](../../assets/art-direction/meta-ultra-reference/provenance.json). 원본 ZIP는 자료로 보존하며 내부 `.gd`를 게임 실행 경로에 추출하지 않았다. 참조의 “98점/AAA+/60fps/200MB”는 검증된 점수나 이번 완료 수치가 아니다.
