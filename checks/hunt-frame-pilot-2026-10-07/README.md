# 전신 프레임 시범 작업 검수 자료

작업 내용과 검증 범위는 [인수인계 문서](../../docs/HANDOFF_HUNT_FRAMES_2026-10-07_KO.md)에 정리했다.

- `captures/whole-pose-animation.mp4`: 레온하르트·고블린의 확대 자세 검수용 느린 재생. 실제 사냥 영상이 아니다.
- `captures/attack-*.png`, `captures/motion-*.png`: 엔진에서 렌더한 선택 자세 이미지.
- `captures/whole-pose-review.json`: 각 이미지의 프레임·렌더러 검사 정보.
- `handoff-tests.json`: 마지막 캐시 수정 이후 집중 회귀 3개 결과.
- `handoff-static-python.json`: 정적·아키텍처·Python 도구 검사 결과.
- `pilot-tests.json`, `initial-tests.json`: 이전 검증 결과, 최종 확인은 handoff 결과를 사용한다.
- `rejected-cutout-source/`: 거절한 관절 조립 방법의 비실행 참고 자료. 현재 게임에는 연결하지 않는다.

실제 사냥 녹화는 사용자 요청으로 중단되어 미완료다. 로그·캐시·개인 플레이 저장·대량 원시 캡처 프레임은 제외했다.
