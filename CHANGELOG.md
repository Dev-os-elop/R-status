# Changelog

## 0.3.3 - 2026-07-09

- 메뉴와 샘플러에서 RAM 사용량 제거
- 지표 이름을 Active, Parallel workers, R processes, OS threads로 명확화

## 0.3.2 - 2026-07-09

- 메뉴와 샘플러에서 시스템 GPU 사용률 제거
- CPU, RAM, task, worker, process, thread 정보만 유지

## 0.3.1 - 2026-07-09

- 기본 배포 방식을 GitHub ZIP 또는 git clone 후 로컬 설치로 변경
- 더블클릭 가능한 설치·제거 `.command` 파일 추가
- 업데이트 확인을 GitHub `main` 브랜치 버전과 비교하도록 변경

## 0.3.0 - 2026-07-09

- 메뉴에 R 관련 CPU와 RAM 사용량 표시
- R 프로세스, active task, 병렬 worker, thread 수 표시
- 권한 없이 조회 가능한 시스템 전체 GPU 이용률 표시
- 메뉴가 열린 상태에서도 2초마다 리소스 정보 갱신

## 0.2.0 - 2026-07-09

- 앱 번들에 RStudio Addin 포함
- 첫 실행 및 메뉴에서 Addin 원클릭 설치·업데이트 지원
- GitHub Release용 DMG와 SHA-256 생성 스크립트 추가
- Developer ID 서명과 Apple 공증 옵션 추가
- 비공개 소스·공개 바이너리 배포 문서 추가

## 0.1.5 - 2026-07-09

- 메뉴에서 기본 `localhost:47821` 상세 행 제거
- 연결 오류 등 실제 상세 메시지가 있을 때만 상세 행 표시

## 0.1.4 - 2026-07-09

- 메뉴에 현재 버전 표시
- GitHub 최신 공개 Release 확인 버튼 추가
- 최신 버전, 업데이트 가능, 확인 실패 상태를 영어 팝업으로 안내

## 0.1.3 - 2026-07-09

- Addin 콜백이 종료된 뒤 Console 명령을 비동기로 전달하도록 변경
- 일부 RStudio 버전에서 Busy/Stop UI가 나타나지 않던 문제 수정

## 0.1.2 - 2026-07-09

- Addin 실행을 RStudio Console에 전달해 일반 실행과 동일한 Busy/Stop UI 제공
- 선택 코드와 현재 문서를 임시 파일로 안전하게 전달하고 실행 후 자동 정리

## 0.1.1 - 2026-07-09

- RStudio Stop으로 작업을 중단하면 `Interrupted` 상태와 알림 표시
- 20초 예제를 `Sys.sleep()` 대신 실제 행렬 연산으로 변경
- 메뉴가 열린 동안에도 실행 경과 시간 타이머가 계속 갱신되도록 수정

## 0.1.0 - 2026-07-09

- macOS 메뉴바 상태 앱 최초 공개
- Running, Complete, Fail 상태 및 실행 시간 표시
- 완료·실패 macOS 알림
- 선택 영역과 현재 문서 실행용 RStudio Addin
- `rstatus_run()` 및 `rstatus_notify()` 제공
- 통합 설치·제거 스크립트 추가
- 20초 동작 확인 예제와 Addin 단계별 사용 설명 추가
