# Connector routing

사용자 스킬이 외부 정보를 요청할 때 적용할 기본 라우팅이다. 이 문서는 연결 정책만 동기화하며 인증 토큰이나
credential은 포함하지 않는다.

| 대상 | 우선 연결 | 비고 |
| --- | --- | --- |
| Slack | Codex Slack Plugin | 채널 조회·요약·메시지 작성 |
| GitHub | Codex GitHub Plugin과 `gh` | 조회는 Plugin, 로컬 Git 작업과 보완 작업은 `gh` |
| Linear | Codex Linear Plugin | 별도 사용자 MCP를 중복 등록하지 않음 |
| Notion | Codex Notion Plugin | 지식 수집·회의·리서치·구현 계획 |
| PostHog | Codex PostHog Plugin | 분석·플래그·실험·에러 조회 |
| Sentry | Codex Sentry Plugin | 리포가 직접 Sentry MCP를 선언하면 프로젝트 작업에는 그 MCP도 사용 |
| Context7 | Codex connector app | 현재 세션에 없으면 공식 문서를 직접 조회 |
| Klaviyo | Codex connector app | Plugin 범위를 넘는 쓰기 작업은 리포 MCP 유무를 확인 |

BigQuery, Google Analytics, 로컬 DB처럼 프로젝트·credential에 묶인 연결은 사용자 전역에서 추정하지 않고 현재
리포의 MCP 설정을 따른다.

연결 가능 여부는 PC와 세션마다 다를 수 있다. 새 PC에서는 dotfiles 동기화 후 Codex·Claude 로그인, connector
OAuth, Google ADC를 각 PC에서 다시 완료하고 실제 노출된 도구를 확인한다.
