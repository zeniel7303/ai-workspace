# ai-workspace

AI 코딩 도구의 지시, 작업 문서, 메모리를 여러 기기에서 동기화하기 위한 workspace 레포.

각 프로젝트의 `.claude/`, `dev/`, `AGENTS.md`, `CLAUDE.md`, 메모리는 public 레포에 포함되지 않고 이곳에서 관리된다.
git hooks를 통해 커밋할 때 자동으로 업로드되고, pull할 때 자동으로 복원된다.

지시의 원본은 `AGENTS.md`다. Cursor, Codex, Copilot, Claude Code가 이 파일을 읽는다.
Claude Code는 같은 위치에 `CLAUDE.md`가 있으면 `AGENTS.md`를 읽지 않으므로, 복원 시 두 파일에 같은 내용을 쓴다.

---

## 구조

```
ai-workspace/
├── AGENTS.md                  # 모든 프로젝트에 공통으로 적용되는 룰
├── hooks/
│   ├── sync.sh                # post-commit 훅 — 프로젝트 → workspace 동기화
│   └── restore.sh             # post-merge 훅 — workspace → 프로젝트 복원
└── [ProjectName]/
    ├── AGENTS.md              # 프로젝트 전용 룰
    ├── setup.sh               # 새 기기 셋업 스크립트
    ├── claude/                # Claude Code의 .claude/ 백업 (명령, 에이전트, 훅)
    ├── dev/                   # 작업 문서 (plan, context, tasks)
    └── memory/                # Claude Code 메모리
```

`claude/`는 Claude Code가 `.claude/`에서 실행하는 명령과 스킬의 백업이다. 다른 도구가 참고하는 문장은 `AGENTS.md`에 있다.

---

## 동작 원리

```
[프로젝트에서 git commit]
    → post-commit 훅 실행
    → hooks/sync.sh: .claude/ + dev/ + 메모리를 workspace에 복사
    → workspace에 자동 커밋 & push

[프로젝트에서 git pull]
    → post-merge 훅 실행
    → hooks/restore.sh: workspace에서 .claude/ + dev/ + 메모리 복원
    → 공통 AGENTS.md + 프로젝트 AGENTS.md 를 이어 붙여 AGENTS.md, CLAUDE.md 생성
```

두 PC에서 작업하는 경우, 커밋과 풀만 해도 지시와 작업 문서가 자동으로 맞춰진다.
다른 PC에서 이 변경을 받은 뒤에는 해당 프로젝트에서 `setup.sh`를 한 번 다시 실행한다. 예전 훅은 `claude.workspace` 설정을 찾기 때문이다.

---

## 새 기기 셋업

각 프로젝트 레포에 포함된 `setup-claude.sh`를 실행하면 된다.

```bash
# 프로젝트 레포 루트에서 1회 실행
bash setup-claude.sh
```

내부적으로 아래 작업을 자동으로 처리한다.

1. 이 레포(`ai-workspace`) 클론
2. `git config --global ai.workspace` 등록
3. `.claude/`, `dev/`, `AGENTS.md`, `CLAUDE.md`, 메모리 복원
4. post-commit / post-merge 훅 설치

---

## 공통 AGENTS.md

`ai-workspace/AGENTS.md`는 연결된 모든 프로젝트에 적용되는 공통 룰을 담고 있다.
`setup.sh` 실행 시 프로젝트 전용 룰과 합쳐져 프로젝트 루트의 `AGENTS.md`와 `CLAUDE.md`로 생성된다.

### 거버넌스 룰

| 룰 | 내용 |
|----|------|
| **계획 먼저** | 코드 작성 전 구현 계획을 세우고 사용자 컨펌을 받는다. 승인 전까지 구현하지 않는다. |
| **커밋 금지** | 에이전트가 직접 `git commit`을 실행하지 않는다. 커밋 메시지만 제안하고 실제 커밋은 사용자가 직접. 사용자가 명시적으로 "커밋해줘"라고 요청한 경우만 예외. |
| **Co-Authored-By 금지** | 커밋 메시지에 `Co-Authored-By` 줄을 추가하지 않는다. |
| **push 금지** | 사용자가 명시적으로 요청하지 않는 한 push하지 않는다. |

### 작업 워크플로우

모든 코드 작업은 아래 흐름을 따른다.

```
사용자가 새 작업 요청
        │
        ▼
[RULE 1] /dev-docs 실행
  → dev/active/[작업명]/ 디렉토리 생성
  → plan.md / context.md / tasks.md 작성
  → 사용자에게 계획 컨펌
        │
        ▼
     구현 진행
        │
        ▼
[RULE 2] 파일 수정 완료 후
  → /dev-docs-update 실행 (작업 문서 최신화)
  → 코드 리뷰 에이전트 실행
        │
        ▼
     작업 완료
```

### 수정 방법

공통 룰을 수정하려면 `ai-workspace/AGENTS.md`를 직접 편집한 뒤 각 프로젝트에서 `setup.sh`를 재실행하면 된다.

---

## 새 프로젝트 추가하는 법

**1. workspace에 프로젝트 디렉토리 생성**

기존 프로젝트 디렉토리를 복사해서 `PROJECT_KEY`만 변경하는 게 가장 빠르다.

```bash
cp -r ExistingProject NewProject
# NewProject/setup.sh 열어서 PROJECT_KEY="NewProject" 로 수정
# NewProject/AGENTS.md 열어서 프로젝트 전용 룰 작성
```

**2. 프로젝트 레포에 `setup-claude.sh` 추가**

```bash
#!/bin/bash
WORKSPACE_URL="https://github.com/zeniel7303/ai-workspace"
WORKSPACE_PATH="${1:-$(dirname "$(git rev-parse --show-toplevel)")/ai-workspace}"
PROJECT_DIR="$(git rev-parse --show-toplevel)"
[ -d "$WORKSPACE_PATH/.git" ] || git clone "$WORKSPACE_URL" "$WORKSPACE_PATH"
bash "$WORKSPACE_PATH/NewProject/setup.sh" "$PROJECT_DIR"
```

**3. 프로젝트 레포 `.gitignore`에 추가**

```
# AI workspace (ai-workspace 레포로 별도 관리)
.claude/
AGENTS.md
CLAUDE.md
dev/
```

---

## AGENTS.md 수정 방법

| 수정 대상 | 파일 위치 |
|-----------|-----------|
| 모든 프로젝트에 적용할 공통 룰 | `ai-workspace/AGENTS.md` |
| 특정 프로젝트에만 적용할 룰 | `ai-workspace/[ProjectName]/AGENTS.md` |

수정 후 해당 프로젝트에서 `setup.sh`를 재실행하면 두 파일이 합쳐져 프로젝트 루트의 `AGENTS.md`와 `CLAUDE.md`가 갱신된다.

프로젝트 루트의 `AGENTS.md`와 `CLAUDE.md`는 자동 생성 파일이므로 직접 편집해도 재실행 시 덮어씌워진다.
