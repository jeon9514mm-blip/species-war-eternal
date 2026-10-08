# Native canvas batch buffer fix

사냥 검수 실행이 두 차례 Windows 힙 손상 종료 코드 `0xC0000374`로 중단됐다. 고정 크기 원형 입자와 MultiMesh 단독 검사에서는 발생하지 않았으며, 가변 개수의 발자국 먼지를 그리는 새 캔버스 배치 경로를 조사했다.

## 엔진 소스에서 확인한 원인

실제 사용한 Godot `4.7.2-stable`, Git 리비전 `ed1daf0bf`의 캔버스 렌더러는 인덱스 버퍼를 전달된 개수에 맞춰 할당한 뒤, 전달된 인덱스 배열 **전체 길이**를 복사한다. 따라서 큰 용량 배열을 전달하면서 작은 `count`만 지정하면 할당 범위를 넘어선다. [사용 엔진의 인덱스 버퍼 할당·복사 코드](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_rd/renderer_canvas_render_rd.cpp#L290-L300)

공개 API의 `count`는 삼각형 개수이며 내부에서 인덱스 개수로 변환된다. [삼각형 개수를 인덱스 개수로 바꾸는 코드](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_canvas_render.h#L134-L147)

이 배치의 입자 하나는 정점 25개, 삼각형 36개, 인덱스 108개다. 용량 272개에서 입자 1개만 활성화됐을 때 이전 호출은 432바이트 버퍼에 전체 용량의 117,504바이트를 복사하게 했다. 고정 입자 80개 경로는 활성 개수와 용량이 같아서 이 조건을 만들지 않았다. 인덱스 자체는 각 입자의 정점 0~24 범위 안에 있으며, 원인은 축소된 버퍼와 큰 복사 길이의 불일치였다.

## 수정과 확인

`BatchedMotes.draw()`는 활성 입자에 해당하는 인덱스·정점·색 배열을 각각 잘라 전달하고 `count`를 기본값 `-1`로 둔다. 할당 길이와 복사 길이가 같아진다. 입자 수, 색, 반경, 수명과 삼각형 배치는 유지한다.

수정 후 전체 Mobile 검수 실행이 `FINAL_POLISH_REVIEW_OK`로 정상 종료됐다. 해당 실행의 사냥 평균은 아우렐리아 37.27fps, 녹스페라 39.13fps, 자연 크리티컬 조건 40.14fps이며 레이드는 59.33fps다. 이는 고정 입자 단독 검사가 아닌 실제 사냥 및 화면 전환을 포함한 검수 결과다. 최종 수치는 [performance.json](review/performance.json)에, 활성 개수 변화 90프레임 GPU 검사와 출력은 [gpu-final-integration.json](gpu-final-integration.json)에 기록한다. 원시 실행 로그는 저장소의 기존 제외 규칙을 따른다.

이 감사에서는 엔진을 추가 실행하지 않았다. 활성 개수 변화에 대한 별도 GPU 회귀 검사는 루트 작업의 검증 결과에 포함한다.
