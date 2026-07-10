# RStudio Status

RStudio에서 실행하는 R 코드의 상태를 macOS 메뉴바와 알림으로 보여주는 앱입니다.

대기 중에는 메뉴바에 RStudio 로고만 표시되고, Addin 또는 `rstatus_run()`으로 코드를 실행하면 상태가 다음과 같이 바뀝니다.

```text
[RStudio 로고]  →  Running ⏳ 00:12  →  Complete ✅
                                      ↘  Fail ⚠️
                                      ↘  Interrupted ⛔️
```

완료, 실패 또는 사용자 중단 시 macOS 알림도 전송됩니다. 모든 통신은 로컬 주소 `127.0.0.1:47821`에서만 이루어지며 R 코드나 데이터가 외부로 전송되지 않습니다.

## 기능

- RStudio 공식 로고를 사용하는 macOS 메뉴바 앱
- 실행 경과 시간 표시
- 전체 CPU 용량 기준 R 사용률, R 프로세스, 병렬 worker 실시간 표시
- 완료·실패·사용자 중단 시 macOS 알림
- 선택 영역 또는 현재 문서 전체를 실행하는 RStudio Addin
- 일반 R 코드에서 사용할 수 있는 `rstatus_run()` 함수
- 로그인 시 자동 실행, 상태 초기화, 알림 테스트 메뉴
- 현재 버전 표시 및 GitHub `main` 버전 업데이트 확인
- 앱 안에서 RStudio Addin 원클릭 설치·업데이트
- GitHub Release의 사전 빌드 앱을 이용한 Xcode 없는 설치

## 필수 조건

