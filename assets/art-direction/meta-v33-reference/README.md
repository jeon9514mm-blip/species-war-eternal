# Meta v33 참고 자료와 실제 반영

사용자가 제공한 [설명](https://www.meta.ai/share/a/72cf6090-d96a-4bdf-ba38-20354533f5a9), [첫 ZIP](https://www.meta.ai/share/a/b1d59ed0-f5fa-48ac-993a-6e9ce1e92e48), [Godot 우회 구현 ZIP](https://www.meta.ai/share/a/23ad622b-8daa-490f-b3a8-a70da5e80871)을 함께 검토했다. 다운로드한 원본은 `source.zip`과 `godot-workarounds.zip`으로 보존한다. 두 ZIP에는 설명과 코드만 있고 학습 모델·고해상도 원본·털 카드·플러그인은 없다. 누락된 preload와 엔진에 없는 속성·클래스가 있어 원본을 그대로 실행하지 않고 현재 3D 전장에 맞게 수정했다.

| 의도 | 실제 게임 반영 | 범위와 남은 조건 |
|---|---|---|
| 정밀 바닥과 재질 | 기존 돌 원화에 거리별 미세 입자, 균열 AO, 모서리 밝기, 젖은 부분 반사 | 실제 PNG와 공간 셰이더. Nanite나 0.01mm 정밀도는 구현하지 않음 |
| 간접광 | Forward+ 전장 환경에 SSIL와 SSAO 적용 | 화면 공간 효과이며 Lumen 또는 3회 광선 반사가 아님. Mobile에서는 비활성 |
| 부드러운 그림자 | DirectionalLight3D 각도·블러·바이어스, 기존 발 접지 그림자 | 래스터 그림자. Ray tracing 아님 |
| 원화 생동감 | 30명 전원 신규 전신 동작과 좌우 방향, 실제 이동·공격 시점 연결 | 공격8·대기2·보행4·피격1·사망1. NeRF나 360도 뒷면 합성 없음 |
| 머리·털 | 전원 영웅의 머리와 털 있는 몬스터 원화 외곽에 셸8겹/4겹 적용 | `PaintedFurLayers.gd`가 실제 MeshInstance3D 레이어를 생성하고 원화 알파·색을 이용. Forward+8 / Mobile4 / 절전0. 전투 정지 시 바람 시계도 정지. XGen 가닥 물리는 아님 |
| 근육·천 | 각 전신 자세 안에서 몸·머리·옷을 함께 다시 그림 | 독립 근육 물리나 관절 분리 없음 |
| 피부 | 영웅 이동에 따른 약한 얼굴색 효과 | 시각 효과. 혈액·체온 시뮬레이션 아님 |
| 고해상도·디테일 | 신규 투명 PNG와 실제 돌 디테일 PNG를 제작해 원본 바닥에 반복 합성 | 두 번째 ZIP의 기본색+디테일 접근을 구현. 이미지 실제 크기는 `assets/maps/detail-v33/ART_SOURCE.json` 기록. 32K·RealESRGAN·DLSS 없음 |
| 홀로그램 숫자 | 기존 숫자 잉크에 약한 스캔라인·색광, 깊이 그림자 유지 | 읽기 쉬운 2D 효과이며 실제 체적·배경 굴절 아님 |

원화 셰이더는 전신의 UV나 관절을 변형하지 않는다. 털 셸은 완성된 몸을 잘라내는 대신 같은 원화 외곽에 약한 가닥을 더한다. 두 번째 ZIP의 원래 셰이더는 UV의 행을 레이어처럼 처리했지만 실제 셸을 생성하지 않고 색칠한 사각형을 그려, 원화 알파를 읽는 다중 3D 셸로 고쳤다. 타일 visible만 끄는 것으로 텍스처 메모리가 해제되지 않으며, 기본색+디테일 방식은 32K 정보 복원과 다르다. 베이크 스프라이트 방식은 현재 전신 동작 프레임에 사용하고 있으나 학습된 NeRF나 36방향 뒷면 데이터는 제작하지 않았다.

몸체 크기·공격 타이밍·겹침 검수는 `checks/full-body-rollout-2026-10-07/`에 기록한다. 원문 자료의 FPS·점수·품질 퍼센트는 측정 결과로 취급하지 않는다. 장치별 FPS·메모리와 Android 실기기 확인은 별도 검증이다.

엔진 근거: [Environment](https://docs.godotengine.org/en/4.6/classes/class_environment.html), [Light3D](https://docs.godotengine.org/en/4.5/classes/class_light3d.html), [Image 크기 제한](https://docs.godotengine.org/en/4.6/classes/class_image.html), [Instant-NGP 입력 데이터](https://github.com/NVlabs/instant-ngp/blob/master/docs/nerf_dataset_tips.md).
