#!/bin/bash
# restore.sh — post-merge hook에서 호출
# workspace의 도구 설정과 지시 파일을 프로젝트로 복원

WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_KEY=$(git config --local ai.projectKey 2>/dev/null) || PROJECT_KEY=$(git config --local claude.projectKey 2>/dev/null)
MEMORY_PATH=$(git config --local ai.memoryPath 2>/dev/null) || MEMORY_PATH=$(git config --local claude.memoryPath 2>/dev/null)

[ -z "$PROJECT_KEY" ] || [ -z "$MEMORY_PATH" ] && exit 0

REPO_ROOT=$(git rev-parse --show-toplevel)
SOURCE="$WORKSPACE/$PROJECT_KEY"

cd "$WORKSPACE" && git pull --quiet

restore_dir() {
    local src="$1" dst="$2"
    [ -d "$src" ] || return 0
    rm -rf "$dst"
    cp -r "$src" "$dst"
}

restore_dir "$SOURCE/claude"  "$REPO_ROOT/.claude"
restore_dir "$SOURCE/dev"     "$REPO_ROOT/dev"
restore_dir "$SOURCE/memory"  "$MEMORY_PATH"

{
  [ -f "$WORKSPACE/AGENTS.md" ] && cat "$WORKSPACE/AGENTS.md" && echo ""
  [ -f "$SOURCE/AGENTS.md" ]    && cat "$SOURCE/AGENTS.md"
} > "$REPO_ROOT/AGENTS.md"
cp "$REPO_ROOT/AGENTS.md" "$REPO_ROOT/CLAUDE.md"

[ -f "$SOURCE/settings.local.json" ]   && cp "$SOURCE/settings.local.json"   "$REPO_ROOT/.claude/settings.local.json"
