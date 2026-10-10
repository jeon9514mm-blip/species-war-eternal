# 가방·영웅 장비 UI

## 참고 후보와 적용

| 참고 화면 | 반영한 구성 |
| --- | --- |
| [Pinterest · Taylor Buck Inventory + Gear](https://www.pinterest.com/pin/767582330255334725/) | 종류별 아이템 격자, 선택 장비 비교 정보 |
| [Dribbble · Medieval RPG Game Inventory UI](https://dribbble.com/shots/25964428-Medieval-RPG-Game-Inventory-UI) | 장비 부위를 분명히 구분하는 배치와 금속 계열 색상 |
| [Dribbble · Warden of the Wild](https://dribbble.com/shots/25578031-Warden-of-The-Wild-RPG-User-Interface) | 영웅·장비·상태 정보의 분리 |
| [Dribbble · Action RPG Inventory](https://dribbble.com/shots/6845113-Inventory-menu-for-action-RPG-game) | 장비 탐색과 선택 정보의 계층 |
| [Dark RPG Inventory UI kit](https://benjaminui.itch.io/dark-rpg-inventory-ui-kit-figma) | 분류·아이템 선택·오른쪽 상세 정보 |
| [Dungeon Hunter 4 UI](https://www.behance.net/gallery/19915013/Dungeon-Hunter-4-UI) | 아이템 격자와 게임 메뉴의 구분 |
| [Soul Strike](https://holdings.com2us.com/ko/main/game-detail/soulstrike) | 캐릭터 주변 장비 배치와 빠른 장착 |
| [Bladebound](https://app-time.ru/post/artifex-mundi-globalno-zapustyat-bladebound-na-ios-9-noyabrya) | 캐릭터와 장비 정보의 분리 |

Pinterest 공개 핀은 브라우저에서 확인했다. Dribbble 디자이너의 제작 영상 링크도 찾았으나 영상 재생을 확인하지 못했으므로 전체 영상 시청으로 기록하지 않는다. 다른 게임의 이미지·아이콘을 에셋으로 복사하지 않는다.

현재 사냥 화면의 검정·금색 테두리에 맞춰 Unity UI Toolkit에서 직접 조작 가능한 메뉴를 만들었다. 가방 4분류, 희귀도·강화·전투력 정렬, 장착할 영웅과 반지 위치 선택, 장착·강화·잠금·공방 연결, 보관함과 자동장착을 제공한다. 비교 정보는 현재 영웅의 실제 공격력·방어력·체력 전후 수치이며 미리보기가 저장·장착·재화를 변경하지 않는다.

재료 탭에는 보유 중인 옵션 결정·레이드 정수·영웅 조각을 표시한다. 없는 재료나 장비를 일반 계정에 생성하지 않는다.

## 실제 10부위

사진 왼쪽: 무기·투구·장갑·갑옷·부츠. 사진 오른쪽: 벨트·반지 1·반지 2·팔찌·목걸이.

원본 3부위의 weapon·armor·accessory 기록은 그대로 보존하며 accessory를 목걸이로 표시한다. 새 7칸은 미장착으로 시작한다. 반지는 같은 종류를 두 위치에 장착할 수 있으나 서로 다른 실제 아이템을 소비한다. 빈칸 장착은 가방 아이템을 제거하고, 교체 장착은 기존 장비를 가방으로 돌려준다. 모든 부위의 능력치·옵션·세트·강화는 실제 영웅 전투 프로필에 반영된다.

사냥·레이드 보상은 추가 부위도 지급한다. 기존 Godot 미수령 장비와 과거 프리셋은 원래 규칙으로 읽는다. 새 통합 프리셋은 10부위와 빈칸을 함께 저장한다.

자동장착은 출전 원정대 전체와 선택 영웅에 각각 제공한다. 더 강한 후보를 사용하고 잠금·진행 중인 옵션 선택·체력 및 방어 세트 효과를 보호한다. 드롭 즉시 자동장착의 기존 보호 장비 정책은 유지한다.

## 영웅 사진·검수 범위

이미 GitHub에 공개되어 있던 assets/heroes/sd-v36/portraits의 256×256 사진 30개를 UI 리소스로 재사용한다. 새 영웅 외형·전투 모델을 제작하지 않는다. 현재 보이는 사진은 순서대로 로드되며 전투 캐릭터 렌더링은 변경하지 않는다.

실제 Unity Play 모드에서 4개 가방 분류와 영웅 장비 화면을 촬영했다. 촬영은 별도의 Lv20 검수 프로필에 샘플 장비를 넣어 진행했고 실제 계정 저장은 변경하지 않았다. 장착·강화·10부위 저장 복원·두 반지·자동장착·보상·비교 미리보기·실제 배치 36개 확인을 통과했으며 로컬 armory-report.json에 기록된다. 기존 이식 기능 67개 확인도 통과했다. 배치 검수와 별개로 데이터 확인을 실행할 수 있는 Editor.NativeArmoryDataVerification.Run을 제공한다. 기존 0.1.21 APK는 이번 UI를 담은 새 빌드가 아니다.
