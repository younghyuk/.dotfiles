# Google Cloud / GA4 / BigQuery (keyless)

로컬 Google 도구와 MCP는 `ethan@maycoders.com` 사용자 로그인을 출발점으로 삼고,
GA와 BigQuery는 최소 권한 reader 서비스계정을 impersonate한다. 영구 서비스계정 키는
사용하지 않으며 1Password나 Git으로 credential JSON을 복사하지 않는다.

## 최종 credential 구조

| 경로 | 유형 | 유효 권한 |
| --- | --- | --- |
| `~/.config/gcloud/application_default_credentials.json` | `authorized_user` | `ethan@maycoders.com` |
| `~/.config/gcloud/adc-ga-reader.json` | `impersonated_service_account` | Ethan → `ga-reader@seoul4pm-459908.iam.gserviceaccount.com` |
| `~/.config/gcloud/adc-bq-reader.json` | `impersonated_service_account` | Ethan → `bq-reader@seoul4pm-459908.iam.gserviceaccount.com` |

`gcloud` CLI 활성 계정도 `ethan@maycoders.com`, 기본 프로젝트는
`seoul4pm-459908`로 유지한다. 프로젝트의 Claude/Codex MCP 설정은 GA와 BQ named ADC를
각각 명시하므로 일반 기본 ADC와 권한이 섞이지 않는다.

## 구성

- `bootstrap.sh` — 브라우저 사용자 로그인과 두 reader ADC를 안전한 순서로 생성한다.
- `.local/bin/ga-report` — `ga-reader`를 keyless impersonate해 GA4를 조회한다
  (stow → `~/.local/bin/ga-report`).
- 루트 `sync.sh` — credential 구조를 검사하고, 누락 시 대화형 터미널에서 bootstrap 실행 여부를 묻는다.

## 새 머신에서 재현

루트 동기화를 먼저 실행한다. `Brewfile`이 gcloud, MCP Toolbox, uv를 설치한다.

```bash
cd ~/.dotfiles
./sync.sh
```

Google 인증이 준비되지 않았으면 prompt에서 bootstrap을 실행하거나 직접 실행한다.

```bash
gcloud/bootstrap.sh
```

상태 확인만 할 때:

```bash
gcloud/bootstrap.sh --check
```

세 credential을 모두 새로 발급해야 할 때만:

```bash
gcloud/bootstrap.sh --force
```

bootstrap은 중간 실패 시 기존 기본 ADC를 복원하고, 모든 생성 단계가 성공한 뒤에만
두 named ADC를 교체한다. 각 credential 파일은 mode `0600`으로 저장한다.

## 확인

```bash
gcloud auth list
gcloud/bootstrap.sh --check
ga-report
```

repo에서 Claude/Codex를 새로 시작한 뒤 BigQuery `list_dataset_ids`와 Analytics
`get_account_summaries`가 성공하면 MCP까지 정상이다. Claude의 프로젝트 `.mcp.json`은
머신별 최초 1회 승인이 필요할 수 있다.

## IAM 전제

- Ethan 사용자는 두 reader SA에 `roles/iam.serviceAccountTokenCreator`가 있어야 한다.
- `bq-reader`는 `roles/bigquery.dataViewer`와 `roles/bigquery.jobUser`를 가진다.
- `ga-reader`는 GA 속성 Viewer이며 quota project 사용을 위해
  `roles/serviceusage.serviceUsageConsumer`를 가진다.
- 서비스계정 사용자 관리 키는 만들지 않는다.

## 보안 원칙

- `~/.config/gcloud/`는 refresh token, SQLite credential DB 등을 포함하므로 stow/Git 대상이 아니다.
- `application_default_credentials.json`, `adc-*.json`, `*-key.json`을 dotfiles에 복사하지 않는다.
- Codex/Claude 로그인 토큰과 connector OAuth도 파일 동기화하지 않는다. 각 PC에서 로그인한다.
- Claude Code 샌드박스에서 `~/.config/gcloud`는 `denyRead`, `gcloud *`는
  `excludedCommands`로 유지한다(정본: `claude/.claude/settings.json`).
