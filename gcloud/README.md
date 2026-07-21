# gcloud / GA4 (읽기전용)

Claude Code 등에서 GA4 지표를 조회하기 위한 **읽기전용 서비스계정** 설정.

## 구성
- `.local/bin/ga-report` — GA4 조회 CLI (stow → `~/.local/bin/ga-report`)
- `bootstrap.sh` — 새 머신에서 SA 키 복원(1Password) + gcloud 활성화 (stow 대상 아님)

## 원칙 (중요)
- **비밀은 1Password, 설정만 이 repo.** SA 키(`~/.config/gcloud/ga-sa-key.json`)는 **절대 커밋 안 함**.
- 라이브 `~/.config/gcloud/` 는 `credentials.db`·키 등 비밀이 섞여 있어 **stow/추적하지 않음**.
- Claude Code 샌드박스: `~/.config/gcloud` 는 `denyRead`, `gcloud *` 는 `excludedCommands`
  (정본은 `claude/.claude/settings.json` base).

## 새 머신에서 재현
```sh
op signin           # 1Password CLI (앱 CLI 통합 필요)
./bootstrap.sh      # 키 복원 + SA 활성화 + 프로젝트 설정
ga-report           # 확인 (속성 목록)
```

## 자동화 불가 (최초 1회)
GA 콘솔 → 관리 → 속성 액세스 관리 →
`ethan-claude-ga-reader@seoul4pm-459908.iam.gserviceaccount.com` 를 속성 **뷰어**로 부여.

## 서비스계정
- 이메일: `ethan-claude-ga-reader@seoul4pm-459908.iam.gserviceaccount.com`
- 프로젝트: `seoul4pm-459908` · GCP 역할 없음 · GA 뷰어만 · 키 1Password 백업(`op document`)
