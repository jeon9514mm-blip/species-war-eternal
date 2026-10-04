# 영웅 이미지 실제 검토 · 2026-10-04

15명 모두 Godot 4.7.2의 실제 부위 조립 화면을 새로 기록하고 확인했습니다. 왼쪽은 정적 참고 원화, 오른쪽은 부위 조립입니다. 미라·엘리시아는 목 확대와 6개 동작 위치도 확인합니다.

확인한 화면에는 파일 누락·대체 텍스처·다른 영웅 원화 연결·투명 배경 전체가 직사각형으로 그려지는 오류가 없습니다. 다만 원화 부위를 연결한 절단선과 장비 크기가 이미지 깨짐처럼 보이는 문제가 있습니다. 기본 F5 영웅은 자동 교체하지 않으며 검토용 시안으로 공개합니다.

| 영웅 | 실제 기준 자세 | 남은 시각 개선 |
|---|---|---|
| 레온하르트 | [화면](review/leonhardt/neutral.png) | 무릎 갑옷 겹침과 손 접점 |
| 미라 | [화면](review/mira/neutral.png) | 목 경계 세부·활 손가락 접점 |
| 엘리시아 | [화면](review/elisia/neutral.png) | 어깨·무릎 경계와 지팡이 비율 |
| 카이렌 | [화면](review/kairen/neutral.png) | 지팡이 상단 크기와 얼굴 가림 |
| 오르윈 | [화면](review/orwin/neutral.png) | 방패·몸통 비율과 팔 배치 |
| 세리아 | [화면](review/seria/neutral.png) | 손목·무릎 절단선 |
| 아스텔 | [화면](review/astel/neutral.png) | 지팡이 크기와 발 비율 |
| 다리우스 | [화면](review/darius/neutral.png) | 옷깃·무릎 겹침 |
| 루네아 | [화면](review/lunea/neutral.png) | 무릎 피부 끝과 손목 경계 |
| 카엘룸 | [화면](review/caelum/neutral.png) | 옷깃·몸통·갑옷 폭 |
| 아드리엔 | [화면](review/adrien/neutral.png) | 관절 절단선과 의상 연결 |
| 테사 | [화면](review/tessa/neutral.png) | 대포 크기와 양손 자세 |
| 나이아 | [화면](review/naia/neutral.png) | 활 크기와 다리 갑옷 경계 |
| 사엘 | [화면](review/sael/neutral.png) | 무릎 갑옷과 팔 연결 |
| 오델리아 | [화면](review/odelia/neutral.png) | 손목·장갑 연결과 의상 겹침 |

미라·엘리시아의 목 중복 패치는 셰이더로 가렸습니다. [미라 확대](review/mira/neck-neutral.png), [엘리시아 확대](review/elisia/neck-neutral.png). 피부 연결과 옷깃을 더 자연스럽게 만드는 후속 검토가 필요합니다.

기능 검사와 화면 검토는 별개입니다. 원화의 모든 부위를 제대로 불러오고 16동작·21관절·무기 그립이 동작하더라도 조립 모습이 자연스럽다는 뜻은 아닙니다. `reviewed=false`를 유지합니다.
