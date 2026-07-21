#!/usr/bin/env bash
# gcloud + GA4 읽기전용 서비스계정 부트스트랩 (새 머신 재현).
#
# 원칙: 비밀(SA 키)은 1Password 에 있고 여기선 "복원"만 한다. repo 에 키를 두지 않는다.
# 자동화 불가 1회 작업: GA 콘솔에서 SA 를 속성 '뷰어'로 부여(아래 안내).
set -euo pipefail

SA_EMAIL="ethan-claude-ga-reader@seoul4pm-459908.iam.gserviceaccount.com"
PROJECT="seoul4pm-459908"
KEY_PATH="$HOME/.config/gcloud/ga-sa-key.json"
OP_DOC="GCP SA key · ethan-claude-ga-reader · seoul4pm-459908"

need() { command -v "$1" >/dev/null 2>&1 || { echo "필요: $2"; exit 1; }; }
need gcloud "brew install --cask google-cloud-sdk"
need op     "brew install 1password-cli (+ 앱에서 CLI 통합 켜기)"

mkdir -p "$HOME/.config/gcloud"

if [[ -f "$KEY_PATH" ]]; then
  echo "SA 키 이미 있음: $KEY_PATH"
else
  echo "1Password 에서 SA 키 복원…"
  op document get "$OP_DOC" --output "$KEY_PATH"
  chmod 600 "$KEY_PATH"
fi

echo "SA 활성화…"
gcloud auth activate-service-account --key-file="$KEY_PATH"
gcloud config set project "$PROJECT" >/dev/null
echo

cat <<EOF
✅ 완료. 조회:
     ga-report            (속성 목록)
     ga-report <id> 30    (해당 속성 30일 지표)

ℹ️  activate 는 활성 계정을 SA 로 바꾼다. 본인 계정으로 gcloud 를 쓰려면 되돌리기:
     gcloud config set account <you>@example.com
   (ga-report 는 --account 로 SA 를 명시 사용하므로 활성 계정과 무관하게 동작)

⚠️  최초 1회(자동화 불가): GA 콘솔 → 관리 → 속성 액세스 관리 →
     $SA_EMAIL 를 '뷰어'로 추가. (누락 시 ga-report 가 '속성 없음')
EOF
