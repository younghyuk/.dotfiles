# 연결과 탐색 범위

## 공통 좌표

- Linear workspace: Maycoders, team: Maybox, key: `MBX`. 팀·상태·labels·사용자 ID는 현재 도구에서 조회한다.
- GitHub: `maycoders-dev/seoul4pm`. 기본 브랜치는 원격에서 확인한다.
- Maybox 구현: `services/maybox/**`, `packages/api-contract/maybox-api-contract/**`, `packages/api-contract/maybox-public-contract/**`.
- Seoul4PM 연동: `services/seoul4pm/**`. 창고 요청이 소비 측 기능이면 책임과 관련 티켓을 연결한다.
- 도메인·현재 운영: `services/maybox/docs/README.md`, `docs/domain/**`, `docs/runbooks/**`, Android Work README. 역사 기록은 `docs/history/**`에서 확인한다. 과거 plan을 현재 설계로 승계하지 않는다.

## Slack 공개 채널

| 채널 | 채널 ID | 읽을 내용 |
| --- | --- | --- |
| warehouse | C0BPT2S7UCC | 제품·운영 합의, 일정 |
| warehouse-enhancement | C0C2BGGSU85 | 현장 기능 요청·문제 |
| warehouse-comm | C0BV0T3GS7K | 실제 입출고 사례·후속 처리 |
| warehouse-deployment | C0C3LUMCNPJ | 배포 공지·버전 |
| warehouse-noti | C0C3CJ01GH2 | 필요한 사례의 시스템 알림 |

채널 이름·ID·접근 권한은 현재 검색 결과와 대조한다. 전역 `maybox` 검색은 알림 봇에 묻힐 수 있어 채널·기간으로 좁힌다. 채널 읽기는 루트만 반환할 수 있으므로 관련 thread를 별도로 읽는다. 개인정보·사진·상업 자료는 이슈 판단에 필요한 최소 내용만 옮긴다.

## 런타임별 연결

- Codex: 설치된 Linear·Slack·GitHub 커넥터 도구를 검색한다. 별도 사용자 MCP를 중복 등록하지 않는다.
- Claude Code: 활성 Linear·Slack 공식 플러그인의 MCP 도구와 기존 GitHub MCP 또는 `gh`를 사용한다. 처음 인증이 필요하면 Claude의 `/mcp`에서 사용자가 공식 OAuth를 완료한다.
- 스킬 공유는 연결 자격 증명의 공유가 아니다. 토큰·쿠키를 다른 런타임에서 가져오거나 스킬·dotfiles에 저장하지 않는다. 새 머신은 기존 dotfiles 동기화 후 해당 머신에서 로그인한다.
- 커넥터 결과는 런타임마다 다르다. 실제 text/structured payload와 pagination을 확인하고 성공 메시지만 파싱하지 않는다. API 스키마는 현재 도구 설명을 기준으로 한다.

## GitHub 조회 예시

```bash
gh pr list --repo maycoders-dev/seoul4pm --state all --search 'maybox in:title' --limit 100 --json number,title,state,mergedAt,url,body
gh issue list --repo maycoders-dev/seoul4pm --state open --search maybox --limit 100 --json number,title,body,url
gh repo view maycoders-dev/seoul4pm --json defaultBranchRef
```

조회 limit에 도달하면 기간 분할 또는 API pagination으로 나머지를 읽는다. 제목 검색에 잡히지 않는 Seoul4PM 연동 PR은 번호·기능 용어로 추가 조회한다. 멀티라인 GitHub 본문은 파일에 작성해 `--body-file`로 전달한다.
