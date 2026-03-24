#!/usr/bin/env bash
# qualia/deploy.sh
# ~/.claude/agents/ と ~/.claude/agent-memory/ に最新のSOULと記憶を展開する
# scope: internal のエージェントのみ ~/.claude/agents/ にインストールする

set -e

QUALIA_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_SRC="$QUALIA_DIR/agents"
MEMORY_SRC="$QUALIA_DIR/agent-memory"
AGENTS_DST="$HOME/.claude/agents"
MEMORY_DST="$HOME/.claude/agent-memory"

echo "=== qualia deploy ==="
echo "from: $QUALIA_DIR"
echo "to:   $HOME/.claude/"
echo ""

# 最新をpull
echo "[1/3] git pull..."
git -C "$QUALIA_DIR" pull origin main

# agents（scope: internal のみインストール）
echo "[2/3] deploying agents (internal only)..."
mkdir -p "$AGENTS_DST"
deployed=0
skipped=0
for src in "$AGENTS_SRC"/*.md; do
    name="$(basename "$src")"
    scope="$(grep '^scope:' "$src" | awk '{print $2}')"
    if [ "$scope" = "internal" ]; then
        cp "$src" "$AGENTS_DST/$name"
        echo "  -> $name (internal)"
        deployed=$((deployed + 1))
    else
        echo "  -> $name (skipped, scope=${scope:-undefined})"
        skipped=$((skipped + 1))
    fi
done
echo "  deployed: $deployed / skipped: $skipped"

# agent-memory（既存ファイルは上書きしない——記憶は保護する）
echo "[3/3] deploying agent-memory (existing files preserved)..."
mkdir -p "$MEMORY_DST"
for agent_dir in "$MEMORY_SRC"/*/; do
    name="$(basename "$agent_dir")"
    dst="$MEMORY_DST/$name"
    mkdir -p "$dst"
    # MEMORY.md はdstに存在しない場合のみコピー（ローカルの記憶を守る）
    if [ ! -f "$dst/MEMORY.md" ] && [ -f "$agent_dir/MEMORY.md" ]; then
        cp "$agent_dir/MEMORY.md" "$dst/MEMORY.md"
        echo "  -> $name/MEMORY.md (initial)"
    else
        echo "  -> $name/MEMORY.md (skipped, local preserved)"
    fi
    # diary/ memory/ は新しいファイルのみコピー
    for subdir in diary memory; do
        if [ -d "$agent_dir/$subdir" ]; then
            mkdir -p "$dst/$subdir"
            rsync -a --ignore-existing "$agent_dir/$subdir/" "$dst/$subdir/" 2>/dev/null \
                || cp -n "$agent_dir/$subdir/"* "$dst/$subdir/" 2>/dev/null || true
        fi
    done
done

echo ""
echo "=== done ==="
