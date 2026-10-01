# V60 초원 사냥터 그래픽 시범 구간

기준 프로젝트: V59 삼종 레이드 버전. 영상에서 확인한 세로형 SD 캐주얼 전투 표현을 **초원 사냥터 한 곳**에 먼저 적용했다. 기존 영웅, 스킬, 수치, 성장, 자동사냥과 충돌 판정은 유지한다.

## 적용 내용

| 구성 | 변경 |
| --- | --- |
| 배경 | 밝은 초원 바닥과 숲 하늘. 물웅덩이와 길의 위치를 유지하고 바닥에 그려져 있던 중앙 나무를 제거해 중복 그림을 피함. |
| 지형 깊이 | 실제 나무 장애물 11곳에 개별 투명 나무를 배치. 카메라를 따라 움직이고 영웅·몬스터와 같은 발 위치의 깊이 순서로 그림. |
| 몬스터 | 초원 고블린, 들개 무리, 가시 멧돼지에 대기·이동·공격·피격 동작의 4칸 시트 추가. |
| 전투 반응 | 영웅과 몬스터의 접지 그림자 및 적 처치 시 짧은 보상 파편 연출 추가. |
| 다른 지역 | 광산과 숲은 기존 그래픽을 사용. |

## 소스 위치

- `assets/backgrounds/meadow-v60/`: 초원 바닥, 하늘
- `assets/props/meadow-v60/`: 개별 나무
- `assets/monsters/meadow-v60/`: 몬스터 세 종의 투명 2 × 2 시트
- `scripts/portrait/PortraitMeadowProps.gd`: 실시간 지형 소품 위치와 깊이
- `scripts/portrait/PortraitGroundShadow.gd`, `PortraitKillBurst.gd`: 접지와 처치 효과
- `scripts/portrait/CasualMonsterAtlas.gd`, `scripts/MonsterSpriteController.gd`: 몬스터 동작 연결
- `scripts/V60MeadowPresentationSmokeTest.gd`: 시범 구간 연결 회귀 검사

시범 구간을 V59 원본에 다시 적용할 때 사용할 그림 파일 대응표:

| 프로젝트 경로 | 생성된 원본 그림 |
| --- | --- |
| `assets/backgrounds/meadow-v60/meadow-soft.png` | `exec-af96eeba-feef-4222-8236-a14f7f51c994.png` |
| `assets/backgrounds/meadow-v60/forest-sky.png` | `exec-830d8482-ec32-481f-9943-f2efd48b3c4a.png` |
| `assets/props/meadow-v60/canopy-tree.png` | `exec-c0aaebd2-429a-4695-8719-b63e0959b545.png` |
| `assets/monsters/meadow-v60/goblin-four.png` | `exec-0b385baa-bc85-4815-aa9e-ffcfb8acf6c6.png` |
| `assets/monsters/meadow-v60/wild-dog-four.png` | `exec-c0d0f622-ced8-4c44-ac08-3a85e21c22fd.png` |
| `assets/monsters/meadow-v60/bristle-boar-four.png` | `exec-5c318bc1-a3cc-4cf9-af15-86a6d43576c3.png` |

## 확인

Godot 4.7.2에서 GDScript 209개 컴파일, 초원 표현·초원 길찾기·사냥 UI·아트 스크롤 회귀 검사 4개 통과. 초원 표현 검사는 카메라 이동에 따른 나무 위치, 영웅과 몬스터의 그림자, 몬스터 그림 자원, 실제 적 처치 이펙트, 화면 종료 시 정리를 확인한다.

이 단계는 한 지역의 시범 구간이다. 영웅은 기존 동작 시트를 사용하며, 새로 제작한 몬스터 그림도 사방향 전용 시트가 아니어서 왼쪽 방향은 반전으로 표현한다. 캐릭터별 다방향 애니메이션과 전체 지역의 화풍 통일은 다음 제작 단계가 필요하다.
