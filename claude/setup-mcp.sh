#!/usr/bin/env bash
# 새 머신 셋업 시 한 번 실행: bash ~/.dotfiles/claude/setup-mcp.sh

set -e

echo "MCP 서버 등록 중..."

# github MCP은 공식 GitHub MCP 서버(api.githubcopilot.com/mcp)를 HTTP로 직접 등록한다.
# 토큰은 zsh의 GITHUB_MCP_PAT 를 헤더에서 그대로 읽는다(리터럴 저장 → claude 실행 시 확장).
# (구 npx @modelcontextprotocol/server-github 는 deprecated 라 제거, 동명 플러그인도 비활성.)
claude mcp add github -s user --transport http https://api.githubcopilot.com/mcp/ \
  --header 'Authorization: Bearer ${GITHUB_MCP_PAT}'

claude mcp add context7 -s user \
  -- npx -y @upstash/context7-mcp

claude mcp add playwright -s user \
  -- npx @playwright/mcp@latest

echo "완료. 등록된 MCP 서버:"
claude mcp list
