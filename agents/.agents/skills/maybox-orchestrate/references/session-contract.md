# 배정·상태·질문 계약

새 배정과 재개에 사용한다. 공유 scratch 아래 런별 `ledger.json`과 묶음별 디렉터리를 만든다. 현재 런의 경로를 brief에 넣고 과거 Maybox 원장 경로를 고정값으로 복사하지 않는다.

## 파일 소유

| 소유자 | 파일 | 내용 |
| --- | --- | --- |
| 조율자 | ledger.json, 묶음의 brief.md, decisions.json | 세션 등록·cursor·권한·모드·다음 행동·사용자 결정·리뷰·머지 차례 |
| 담당 세션 | status.json, questions.json, report.md, 증거 파일 | 현재 단계·실제 활동·질문·검증·PR·머지 결과 |
| 독립 리뷰어 | 지정 review.md | 고정 SHA와 검토 범위·실제 결함·검증 한계 |

각 JSON은 같은 디렉터리의 임시 파일에 완전히 쓴 뒤 rename으로 교체한다. 담당 세션끼리나 조율자와 담당 세션이 같은 JSON을 동시에 수정하지 않는다. 상태 메시지 전송 실패가 파일 보고를 막지 않게 한다.

## 위임 brief

다음 슬롯을 구체 값으로 채운다. 없는 승인을 만들지 않는다.

- **임무:** 포함 이슈·결과·완료 기준·시작 모드. 자율 실행이면 PR·머지까지, 함께 설계이면 초기 설계 목표와 같은 세션의 실행 전환 조건.
- **문맥:** 현재 전체 이슈·합의·이미 확인한 근거의 경로, 승인 출처, 남은 사용자 결정. 승인된 문서를 참조하고 모든 대화를 다시 붙이지 않는다.
- **소유:** 저장소·별도 worktree·branch·BASE SHA, 담당 범위, 공용 변경·자원·통합 순서. 다른 작업자가 있음을 명시하고 타인의 변경을 되돌리지 않도록 한다.
- **권한:** 현재 실제 확인 상태와 Full access 의도, PR/push/merge 승인 범위, 운영·공유 자원의 별도 승인. 권한 부족 시 구체 작업·실제 거부 결과를 보고한다.
- **질문:** 자율 실행 중 cross-task 질문은 questions.json으로 조율자에게, 함께 설계 중 제품 질문은 해당 세션에서 사용자에게. 기술 판단을 사용자에게 무조건 올리지 않는다.
- **산출물:** status/questions/report/증거의 절대 경로, 아래 보고 시점, 실제 검증 커밋·명령·종료값·로그. PR body와 attach, 자기 리뷰 및 조율자 독립 리뷰 이후 머지 차례까지 포함.
- **계속 실행:** 필요한 범위 내 조사·계획·구현은 스스로 이어간다. 멈출 때는 질문·외부 대기·진단할 장애와 다음 행동을 명시한다. 구현 완료 뒤 보고만 남기고 PR 준비를 빠뜨리지 않는다. 독립 리뷰·머지 차례는 조율자가 관리하며 중복 리뷰어를 만들지 않는다.

설계 합의에는 문제·이번 범위/후속·주요 결정과 이유·완료 검증·남은 사람 확인을 남긴다. 실제 사용자 승인 출처를 조율자가 decisions에 기록하고 담당에게 전달한다. 조율자 판단은 `coordinator`로 기록하며 사용자 답변을 꾸미지 않는다.

## 상태 갱신

시작 직후, 단계 전환, 질문·실패·커밋·PR 발생, 매 턴 종료 전에 갱신한다. 장기 명령을 기다리기 전 프로세스/세션 식별자와 로그를 남긴다. `updatedAt`은 파일 갱신 시각이고 `lastProgressAt`은 실제 작업 진전 시각이다. 단순 점검을 작업 진전으로 기록하지 않는다.

```json
{
  "task": "이슈 또는 묶음",
  "mode": "autonomous",
  "stage": "VERIFYING",
  "updatedAt": "UTC ISO 시각",
  "lastProgressAt": "UTC ISO 시각",
  "headSha": "실제 SHA",
  "nextAction": "실행할 구체 행동",
  "waitingFor": null,
  "activeCommand": {"sessionId": "실제 식별자", "logPath": "절대 경로"},
  "pr": {"url": "실제 URL", "headSha": "실제 SHA", "state": "DRAFT"},
  "verification": [{"headSha": "실제 SHA", "command": "실행 명령", "exitCode": 0, "logPath": "절대 경로"}],
  "reportPath": "절대 경로"
}
```

`mode`: autonomous / collaborative-design. 합의 후 autonomous로 바꾼다. `stage`: DISCOVERING / DESIGNING / WAITING_USER / IMPLEMENTING / VERIFYING / REVIEWING / CI_WAIT / WAITING_EXTERNAL / BLOCKED / MERGED / DONE. 각 waiting 상태에는 대상·질문 또는 외부 조건·허용된 독립 작업을 기록한다. 모르는 SHA/PR/명령은 null로 두며 완료 상태를 만드는 데 예시값을 사용하지 않는다.

`questions.json`에는 안정적인 질문 ID·대상(coordinator/user/external)·질문·선택지·추천과 근거·선택별 영향·질문 위치·답변 후 행동을 담는다. 같은 질문이 이미 사용자에게 표시돼 있으면 조율자는 해당 세션을 안내하고 재발행하지 않는다. 답변은 decisions의 실제 출처를 참조해 반영한다. 메시지 도구 유무와 무관하게 파일에 먼저 기록한다.

## 조율 원장

런의 사용자 승인·현재 모니터 ID와 묶음별 다음 필드를 조율자가 관리한다.

- 이슈·모드·목표·완료 기준·의존성·파일/자원 소유
- 실제 threadId/hostId/worktree/branch/BASE, pin 확인, 실제 권한 또는 미확인 이유
- 실제 세션 상태·최근 turn/cursor·담당 파일 경로·현재 SHA/PR
- 승인 결정 출처, 질문 위치·대기 대상, 다음 행동
- 재개 요청 ID·보낸 행동·응답 상태: 응답 전 같은 요청 재전송 방지
- 독립 reviewer·고정 SHA·보고서·지적 판단, CI 대상 SHA
- 저장소별 머지 차례: PR·허용 HEAD·담당 실행자·상태. HEAD 변경·새 미결 조건이면 철회
- 실제 merge 결과·Linear 저장/재조회·남은 범위

worker가 미완료 상태로 idle이면 최근 인간 지시부터 확인한다. 작업 가능한데 멈췄다면 승인 범위의 다음 구체 행동과 보고 경로를 전달해 기존 세션을 깨운다. 살아 있는 장기 명령이나 이미 보낸 재개 요청을 중복 실행하지 않는다. 같은 막힘이 되풀이되면 이유에 맞춰 문맥 보충·범위 축소·별도 진단을 선택하고 단순 재시도로 기다림을 연장하지 않는다.