- macOS 13 Ventura 이상
- Apple Silicon Mac
- [RStudio Desktop](https://posit.co/download/rstudio-desktop/)
- R 4.1 이상

현재 앱은 Apple Silicon용으로 테스트했습니다. Intel Mac은 아직 검증하지 않았습니다.

## 설치

### 가장 쉬운 방법: ZIP 다운로드

1. [Dev-os-elop/R-status](https://github.com/Dev-os-elop/R-status)에서 **Code → Download ZIP**을 선택합니다.
2. 다운로드한 ZIP의 압축을 풉니다.
3. 폴더 안의 **Install RStudio Status.command**를 더블클릭합니다.
4. macOS가 실행을 막으면 파일을 우클릭하고 **Open**을 선택합니다.
5. 설치가 완료되면 RStudio를 완전히 종료했다가 다시 실행합니다.
6. RStudio에서 **Addins → Run Selection with Status**를 사용합니다.

설치 파일은 GitHub Release에서 사전 빌드된 Apple Silicon 실행 파일을 내려받고 SHA-256을 검증합니다. 일반 사용자는 Xcode나 Command Line Tools를 설치할 필요가 없습니다. RStudio 로고는 상표 파일을 재배포하지 않고 사용자의 RStudio 설치에서 가져옵니다.

처음 실행하면 macOS가 알림 권한을 요청합니다. 완료·실패 알림을 받으려면 **허용**을 선택하세요.

### 터미널에서 설치하기

git을 사용한다면 다음 명령을 실행합니다.

```sh
git clone https://github.com/Dev-os-elop/R-status.git
cd R-status
chmod +x install.sh uninstall.sh Resources/*.sh scripts/*.sh
./install.sh
```

이미 ZIP을 받았다면 압축을 푼 폴더에서 실행할 수도 있습니다.

```sh
chmod +x install.sh uninstall.sh Resources/*.sh scripts/*.sh
./install.sh
```

## RStudio Addin 사용

설치 후 RStudio를 완전히 종료했다가 다시 실행합니다. 상단의 **Addins** 메뉴에 다음 두 항목이 표시됩니다.

- **Run Selection with Status**: 에디터에서 선택한 R 코드를 실행
- **Run Current Document with Status**: 현재 R 문서 전체를 실행

### `Run Selection with Status` 실행 방법

1. RStudio 에디터에 실행할 R 코드를 입력하거나 `.R` 파일을 엽니다.
2. 상태를 추적할 코드를 마우스로 드래그해 선택합니다. 문서 전체를 선택하려면 `Cmd + A`를 누릅니다.
3. RStudio 상단 메뉴에서 **Addins**를 클릭합니다.
4. **Run Selection with Status**를 클릭합니다.
5. 선택 코드가 RStudio Console의 일반 실행 명령으로 전달되고 Console이 Busy 상태가 되는지 확인합니다.
6. 메뉴바의 RStudio 로고가 `Running ⏳`으로 바뀌는지 확인합니다.
7. 코드가 정상적으로 끝나면 `Complete ✅`, 오류가 발생하면 `Fail ⚠️`가 표시됩니다.
8. 실행 중 RStudio Console의 **Stop** 버튼을 누르면 `Interrupted ⛔️`가 표시됩니다.

선택 영역이 비어 있으면 Addin이 실행할 코드가 없다는 오류를 표시합니다. 파일 전체를 실행하려면 코드를 선택하지 않고 **Run Current Document with Status**를 사용할 수도 있습니다.

### 20초 확인용 예제

저장소의 [`examples/status-test-20-seconds.R`](examples/status-test-20-seconds.R)을 RStudio에서 엽니다. 파일 전체를 선택한 뒤 **Addins → Run Selection with Status**를 실행하세요.

예제 코드는 다음과 같습니다.

```r
message("20-second matrix computation started")

started_at <- proc.time()[["elapsed"]]
iteration <- 0L
checksum <- 0

while (proc.time()[["elapsed"]] - started_at < 20) {
  matrix_size <- 600L
  values <- matrix(rnorm(matrix_size * matrix_size), nrow = matrix_size)
  gram_matrix <- crossprod(values)
  checksum <- checksum + sum(diag(gram_matrix))
  iteration <- iteration + 1L
}

message("Matrix computation complete: ", iteration, " iterations")
```

예상되는 메뉴바 변화:

```text
[RStudio 로고] → Running ⏳ 00:01 → Running ⏳ 00:20 → Complete ✅
```

이 예제는 `Sys.sleep()`이 아니라 실제 행렬 생성과 곱셈을 반복합니다. Addin이 코드를 Console로 전달하므로 RStudio가 Busy 상태가 되고 **Stop** 버튼으로 중단할 수 있습니다. 실행 중 Stop을 누르면 다음처럼 표시됩니다.

```text
Running ⏳ 00:08 → Interrupted ⛔️
```

완료하거나 중단하면 macOS 알림도 표시됩니다. 중단하지 않으면 전체 과정은 약 20초가 걸립니다.

### 단축키 지정

RStudio에서 다음 메뉴를 엽니다.

```text
Tools → Modify Keyboard Shortcuts…
```

검색창에 `Status`를 입력하고 두 Addin 중 원하는 항목에 단축키를 지정합니다. 이후 해당 단축키로 실행하면 메뉴바 상태가 자동으로 변경됩니다.

일반적인 `Cmd + Enter` 실행을 앱이 외부에서 자동 감지하지는 않습니다. 상태 추적이 필요한 코드는 Addin 단축키 또는 아래의 `rstatus_run()`을 사용해야 합니다.

## R 함수로 사용

긴 작업을 `rstatus_run()`으로 감싸면 시작·완료·실패가 자동으로 보고됩니다.

```r
library(rstudiostatus)

rstatus_run({
  Sys.sleep(5)
  model <- lm(mpg ~ wt, data = mtcars)
  saveRDS(model, "model.rds")
}, name = "모델 학습")
```

상태를 직접 전송할 수도 있습니다.

```r
library(rstudiostatus)

rstatus_notify("running", "데이터 처리")
rstatus_notify("complete", "데이터 처리")
rstatus_notify("fail", "데이터 처리", "입력 파일을 찾을 수 없습니다")
rstatus_notify("interrupted", "데이터 처리", "사용자가 작업을 중단했습니다")
rstatus_notify("idle", "")
```

## 메뉴바 메뉴

RStudio 로고 또는 상태 텍스트를 클릭하면 다음 기능을 사용할 수 있습니다.

- 현재 작업 이름과 실행 시간 확인
- R CPU 사용량 확인
- R process와 병렬 worker 수 확인
- 상태 초기화
- 알림 테스트
- RStudio 열기
- 로그인 시 실행 설정
- 현재 설치 버전 확인
- **Check for Updates…**로 GitHub `main` 브랜치의 최신 버전 확인
- **Install/Update RStudio Addin…**으로 Addin 설치 또는 업데이트
- 앱 종료

업데이트가 없으면 `You're using the latest version.` 팝업이 표시됩니다. GitHub의 `main` 브랜치에 더 높은 버전이 있으면 **Open GitHub** 버튼이 표시됩니다. 저장소에서 최신 ZIP을 다시 받거나 `git pull` 후 `./install.sh`을 실행하면 업데이트됩니다.

### 리소스 정보 해석

메뉴의 리소스 정보는 약 2초마다 갱신됩니다.

```text
R Resource Usage
CPU: 100.0%
Parallel workers: 12
R processes: 13
```

- **CPU**: `R`, `Rscript`, RStudio `rsession`의 코어별 CPU 사용률 합계를 현재 사용 가능한 논리 CPU 수로 나눈 값입니다. 로컬 CPU 전체 용량을 기준으로 0–100%로 표시됩니다.
- **Parallel workers**: `parallel`, PSOCK 등으로 생성된 병렬 작업용 R 프로세스 수입니다.
- **R processes**: main R 세션과 병렬 worker를 합친 전체 R 관련 프로세스 수입니다.

논리 CPU가 12개인 컴퓨터를 예로 들면 다음과 같습니다.

| 실행 방식 | CPU | Parallel workers | R processes |
|---|---:|---:|---:|
| R 세션 하나가 CPU 하나를 최대 사용 | 약 8.3% | 0 | 1 |
| `makeCluster(3)`의 worker 3개가 각각 CPU 하나를 최대 사용 | 약 25% | 3 | 4 |
| `makeCluster(12)`의 worker 12개가 전체 CPU를 최대 사용 | 약 100% | 12 | 13 |

`R processes`에는 main R 세션도 포함되므로 일반적인 PSOCK 병렬 처리에서는 `Parallel workers + 1`로 표시됩니다. CPU 값은 순간 샘플과 운영체제 스케줄링에 따라 조금 달라질 수 있습니다.

PSOCK cluster처럼 worker의 부모 PID가 분리되는 경우에는 실행 인자에서 `workRSOCK`과 `MASTER` 정보를 함께 확인해 worker를 계산합니다.

병렬 지표를 확인하려면 [`examples/parallel-resource-test-20-seconds.R`](examples/parallel-resource-test-20-seconds.R)을 전체 선택하고 **Addins → Run Selection with Status**로 실행하세요. worker 3개가 약 20초 동안 행렬 연산을 수행하므로 일반적으로 `Parallel workers: 3`, `R processes: 4`가 표시됩니다. CPU는 전체 논리 CPU 용량을 기준으로 계산되므로, 예를 들어 논리 CPU 12개 중 worker 3개가 코어 하나씩 최대 사용하면 약 25%로 표시됩니다.

## 제거

앱을 종료하고 Applications에서 `RStudio Status.app`을 휴지통으로 이동합니다. Addin도 제거하려면 RStudio Console에서 실행합니다.

```r
remove.packages("rstudiostatus")
```

소스 저장소로 설치했다면 다음 명령으로 둘을 함께 제거할 수 있습니다.

```sh
./uninstall.sh
```

이 명령은 `/Applications` 또는 `~/Applications`의 앱과 사용자 R 라이브러리의 `rstudiostatus` 패키지를 제거합니다.

## 문제 해결

### `unable to lookup item 'PlatformPath'` 설치 오류

이 오류는 소스를 로컬에서 빌드하던 0.3.5 이하 설치기에서 발생합니다. 최신 ZIP을 다시 내려받아 설치하세요. 0.3.6부터 일반 설치는 사전 빌드된 앱을 사용하므로 Xcode Command Line Tools가 필요하지 않습니다.

### Addins 메뉴에 항목이 보이지 않음

RStudio를 완전히 종료하고 다시 실행하세요. 그래도 보이지 않으면 RStudio 콘솔에서 다음을 확인합니다.

```r
find.package("rstudiostatus")
system.file("rstudio", "addins.dcf", package = "rstudiostatus")
```

RStudio가 터미널의 R과 다른 버전을 사용한다면, RStudio의 **Tools → Global Options → General → R version**에서 사용하는 R 버전을 확인한 후 해당 R로 설치 스크립트를 다시 실행하세요.

### 메뉴바 상태가 바뀌지 않음

메뉴바 앱이 실행 중인지 확인하고 다음 명령으로 로컬 서버 상태를 점검합니다.

```sh
curl http://127.0.0.1:47821/health
```

정상 응답:

```json
{"ok":true,"app":"RStudio Status"}
```

포트 47821을 다른 프로그램이 사용 중인지 확인하려면 다음을 실행합니다.

```sh
lsof -nP -iTCP:47821 -sTCP:LISTEN
```

### 알림이 오지 않음

macOS **시스템 설정 → 알림 → RStudio Status**에서 알림 허용이 켜져 있는지 확인하세요. 메뉴바 앱을 클릭한 뒤 **알림 테스트**로 확인할 수 있습니다.


## 보안

- 서버는 `127.0.0.1`에만 바인딩됩니다.
- R 코드는 앱으로 전송되지 않습니다.
- 앱에는 상태, 작업 이름, 오류 메시지만 전달됩니다.
- 리소스 정보는 로컬의 `ps`에서만 읽으며 외부로 전송하지 않습니다.
- 인터넷 연결은 Addin 의존성 설치와 업데이트 확인에 사용됩니다.

## 라이선스 및 상표

이 프로젝트의 코드는 [MIT License](LICENSE)로 배포됩니다.

RStudio 및 RStudio 로고는 Posit Software, PBC의 상표입니다. 이 프로젝트는 Posit의 공식 제품이 아니며 Posit과 제휴하거나 보증받지 않았습니다. 저장소는 RStudio 로고 파일을 포함하지 않고, 설치 과정에서 사용자의 로컬 RStudio 설치본에서 아이콘을 가져옵니다.
