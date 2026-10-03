# 초원 맵 — 18개 합성 레이어와 원화 프롬프트

이 문서는 밝은 초원 시범의 배경 제작 기준이다. **신규 원화 파일은 9장이고, 합성 구성은 18개 레이어**다. 배경용 8장은 2172×724px(3:1), 추가 지면 디테일 아틀라스 1장은 1536×1024px(3:2)다. 하늘은 RGB, 나머지는 RGBA이며 파일별 크기·알파 범위·SHA-256을 실측했다. 구름·전경 수풀은 두 깊이에 재사용한다. 기존 전투 지면과 코드로 만든 안개·지면 빛·먼지·빛줄기·나비·전경 보케를 더한다. 지면 아틀라스의 6개 변형은 한 파일의 3열×2행 구역이며 독립 이미지 6장이 아니다. 18장의 독립 원화나 새로운 영웅 애니메이션을 제작했다는 뜻이 아니다.

## 참고한 제안과 우리 게임에 맞춘 변경

사용자가 제공한 [Meta AI 공유 대화](https://www.meta.ai/share/c/OKcrGPZBNy?utm_source=android_meta_ai_sl)의 원경·중경·전투 지면·전경 분리, 대기 원근감, 낮은 채도의 녹색·하늘색·크림색, 왼쪽 위에서 오는 빛을 디자인 참고로 사용한다. 공유 내용은 **시각적 제안**이다. 영상 게임의 실제 엔진·자산 수·레이어 구조·제작 도구가 확인됐다는 근거로 사용하지 않는다.

해당 대화의 `ParallaxBackground`·`ParallaxLayer` 예제와 전투 지면 `0.8` 배율, 끝없이 옆으로 흐르는 횡스크롤 구성은 그대로 이식하지 않는다. 우리 게임은 32×20 월드에서 8방향 몬스터가 접근하고 영웅이 실제 위치를 이동한다. 지면·영웅·발밑 그림자·적·피격 표시의 좌표를 기존 전투 카메라에 맞춘 채, **장식 레이어만 실제 카메라 초점 변화에 따라 제한된 폭으로 이동**시킨다. 시간이 흘렀다는 이유만으로 전장 전체를 자동 스크롤하지 않는다.

공유 대화에 추가된 품질 시안도 확인했다. 부드러운 좌상광, 푸르게 바랜 산, 낮은 중앙 계곡, 좌우 마을 군집, 불규칙한 클로버·꽃·돌, 흐린 전경과 작은 나비가 핵심이다. 이는 사용자 UI를 포함한 정적인 디자인 예시이며 실제 게임 실행 화면이나 성능 측정 결과로 간주하지 않는다. 화면 중앙을 꽃·빛점으로 채우는 대신 실제 전투 가독성을 유지하는 범위에서 적용한다.

추가 예제의 `CanvasItemMaterial > Blur`, `CanvasModulate`의 `Intensity`, `World2D.environment`에서 SDFGI·볼류메트릭 안개를 켠다는 코드는 Godot 4.7.2에 그대로 적용할 수 있는 설정이 아니다. 이 작업은 `canvas_item` 셰이더와 표시 전용 도형을 사용한다. 실제 월드 지면은 기존 3D 좌표에 유지하고, 무거운 볼류메트릭 안개나 SDFGI로 해당 2D 효과를 대체하지 않는다. 이것이 Android 실기기 성능을 확인했다는 뜻은 아니다.

구현 위치는 [LayeredMeadowBackdrop](../scripts/art/LayeredMeadowBackdrop.gd), [PainterlyMeadow](../scripts/art/PainterlyMeadow.gd), [ArtDirectionBattlefield](../scripts/art/ArtDirectionBattlefield.gd)다. 영웅·적의 월드 좌표, 진형, 스폰, 사거리, 피해, 보상은 배경 코드가 결정하지 않는다.

## 공통 원화 기준

- **구도:** 배경용 신규 8종은 가로 3:1을 목표로 요청한다. 지면 디테일은 1536×1024의 3열×2행 아틀라스로 별도 제작한다. 실제 생성 결과의 픽셀 크기·비율은 별도로 확인하며, 프롬프트에 3:1이 있다는 이유로 결과가 해당 비율이라고 기록하지 않는다.
- **스타일:** 기존 게임 원화와 어울리는 독창적인 애니메이션 배경·부드러운 손그림 질감. 게임 스크린샷 복제, 로고, 특정 캐릭터, UI, 글자는 포함하지 않는다.
- **빛:** 왼쪽 위의 따뜻한 확산광. 강한 검정 그림자와 대비가 큰 테두리를 피한다. 멀수록 청회색·낮은 채도, 가까울수록 절제된 짙은 녹색을 사용한다.
- **색 기준:** 녹색 `#8DBF8A`, 하늘색 `#A9C9E8`, 햇빛 `#F5E9C9`를 출발점으로 삼되 모든 층이 같은 색 덩어리로 보이지 않게 명도·채도를 구분한다.
- **알파:** 하늘만 불투명이다. 구름·산·구릉·숲·마을·중경 나무·전경 수풀은 필요한 실루엣 바깥을 투명하게 만든다. 흰색·검은색·체크무늬 배경이 그림에 구워지면 분리 레이어로 검수하지 않는다.
- **중앙 가독성:** 실제 사냥 공간에는 커다란 건물·나무줄기·꽃 더미·짙은 수풀을 배치하지 않는다. 전경 그림에 중앙을 비워 달라고 요청하고, 런타임에서도 플레이 영역을 가리지 않도록 별도 보호한다.
- **경계:** 카메라 이동 여유가 있는 넓은 구도를 사용한다. 시범은 제한된 이동폭을 사용하므로 무한 타일링을 전제로 하지 않는다. 이어 붙이기 검수 없이 `seamless`라고 기록하지 않는다.

아래 영문은 **복사해서 다시 제작할 수 있는 권장 프롬프트**다. 최초 생성 호출에 입력한 문구를 그대로 복원한 기록은 아니다. 실제 파일 출처·해상도·확인 상태는 [ART_SOURCE.json](../assets/art-direction/pilot-01/ART_SOURCE.json)에 기록한다.

## 18개 합성 레이어의 역할

| 순서 | 런타임 이름 | 원화 / 방식 | 알파와 구도 |
| --- | --- | --- | --- |
| 1 | Sky | 신규 `layers/sky.png` | 불투명 하늘. 산·땅·구름은 별도 층 |
| 2 | FarClouds | 신규 `layers/clouds.png` | 투명 구름 띠. 낮은 대비·작은 움직임 |
| 3 | Mountains | 신규 `layers/mountains.png` | 투명 산맥 실루엣, 청회색 원경 |
| 4 | NearClouds | `clouds.png` 재사용 | 크기·위치·투명도를 달리한 두 번째 깊이 |
| 5 | Foothills | 신규 `layers/foothills.png` | 투명 녹색 구릉, 낮은 능선 |
| 6 | Treeline | 신규 `layers/treeline.png` | 투명 숲 가장자리, 작은 실루엣 |
| 7 | Village | 신규 `layers/village.png` | 투명 작은 마을, 좌우 비대칭 배치 |
| 8 | Midtrees | 신규 `layers/midtrees.png` | 투명 중경 나무, 중앙은 넓게 비움 |
| 9 | HorizonHaze | 코드로 만든 얇은 안개 띠 | 원경과 지면 경계를 낮은 불투명도로 연결 |
| 10 | Ground | 기존 `meadow-ground.png` | 실제 월드 지면. 임의의 0.8 스크롤을 적용하지 않음 |
| 11 | GroundDapple | 코드로 만든 지면 빛 | 실제 월드 좌표에 붙는 작은 명암 변화 |
| 12 | ForegroundFar | 신규 `layers/foreground.png` | 가장자리 잎, 투명 중앙, 절제된 부드러움 |
| 13 | ForegroundNear | `foreground.png` 재사용 | 더 가까운 크기·깊이, 실제 플레이 영역 알파 제거 |
| 14 | EdgeDust | 코드로 만든 움직이는 가장자리 먼지 | 플레이 영역 밖, 제한된 표시 전용 시간 사용 |
| 15 | GroundDetails | 신규 `layers/ground-details.png` | 6구역 아틀라스를 실제 월드 지면 메시에서 사용 |
| 16 | LightShafts | 코드로 만든 얕은 빛줄기 | 좌상단 방향, 낮은 불투명도, 전투 영역 보호 |
| 17 | AmbientButterflies | 코드로 만든 작은 나비 3개 | 경계 안의 짧은 비행, 실제 정지 상태와 연동 |
| 18 | ForegroundBokeh | 코드로 만든 전경 보케 | 가장자리의 흐린 작은 빛점, 중앙 침범 방지 |

위 번호는 원화·효과를 관리하기 위한 목록 번호이며 실제 렌더 순서나 노드 트리의 인덱스가 아니다. 월드 지면은 UI 그림층과 같은 좌표계의 스크롤 사각형이 아니다. 개별 이동 계수와 경계는 코드의 현재 `layer_manifest()`를 기준으로 확인한다.

## 원화별 복사용 프롬프트

### 1. Sky — 하늘

파일 제안: `layers/sky.png`. 불투명. 별도 구름·산과 충돌하지 않도록 넓은 색면만 만든다.

```text
Create an original wide 3:1 fantasy game background layer containing only a luminous daytime sky. Soft hand-painted anime background treatment with subtle watercolor and gouache texture, pale blue #A9C9E8 above and warm cream #F5E9C9 near the lower horizon. Gentle warm light comes from the upper left. Use broad quiet color transitions and atmospheric depth. Fully opaque canvas. No clouds, mountains, land, trees, buildings, characters, sun disc, text, logos, UI, borders, photographic detail, hard outlines, or dramatic dark shadows. This will sit behind several separately composited landscape layers.
```

### 2. FarClouds — 먼 구름

파일 제안: `layers/clouds.png`. 투명. 아래 프롬프트 한 장을 먼 구름과 가까운 구름에 함께 사용한다.

```text
Create an original wide 3:1 isolated cloud layer for a bright fantasy RPG. A few loosely spaced soft cumulus cloud groups span the width, with large transparent gaps and an irregular airy silhouette. Hand-painted anime background art, delicate watercolor and gouache edges, warm ivory highlights from the upper left, very pale cool blue shadows. Keep the lower portion and the spaces between clouds genuinely transparent. No blue sky rectangle, landscape, mountains, land, trees, characters, text, UI, border, black background, white background, or checkerboard pattern. Output transparent RGBA artwork intended for layered compositing.
```

### 3. Mountains — 먼 산맥

파일 제안: `layers/mountains.png`. 투명. 선명한 암석 질감보다 크게 이어진 능선과 대기 원근감을 우선한다.

```text
Create an original wide 3:1 isolated distant mountain range for a bright hand-painted fantasy RPG. Arrange broad overlapping blue-grey ridges with a low, varied horizon and one modest higher peak off center. Very low contrast, desaturated atmospheric perspective, pale sky-blue haze, soft watercolor and gouache brushwork. Gentle warm light from the upper left. The area above the mountain silhouette must be transparent; the artwork contains only the mountain forms and a softly fading lower edge. No painted sky, clouds, foreground ground, houses, close trees, characters, text, UI, border, white or checkerboard backdrop, sharp black outlines, or photorealism. Transparent RGBA.
```

### 4. NearClouds — 가까운 구름 재사용

추가 원화를 만들지 않는다. `clouds.png`의 위치·크기·불투명도를 조정해 두 번째 깊이를 만든다. 아래는 재사용 지시이며 새 이미지 생성 프롬프트가 아니다.

```text
Reuse the existing isolated cloud artwork as a second compositing layer. Use a different placement, slightly larger scale, and restrained opacity. Preserve transparent gaps and the shared upper-left light direction. Drive its bounded offset from the actual battle camera focus, without time-driven endless scrolling or a new painted sky.
```

### 5. Foothills — 녹색 구릉

파일 제안: `layers/foothills.png`. 투명. 먼 산보다 조금 진한 회녹색, 낮은 둥근 능선.

```text
Create an original wide 3:1 isolated rolling foothill layer for a peaceful fantasy game meadow. Low rounded sage-green hills, softly overlapping contours, subtle grassy color patches, and a broad low central valley. Soft hand-painted anime background art with watercolor and gouache brush texture, muted greens around #8DBF8A, warm diffuse sunlight from the upper left. Maintain restrained detail and atmospheric depth. Transparent above the hill silhouettes, softly fading at the lower edge. No sky, clouds, distant blue mountains, houses, individual foreground trees, characters, text, UI, border, photographic textures, dark outlines, or opaque backdrop. Transparent RGBA.
```

### 6. Treeline — 원경 숲 띠

파일 제안: `layers/treeline.png`. 투명. 개별 나무를 거대하게 그리지 않고 멀리 이어지는 숲 실루엣으로 구성한다.

```text
Create an original wide 3:1 isolated distant treeline for a bright fantasy RPG background. A long uneven band of small deciduous tree crowns, with softly varied heights, a lower open center, and a few natural gaps. Muted sage and olive greens, lighter and less detailed than nearby trees. Soft hand-painted anime environment art, broad watercolor and gouache color shapes, warm upper-left daylight. Keep everything above and between the tree silhouettes transparent and fade the base gently. No sky, mountains, grass-field rectangle, village, large foreground trunks, characters, text, UI, borders, hard black outlines, white backdrop, or checkerboard. Transparent RGBA.
```

### 7. Village — 작은 마을

파일 제안: `layers/village.png`. 투명. 화면 중앙의 전투보다 강한 시선을 끌지 않도록 작은 건물 군집과 낮은 대비를 사용한다.

```text
Create an original wide 3:1 isolated small fantasy village layer. A few cozy timber-and-plaster cottages with muted warm roofs, grouped asymmetrically toward the left and right thirds, with a broad quiet opening in the center. Small supporting shrubs and short fence fragments may connect each group, but no continuous grass or ground rectangle. Hand-painted anime background art, soft watercolor and gouache texture, cream plaster, restrained sage foliage, warm diffuse sunlight from the upper left. Distant scale with readable simple silhouettes and gentle contrast. Fully transparent around and between the buildings. No sky, mountains, giant castle, roads crossing the canvas center, characters, text, signs, UI, logos, hard outlines, opaque white backdrop, or checkerboard. Transparent RGBA.
```

### 8. Midtrees — 중경 나무

파일 제안: `layers/midtrees.png`. 투명. 양옆 나무가 입체감을 만들고 중앙은 비어 있어야 한다.

```text
Create an original wide 3:1 isolated mid-distance tree layer for a bright fantasy battle meadow. Two or three graceful broadleaf tree groups sit mainly in the outer left and right thirds, with an expansive transparent opening across the central half. Rounded but irregular hand-painted foliage masses, a few visible warm brown trunks, sage and moss greens, cream highlights from gentle upper-left sunlight. Soft anime environment painting with watercolor and gouache texture, restrained leaf detail, no hard black outlines. Keep the entire canvas outside the trees transparent, including below branches. No sky, horizon panorama, grass-field rectangle, village, characters, text, UI, border, photographic leaves, white background, or checkerboard. Transparent RGBA.
```

### 9. HorizonHaze — 원경 연결 안개

별도 PNG를 만들지 않는다. 현재는 코드로 만드는 낮은 불투명도의 얇은 띠다. 영어 미술 지시는 다음과 같다.

```text
Add a thin, very low-opacity pale sage-and-cream atmospheric veil where the distant scenery meets the meadow. Use a soft vertical fade with no hard seam. Keep battle silhouettes and ground contact readable. This is a procedural compositing effect, not an additional landscape painting.
```

### 10. Ground — 실제 전투 지면

이번 신규 이미지 9장에 포함하지 않는다. 기존 `meadow-ground.png`를 실제 월드 바닥에 사용한다. 32×20 사냥 좌표는 유지하고 그림은 원점 (-16,-34), 크기 64×88의 시각 영역까지 확장한다. 향후 재제작할 때만 다음 프롬프트를 사용한다. 지면 원화는 가로 3:1 배경 띠와 달리 현재 실제 사용 중인 3:2 바닥 규격을 기준으로 따로 검토한다.

```text
Create an original 3:2 hand-painted ground texture for a bright fantasy battle meadow, viewed from above for mapping onto an existing flat game-world plane. Soft moss and sage grass, small clover patches, sparse tiny wildflowers near the outer edges, occasional subtle pale soil patches, gentle warm light from the upper left. Keep the broad central battle area quiet and evenly readable, with very low contrast and no large objects. Painterly anime environment treatment with watercolor and gouache texture. Fully opaque ground only: no sky, horizon, mountains, village, trees, characters, cast character shadows, text, UI, borders, strong perspective lines, or photographic grass. Do not paint a separate scrolling stage or a floating island edge.
```

### 11. GroundDapple — 지면 빛

별도 원화를 추가하지 않는다. 캐릭터 그림자와 섞여 지면 접촉을 흐리지 않도록 약한 변화만 사용한다.

```text
Apply subtle broad patches of warm filtered light to the actual world-space meadow surface. Keep the modulation low contrast, stable relative to the ground, and consistent with upper-left sunlight. Do not slide the ground beneath the actors or add screen-space lighting that detaches their feet from the world. This is a procedural material effect, not a new painted image.
```

### 12. ForegroundFar — 가장자리 수풀

파일 제안: `layers/foreground.png`. 투명. 원화는 테두리 장식이며 중앙 전투를 가릴 수 없다.

```text
Create an original wide 3:1 transparent foreground foliage frame for a bright fantasy RPG. Soft close-up moss-green and deep sage leaves enter only from the extreme left edge, extreme right edge, and a few low bottom corners. Keep at least the central seventy percent of the canvas completely transparent and unobstructed, with no branch crossing it. Hand-painted anime environment art, watercolor and gouache color shapes, warm upper-left light, gentle out-of-focus softness without muddy silhouettes. No complete landscape, sky, ground rectangle, mountains, buildings, characters, flowers filling the center, text, UI, border line, photographic bokeh circles, black or white backdrop, or checkerboard. Transparent RGBA.
```

### 13. ForegroundNear — 가까운 전경 재사용

추가 원화를 만들지 않는다. 같은 수풀의 크기·위치·부드러움을 조정하고 실제 플레이 영역은 런타임에서도 알파로 보호한다.

```text
Reuse the existing transparent edge foliage as a nearer framing layer with a different scale and bounded camera response. Add only restrained softness. Keep the dynamically protected battle rectangle fully clear, including actors and enemies approaching from every direction. Do not create a second opaque foreground painting or obscure essential combat indicators.
```

### 14. EdgeDust — 가장자리 먼지

별도 PNG를 만들지 않는다. 작은 빛점은 화면 가장자리에 한정하며 중앙의 전투 상태를 가리지 않는다. 제한된 표시 전용 시간으로 천천히 움직이고 실제 게임 일시정지 시 정지한다.

```text
Add a sparse set of tiny, low-opacity warm cream motes near the outer scenery edges. Keep all motes outside the protected battle area. Use deterministic presentation-only placement and small bounded local movement that never consumes the gameplay random sequence. Freeze the effect when the actual game is paused. This is a procedural decorative effect, not new artwork and not evidence of mobile performance.
```

### 15. GroundDetails — 지면 클로버·꽃·돌 아틀라스

파일: `layers/ground-details.png`. 실제 크기는 1536×1024 RGBA이며 알파 범위는 0~254다. 512×512 크기 구역 6개를 3열×2행으로 배치했다. 왼쪽 위부터 클로버, 흰 데이지, 이끼 낀 돌, 노란 민들레, 푸른 꽃, 풀과 돌이다. **한 파일의 6개 스프라이트 변형**이며 이미지 6장으로 집계하지 않는다.

카메라 위의 장식 그림으로 덮지 않고 실제 지면의 평면 메시에서 구역별 UV를 사용한다. 현재는 6변형을 24개 위치에 배치하고 단일 메시로 묶었다. 위치·크기·회전의 차이는 표시용 난수만 사용하고, 사냥 경로·충돌·월드 위치를 바꾸지 않는다. 중앙 전투 영역의 채도·대비·밀도를 낮게 유지한다.

```text
Create one original 1536x1024 RGBA game-art atlas arranged as exactly three columns and two rows of six separate 512x512 square cells. Each cell contains one isolated small meadow ground patch viewed from directly above. Reading left to right: row one has a clover cluster, white daisies with low grass, and two small mossy stones; row two has yellow dandelions, small blue wildflowers, and a mixed grass tuft with one pale pebble. Use soft hand-painted anime environment art, watercolor and gouache texture, sage and moss greens, warm cream highlights from the upper left, low contrast, and gently irregular natural shapes. Keep generous truly transparent padding around every patch and between all cells. Each patch must stay inside its own cell. No labels, grid lines, text, ground rectangle, checkerboard, scenery, horizon, sky, characters, oversized plants, hard outlines, or photographic textures. These are six variations inside one atlas image for placement on a real world-space battle lawn, not six separate full backgrounds.
```

### 16. LightShafts — 낮은 대비의 빛줄기

별도 원화를 만들지 않는다. `canvas_item` 셰이더로 얕은 사선 빛을 표현하며, 실제 전투 영역 안에서는 알파를 최대 0.026으로 제한해 명암과 실루엣을 읽을 수 있게 한다. 볼류메트릭 안개나 SDFGI를 켠다는 요구가 아니다.

```text
Add a few broad, extremely subtle warm daylight streaks entering from the upper left. Use a lightweight procedural canvas shader with soft boundaries and low alpha. Cap alpha inside the protected battle area at 0.026 and avoid washing out characters or combat indicators. Do not change the world-space lighting contract, enable heavy volumetric fog, or imply that a 2D WorldEnvironment provides SDFGI god rays.
```

### 17. AmbientButterflies — 작은 나비 세 마리

새 나비 PNG를 생성하지 않는다. 작은 표시용 도형 3개에 제한된 이동·날갯짓을 준다. 영웅·적·투사체로 오인되지 않는 크기와 위치를 유지한다.

```text
Create three very small decorative butterfly silhouettes using lightweight procedural shapes, with restrained warm yellow and pale blue accents. Give them short bounded paths and subtle wing beats near the scenic edges, outside essential combat space. Drive them from a presentation-only local timer and freeze them with the actual game pause state. They must not consume gameplay random values, move combat actors, create collisions, or resemble enemy projectiles. This is a procedural effect, not three additional painted assets.
```

### 18. ForegroundBokeh — 전경의 흐린 빛점

원화에 강한 빛점을 굽지 않고 코드로 가장자리에 추가한다. 가까운 잎의 작은 흔들림과 함께 사용하되 전장을 통째로 흔들거나 자동 스크롤하지 않는다.

```text
Add a few softly blurred, low-opacity warm cream and pale gold bokeh spots only at the outer foreground edges. Use small procedural canvas shapes or a lightweight shader, with no hard rings and no large opaque discs. Keep the dynamically protected battle rectangle fully transparent. Combine them with a tiny bounded sway of the existing foreground foliage, while keeping the ground and actors fixed to the actual battle camera. Freeze time-based decoration when the game is paused. Do not bake the effect into new landscape artwork or use endless scene scrolling.
```

## 동작과 전투 일시정지

카메라 반응과 환경 동작을 구분한다. 산·마을 등은 실제 카메라 초점 변화에 반응하고, 먼지·전경 잎의 흔들림·나비는 제한된 표시 전용 시간으로 움직인다. 이 시간은 실제 게임 일시정지에서 멈춰야 하며 `Time.get_ticks_msec()`에 직접 연결해 정지 상태를 무시하지 않는다. 환경 동작은 전투 RNG, 영웅 이동, 공격·스킬 시간, 보상 계산을 변경하지 않는다.

## 최종 검수 기준

파일별 실제 크기·RGBA 여부·투명 바깥 영역을 확인하고 경계에 흰색 후광이나 구워진 체크무늬가 없는지 본다. 카메라를 움직여 먼 층은 작게, 가까운 층은 더 크게 반응하는지 확인하되 원경 가장자리 노출과 과도한 흔들림을 피한다. 전경은 실제 영웅·적·표시 영역을 가리지 않아야 한다. 맵 비교 전환 시 전투 시간·HP·보상·게임 난수 상태가 바뀌지 않는지 확인한다.

스크린샷과 PC 소프트웨어 렌더 검사는 Android 실기기의 FPS·메모리·발열 측정이 아니다. 파일 해시는 실제 파일에서 계산해 출처 기록에 남겼다. 18층의 최종 `run05` 통합 실행 검사는 411/411항목을 통과했고, 실제 영웅·적의 머리와 발 위치 4,844개 표본에서 가독성 영역을 확인했다. 이 표본 수는 411개 검사 수와 별도로 기록한다. 새 영웅 원화의 부위 분리·16종 동작은 별도 후속 단계이며, 이 맵 제작 결과만으로 영상과 90% 이상 같다는 결론을 내리지 않는다.
