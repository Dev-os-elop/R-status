# RStudio Status

RStudio에서 실행하는 R 코드의 상태를 macOS 메뉴바와 알림으로 보여주는 앱입니다.

대기 중에는 선택한 상태 아이콘만 표시되고, Addin 또는 `rstatus_run()`으로 코드를 실행하면 아이콘 색상과 상태가 다음과 같이 바뀝니다.

```text
[상태 아이콘]  →  Running 00:12  →  Complete
                                      ↘  Fail ⚠️
                                      ↘  Interrupted ⛔️
```

완료, 실패 또는 사용자 중단 시 macOS 알림도 전송됩니다. 모든 통신은 로컬 주소 `127.0.0.1:47821`에서만 이루어지며 R 코드나 데이터가 외부로 전송되지 않습니다.

## 기능

- Cat Original·Cat Silhouette을 포함한 선택형 macOS 메뉴바 아이콘
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

설치 파일은 GitHub Release에서 사전 빌드된 Apple Silicon 실행 파일을 내려받고 SHA-256을 검증합니다. 일반 사용자는 Xcode나 Command Line Tools를 설치할 필요가 없습니다. 앱은 프로젝트의 독자적인 고양이 아이콘을 포함하며 RStudio 로고를 사용하지 않습니다.

처음 실행하면 macOS가 알림 권한을 요청합니다. 완료·실패 알림을 받으려면 **허용**을 선택하세요.

### 터미널에서 설치하기

Xcode가 없는 Mac에서는 `git clone`을 사용하지 마세요. 위에서 ZIP을 받은 뒤 압축을 푼 폴더의 터미널에서 실행합니다.

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
6. 메뉴바 상태 아이콘이 파란색 `Running` 상태로 바뀌는지 확인합니다.
7. 코드가 정상적으로 끝나면 `Complete ✅`, 오류가 발생하면 `Fail ⚠️`가 표시됩니다.
8. 실행 중 RStudio Console의 **Stop** 버튼을 누르면 `Interrupted ⛔️`가 표시됩니다.

선택 영역이 비어 있으면 Addin이 실행할 코드가 없다는 오류를 표시합니다. 파일 전체를 실행하려면 코드를 선택하지 않고 **Run Current Document with Status**를 사용할 수도 있습니다.

실행 중 RStudio 앱을 완전히 종료하면 상태 앱이 실행 중인 R 세션 PID를 감시해 약 0.5초 안에 카운트를 멈추고 `Interrupted ⛔️`로 전환합니다. macOS에서 창의 빨간 닫기 버튼은 앱 종료가 아니므로 RStudio를 끝내려면 `Cmd + Q`를 사용하세요.

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
[상태 아이콘] → Running 00:01 → Running 00:20 → Complete
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

상태 아이콘 또는 상태 텍스트를 클릭하면 다음 기능을 사용할 수 있습니다.

- 현재 작업 이름과 실행 시간 확인
- R CPU 사용량 확인
- R process와 병렬 worker 수 확인
- `progress`/`progressr` 실행 시 진행 바·퍼센트·남은 시간 확인
- 상태 초기화
- 알림 테스트
- RStudio 열기
- 오른쪽 **Settings** 패널에서 언어·아이콘·실행 시간·로그인 실행 설정
- 현재 설치 버전 확인
- **Check for Updates…**로 최신 버전을 확인하고 자동 다운로드·설치
- **Install/Update RStudio Addin…**으로 Addin 설치 또는 업데이트
- 앱 종료

업데이트가 없으면 `You're using the latest version.` 팝업이 표시됩니다. 새 버전이 있으면 **Download and Install**을 눌러 태그 ZIP과 검증된 사전 빌드 실행 파일을 내려받고, 앱과 Addin을 설치한 뒤 RStudio Status를 자동으로 재실행합니다. Xcode는 필요하지 않습니다.

### 고양이 아이콘 테마

**Settings → Appearance**에서 두 가지 고양이 디자인을 선택할 수 있습니다.

- **Cat Original**: 흰 얼굴, 분홍 귀·코, 짧은 수염, 상태별 표정과 보조 기호를 사용하는 기본 메뉴바 디자인이자 고정 앱·알림 아이콘
- **Cat Silhouette**: 진한 고양이 실루엣과 상태색 눈만 사용하는 초단순 선택 디자인

Cat Original은 회색 점, 파란 회전 화살표, 초록 체크, 주황 일시정지, 빨간 느낌표를 표정과 함께 표시합니다. Cat Silhouette은 대기 회색 원, 실행 파란 재생 모양, 완료 초록 체크, 중단 주황 일시정지, 실패 빨간 X 모양의 눈으로 상태를 구분합니다.

### Progress 표시

Addin으로 실행한 코드가 `progress::progress_bar` 또는 `progressr`를 사용할 때만 R Resource Usage 아래에 추가 정보가 나타납니다.

```text
Progress: [████████░░░░░░] 57%
Remaining: 00:04 · step 57
```

`progress` 패키지는 `tick()`, `update()`, `terminate()`를 자동 감지합니다. `progressr`는 실행 중에만 전용 handler를 추가하고 종료 후 사용자의 기존 handler 설정을 복원합니다. 진행 이벤트는 최대 약 0.25초 간격으로 전달하므로 tick이 매우 잦아도 네트워크 전송이 연산을 과도하게 느리게 하지 않습니다. 진행 패키지를 사용하지 않는 일반 코드는 이 메뉴 항목을 표시하지 않습니다.

확인하려면 [`examples/progress-status-test.R`](examples/progress-status-test.R)을 전체 선택하고 **Addins → Run Selection with Status**로 실행하세요.

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

### `'git' 명령에는 명령어 라인 개발자 도구가 필요합니다` 팝업

RStudio Status의 ZIP 설치와 자동 업데이트는 `git`을 사용하지 않으며 Xcode Command Line Tools가 필요하지 않습니다. 이 팝업은 보통 `git clone`을 실행했거나, RStudio가 `.git` 폴더가 있는 프로젝트의 Git 상태를 확인할 때 macOS의 `/usr/bin/git`이 표시합니다.

- 설치할 때는 `git clone` 대신 위의 **Code → Download ZIP**을 사용하세요.
- RStudio에서 Git을 사용하지 않는다면 **Tools → Global Options → Git/SVN**에서 **Enable version control interface for RStudio projects**를 끄고 RStudio를 재시작하세요.
- 압축을 푼 설치 폴더에는 `.git` 디렉터리가 없어야 합니다.

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

RStudio는 Posit Software, PBC의 상표입니다. 이 프로젝트는 Posit의 공식 제품이 아니며 Posit과 제휴하거나 보증받지 않았습니다. 앱과 저장소는 RStudio 로고를 사용하거나 포함하지 않습니다.
