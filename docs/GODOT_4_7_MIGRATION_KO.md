# Godot 4.7 계열 전환 메모

v14부터 현재 프로젝트 기준 엔진을 Godot 4.7 계열로 올렸습니다.

- `project.godot`의 `config/features`는 `4.7`로 설정합니다.
- 개발/검증 권장 버전은 현재 4.7 계열 안정 유지보수판인 Godot 4.7.2-stable입니다.
- 프로젝트는 GDScript + 2D Control/Canvas 기반이며 GL Compatibility 렌더러를 유지합니다.
- 4.6→4.7 마이그레이션 문서의 주요 GDScript 비호환 API를 소스에서 별도 검사합니다.
- 프로젝트에서 사용하지 않는 3D Jolt, OpenXR, 제거된 AudioEffectSpectrumAnalyzer 속성 등은 현재 영향 대상이 아닙니다.
- 4.7의 CanvasItem 선 렌더링 변화에 대비해 월드맵 행군선은 명시적 선 두께를 사용합니다.

실행 전에는 프로젝트 백업을 권장합니다. Godot에서 처음 열 때 import 캐시가 새로 생성될 수 있습니다.
