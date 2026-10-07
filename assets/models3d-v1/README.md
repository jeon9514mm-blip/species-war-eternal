# 제작 원본과 현재 기본 화면

사용자 중간 검수 후 기본 표현은 **원화 캐릭터 + 실제 3D 맵의 2.5D**로 맞췄습니다. 단순한 실시간 3D 캐릭터 초안은 최종 캐릭터 디자인으로 승인되지 않았습니다.

- Blender 5.2.2 LTS: 30명 영웅·13종 몬스터·3종 보스의 입체 메시, 가중치·뼈대, 8개 애니메이션 초안을 실제 생성했습니다. 기본 화면에서는 이 초안들을 사용하지 않습니다.
- 실제 게임에는 `environments/`의 6개 GLB를 사용합니다. 초원 유적·광산 결정/목재·월광 숲의 형태와 레이드 테두리를 제작했고 이동·경고 좌표를 보존합니다.
- Material Maker 1.7: 1024 PBR 색·노멀·ORM·발광·높이 이미지를 출력했습니다. 게임 바닥은 색·노멀·거칠기·AO를 사용하며 고비용 패럴랙스는 껐습니다. 그래프는 1.7의 `medieval_wall.ptex`를 기반으로 색을 조정했으며 [MIT 라이선스](materials/MATERIAL_MAKER_LICENSE.md)를 포함합니다.
- Krita 5.3.4는 설치와 실행 파일 버전을 확인했습니다. 이번 자산을 Krita에서 직접 그렸다고 표시하지 않습니다. 설치 출처·해시·실제 사용 범위는 [INSTALLATION.json](INSTALLATION.json)에 기록했습니다.

캐릭터 초안의 편집 원본은 [Blender 라이브러리](source/eternal-model-library.blend), 모델 정보는 [catalog.json](catalog.json)에 있습니다. `source/.gdignore`로 원본을 실행 게임에 자동 임포트하지 않습니다. 기본 원화는 기존 전신 원화 폴더에서 가져오며 재생성하거나 덮어쓰지 않았습니다.

```powershell
blender --background --factory-startup --python tools/build_models3d.py
blender --background --factory-startup --python tools/refine_models3d.py
./tools/export_materials3d.ps1 -MaterialMakerExe '설치된 Material Maker 실행 파일 경로'
```

모델 정리는 새 라이브러리를 생성한 직후 한 번 실행합니다. 바닥 PBR 맵은 공유 파일로 런타임에 연결되므로 GLB 6개에 같은 이미지를 반복해서 넣지 않습니다. 테스트 전용 자산이나 유료 서비스, 32K 원본, NeRF 모델, 실제 Android 성능 측정 결과로 취급하지 않습니다.
