# 종의전쟁: 이터널 v71 — 자동사냥 흐름 개선

## 이번 업데이트
- 3개 사냥터마다 5개의 authored hunt habitat 좌표를 추가해 8~20마리 몬스터가 한 지점에 몰리지 않도록 분산
- 정예 스테이지에서는 첫 정예 팩을 더 깊은 사냥 구역에 배치해 일반 팩 → 정예 팩으로 자연스럽게 진행
- 같은 habitat pack의 몬스터가 한 마리의 교전을 감지하면 로컬 팩 단위로 지원 어그로가 연결됨
- 몬스터 간 로컬 separation steering을 추가해 같은 영웅에게 접근해도 완전히 겹치는 현상을 완화
- 영웅 타깃 선택에 soft target-load penalty를 추가해 일반 적 한 마리에 10명이 몰리는 현상을 완화
- 처형형(finisher) 및 same-target 패시브 영웅은 기존 집중 공격 의도를 유지
- 기존 세이브, zone id, 몬스터 수 8~20, 전투 수치/보상 규칙은 유지

## 검증
- `tools/static_validate.py`
- `tools/godot47_compat_scan.py`
- 신규 `tests/regression/V71HuntFlowSmokeTest.gd` 추가
- 패키징 환경에 Godot 실행 바이너리가 없으면 headless 런타임 테스트는 별도 환경에서 실행 필요
