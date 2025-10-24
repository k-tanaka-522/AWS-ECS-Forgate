@echo off
REM ============================================
REM AI開発ファシリテーター - 新規プロジェクト初期化スクリプト (Windows)
REM ============================================

echo ========================================
echo AI Development Facilitator
echo New Project Initialization
echo ========================================
echo.

REM 確認プロンプト
echo This script will:
echo   1. Delete .git directory (remove git history)
echo   2. Clear docs/ directory (keep .gitkeep)
echo   3. Reset .claude-state/project-state.json to initial state
echo   4. Initialize new git repository
echo   5. Create initial commit
echo.
set /p CONFIRM="Are you sure you want to initialize a new project? (yes/no): "

if /i not "%CONFIRM%"=="yes" (
    echo Initialization cancelled.
    exit /b 1
)

echo.
echo Starting initialization...
echo.

REM 1. .git ディレクトリを削除
echo [1/5] Removing .git directory...
if exist ".git" (
    rmdir /s /q ".git"
    echo   - .git directory removed
) else (
    echo   - .git directory not found (skipped)
)

REM 2. docs/ の中身を削除（.gitkeep は残す）
echo [2/5] Clearing docs/ directory...
if exist "docs" (
    for /d %%D in (docs\*) do rmdir /s /q "%%D"
    for %%F in (docs\*) do (
        if not "%%~nxF"==".gitkeep" del /q "%%F"
    )
    echo   - docs/ cleared (kept .gitkeep)
) else (
    mkdir docs
    type nul > docs\.gitkeep
    echo   - docs/ created with .gitkeep
)

REM 3. .claude-state/project-state.json を初期状態にリセット
echo [3/5] Resetting project state...
if not exist ".claude-state" mkdir ".claude-state"

(
echo {
echo   "project": {
echo     "name": null,
echo     "type": null,
echo     "phase": "planning",
echo     "created_at": null,
echo     "updated_at": null
echo   },
echo   "phases": {
echo     "planning": {
echo       "status": "pending",
echo       "started_at": null,
echo       "completed_at": null,
echo       "document": null
echo     },
echo     "requirements": {
echo       "status": "pending",
echo       "started_at": null,
echo       "completed_at": null,
echo       "document": null
echo     },
echo     "design": {
echo       "status": "pending",
echo       "started_at": null,
echo       "completed_at": null,
echo       "document": null
echo     },
echo     "implementation": {
echo       "status": "pending",
echo       "started_at": null,
echo       "completed_at": null,
echo       "document": null
echo     },
echo     "testing": {
echo       "status": "pending",
echo       "started_at": null,
echo       "completed_at": null,
echo       "document": null
echo     },
echo     "deployment": {
echo       "status": "pending",
echo       "started_at": null,
echo       "completed_at": null,
echo       "document": null
echo     }
echo   },
echo   "requirements": {
echo     "business_background": {},
echo     "tech_stack": {},
echo     "functional_requirements": [],
echo     "non_functional_requirements": {},
echo     "constraints": {}
echo   },
echo   "design": {
echo     "architecture": null,
echo     "tech_stack": {},
echo     "infrastructure": {},
echo     "cicd_strategy": {}
echo   },
echo   "implementation": {
echo     "directory_structure": null,
echo     "coding_standards_applied": false
echo   },
echo   "metadata": {
echo     "version": "1.0.0",
echo     "last_command": null
echo   }
echo }
) > .claude-state\project-state.json

if not exist ".claude-state\tasks.json" (
    echo {"tasks": [], "issues": []} > .claude-state\tasks.json
)

if not exist ".claude-state\decisions.json" (
    echo {"decisions": []} > .claude-state\decisions.json
)

echo   - Project state reset to initial state

REM 4. git init で新規リポジトリ化
echo [4/5] Initializing new git repository...
git init
echo   - New git repository initialized

REM 5. 初回コミットを作成
echo [5/5] Creating initial commit...
git add .
git commit -m "Initial commit: New project initialized with AI Development Facilitator" -m "🤖 Generated with [Claude Code](https://claude.com/claude-code)" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
echo   - Initial commit created

echo.
echo ========================================
echo Initialization Complete!
echo ========================================
echo.
echo Your new project is ready to start.
echo.
echo Next steps:
echo   1. Open Claude Code
echo   2. Tell Claude what you want to build
echo   3. Start the facilitated development process!
echo.
echo Note: You can now connect to your own remote repository:
echo   git remote add origin YOUR_REPOSITORY_URL
echo   git push -u origin main
echo.
