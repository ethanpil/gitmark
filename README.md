# GitMark

**GitMark** is a lightweight, pipe-friendly shell script designed to aggregate your Git repository into a single, formatted Markdown file. It creates a context-rich prompt perfect for pasting into Large Language Models (LLMs) like ChatGPT, Claude, or Gemini.

It respects your `.gitignore`, filters out "noise" (lockfiles, binaries), and includes a directory tree for structural context.

## ✨ Features

* **Git-Aware:** Automatically respects `.gitignore` rules (using `git ls-files`).
* **Smart Filtering:** Automatically excludes "noise" files like `package-lock.json`, `yarn.lock`, `go.sum`, and minified assets (`.min.js`).
* **Directory Tree:** Adds a visual map of your file structure at the top of the context file.
* **Binary Safety:** Checks mime-types to ensure only text files are added.
* **Token Saver:** Skips large files based on your configured threshold.

---

## ⚡ Quick Start (One-Liner)

Run GitMark directly from the web without downloading anything. This commands pipes the script into `sh` and runs it in your current repo's directory. GitMark does not operate outside of a Git repo.

```bash
curl -fsSL https://raw.githubusercontent.com/ethanpil/gitmark/refs/heads/main/gitmark.sh | sh

```

*This generates a file named `llm_context.md` in your current directory.*

---

## Configuration

You can customize GitMark's behavior by passing environment variables before the `sh` command.

| Variable | Default | Description |
| --- | --- | --- |
| **`OUTPUT_FILE`** | `llm_context.md` | The name of the generated markdown file. |
| **`MAX_FILESIZE_KB`** | `100` | Skip files larger than this size (in KB) to save context window. |
| **`ADD_LINE_NUMBERS`** | `true` | Adds line numbers to code blocks for easier referencing in chats. |

### Usage Examples

**1. Custom Output Filename**
Save the context to a specific file.

```bash
curl -fsSL https://raw.githubusercontent.com/ethanpil/gitmark/refs/heads/main/gitmark.sh | OUTPUT_FILE="backend_context.md" sh

```

**2. Disable Line Numbers**
If you prefer raw code without line numbering (saves tokens).

```bash
curl -fsSL https://raw.githubusercontent.com/ethanpil/gitmark/refs/heads/main/gitmark.sh | ADD_LINE_NUMBERS=false sh

```

**3. Increase File Size Limit**
Include larger files (e.g., up to 500KB).

```bash
curl -fsSL https://raw.githubusercontent.com/ethanpil/gitmark/refs/heads/main/gitmark.sh | MAX_FILESIZE_KB=500 sh

```

**4. Combine Multiple Options**
Customize everything at once.

```bash
curl -fsSL https://raw.githubusercontent.com/ethanpil/gitmark/refs/heads/main/gitmark.sh | OUTPUT_FILE="full_repo.md" MAX_FILESIZE_KB=200 ADD_LINE_NUMBERS=false sh

```

---

## Local Installation

For frequent use or if you want to modify the script defaults permanently, download it locally.

1. **Download the script:**
```bash
curl -fsSL https://raw.githubusercontent.com/ethanpil/gitmark/refs/heads/main/gitmark.sh -o gitmark.sh

```


2. **Make it executable:**
```bash
chmod +x gitmark.sh

```


3. **Run it:**
```bash
./gitmark.sh
# OR with options
OUTPUT_FILE="my_app.md" ./gitmark.sh

```

---

## ⚠️ A Note on Token Counts

At the end of execution, GitMark provides an **Estimated Token Count**.

> **Note:** This is a **very rough estimate** based on the rule of thumb that `4 characters ≈ 1 token`. Actual tokenization varies significantly between models (GPT-4, Claude 3, Gemini, etc.). Use this number as a general guide only, not an exact metric for billing or context limits.
