function pushTag() {
	git tag $1
	git push origin $1
}

function based() {
	echo -n $1 | base64 -d;
}

function base() {
	echo -n $1 | base64;
}

touchi() {
  touch $1 && idea -e $1;
}

function i() {
    idea -e $1;
}

function mkcd() {
  mkdir $1 && cd $1;
}

function listPhones() {
    if echo $1 | grep -q "i"
    then
        echo "Apple: "
        xcrun xctrace list devices
    fi
    
    if echo $1 | grep -q "a"
    then
        echo "Android: "
        adb devices
    fi
}

function syncClaudeAgents() {
    local renamedCount=0
    local linkedCount=0
    local skippedCount=0
    local claudeFile
    local agentsFile
    local claudeLink
    local linkTarget

    while IFS= read -r -d '' claudeFile; do
        agentsFile="${claudeFile:h}/AGENTS.md"

        if [[ -e "$agentsFile" ]]; then
            echo "Skip rename (AGENTS.md already exists): ${claudeFile:h}"
            ((skippedCount++))
            continue
        fi

        mv "$claudeFile" "$agentsFile"
        ((renamedCount++))
    done < <(find . \( -type f -o -type l \) -name "CLAUDE.md" -print0)

    while IFS= read -r -d '' agentsFile; do
        claudeLink="${agentsFile:h}/CLAUDE.md"

        if [[ -L "$claudeLink" ]]; then
            linkTarget=$(readlink "$claudeLink")
            if [[ "$linkTarget" != "AGENTS.md" ]]; then
                ln -sfn "AGENTS.md" "$claudeLink"
                ((linkedCount++))
            fi
            continue
        fi

        if [[ -e "$claudeLink" ]]; then
            echo "Skip symlink (CLAUDE.md exists and is not a symlink): ${agentsFile:h}"
            ((skippedCount++))
            continue
        fi

        ln -s "AGENTS.md" "$claudeLink"
        ((linkedCount++))
    done < <(find . \( -type f -o -type l \) -name "AGENTS.md" -print0)

    echo "Renamed: $renamedCount, symlinks created/updated: $linkedCount, skipped: $skippedCount"
}

# Beads auto-work loop for Claude Code
# Add this to your ~/.zshrc or source it directly
#
# Usage:
#   bd-loop              # run until all tasks done (max 20 iterations)
#   bd-loop 10           # run max 10 iterations
#   bd-loop 5 "focus on auth tasks only"  # custom instruction
#
# To stop: bd-loop-kill (from another terminal)

BD_LOOP_STOP_FILE="/tmp/bd-loop.stop"

bd-loop-kill() {
  touch "$BD_LOOP_STOP_FILE"
  echo "☠️  Stop signal sent — loop will exit after current claude finishes"
}

bd-loop() {
  local max_iterations="${1:-20}"
  local custom_instruction="${2:-}"
  local i=0
  local ready_count

  # Clean up any leftover stop file
  rm -f "$BD_LOOP_STOP_FILE"

  # Check we're in a beads project
  if ! bd ready --json &>/dev/null; then
    echo "❌ Not a beads project. Run 'bd init' first."
    return 1
  fi

  ready_count=$(bd ready --json 2>/dev/null | jq 'length')
  echo "🔗 Beads loop — $ready_count tasks ready, max $max_iterations iterations"
  echo "💡 To stop: run 'bd-loop-kill' from another terminal"
  echo ""

  while [ "$ready_count" -gt 0 ] && [ "$i" -lt "$max_iterations" ] && [ ! -f "$BD_LOOP_STOP_FILE" ]; do
    i=$((i + 1))
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 Iteration $i/$max_iterations — $ready_count tasks remaining"
    bd ready 2>/dev/null
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local prompt="Check bd ready, pick the highest priority item, implement it fully, run tests, then land the plane (close the issue, bd sync, git commit and push)."
    if [ -n "$custom_instruction" ]; then
      prompt="$prompt Additional instruction: $custom_instruction"
    fi

    claude -p --output-format stream-json "$prompt" 2>&1 | jq --unbuffered -rj '
      if .type == "content_block_delta" then (.delta.text // empty)
      elif .type == "assistant" then (.message.content[]? | select(.type=="text") | .text // empty)
      else empty
      end
    ' 2>/dev/null

    echo ""
    echo "✓ Iteration $i done"
    echo ""

    ready_count=$(bd ready --json 2>/dev/null | jq 'length')
  done

  # Clean up
  local was_killed=0
  if [ -f "$BD_LOOP_STOP_FILE" ]; then
    was_killed=1
  fi
  rm -f "$BD_LOOP_STOP_FILE"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ "$was_killed" -eq 1 ]; then
    echo "⛔ Stopped by bd-loop-kill after $i iterations"
  elif [ "$ready_count" -eq 0 ]; then
    echo "✅ All tasks complete after $i iterations!"
  else
    echo "⏸️  Stopped after $i iterations — $ready_count tasks remaining"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bd stats 2>/dev/null
}