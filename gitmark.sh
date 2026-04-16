#!/bin/sh

# Configuration (Defaults can be overridden by Environment Variables)
# Usage: OUTPUT_FILE="my_context.md" ADD_LINE_NUMBERS=false curl ... | sh
OUTPUT_FILE="${OUTPUT_FILE:-llm_context.md}"
MAX_FILESIZE_KB="${MAX_FILESIZE_KB:-100}"
ADD_LINE_NUMBERS="${ADD_LINE_NUMBERS:-true}"
EXCLUDE="${EXCLUDE:-}"

# --- PIPE-AWARENESS LOGIC ---
# If the script is run locally, exclude itself. If piped, $0 is usually 'sh'.
if [ -f "$0" ]; then
    SCRIPT_NAME="$(basename "$0")"
    EXCLUDE_PATTERN="^($SCRIPT_NAME|$OUTPUT_FILE)$"
else
    EXCLUDE_PATTERN="^($OUTPUT_FILE)$"
fi

# --- SMART IGNORE (NOISE FILES) ---
# Exclude lockfiles and minified code
NOISE_FILES="package-lock.json|yarn.lock|pnpm-lock.yaml|go.sum|cargo.lock|.min.js|.min.css|.svg"
NOISE_REGEX=$(echo "$NOISE_FILES" | sed 's/\./\\./g')
EXCLUDE_PATTERN="$EXCLUDE_PATTERN|($NOISE_REGEX)"

# --- USER-SUPPLIED EXCLUSIONS ---
if [ -n "$EXCLUDE" ]; then
    # Strip surrounding quotes, carriage returns (\r from Windows CMD), and trailing commas
    EXCLUDE=$(printf '%s' "$EXCLUDE" | tr -d '\r' | tr -d '"'"'" | sed 's/,*$//')
    EXCLUDE_REGEX=$(echo "$EXCLUDE" | tr ',' '|' | sed 's/\./\\./g')
    EXCLUDE_PATTERN="$EXCLUDE_PATTERN|($EXCLUDE_REGEX)"
fi

# Detect if we are in a git repo
IS_GIT_REPO=true
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    IS_GIT_REPO=false
    echo "⚠️ Not a git repository. Running without .gitignore rules."
fi

# Helper: Pure-shell recursive file lister (no external dependencies)
_list_files_recursive() {
    for item in "$1"/* "$1"/.*; do
        # Skip non-existent globs and the . / .. entries
        [ -e "$item" ] || continue
        case "$(basename "$item")" in .|..) continue ;; esac

        if [ -d "$item" ]; then
            case "$item" in
                ./.git|./.git/*) continue ;;
            esac
            _list_files_recursive "$item"
        elif [ -f "$item" ]; then
            echo "$item" | sed 's|^\./||'
        fi
    done
}

# Helper: List project files respecting gitignore (git) or using find/shell walk (non-git)
list_files() {
    if [ "$IS_GIT_REPO" = true ]; then
        git ls-files --cached --others --exclude-standard
    elif command -v find >/dev/null 2>&1; then
        find . -not -path './.git/*' -not -path './.git' -type f | sed 's|^\./||'
    else
        _list_files_recursive "."
    fi
}

echo "🚀 Starting export to $OUTPUT_FILE..."

# Initialize file
echo "# Project Context for LLM" > "$OUTPUT_FILE"
echo "Generated on: $(date)" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# --- DIRECTORY TREE ---
echo "## Directory Structure" >> "$OUTPUT_FILE"
echo '```text' >> "$OUTPUT_FILE"

if command -v tree >/dev/null 2>&1; then
    list_files | \
    grep -vE "$EXCLUDE_PATTERN" | \
    tree --fromfile . >> "$OUTPUT_FILE"
else
    echo "." >> "$OUTPUT_FILE"
    list_files | \
    grep -vE "$EXCLUDE_PATTERN" | \
    while read -r file; do
        echo "├── $file" >> "$OUTPUT_FILE"
    done
fi
echo '```' >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"

# --- FILE AGGREGATION ---
MAX_BYTES=$((MAX_FILESIZE_KB * 1024))

list_files | while read -r file; do
    # Check exclusion pattern
    if echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then continue; fi

    if [ -f "$file" ]; then
        # Check file size
        FILE_SIZE=$(wc -c < "$file")
        if [ "$FILE_SIZE" -gt "$MAX_BYTES" ]; then
            echo "⚠️ Skipping large file: $file ($((FILE_SIZE / 1024))KB)"
            continue
        fi

        # Check if text file using 'file' command
        if file -b --mime-type "$file" | grep -q "text"; then
            echo "✅ Adding: $file"
            
            # Extract extension for code block
            ext="${file##*.}"
            # If no extension, default to text
            if [ "$ext" = "$file" ]; then ext="text"; fi

            echo "## File: \`$file\`" >> "$OUTPUT_FILE"
            echo "<file path=\"$file\">" >> "$OUTPUT_FILE"
            echo '```'"$ext" >> "$OUTPUT_FILE"
            
            # Feature: Optional Line Numbers
            if [ "$ADD_LINE_NUMBERS" = "true" ]; then
                # nl -ba numbers all lines (POSIX equivalent to cat -n)
                nl -ba "$file" >> "$OUTPUT_FILE"
            else
                cat "$file" >> "$OUTPUT_FILE"
            fi
            
            echo '```' >> "$OUTPUT_FILE"
            echo "</file>" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "---" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    fi
done

# --- TOKEN ESTIMATION ---
CHAR_COUNT=$(wc -c < "$OUTPUT_FILE")
EST_TOKENS=$((CHAR_COUNT / 4))

echo ""
echo "✅ Done! Output saved to $OUTPUT_FILE"
echo "📊 Estimated Token Count: ~${EST_TOKENS} tokens (VERY ROUGH ESTIMATE!)"
