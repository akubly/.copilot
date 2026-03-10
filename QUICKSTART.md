# Copilot CLI + Skills: Quickstart Guide

Get up and running with Copilot CLI and the Mobile Connectivity team's custom skills and instructions in ~5 minutes.

## What You're Getting

- **Instructions** — `.instructions.md` files that teach Copilot our codebase conventions: C++ coding standards, Razzle build system, Team Omega pointer prefixes, ADO access patterns, and more. These make Copilot write code that passes review.
- **Skills** — 30+ reusable engineering workflows: bug triage, test generation, branch validation, containment, VM management, PR creation, and more. These let Copilot orchestrate multi-step tasks autonomously.

## Step 1: Install Copilot CLI

Open PowerShell and run:

```powershell
iex "& { $(irm aka.ms/InstallTool.ps1)} agency"
```

More info: <https://aka.ms/agency>

## Step 2: Install Instructions

Instructions tell Copilot how to write code for our team. Clone and copy from the shared repo:

```powershell
# Clone the instructions repo (one-time)
git clone https://microsoft.visualstudio.com/OS/_git/os.copilot.prompts $env:TEMP\os.copilot.prompts

# Create the instructions directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.github\instructions"

# Copy instruction files
Copy-Item "$env:TEMP\os.copilot.prompts\instructions\*" "$env:USERPROFILE\.github\instructions\" -Recurse
```

**What's in there:**

| File | What it does |
|------|-------------|
| `global.instructions.md` | Razzle environment, build system, search strategy |
| `global-cli.instructions.md` | CLI-specific workflow (build commands, Search-Code) |
| `global-vscode.instructions.md` | VS Code-specific workflow |
| `windows.os2020.instructions.md` | C++ coding standards, WIL, SAL, containment, error handling |
| `windows.teamomega.instructions.md` | Team Omega exceptions: pointer prefixes, C++20, feature staging XML |
| `ado-access.instructions.md` | Azure DevOps: Search-Code, PRs, work items via PowerShell |
| `memory-mcp-agent-learning.instructions.md` | Persistent learning across sessions |

## Step 3: Install Skills

Skills are reusable engineering workflows. Get them from Aaron's PR:

```powershell
# Clone the skills repo (one-time)
git clone https://dev.azure.com/microsoft/OS.Developer/_git/akubly.copilot $env:TEMP\akubly.copilot

# Create the skills directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.copilot\skills"

# Copy skills
Copy-Item "$env:TEMP\akubly.copilot\skills\*" "$env:USERPROFILE\.copilot\skills\" -Recurse
```

**Highlights:**

| Skill | What it does |
|-------|-------------|
| `bug-triage` | Read an ADO bug and produce a structured triage summary |
| `root-cause-analysis` | Systematic 5-step debugging from symptom to root cause |
| `add-containment` | Add Velocity feature flag containment to code changes |
| `validate-topic-branch-on-vm` | End-to-end: build → provision VM → deploy → test |
| `find-tests-for-topic-branch-changes` | Find the right tests for your changes |
| `investigate-test-failure` | Parse WTL, trace source, classify regression vs pre-existing |
| `create-pull-request` | Create a PR with proper template and work item linking |

See `~/.copilot/skills/` for the full list (30+ skills across concepts, technologies, and workflows).

## Step 4: Try It

Open a Razzle window, then launch Copilot CLI:

```powershell
ghcp
```

### Suggested First Tasks

**Easy (< 1 minute):**
- `"Explain what this component does"` — in any source directory
- `"Summarize the changes on my current branch"`
- `"What tests cover these files?"` — for files you've changed

**Medium (5-10 minutes):**
- `"Triage bug #NNNNNN"` — give it a bug you've been assigned
- `"Generate unit tests for [function/class]"` — point it at code that needs coverage
- `"Review my branch changes and suggest improvements"`

**Advanced (let it run):**
- `"Validate my topic branch changes on a VM"` — full inner-loop automation
- `"Find and fix the root cause of [symptom]"` — systematic investigation
- `"Add containment for my changes using feature flag [name]"`

## Tips

- **Start small.** Ask it to explain code before asking it to change code.
- **Partial success is success.** If it gets 80% right, that's 80% you didn't type.
- **Review everything.** Copilot is a fast pair programmer, not an infallible oracle.
- **Let it fail.** When it gets something wrong, correct it — it learns from the conversation.
- **Use Plan mode.** Press `Shift+Tab` to switch to plan mode for complex multi-step tasks. Review the plan before saying "go."

## Getting Help

- Questions? Ask Aaron (akubly) or ping in the Mobile Connectivity Teams channel
- Found a bug in a skill? Fix it and submit a PR — these are just markdown files
- Want to create your own skill? Look at any existing skill file as a template
