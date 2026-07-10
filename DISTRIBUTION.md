# Distribution Guide

## 권장 저장소 구성

- **비공개 소스 저장소**: Swift 앱, R 패키지, 빌드 스크립트
- **공개 릴리스 저장소**: README와 GitHub Release의 DMG·SHA-256 파일만 포함

현재 소스 원격 `Dev-os-elop/R-status`는 공개 상태입니다. 이미 공개된 Git 기록까지 숨기려면 조직의 Admin 권한으로 저장소를 Private으로 변경해야 합니다. 단순히 현재 파일을 삭제해도 과거 Git 기록에서는 소스를 볼 수 있습니다.

공개 릴리스 저장소의 권장 이름은 `Ljwook92/R-status-releases`입니다. `distribution/PUBLIC_README.md`를 그 저장소의 `README.md`로 사용하세요.

## DMG 빌드

```sh
make release
```

결과:

```text
release/RStudio-Status-<version>.dmg
release/RStudio-Status-<version>.dmg.sha256
```

DMG의 앱에는 R Addin 패키지와 설치 스크립트가 포함됩니다. 사용자는 앱을 Applications로 옮긴 뒤 첫 실행에서 **Install Addin**만 누르면 됩니다.

## Developer ID 서명

현재 컴퓨터에는 유효한 Developer ID Application 인증서가 없습니다. 인증서가 없으면 테스트용 ad-hoc 서명 DMG는 만들 수 있지만, 다른 사용자의 Mac에서 Gatekeeper 경고가 발생합니다.

Apple Developer Program에 가입하고 Developer ID Application 인증서를 Keychain에 설치한 후:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make release
```

## Apple 공증

공증 자격 증명을 Keychain profile로 한 번 저장합니다.

```sh
xcrun notarytool store-credentials "rstatus-notary" \
  --apple-id "APPLE_ID" \
  --team-id "TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

그다음 서명과 공증을 함께 실행합니다.

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="rstatus-notary" \
make release
```

## GitHub Release 게시

공개 릴리스 저장소를 만든 뒤:

```sh
RELEASE_REPO="Ljwook92/R-status-releases" make publish
```

`scripts/publish-release.sh`가 현재 버전 태그, DMG, SHA-256 파일, 릴리스 노트를 게시합니다.

## 소스 보호의 한계

- Swift는 컴파일되지만 역공학을 완전히 막을 수는 없습니다.
- RStudio Addin은 R에서 로드돼야 하므로 최소한의 R 연결 코드는 사용자 컴퓨터에 설치됩니다.
- 저장소를 Private으로 바꾸는 것은 원본 소스의 일반 공개를 막지만, 이미 복제된 사본을 회수하지는 못합니다.
- 진정한 비밀정보, 토큰, 서명 인증서, 공증 암호는 코드나 앱에 포함하지 말고 Keychain과 GitHub Secrets로 관리해야 합니다.
