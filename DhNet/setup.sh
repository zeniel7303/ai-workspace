#!/bin/bash
# DhNet/setup.sh — 새 PC에서 1회 실행
# .claude/, AGENTS.md, CLAUDE.md 복원 + git hooks 설치

PROJECT_KEY="DhNet"
WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${1:-$(pwd)}"

if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "❌ git repo를 찾을 수 없음: $PROJECT_DIR"
    echo "   사용법: bash setup.sh /path/to/DhNet"
    exit 1
fi

derive_memory_key() {
    local path="$1"
    path="${path#/}"
    path="${path/:/}"
    local first_upper
    first_upper=$(echo "${path:0:1}" | tr 'a-z' 'A-Z')
    path="${first_upper}${path:1}"
    path="${path/\//"--"}"
    path="${path//\//-}"
    path="${path//_/-}"
    echo "$path"
}

MEMORY_KEY=$(derive_memory_key "$PROJECT_DIR")
USERPROFILE_UNIX=$(echo "$USERPROFILE" | sed 's|\\|/|g')
MEMORY_PATH="$USERPROFILE_UNIX/.claude/projects/$MEMORY_KEY/memory"

# workspace 경로 등록
git config --global --unset-all claude.workspace 2>/dev/null || true
git config --global ai.workspace "$WORKSPACE"
git -C "$PROJECT_DIR" config --unset-all claude.projectKey 2>/dev/null || true
git -C "$PROJECT_DIR" config --unset-all claude.memoryPath 2>/dev/null || true
git -C "$PROJECT_DIR" config ai.projectKey "$PROJECT_KEY"
git -C "$PROJECT_DIR" config ai.memoryPath "$MEMORY_PATH"

# .claude/, dev, 메모리 복원
rm -rf "$PROJECT_DIR/.claude"
cp -r "$WORKSPACE/$PROJECT_KEY/claude" "$PROJECT_DIR/.claude"
[ -d "$WORKSPACE/$PROJECT_KEY/dev" ] && { rm -rf "$PROJECT_DIR/dev"; cp -r "$WORKSPACE/$PROJECT_KEY/dev" "$PROJECT_DIR/dev"; }
[ -d "$WORKSPACE/$PROJECT_KEY/memory" ] && { mkdir -p "$MEMORY_PATH"; cp -r "$WORKSPACE/$PROJECT_KEY/memory/." "$MEMORY_PATH/"; }

# AGENTS.md가 원본. Claude Code는 CLAUDE.md가 있으면 AGENTS.md를 읽지 않으므로 같은 내용을 두 파일로 쓴다.
{
  [ -f "$WORKSPACE/AGENTS.md" ] && cat "$WORKSPACE/AGENTS.md" && echo ""
  [ -f "$WORKSPACE/$PROJECT_KEY/AGENTS.md" ] && cat "$WORKSPACE/$PROJECT_KEY/AGENTS.md"
} > "$PROJECT_DIR/AGENTS.md"
cp "$PROJECT_DIR/AGENTS.md" "$PROJECT_DIR/CLAUDE.md"

# git hooks 설치
cat > "$PROJECT_DIR/.git/hooks/post-commit" << EOF
#!/bin/bash
bash "\$(git config --global ai.workspace)/hooks/sync.sh"
EOF
cat > "$PROJECT_DIR/.git/hooks/post-merge" << EOF
#!/bin/bash
bash "\$(git config --global ai.workspace)/hooks/restore.sh"
EOF
chmod +x "$PROJECT_DIR/.git/hooks/post-commit" "$PROJECT_DIR/.git/hooks/post-merge"

echo "✓ $PROJECT_KEY 설정 완료"
echo "  Memory key : $MEMORY_KEY"
echo "  Memory path: $MEMORY_PATH"
