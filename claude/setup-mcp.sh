#!/usr/bin/env bash
# 새 머신 셋업 시 한 번 실행: bash ~/.dotfiles/claude/setup-mcp.sh

set -e

echo "MCP 서버 등록 중..."

claude mcp add mysql_seoul4pm_local -s user \
  -e MYSQL_HOST=127.0.0.1 \
  -e MYSQL_PORT=3306 \
  -e MYSQL_USER=root \
  -e MYSQL_PASS='4pm!234' \
  -e MYSQL_DB=seoul4pm \
  -- npx -y @benborla29/mcp-server-mysql

echo "완료. 등록된 MCP 서버:"
claude mcp list
