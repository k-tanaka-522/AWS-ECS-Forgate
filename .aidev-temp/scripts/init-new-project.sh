#!/bin/bash

# ============================================
# AI開発ファシリテーター - 新規プロジェクト初期化スクリプト (Mac/Linux)
# ============================================

set -e

echo "========================================"
echo "AI Development Facilitator"
echo "New Project Initialization"
echo "========================================"
echo ""

# 確認プロンプト
echo "This script will:"
echo "  1. Delete .git directory (remove git history)"
echo "  2. Clear docs/ directory (keep .gitkeep)"
echo "  3. Reset .claude-state/project-state.json to initial state"
echo "  4. Initialize new git repository"
echo "  5. Create initial commit"
echo ""
read -p "Are you sure you want to initialize a new project? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Initialization cancelled."
    exit 1
fi

echo ""
echo "Starting initialization..."
echo ""

# 1. .git ディレクトリを削除
echo "[1/5] Removing .git directory..."
if [ -d ".git" ]; then
    rm -rf .git
    echo "  - .git directory removed"
else
    echo "  - .git directory not found (skipped)"
fi

# 2. docs/ の中身を削除（.gitkeep は残す）
echo "[2/5] Clearing docs/ directory..."
if [ -d "docs" ]; then
    find docs -mindepth 1 ! -name '.gitkeep' -delete
    echo "  - docs/ cleared (kept .gitkeep)"
else
    mkdir -p docs
    touch docs/.gitkeep
    echo "  - docs/ created with .gitkeep"
fi

# 3. .claude-state/project-state.json を初期状態にリセット
echo "[3/5] Resetting project state..."
mkdir -p .claude-state

cat > .claude-state/project-state.json <<'EOF'
{
  "project": {
    "name": null,
    "type": null,
    "phase": "planning",
    "created_at": null,
    "updated_at": null
  },
  "phases": {
    "planning": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "requirements": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "design": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "implementation": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "testing": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "deployment": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    }
  },
  "requirements": {
    "business_background": {},
    "tech_stack": {},
    "functional_requirements": [],
    "non_functional_requirements": {},
    "constraints": {}
  },
  "design": {
    "architecture": null,
    "tech_stack": {},
    "infrastructure": {},
    "cicd_strategy": {}
  },
  "implementation": {
    "directory_structure": null,
    "coding_standards_applied": false
  },
  "metadata": {
    "version": "1.0.0",
    "last_command": null
  }
}
EOF

if [ ! -f ".claude-state/tasks.json" ]; then
    echo '{"tasks": [], "issues": []}' > .claude-state/tasks.json
fi

if [ ! -f ".claude-state/decisions.json" ]; then
    echo '{"decisions": []}' > .claude-state/decisions.json
fi

echo "  - Project state reset to initial state"

# 4. git init で新規リポジトリ化
echo "[4/5] Initializing new git repository..."
git init
echo "  - New git repository initialized"

# 5. 初回コミットを作成
echo "[5/5] Creating initial commit..."
git add .
git commit -m "$(cat <<'COMMIT_EOF'
Initial commit: New project initialized with AI Development Facilitator

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
COMMIT_EOF
)"
echo "  - Initial commit created"

echo ""
echo "========================================"
echo "Initialization Complete!"
echo "========================================"
echo ""
echo "Your new project is ready to start."
echo ""
echo "Next steps:"
echo "  1. Open Claude Code"
echo "  2. Tell Claude what you want to build"
echo "  3. Start the facilitated development process!"
echo ""
echo "Note: You can now connect to your own remote repository:"
echo "  git remote add origin YOUR_REPOSITORY_URL"
echo "  git push -u origin main"
echo ""
