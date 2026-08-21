---
name: managing-ssh-keys
description: "Use when SSH 키를 발급·등록·조회하거나, 서버 SSH 접속을 세팅하거나, ~/.ssh/config·1Password agent.toml을 수정하거나, 접속 실패(Too many authentication failures, Permission denied (publickey), Host key verification failed)를 진단할 때, 또는 sshs 접속 목록에 호스트를 추가할 때."
---

# SSH 키 관리 (1Password 정본 + .pub 핀)

## Overview

개인키의 정본은 1Password다. 로컬 디스크에는 공개키(.pub)만 두고, 서명은 1P SSH 에이전트가 한다. 설정(config·.pub·agent.toml)은 dotfiles가 정본이며 stow로 모든 PC에 배포된다.

```
1Password(개인키 정본) → agent.toml(서빙 볼트) → ~/.ssh/config(.pub 핀) → dotfiles(배포)
```

## 키가 필요할 때: 먼저 있는 키인지 확인

1. `op item list --categories "SSH Key"` — 정본 목록. 볼트: 개인=`Personal`, 회사=`Maycoders`.
2. **같은 키가 다른 이름으로 존재할 수 있다** — 후보 키와 지문 대조: `ssh-keygen -lf <파일|pub>` ↔ `SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ssh-add -l`. (실례: preview_key = inc.pem 동일 키)
3. EC2 박스는 키를 추측하지 말고 실측: `aws ec2 describe-instances --query '...KeyName'`. 현재 매핑: 서울 리전 전부=`inc`, 해외 seoul4pm=`seoul4pm`(1P `4pm.pem`), mayk=`mayk`.

## 새 키 발급 레시피

1. **1P에 먼저 등록** — 항목 타입 반드시 `SSH Key`(노트/문서는 에이전트가 서빙 못 함), 제목 `SSH Key - <이름>`, 볼트는 개인/회사 구분해 Personal/Maycoders. 생성은 1P GUI 권장(op CLI는 SSH Key 편집 미지원; `op item create --category ssh`는 되지만 실패 시 GUI로).
2. 해당 볼트가 `~/.config/1Password/ssh/agent.toml`의 `[[ssh-keys]]`에 포함돼 있는지 확인(현재 Personal·Maycoders 서빙 중). 추가했으면 1P 앱 재시작.
3. **사용자에게 로컬 연동 여부를 질문**한다. 원하면 아래 "호스트 연동 레시피" 수행.
4. AWS EC2용 새 키페어라면: **1P에서 생성하고 공개키만 AWS에 등록**한다 — `aws ec2 import-key-pair --key-name <이름> --public-key-material fileb://<이름>.pub`. 개인키가 AWS를 경유하지 않아 정본=1P가 유지된다(콘솔에서 .pem 다운로드 방식은 쓰지 않는다).

## 호스트 연동 레시피 (config + dotfiles + sshs)

1. 작업 전 `ls -ld ~/.ssh` — 실디렉터리여야 정상. 심링크(폴딩)라면 dotfiles 쪽 파일이 곧 라이브다: 사본으로 취급해 지우면 안 되고, `stow --restow --no-folding ssh`로 먼저 언폴딩.
2. 공개키를 dotfiles에: `op item get "SSH Key - <이름>" --fields "public key" > ~/.dotfiles/ssh/.ssh/<이름>.pub`
3. `~/.dotfiles/ssh/.ssh/config`에 이름 있는 Host 블록 추가 — **named Host 블록이 곧 sshs 접속 목록 항목**이다(HostName·User 명시, 와일드카드는 목록에 안 뜸):

```ssh-config
Host <별칭>
  HostName <주소>
  User <유저>
  IdentityFile ~/.ssh/<이름>.pub
```

전역 블록은 이미 있고 손대지 않는다(모든 호스트가 상속):

```ssh-config
Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  IdentitiesOnly yes
```

4. `stow --dir="$HOME/.dotfiles" --target="$HOME" --restow --no-folding ssh`
5. dotfiles 커밋·푸시. **git 추적은 config와 *.pub만** — 개인키는 어떤 형태로도 커밋 금지(`.gitignore`: `ssh/.ssh/*` + `!config` + `!*.pub`가 강제).
6. 검증: `ssh -G <별칭> | grep -E "identityfile|identitiesonly"` → 핀한 .pub 하나만 나와야 한다.

## 트러블슈팅

| 증상 | 원인/처방 |
|---|---|
| Too many authentication failures | 그 호스트에 `IdentityFile` 핀이 없어 에이전트 키 전부를 순서대로 내밀다 서버 상한(6) 초과 → Host 블록에 .pub 핀 추가 |
| Permission denied (publickey) | 에이전트가 그 키를 안 내밈 → `ssh-add -l`(위 SOCK 지정)로 서빙 확인; 없으면 agent.toml 볼트 누락 또는 1P 항목이 SSH Key 타입이 아님 |
| Host key verification failed | known_hosts에 호스트키 없음(비대화 컨텍스트) → 공식 지문 대조 후 `ssh-keyscan` 등록 |
| config에 없는 호스트 일회 접속 | 전역 IdentitiesOnly 때문에 키를 안 내밈 → `ssh -o IdentitiesOnly=no user@host` |
| DNS로 접속했는데 connection refused | 그 도메인이 ALB 등 다른 리소스를 가리킬 수 있음 → EC2 실 IP를 describe-instances로 확인 |

## Common Mistakes

- 새 키부터 만들기 — 기존 키 확인(1P 목록+지문 대조)이 항상 먼저다.
- 개인키 파일을 로컬/레포에 복사 — .pub만 둔다. 도구가 파일 경로를 요구하는 예외(예: preview CLI의 `~/.ssh/preview_key`)만 해당 도구의 설치 명령으로.
- 호스트 블록마다 IdentityAgent/IdentitiesOnly 반복 — 전역 `Host *` 상속으로 충분.
- plain `stow ssh` — 폴딩으로 디렉터리째 심링크된다. 항상 `--no-folding`.
