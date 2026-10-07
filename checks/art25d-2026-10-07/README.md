# 원화 기반 2.5D 화면과 움직임 검수

사용자 요청에 따라 3D 초안을 중간 검수했고, 원화 느낌을 보존하는 2.5D로 기본 화면을 맞췄습니다. 영웅30·몬스터13·보스3의 기존 전신 원화를 실제 3D 맵6개 위에 표시합니다. 사진은 합성 예상도가 아니라 Godot 4.7.2의 실제 Mobile 렌더입니다.

## 실제 화면

- [아우렐리아 10인 사냥](captures/aurelia-ten-hero-hunt.png), [녹스페라 10인 사냥](captures/noxfera-ten-hero-hunt.png)
- [광산 10인 사냥](captures/forgotten_mine-ten-hero-hunt.png), [월광 숲 10인 사냥](captures/moonrest_forest-ten-hero-hunt.png)
- [초원 레이드](captures/gray_meadow-raid.png), [광산 레이드](captures/forgotten_mine-raid.png), [월광 레이드](captures/moonrest_forest-raid.png)
- [30명 서 있는 크기 비교](captures/thirty-heroes-same-height.png), [30명 공격 자세](captures/thirty-heroes-original-attack.png), [16종 몬스터·보스 원화](captures/original-monsters-and-bosses.png)

캡처는 기본 전투 수치·레벨을 유지합니다. [캡처 기록](captures/captures.json)의 7개 실제 장면은 몸체 예약 영역 겹침0개이며 10명 영웅이 같은 혼잡 배율을 공유합니다. 스킬 무기 궤적이나 의도된 전투 VFX까지 몸체 겹침으로 표시하지 않습니다.

## 실제 움직임

[레온하르트 실제 사냥 영상](movement/captures/actual-hunting.mp4), [타격 자세](movement/captures/actual-attack-3.png), [보행 자세](movement/captures/actual-walk.png), [재생 기록](movement/captures/actual-hunt.json).

영상은 실제 기본 게임·레벨1·기본 수치로 전투를 진행합니다. 마지막4초는 같은 전투를 확대하는 검수 카메라입니다. 프레임 재생은 30fps 녹화이며 실제 Android 성능60fps를 측정했다는 뜻이 아닙니다.

30명 모두에 작은 천/머리카락 흔들림, 이동 거리로 진행하는 보행, 실제 타격 시점과 회수, 동결 가능한 보조 움직임 시계를 연결했습니다. 얼굴·팔다리를 분리하지 않으며 보조 효과는 끌 수 있습니다. 원화의 공격8·대기2·보행4·피격1·사망1 자세를 사용하며 새 8방향 원화 시트를 제작했다고 표시하지 않습니다.

## 검사와 재현

최종 회귀 **10/10개·명시적3,812항목**, 현재 GDScript **492/492개** 구문 범위, Python **50/50개**, 리소스·문서 링크 검사를 통과했습니다. [통합 요약](validation-summary.json), [최종 실행 결과](final-runtime.json), [구문 범위와 재검사](final-syntax.json)에서 확인할 수 있습니다. 전체 구문 검사 중 수정하지 않은 V43 검사 프로세스1개가 진단 없이 종료되어 별도 재검사했고, 변경·신규 스크립트도 순차 재검사했습니다.

최종 실행 검사 결과와 추가 구문 검사 결과는 아래 JSON에 기록합니다. 실패했던 중간 실행 기록도 보존하며 최종 결과와 구분합니다. 창 크기 변경 요청이 이미 새 크기로 생성된 레이드 화면을 다시 만들던 문제를 수정했고, 크기0인 전장에서는 투영을 기다리도록 했습니다.

```powershell
python tools/render_25d.py --godot 'Godot 4.7.2 실행 파일' --output checks/art25d-2026-10-07/captures
python tools/render_hunt_frames.py --godot 'Godot 4.7.2 실행 파일' --ffmpeg 'FFmpeg 실행 파일' --live --output checks/art25d-2026-10-07/movement
python tools/run_tests.py --godot 'Godot 4.7.2 실행 파일' --jobs 2 --tests PaintedMotion25DSmokeTest.gd FullBodyRolloutSmokeTest.gd
```

Raw 프레임·임시 저장·캐시·로그는 Git에 넣지 않습니다. 설치 출처와 초안 상태는 [제작 기록](../../assets/models3d-v1/README.md), 제공 링크 적용 범위는 [Meta 자료 기록](../../assets/art-direction/meta-mobile25d-reference/README.md)에 있습니다.

남은 검증 범위는 Android 실기기의 FPS·메모리·발열·배터리와 장시간 플레이입니다. 46종 실시간 3D 캐릭터 초안은 승인된 최종 디자인으로 사용하지 않습니다.
