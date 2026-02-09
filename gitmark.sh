#!/bin/bash

# Configuration
OUTPUT_FILE="llm_context.md"
MAX_FILESIZE_KB=100 # Exclude files larger than this many KB
ADD_LINE_NUMBERS=true # Set to false if you want code without line numbers

# --- PIPE-AWARENESS LOGIC ---
if [[ -f "$0" ]]; then
    SCRIPT_NAME="$(basename "$0")"
    EXCLUDE_PATTERN="^($SCRIPT_NAME|$OUTPUT_FILE)$"
else
    EXCLUDE_PATTERN="^($OUTPUT_FILE)$"
fi

# --- SMART IGNORE (NOISE FILES) ---
# Exclude lockfiles and minified code which burn tokens uselessly
NOISE_FILES="package-lock.json|yarn.lock|pnpm-lock.yaml|go.sum|cargo.lock|\.min\.js|\.min\.css|\.svg"
EXCLUDE_PATTERN="$EXCLUDE_PATTERN|($NOISE_FILES)"

# Safety check
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Error: Not a git repository."
    exit 1
fi

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
    git ls-files --cached --others --exclude-standard | \
    grep -vE "$EXCLUDE_PATTERN" | \
    tree --fromfile . >> "$OUTPUT_FILE"
else
    echo "." >> "$OUTPUT_FILE"
    git ls-files --cached --others --exclude-standard | \
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

git ls-files --cached --others --exclude-standard | while read -r file; do
    if [[ "$file" =~ $EXCLUDE_PATTERN ]]; then continue; fi

    if [[ -f "$file" ]]; then
        FILE_SIZE=$(wc -c < "$file")
        if [[ "$FILE_SIZE" -gt "$MAX_BYTES" ]]; then
            echo "⚠️ Skipping large file: $file ($((FILE_SIZE / 1024))KB)"
            continue
        fi

        if file -b --mime-type "$file" | grep -q "text"; then
            echo "✅ Adding: $file"
            ext="${file##*.}"
            if [[ "$file" == "$ext" ]]; then ext="text"; fi

            echo "## File: \`$file\`" >> "$OUTPUT_FILE"
            echo "<file path=\"$file\">" >> "$OUTPUT_FILE"
            echo '```'"$ext" >> "$OUTPUT_FILE"
            
            # Feature: Optional Line Numbers
            if [ "$ADD_LINE_NUMBERS" = true ]; then
                cat -n "$file" >> "$OUTPUT_FILE"
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
