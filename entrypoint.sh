#!/bin/bash
# entrypoint.sh — Builder Workspace startup script
# Clones a git repo (if configured), installs dependencies, starts code-server.
#
# Environment variables (all optional — set per-builder in Qovery):
#   GIT_REPO_URL    — HTTPS URL of the repo to clone (e.g., https://github.com/org/project.git)
#   GIT_TOKEN       — Personal access token for git auth (secret). Auto-detects provider.
#   GITHUB_TOKEN    — Fallback token if GIT_TOKEN is not set (GitHub only)
#   GIT_BRANCH      — Branch to checkout (default: main)
#   GIT_USER_NAME   — Git author name for commits
#   GIT_USER_EMAIL  — Git author email for commits
set -e

PROJECT_DIR="/home/coder/project"

# ── Clear stale workspace state to prevent webview deserialization crashes ────
rm -rf /home/coder/.local/share/code-server/User/workspaceStorage/*/state.vscdb 2>/dev/null

# ── Detect git provider from URL and return the correct credential username ──
detect_git_username() {
  local url="$1"
  case "$url" in
    *github.com*)    echo "x-access-token" ;;
    *gitlab.com*|*gitlab.*)  echo "oauth2" ;;
    *bitbucket.org*) echo "x-token-auth" ;;
    *)               echo "x-access-token" ;;
  esac
}

# ── Configure git credentials ───────────────────────────────────────────────
TOKEN="${GIT_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -n "$TOKEN" ]]; then
  GIT_USERNAME=$(detect_git_username "${GIT_REPO_URL:-}")
  git config --global credential.helper \
    '!f() { echo "username='"$GIT_USERNAME"'"; echo "password='"$TOKEN"'"; }; f'
fi

# Git user identity (for commits)
if [[ -n "${GIT_USER_NAME:-}" ]]; then
  git config --global user.name "$GIT_USER_NAME"
fi
if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
  git config --global user.email "$GIT_USER_EMAIL"
fi

# ── Clone or pull project from GIT_REPO_URL ─────────────────────────────────
if [[ -n "${GIT_REPO_URL:-}" ]]; then
  BRANCH="${GIT_BRANCH:-main}"

  if [[ ! -d "$PROJECT_DIR/.git" ]]; then
    # First start — clone the repo
    echo "Cloning $GIT_REPO_URL (branch: $BRANCH)..."
    if git clone --branch "$BRANCH" --single-branch "$GIT_REPO_URL" "$PROJECT_DIR" 2>&1; then
      echo "Clone successful."
    else
      echo "WARNING: Git clone failed. Starting with empty project directory."
    fi
  else
    # Container restart — pull latest changes
    echo "Project already cloned. Pulling latest from $BRANCH..."
    cd "$PROJECT_DIR" && git pull origin "$BRANCH" 2>&1 || echo "WARNING: Git pull failed (non-critical)."
  fi

  # Auto-install dependencies
  if [[ -f "$PROJECT_DIR/package.json" && ! -d "$PROJECT_DIR/node_modules" ]]; then
    echo "Installing Node.js dependencies..."
    cd "$PROJECT_DIR" && npm install 2>&1 || echo "WARNING: npm install failed (non-critical)."
  fi

  if [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
    echo "Installing Python dependencies..."
    cd "$PROJECT_DIR" && pip install --user -r requirements.txt 2>&1 || echo "WARNING: pip install failed (non-critical)."
  fi
fi

# ── Generate WELCOME.md for new builders ─────────────────────────────────────
generate_welcome_md() {
  if [[ ! -f "$PROJECT_DIR/WELCOME.md" ]]; then
    cat > "$PROJECT_DIR/WELCOME.md" << 'WELCOME'
# Welcome to Your Builder Workspace

This is your personal space to build apps, websites, and tools. You don't need
any technical skills — an AI assistant called **Claude** will do the building for
you. You just describe what you want in plain English.

Your Platform Engineering team set this workspace up for you. Everything here is
safe: you can experiment, try things out, and even break stuff. Nothing bad will
happen. If anything goes wrong, you can always start over or ask your Platform
Engineering team for help. That's what this environment is designed for.


---


## What you'll see on screen

When your workspace loads, you'll see two main areas:

- **The left panel (Claude)** — This is your AI assistant. You talk to Claude
  here by typing messages, just like a chat app.
- **The center area** — This is where you're reading right now. When Claude
  builds something for you, a live preview of your app will also appear here.

That's it. You don't need to touch anything else.


---


## Getting started — your first app in 2 minutes

Let's build something right now to see how it works.

**Step 1.** Click on the **Claude panel** on the left side of the screen. You'll
see a text box where you can type a message.

**Step 2.** Type something like this and press Enter:

> Build me a landing page for a coffee shop called Brew & Bean. Include a hero
> section with a big photo, a menu section with drinks and prices, and a contact
> section with the address and opening hours. Make it look modern and warm.

**Step 3.** Watch Claude work. It will start creating your app automatically.
You don't need to do anything — just wait a moment.

**Step 4.** A **preview window** will appear showing your app. This is what your
website looks like! You can scroll around, click things, and see it in action.


---


## More things you can ask Claude to build

Here are some ideas to get you inspired. Just copy-paste any of these into the
Claude panel, or come up with your own:

**A team directory**
> Create a team directory page where I can see employee cards with their photo,
> name, job title, and a short bio. Make it look clean and professional.

**A feedback form**
> Build a customer feedback form with a star rating (1 to 5), a text area for
> comments, and a submit button. When someone submits, show a "Thank you"
> message.

**A dashboard with charts**
> Make a sales dashboard that shows monthly revenue as a bar chart, the number
> of new customers as a line chart, and a summary section with total sales and
> average order value. Use sample data.

**A simple blog**
> Build a blog where I can see a list of articles with titles and dates. When I
> click on one, it shows the full article. Pre-fill it with 3 sample posts.

**An event registration page**
> Create a page for a company workshop. Include the event name, date, location,
> a description, and a registration form that asks for name and email.

You can ask for literally anything — Claude will figure out how to build it.


---


## How to make changes

Once Claude has built something for you, you can keep improving it. Just tell
Claude what you want to change. For example:

- "Make the background dark blue instead of white"
- "Add a logo at the top — use a placeholder image for now"
- "The text is too small, make it bigger"
- "Add a new page for testimonials"
- "I don't like the layout — make it more like [describe what you want]"

The key is to **be specific**. Instead of "make it look better", try "make the
header bigger, change the font to something more modern, and add more spacing
between sections."

You can go back and forth with Claude as many times as you want. Each time, it
will update your app and you'll see the changes in the preview.


---


## How to see your app

Your app shows up automatically in a **preview panel** inside this workspace.
This preview is only visible to you — nobody else can see it yet.

If the preview doesn't appear, or if it looks stuck, just tell Claude:

> "The preview isn't showing, can you restart the app?"

Claude will fix it for you.


---


## Sharing your app with others (putting it online)

Right now your app lives only in this workspace. To let other people see it —
your team, your boss, your customers — you need to **put it online**. This gives
your app a real web address (like `https://my-app.example.com`) that anyone can
visit from their browser.

To do this, just tell Claude:

> "I'm happy with this — can you put it online so I can share it with my team?"

or

> "Deploy my app so other people can see it"

Claude knows how to do this. It will set everything up, and after a minute or
two, it will give you a link. You can send that link to anyone and they'll see
your app.


---


## It's safe to experiment

This is worth repeating: **you cannot break anything important here.** This
workspace is your personal sandbox.

- If your app looks wrong — tell Claude to fix it.
- If everything seems broken — tell Claude "start over" or "undo the last change."
- If you're stuck — tell Claude "I'm stuck, can you help?"
- If nothing works — close the browser tab and reopen the workspace. Everything
  will reset to a working state.
- If all else fails — ask your Platform Engineering team. They can reset your
  workspace in seconds.

The whole point of this workspace is for you to experiment and try things. There
is no wrong way to use it.


---


## Tips for getting great results

- **Be specific.** "Add a contact form with name, email, phone number, and a
  message box" works much better than "add a form."
- **One thing at a time.** Ask for one feature or change per message. This helps
  Claude get it right on the first try.
- **Describe what you see, not what you think is wrong technically.** Say "the
  text is overlapping the image" or "the button isn't doing anything when I
  click it" — Claude will figure out the technical fix.
- **Paste errors.** If you see a red error message or something that looks like
  an error, copy it and paste it to Claude. It will know what to do.
- **Ask Claude to explain anything.** If you're curious about how something
  works, just ask. Claude is happy to explain things in simple terms.
- **Save your progress.** When you have something you like, tell Claude: "put
  this online" so it's saved and accessible from a real web address.


---


## If Claude asks you to log in

If you see a message about logging in or an "API key":

- In most cases, your Platform Engineering team has already set this up for you,
  and you don't need to do anything.
- If Claude asks you to log in, click the link it shows and sign in with your
  account.
- If something doesn't work, contact your Platform Engineering team — they can
  fix it quickly.


---


You're all set. Click on the Claude panel, tell it what you want to build, and
enjoy watching your ideas come to life.
WELCOME
    echo "Generated WELCOME.md"
  fi
}

generate_welcome_md

# ── Generate CLAUDE.md for Claude Code (sidebar + terminal) ──────────────────
generate_claude_md() {
  if [[ ! -f "$PROJECT_DIR/CLAUDE.md" ]]; then
    if [[ -f /opt/builder-skill/CLAUDE.md ]]; then
      cp /opt/builder-skill/CLAUDE.md "$PROJECT_DIR/CLAUDE.md"
      echo "Generated CLAUDE.md (Claude Code instructions)"
    fi
  fi
}

generate_claude_md

# ── Generate OpenCode skill for builder workspace ────────────────────────────
generate_opencode_skill() {
  local skill_dir="$PROJECT_DIR/.opencode/skills/builder-workspace"
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    if [[ -f /opt/builder-skill/SKILL.md ]]; then
      mkdir -p "$skill_dir"
      cp /opt/builder-skill/SKILL.md "$skill_dir/SKILL.md"
      echo "Generated OpenCode builder-workspace skill"
    fi
  fi
}

generate_opencode_skill

# ── Auto-generate .vscode/tasks.json for dev server auto-start ───────────────
generate_tasks_json() {
  local run_cmd=""

  if [[ -f "$PROJECT_DIR/package.json" ]]; then
    # Detect the best run command from package.json scripts
    if jq -e '.scripts.dev' "$PROJECT_DIR/package.json" >/dev/null 2>&1; then
      run_cmd="npm run dev"
    elif jq -e '.scripts.start' "$PROJECT_DIR/package.json" >/dev/null 2>&1; then
      run_cmd="npm start"
    elif jq -e '.scripts.serve' "$PROJECT_DIR/package.json" >/dev/null 2>&1; then
      run_cmd="npm run serve"
    elif jq -e '.scripts.preview' "$PROJECT_DIR/package.json" >/dev/null 2>&1; then
      run_cmd="npm run preview"
    fi
  elif [[ -f "$PROJECT_DIR/requirements.txt" ]] || [[ -f "$PROJECT_DIR/manage.py" ]]; then
    if [[ -f "$PROJECT_DIR/manage.py" ]]; then
      run_cmd="python3 manage.py runserver 0.0.0.0:3100"
    fi
  fi

  # Only generate tasks.json if we detected a run command and none exists yet
  if [[ -n "$run_cmd" && ! -f "$PROJECT_DIR/.vscode/tasks.json" ]]; then
    mkdir -p "$PROJECT_DIR/.vscode"
    cat > "$PROJECT_DIR/.vscode/tasks.json" << TASKS
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start Dev Server",
      "type": "shell",
      "command": "${run_cmd}",
      "runOptions": { "runOn": "folderOpen" },
      "isBackground": true,
      "presentation": {
        "reveal": "silent",
        "panel": "dedicated",
        "showReuseMessage": false
      },
      "problemMatcher": []
    }
  ]
}
TASKS
    echo "Auto-configured dev server task: ${run_cmd}"
  fi
}

generate_tasks_json

# ── Start code-server ────────────────────────────────────────────────────────
echo "Starting Builder Workspace..."
exec code-server --host 0.0.0.0 --port 8080 "$PROJECT_DIR"
