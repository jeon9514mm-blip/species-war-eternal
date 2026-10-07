# Godot 그래픽 제작 흐름 조사

**설치·제작 후 갱신:** Blender 5.2.2 LTS·Material Maker 1.7·Krita 5.3.4 설치를 확인했습니다. 실제 6개 GLB 맵·1024 PBR 출력과 46종 캐릭터 초안을 생성했고, 사용자 검수에 따라 기본 화면은 원화 기반 2.5D로 맞췄습니다. [현재 제작 범위](../assets/models3d-v1/README.md), [현재 검수](../checks/art25d-2026-10-07/README.md). 아래 튜토리얼 조사와 초기 구조 설명은 설치 이전의 기록입니다.
2026-10-07, 사용자 요청으로 YouTube의 캐릭터·맵·조명 튜토리얼을 찾아 KiriSoft 캐릭터 영상의 공개 자동 자막 원문, 다른 영상의 설명·목차·작성자 자료를 현재 Godot 공식 문서와 게임 소스에 대조했습니다. 영상 전체를 시각적으로 시청했다는 기록은 아닙니다. GameFromScratch 조명 영상은 자막이 제공되지 않아 작성자 목차·공개 코드와 공식 문서를 참고했습니다. 오래된 영상의 옵션을 그대로 가져오지 않고 Godot 4 문서와 구분했습니다.

## 지금 변화가 제한적인 이유

현재 영웅·몬스터는 전신 PNG 자세를 실루엣 메시로 표시합니다. `shaders/OriginalPainting.gdshader`의 `unshaded` 모드가 원화 색을 유지하므로 태양 에너지·간접광을 조정해도 몸의 실제 입체 음영은 바뀌지 않습니다. 이는 [Godot의 unshaded 정의](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)와 일치합니다. 털·가장자리·잔상은 별도 시각 효과입니다.

레이드의 `scripts/art/RaidArenaBattlefield.gd`는 배경 PNG를 TextureRect로 표시하고 투명 3D 전장에 원화 캐릭터를 올립니다. 배경 그림에 있는 기둥·계단은 실제 3D 메시가 아니므로 3D 광원이나 카메라로 그림 속 표면을 다시 조명하거나 가릴 수 없습니다. 사냥은 돌바닥 PNG 한 종류를 반복하고 룬·이끼·젖은 부분을 셰이더로 더합니다. 현재 소스와 검수 이미지에서 확인한 제한입니다.

영웅의 서 있는 높이는 10인 사냥에서 논리 화면 기준 약 44~45px입니다. 300px 안팎의 원화를 축소해서 보여주므로 텍스처 해상도·슈퍼샘플링만 올려서는 얼굴·장비·동작을 크게 바꿀 수 없습니다. 큰 변화에는 배경 구성, 실제 자산의 형태·명암, 공격 자세와 카메라 배치를 함께 개선해야 합니다. 이 부분은 조사와 현재 구조를 근거로 한 판단입니다.

## 참고한 튜토리얼

