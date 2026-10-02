
# Aurelia 3D Maps - Final Setup

## 파일 구조
res://assets/maps/reference/
  - map_elven_ruins_ref.webp
  - map_canyon_mine_ref.webp
  - map_forest_meadow_ref.webp

res://scenes/maps/
  - Map_ElvenRuins_Final.tscn (달빛 + 안개 + 청록 발광)
  - Map_CanyonMine_Final.tscn (석양 + 오렌지 랜턴)
  - Map_ForestMeadow_Final.tscn (주간 + 나뭇잎 그림자)

res://scripts/maps/MapLoader.gd

## Godot 4.3 세팅
1. WorldEnvironment: 각 맵에 맞는 안개/앰비언트 세팅됨
2. DirectionalLight3D: 그림자 ON, 10m 높이
3. CSGCylinder3D: 임시 바닥 (나중에 glb로 교체)
4. NavigationRegion3D: 이미 원형으로 베이크 준비됨, Bake 버튼 클릭
5. GPUParticles: 크리스탈 반짝임 (ElvenRuins만 활성화)

## glb 교체 방법
Tripo에서 glb 뽑으면:
- ArenaFloor 노드 숨기고 (visible=false)
- glb 인스턴스 추가
- NavigationRegion3D에서 Bake 다시

## 성능
- CSG는 프로토타이핑용, 최종 빌드 전에 MeshInstance3D로 변환 권장 (CSG > Bake Mesh)
- 라이트 2개 + 파티클 1개로 모바일에서도 60fps 유지
