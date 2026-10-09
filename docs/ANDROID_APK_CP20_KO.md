# Unity Android APK · CP20

현재 Unity 게임을 휴대폰에 직접 설치할 테스트 APK로 제작하는 체크포인트다. 기존 30명·120스킬·10인 사냥·24/28/32마리 무리·타락한 몬스터 7종·세 레이드·직접 이동·배율 조절을 포함한다.

## 설정

- Unity 6000.6.4f1, Android Build Support, NDK r27c, OpenJDK 17, SDK Build Tools 36.0.0.
- 패키지 `com.specieswar.eternal`, 버전 0.1.20, 버전 코드 20.
- 최소 Android API 26(Android 8.0), 대상 API 36, ARM64, IL2CPP.
- 가로 양방향 자동 회전, Vulkan 및 OpenGL ES 3, 기존 Android ASTC 텍스처 설정.
- 단일 APK이며 별도 OBB 파일을 요구하지 않는다. Development Build는 꺼져 있다.
- 기본 Android 디버그 서명으로 직접 설치하는 테스트용이다. Play Store 배포용 AAB/정식 배포 서명은 별도 작업이다.
- Android 앱 이름은 `종의전쟁: 이터널`. 빌드 중에만 회사/제품 이름을 설정하고 완료·실패 후 원래 값으로 복원해 기존 Windows 저장 폴더를 유지한다.

## 재빌드

Unity 메뉴 `Eternal > Android > Build signed test APK`, 또는 Editor의 배치 실행에서 `Eternal.UnityMigration.Editor.AndroidApkBuilder.Build`를 호출한다. 빌드 장면은 `Assets/Scenes/Eternal.unity` 하나다. 출력은 `Unity/Builds/Android/EternalUnity-0.1.20-arm64.apk`이며 빌드 결과와 SHA-256을 `checks/unity-migration-2026-10-08/android-build-cp20.json`에 기록한다.

`tools/unity/verify-android-apk.ps1`은 manifest, APK 서명, ZIP/16KB 네이티브 라이브러리 정렬, ZIP CRC 및 ARM64 ELF 헤더를 검사한다. `verify-apk-zip.py`는 파일을 읽기만 하며 APK를 수정하거나 압축 해제하지 않는다. 개인 서명 키 파일이 APK에 들어 있지 않은지도 확인한다.

통합 Editor 빌드는 Gradle 포장 중 디스크 공간 부족으로 중단됐다. IL2CPP·텍스처·셰이더·Gradle 프로젝트 생성은 완료되어 있어 Editor를 종료한 뒤 `tools/unity/finish-android-apk.ps1`로 해당 프로젝트의 `assembleRelease`를 마쳤다. 이 스크립트는 Java 힙 1024MB, 동시 작업 2개, 병렬 작업·상시 데몬 비활성화를 사용한다. `android-build-cp20.json`에는 이전 Editor 시도의 실패 원인을, `android-gradle-recovery-cp20.json`에는 실제 APK 포장 성공을 기록한다. 처음부터 다시 빌드할 때는 Editor 메뉴를 사용하고, 포장 단계의 공간 부족이 반복되면 Editor를 종료한 뒤 복구 스크립트를 실행한다.

## 완성 파일

- `EternalUnity-0.1.20-arm64.apk`: 72,753,387 bytes (72.75MB / 69.38MiB).
- SHA-256: `2b6ff9a69eae664567b07c7fc5cb78384d750fd3aa011195f8ba9651669df069`.
- Android manifest, 기본 서명, ZIP CRC, 6개 ARM64 ELF 라이브러리와 각 PT_LOAD의 16KB 정렬을 검수했다.
- 전송 도구의 64MiB 요청 제한 때문에 `releases/android/cp20`에 검증 가능한 3개 부분 파일과 manifest를 보관한다. 이는 설치 파일 형식을 변경하지 않는다.
- 기본 브랜치 반영 시 `.github/workflows/android-apk-cp20.yml`이 원본 APK를 복원하고 SHA-256을 확인한 뒤 테스트 GitHub Release에 올린다. Unity를 클라우드에서 다시 빌드하지 않는다.
- [APK 다운로드](https://github.com/jeon9514mm-blip/species-war-eternal/releases/download/android-v0.1.20-cp20/EternalUnity-0.1.20-arm64.apk), [Release 페이지](https://github.com/jeon9514mm-blip/species-war-eternal/releases/tag/android-v0.1.20-cp20).
- APK 직접 다운로드가 막히면 [ZIP 다운로드](https://github.com/jeon9514mm-blip/species-war-eternal/releases/download/android-v0.1.20-cp20/EternalUnity-0.1.20-arm64.zip)를 사용한다. ZIP을 압축 해제하고 안에 있는 APK를 설치한다. 앱 내 브라우저에서 링크가 열리지 않으면 주소를 Chrome 등 외부 브라우저에서 연다. ZIP에는 같은 서명과 SHA-256을 가진 원본 APK 하나만 포함된다.
- 로컬 복원이 필요하면 `python tools/unity/publish-android-release.py reconstruct`를 실행한다. 복원한 APK의 해시와 서명 검수도 통과했다.

## 설치와 확인 범위

Android 휴대폰에서 APK를 내려받아 실행하고, 해당 다운로드 앱의 외부 앱 설치 허용을 켜서 설치한다. 설치 후 가로 화면에서 진영을 선택해 시작한다. 처음 설치한 휴대폰에는 새 Unity 원정대가 생성되며 PC 진행 기록을 자동으로 옮기지는 않는다. 기존 Windows/Godot 저장 파일은 APK에 넣지 않는다.

컴퓨터에 Android 휴대폰이 연결되어 있지 않아 실제 기기의 실행·터치·레이드·저장 재실행·FPS·발열·메모리를 검증한 것으로 표시하지 않는다. 빌드 및 패키지 검수와 휴대폰 플레이 검수는 구분한다. 전체 프레임 최적화는 이전 사용자 지시대로 후속 작업이다.

설치 공간 확보 과정에서 현재 프로젝트가 쓰지 않는 예전 검수용 Unity 6000.3.25f1 설치본을 공식 CLI로 제거했다. 게임 소스/원화는 보존했다. 이전 검수 빌드 폴더의 재귀 삭제는 자동 승인 검토에서 차단되어 진행하지 않았다. 설치 도구·빌드 캐시·이전 검수 빌드 파일에는 내용 변경 없이 Windows 압축을 적용해 공간을 확보했다.

공식 참고: [Android 빌드 절차](https://docs.unity.com/en-us/engine/6000.6/manual/platform-specific/android/building-and-delivering/build-process), [지원 SDK·NDK·JDK](https://docs.unity.com/en-us/engine/6000.6/manual/platform-specific/android/getting-started/sdksetup/supported-dependency-versions).
