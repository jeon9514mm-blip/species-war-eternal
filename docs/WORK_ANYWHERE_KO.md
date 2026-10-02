# 종의전쟁 — 다른 컴퓨터에서 작업 이어가기

저장소: https://github.com/jeon9514mm-blip/species-war-eternal

## 가장 쉬운 방법: GitHub Desktop

1. 사용할 컴퓨터에 [GitHub Desktop](https://desktop.github.com/)과 [Godot 4.6.3](https://godotengine.org/download/archive/4.6.3-stable/) 일반 에디터를 설치합니다.
2. GitHub Desktop에 저장소 소유 계정 또는 접근 권한을 받은 계정으로 로그인합니다.
3. **File → Clone repository → URL**에 위 저장소 주소를 넣고 저장할 폴더를 선택합니다.
4. Godot 프로젝트 관리자에서 **가져오기(Import)**를 누르고 복제한 폴더의 `project.godot`를 선택합니다.
5. 최초 리소스 임포트를 기다린 뒤 F5로 실행합니다. `.godot` 폴더는 자동 생성됩니다.

이미지, 음원, 씬, 셰이더까지 Git에 포함되어 있습니다. 초기 파일은 GitHub의 개별 파일 제한 이내라 Git LFS를 사용하지 않으며 별도 에셋 다운로드는 필요하지 않습니다. 저장소가 비공개이므로 권한이 없는 계정에는 표시되지 않습니다.

## 매일 작업하는 순서

1. 작업 시작 전 GitHub Desktop에서 **Fetch origin → Pull origin**으로 새 변경을 받습니다.
2. **Current Branch → New Branch**로 `work/map-polish`처럼 작업 브랜치를 만듭니다.
3. Godot/Codex/코드 편집기로 수정하고 실행하여 확인합니다.
4. GitHub Desktop의 Changes에서 수정 파일을 확인하고 설명을 입력해 **Commit**합니다.
5. **Push origin** 또는 새 브랜치의 **Publish branch**를 누릅니다.
6. 다른 컴퓨터에서는 Fetch/Pull한 뒤 같은 브랜치를 선택하여 이어갑니다.

Commit은 현재 컴퓨터에 기록하고, Push가 GitHub에 보관합니다. 컴퓨터를 옮기기 전 Push까지 완료하세요. 같은 파일을 두 컴퓨터에서 따로 수정했다면 충돌을 확인하고 합쳐야 합니다. 최신 코드를 받기 전 내 수정 사항을 먼저 커밋하면 안전하게 이력을 보존할 수 있습니다.

## 터미널을 사용할 때

```sh
git clone https://github.com/jeon9514mm-blip/species-war-eternal.git
cd species-war-eternal
git switch -c work/my-change
# 파일 수정 및 Godot 실행 확인
git add .
git commit -m "Describe the change"
git push -u origin work/my-change
```

다른 컴퓨터의 최초 복제 뒤에는 `git switch work/my-change`로 원격 작업 브랜치를 선택합니다. 이미 복제했다면 해당 브랜치에서 `git pull --ff-only`로 받습니다. 인증은 GitHub Desktop 또는 `gh auth login`을 사용하고, 토큰을 소스나 채팅에 붙여넣지 마세요.

## 다른 Codex 환경에서 이어가기

- **로컬 Codex**: 복제한 `species-war-eternal` 폴더를 프로젝트로 열고 `README.md`, `CURRENT_DEVELOPMENT.md`, `MAPS_3D_README.md`를 먼저 읽도록 요청합니다.
- **GitHub를 사용하는 클라우드 Codex**: GitHub 연결에 이 비공개 저장소 접근을 허용하고 해당 저장소·브랜치를 선택합니다. 접근 목록에 안 보이면 GitHub 앱의 저장소 접근 범위를 확인합니다.
- 실행 검증에는 해당 환경에도 Godot 4.6.3이 설치되어 있어야 합니다. 리소스 최초 임포트는 `godot --headless --editor --path . --quit`로 할 수 있습니다.
- 이 저장소는 소스와 개발 문서를 보관합니다. 이 ChatGPT 대화 전체가 GitHub에 자동 복제되지는 않습니다.

## 버전과 복구

- `v83-6.2`: 부대 사냥·진형·화면 회전을 구현한 기준 버전
- `v83-6.3`: 3D 맵과 GitHub 작업 안내를 포함한 보관 버전
- 새 개발은 `main`에서 브랜치를 만듭니다. 이전 버전을 검토하려면 별도 복제본에서 `git switch --detach v83-6.2`를 사용합니다.

Godot의 **플레이 진행 저장(user://)**은 GitHub 코드 동기화와 별개입니다. 다른 PC에서도 같은 캐릭터 성장 상태를 쓰려면 게임 저장을 따로 옮겨야 합니다. [저장 안내](../START_HERE_KO.md)를 확인하세요.
