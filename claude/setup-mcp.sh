#!/usr/bin/env bash
# 새 머신 셋업 시 한 번 실행: bash ~/.dotfiles/claude/setup-mcp.sh

set -e

echo "MCP 서버 등록 중..."

claude mcp add github -s user \
  -e 'GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_MCP_PAT}' \
  -- npx -y @modelcontextprotocol/server-github

claude mcp add context7 -s user \
  -- npx -y @upstash/context7-mcp

claude mcp add playwright -s user \
  -- npx @playwright/mcp@latest

echo "완료. 등록된 MCP 서버:"
claude mcp list