| 공개 자료 | 확인한 범위 | 현재 게임에 대한 판단 |
| --- | --- | --- |
| [KiriSoft Games: Make Stunning 2D Characters in a 3D World](https://www.youtube.com/watch?v=s5pvDsDDxAY), Godot 4 | 0:51 스프라이트 임포트, 1:38 픽셀 필터, 2:20 알파 잘라내기와 그림자, 2:54 카메라 빌보드의 자동 자막 원문 | 최근접 필터는 픽셀 그림에 한정합니다. 실제 원화 실루엣의 방향광 그림자를 사냥 돌바닥에 연결하고 절전에서 끕니다. |
| [Wabsa Studios: Animated Sprite 3D Guide Godot 4.3+](https://www.youtube.com/watch?v=t26dp3_NhAc) | 영상 제목·공개 설명의 2.5D/HD-2D 방식 | 입체 지형과 전신 프레임 원화를 함께 사용하는 방향과 맞습니다. 현재 전신 메시·타격 시계를 단순 AnimatedSprite3D로 교체할 필요는 없습니다. |
| [GameFromScratch: Godot 4.x Lighting, Shadows and Global Illumination](https://www.youtube.com/watch?v=xmykSGbq7AE) / [작성자 자료](https://gamefromscratch.com/godot-4-x-3d-tutorial-lighting-shadows-and-global-illumination/) | 작성자 공개 목차·발광 Tween 코드. 영상의 자막은 제공되지 않았습니다. 광원, WorldEnvironment, 톤매핑, GI와 환경광 항목 | 조명과 발광을 올리기 전에 어떤 표면이 조명을 받는지 확인해야 합니다. 그림 배경·unshaded 캐릭터에는 같은 방식으로 작용하지 않습니다. |
| [GDQuest: How to light a 3d scene](https://www.youtube.com/watch?v=iamttSmxA2I) / [작성자 설명](https://www.gdquest.com/tutorial/godot/3d/3d-lighting-basics/) | HDRI·간접광·톤매핑의 개념. 2019년 Godot 3 자료 | 개념만 참고하고 옵션은 Godot 4 공식 문서로 확인합니다. |
| [Material Maker 공식 시작 페이지와 튜토리얼 링크](https://www.materialmaker.org/) / [개발자 인터뷰와 영상 추천](https://godotengine.org/article/godot-showcase-material-maker/) | PBR 제작·PNG 출력·재질 그래프, 개발자가 추천한 Kasper Arnklit/Pavel Oliva 영상 | 돌·이끼·청동의 서로 다른 재질을 실제 맵으로 제작할 때 사용할 수 있습니다. |

## 추가 제작 프로그램과 연결 방식

| 프로그램 | 개선할 수 있는 것 | Godot로 전달하는 형식 | 현재 연결 상태 |
| --- | --- | --- | --- |
| **Blender** | 입체 돌·유적·나무·기둥·소품, 캐릭터 모델·리그·애니메이션, 전체 자세의 스프라이트 베이크 | **GLB/glTF** 메시·재질·애니메이션, 또는 렌더한 투명 PNG 프레임 | 호환 방식 확인. 이번 수정에 Blender 모델은 추가하지 않았습니다. |
| **Material Maker** | 돌·균열·이끼·금속의 색·노멀·거칠기·AO 맵 | **PNG PBR 맵**. 출력한 맵을 현재 공간 셰이더나 Godot StandardMaterial3D에 연결 | 출력 방식 확인. 이번 돌 셰이더는 기존 디테일 PNG를 사용합니다. |
| **Krita** | 전신 원화의 명암·색상·얼굴·옷·무기 정리, 동작 사이의 중간 그림 | **투명 PNG 시퀀스** → 현재 전신 시트 제작 도구·자산 목록 | 원화 제작 방식 확인. 이번 변경은 기존 PNG 자세를 유지합니다. |
| **Substance 3D Painter** | UV가 있는 모델의 갑옷·가죽·털·돌 표면을 직접 칠하고 재질 맵 제작 | **glTF PBR Metal Roughness 템플릿** 또는 개별 PBR 텍스처 | 선택 가능한 제작 도구로 조사했습니다. 실행·라이선스·모델 제작은 별도입니다. |

무료 도구 조합은 Blender+Material Maker+Krita입니다. [Blender 공식 소개](https://www.blender.org/about/), [Material Maker 개발자 소개](https://godotengine.org/article/godot-showcase-material-maker/), [Krita 공식 기능](https://krita.org/en/features/)에서 자유·오픈소스 소프트웨어임을 확인했습니다. 외부 프로그램을 설치하기만 하면 게임 품질이 올라가는 것이 아니라, 그 프로그램에서 제작한 실제 메시·프레임·재질 맵을 게임에 넣어야 합니다.

Godot는 [GLB/glTF를 권장하며 .blend 직접 임포트도 지원](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)합니다. `.blend` 직접 임포트는 각 작업 컴퓨터에 Blender가 필요하므로, GitHub에서 받은 게임을 다른 컴퓨터에서 실행할 수 있게 제작 원본과 출력 GLB를 분리하는 방식이 적합합니다. `.blend`를 저장했다고 Godot 안의 기존 코드·배치가 자동으로 설계되는 것은 아닙니다.

Material Maker는 [출력 속성을 PNG로 내보내고 AO·roughness·metallic을 ORM 파일로 묶습니다](https://rodzill4.github.io/material-maker/doc/node_miscellaneous_material.html). 오래된 문서의 SpatialMaterial 자동 생성 설명을 Godot 4용 플러그인 호환 확인으로 취급하지 않습니다. 현재 게임에는 텍스처 파일을 가져오는 경로가 더 명확합니다. Krita는 [프레임 시퀀스 출력](https://docs.krita.org/en/reference_manual/render_animation.html), Substance Painter는 [glTF PBR 출력 템플릿](https://experienceleague.adobe.com/en/docs/substance-3d-painter/using/export/output-templates/default-output-templates/predefined-presets)을 제공합니다.

## 이 게임에서 품질을 올리는 순서

1. **사냥터 한 곳의 구성부터 개선:** 전투 중앙은 읽기 쉽게 남기고 가장자리의 돌·나무·기둥 등 실제 3D 소품과 명암 층을 제작합니다. 발·경고·클릭 좌표와 이동 영역을 유지합니다. 3D 형태가 들어가야 그림자와 조명으로 깊이가 생깁니다.
2. **돌 재질의 실제 맵 제작:** 원화 색에 이미 들어 있는 그림자를 중복으로 조명하지 않도록 색·높이·노멀·거칠기·AO를 분리해서 검토합니다. 색 이미지의 밝기를 바로 높이값으로 바꾸면 엉뚱한 요철이 생길 수 있습니다.
3. **영웅 한 명과 몬스터 한 종을 기준으로 검수:** 전신 그림과 통일 높이를 보존하면서 얼굴·옷·무기 명암, 접지, 공격 예비·타격·회수 자세를 다듬습니다. 조명을 받는 원화 셰이더는 별도 비교해야 하며 `unshaded`만 제거하면 이미 그려진 음영이 다시 어두워질 수 있습니다.
4. **두 렌더러에서 검증 후 확대:** 같은 전투 수치와 카메라로 전후 비교, 10인 몸체·숫자 겹침·정지·레이드 경고 검사를 유지합니다. Android는 실기기에서 프레임 시간·메모리·발열을 측정합니다.

[Godot 환경·후처리 문서](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)에 따르면 여러 GI·화면 공간 효과에는 렌더러 제한이 있습니다. SSIL 하나를 켜는 것은 전체 간접광 구현과 다르며, 그림 한 장을 실제 3D 지형으로 바꾸지도 않습니다. 현재 수치 변경과 새 자산 제작을 구분해서 검수합니다.

이번에 실제로 수정한 그래픽은 [Meta v40 반영 내역](../assets/art-direction/meta-v40-reference/README.md)과 [전후 화면·실행 검사](../checks/meta-v40-2026-10-07/README.md)에 있습니다. 추가 프로그램과 메시 제작의 갱신 내용은 위의 현재 제작 범위를 참고하세요.
