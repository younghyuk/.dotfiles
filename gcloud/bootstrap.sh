#!/usr/bin/env bash
# Keyless Google CLI/ADC bootstrap for a new machine.
#
# Result:
#   application_default_credentials.json -> ethan@maycoders.com authorized_user
#   adc-ga-reader.json                    -> Ethan -> ga-reader impersonation
#   adc-bq-reader.json                    -> Ethan -> bq-reader impersonation

set -euo pipefail

USER_ACCOUNT="${GCLOUD_USER_ACCOUNT:-ethan@maycoders.com}"
PROJECT_ID="${GCLOUD_PROJECT_ID:-seoul4pm-459908}"
GA_SERVICE_ACCOUNT="${GA_SERVICE_ACCOUNT:-ga-reader@seoul4pm-459908.iam.gserviceaccount.com}"
BQ_SERVICE_ACCOUNT="${BQ_SERVICE_ACCOUNT:-bq-reader@seoul4pm-459908.iam.gserviceaccount.com}"
GCLOUD_CREDENTIAL_DIR="$HOME/.config/gcloud"
DEFAULT_ADC="$GCLOUD_CREDENTIAL_DIR/application_default_credentials.json"
GA_ADC="$GCLOUD_CREDENTIAL_DIR/adc-ga-reader.json"
BQ_ADC="$GCLOUD_CREDENTIAL_DIR/adc-bq-reader.json"
MODE="${1:-}"

case "$MODE" in
  '' | --force | --check) ;;
  *)
    printf 'usage: %s [--check|--force]\n' "$0" >&2
    exit 2
    ;;
esac

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '필요: %s\n' "$2" >&2
    exit 1
  }
}

file_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

check_adc() {
  local label="$1"
  local path="$2"
  local expected_type="$3"
  local expected_target="${4:-}"

  if [[ ! -f "$path" ]]; then
    printf 'FAIL %-12s missing: %s\n' "$label" "$path"
    return 1
  fi
  if [[ "$(file_mode "$path")" != "600" ]]; then
    printf 'FAIL %-12s mode must be 600: %s\n' "$label" "$path"
    return 1
  fi
  if ! jq -e --arg type "$expected_type" '.type == $type' "$path" >/dev/null; then
    printf 'FAIL %-12s unexpected credential type\n' "$label"
    return 1
  fi
  if [[ -n "$expected_target" ]] && ! jq -e --arg target "$expected_target" \
    '.service_account_impersonation_url | contains("serviceAccounts/" + $target + ":generateAccessToken")' \
    "$path" >/dev/null; then
    printf 'FAIL %-12s unexpected impersonation target\n' "$label"
    return 1
  fi

  printf 'PASS %-12s %s\n' "$label" "$path"
}

check_all() {
  local status=0
  local active_account
  active_account="$(gcloud config get-value account 2>/dev/null || true)"
  if [[ "$active_account" == "$USER_ACCOUNT" ]]; then
    printf 'PASS %-12s %s\n' 'gcloud user' "$USER_ACCOUNT"
  else
    printf 'FAIL %-12s expected %s, got %s\n' 'gcloud user' "$USER_ACCOUNT" "${active_account:-<unset>}"
    status=1
  fi

  check_adc 'default ADC' "$DEFAULT_ADC" authorized_user || status=1
  check_adc 'GA ADC' "$GA_ADC" impersonated_service_account "$GA_SERVICE_ACCOUNT" || status=1
  check_adc 'BQ ADC' "$BQ_ADC" impersonated_service_account "$BQ_SERVICE_ACCOUNT" || status=1
  return "$status"
}

need gcloud 'brew install --cask gcloud-cli'
need jq 'brew install jq'
need install 'macOS install command'
mkdir -p "$GCLOUD_CREDENTIAL_DIR"

if [[ "$MODE" == "--check" ]]; then
  check_all
  exit $?
fi

if [[ "$MODE" != "--force" ]] && check_all; then
  printf '\n이미 올바른 keyless Google 인증 구조입니다.\n'
  exit 0
fi

if ! gcloud auth print-access-token --account="$USER_ACCOUNT" >/dev/null 2>&1; then
  printf '\nGoogle CLI 사용자 로그인: %s\n' "$USER_ACCOUNT"
  gcloud auth login "$USER_ACCOUNT" --brief
fi
gcloud config set account "$USER_ACCOUNT" >/dev/null
gcloud config set project "$PROJECT_ID" >/dev/null

TEMP_ADC_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gcloud-adc-bootstrap.XXXXXX")"
DEFAULT_BACKUP="$TEMP_ADC_DIR/default.before-bootstrap.json"
GA_CANDIDATE="$TEMP_ADC_DIR/adc-ga-reader.json"
BQ_CANDIDATE="$TEMP_ADC_DIR/adc-bq-reader.json"
HAD_DEFAULT=false
COMPLETED=false

if [[ -f "$DEFAULT_ADC" ]]; then
  install -m 600 "$DEFAULT_ADC" "$DEFAULT_BACKUP"
  HAD_DEFAULT=true
fi

cleanup() {
  if [[ "$COMPLETED" != true ]]; then
    if [[ "$HAD_DEFAULT" == true && -f "$DEFAULT_BACKUP" ]]; then
      install -m 600 "$DEFAULT_BACKUP" "$DEFAULT_ADC"
      printf '\n기존 기본 ADC를 복원했습니다: %s\n' "$DEFAULT_ADC" >&2
    elif [[ "$HAD_DEFAULT" == false && -f "$DEFAULT_ADC" ]]; then
      rm -f "$DEFAULT_ADC"
    fi
  fi

  rm -f "$DEFAULT_BACKUP" "$GA_CANDIDATE" "$BQ_CANDIDATE"
  rmdir "$TEMP_ADC_DIR" 2>/dev/null || true
}
trap cleanup EXIT

printf '\n1/3 GA reader impersonated ADC 생성\n'
gcloud auth application-default login "$USER_ACCOUNT" \
  --impersonate-service-account="$GA_SERVICE_ACCOUNT" \
  --scopes=openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/analytics.readonly \
  --project="$PROJECT_ID" \
  --quiet
check_adc 'GA candidate' "$DEFAULT_ADC" impersonated_service_account "$GA_SERVICE_ACCOUNT"
install -m 600 "$DEFAULT_ADC" "$GA_CANDIDATE"

printf '\n2/3 BigQuery reader impersonated ADC 생성\n'
gcloud auth application-default login "$USER_ACCOUNT" \
  --impersonate-service-account="$BQ_SERVICE_ACCOUNT" \
  --project="$PROJECT_ID" \
  --quiet
check_adc 'BQ candidate' "$DEFAULT_ADC" impersonated_service_account "$BQ_SERVICE_ACCOUNT"
install -m 600 "$DEFAULT_ADC" "$BQ_CANDIDATE"

printf '\n3/3 Ethan 사용자 기본 ADC 생성\n'
gcloud auth application-default login "$USER_ACCOUNT" \
  --project="$PROJECT_ID" \
  --quiet
check_adc 'default ADC' "$DEFAULT_ADC" authorized_user

install -m 600 "$GA_CANDIDATE" "$GA_ADC"
install -m 600 "$BQ_CANDIDATE" "$BQ_ADC"
COMPLETED=true

printf '\n최종 상태\n'
check_all
printf '\n완료: 영구 서비스계정 키 없이 Ethan 사용자 인증으로 reader SA를 위임합니다.\n'
