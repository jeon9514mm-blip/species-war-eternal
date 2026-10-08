# 원화 기반 2.5D 제작 원본

30영웅·13일반 몬스터·3레이드 보스 총46종. 기존 전신 원화의 캐릭터·색·무기·16자세를 하나의1024 RGBA atlas에 보존하고 Blender에서 얕은 입체 billboard를 제작했습니다. 완전한 해부학적 캐릭터 리깅이나 NeRF 학습 모델은 아닙니다.

- `<id>/poses_1024.png`: 공격8/대기2/보행4/피격1/사망1. 원화 비율·발 기준점은 frames.json.
- `<id>/billboard.glb`: 영웅6600 triangles(몸체6000+hair cards300개600triangles),몬스터/보스 몸체3000. 모든 자세가 같은 메시/텍스처 공유.
- `source/mobile25d-library.blend`: Blender5.2.2 LTS 원본. 제작 파일은 .gdignore로 runtime import 제외.
- `floor/stone_1024_albedo_ao.png`: AO alpha packing. stone_1024_normal.png는 runtime normal. material.json에 실제 coverage 측정. 별도 AO PNG는 제작 참고.
- `vfx/moss_bronze_circle.png`: 투명 문양.1024제한/VRAM 압축/mipmap.

재생성: `blender --background --python tools/build_mobile25d.py` 후 Godot import, `python tools/build_mobile25d_support.py`로 import 옵션·접지 마스크·짧은 절차적 몬스터 음향 생성. 바닥만 변경할 때 `-- --floor-only`. 이미지 생성은 재현 스크립트에서 호출하지 않습니다.

## 이미지 생성 기록

`imagegen` skill의 **built-in 모드**를 사용했습니다. 아래는 생성 의도와 출처를 보존한 prompt brief입니다. 새 영웅 원화를 생성한 것으로 표시하지 않습니다. 생성 원본은 유지하고 프로젝트에는 사용 사본을 넣었습니다.

1. **Stone brief:** seamless flat continuous aged warm-gray limestone surface, fine mineral grain, restrained hand-painted dark-fantasy realism, scratches and hairline fissures; no tile boundaries, bricks, moss, baked directional lighting or perspective.1024 texture detail. 원본 exec-3b3820b0-a5b8-40ed-bf83-fbf5805b5260.png → [stone_detail.png](source/stone_detail.png). 석판 표면 디테일로 결합하며 균열·이끼·patina·AO·normal은 제작 스크립트에서 coverage에 맞춰 만듦.
2. **Circle brief:** transparent centered perfect circular moss/bronze magical ground seal, bands at approximately80% and61% of canvas, moss fibers, ornate bronze, four dominant cardinal runes, restrained luminous flecks/attached leaves;#A8B89E/#C4A484; empty transparent center, no people, floor or text. 원본 exec-c475ddf6-4c6a-4e1e-b960-13fa49e76b1f.png → [moss_bronze_circle.png](vfx/moss_bronze_circle.png).

원본 생성 폴더 `C:/Users/x/.codex/generated_images/01a11454-ef0a-72b2-9196-64729d220f85/`. 원본 문양을 보존하고 최종 런타임 셰이더에서 주요 룬8개·입자8개·낙엽12개·균열·glow .5·inner glow .35·회전 .12rad/s를 제어합니다. 낙엽과 입자는 가장 가까운 원형 구간을 계산하므로 개체 생성이나 픽셀마다 28회 반복 계산이 없습니다. MossPointLight는 .6 에너지에 그림자를 끈 실제 OmniLight3D입니다. [기존 사양·실측·실제 화면](../../checks/mobile25d-spec-2026-10-07/README.md).

최종 석판은 동일 Blender 절차를 바닥만 다시 실행했습니다. 실제 이끼 면적 14.99996%, 균열 밖 이끼0, 균열 내 녹20.00026%, edge wear .6, crack dark .35, AO .5입니다. `FinalStonePBR.gdshader`가 두1024 맵과 AO alpha를 재사용하고 이끼 pigment의 색 차이를 읽어 .15 emission을 더합니다. 추가 풀 사이즈 마스크는 없습니다. Mobile의 광선은 후처리에서 계산하는 세 개의 절제된 광선이며, Forward+의 SDFGI나 볼륨 광선으로 표시하지 않습니다.

실제 GPU 검수 뒤 바닥 반복을 카메라에 맞춰 분리했습니다. 기존 가로22.222/세로17.5 대신 사냥11.111/8.75(석판2배), 레이드5.556/4.375(석판4배)입니다. 원본1024 타일 내부의 석판은 약3×3개이며, 사냥은 지나치게 큰 바닥 조각을 줄이고 레이드는 작은 벽돌처럼 보이던 반복을 줄였습니다. 텍스처 해상도·UV 원형·필터·메모리는 유지합니다. 새 보스 접지 문양이 있는 레이드는 기존2D 주황색 접지 링·타원만 끄고, 보스 행동·공격 관찰과 지역별 보조 연출은 유지합니다.
