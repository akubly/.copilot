# .copilot

Personal [Copilot CLI](https://githubnext.com/projects/copilot-cli/) configuration that turns a general-purpose AI assistant into an opinionated engineering partner. It enforces structured reasoning, multi-persona review, and cross-session learning — so the AI doesn't just generate code, it *thinks* before it ships.

## What's in this repo

```
.copilot/
├── instructions/          # Behavioral rules and coding standards
│   └── *.instructions.md  # Global and language-specific guidelines
├── agents/                # Custom agent definitions
│   └── *.agent.md         # Specialized agents (code-reviewer, investigator, etc.)
├── knowledge/
│   ├── concepts/          # Domain judgment — bug triage, fix scoping, root cause analysis
│   └── technologies/      # Tool knowledge — voice calibration, PR conventions, workflows
├── skills/                # Orchestrated workflows (build → test → deploy sequences)
├── personal/              # Growth tracking — diary, TODOs, aspirations, learning roadmap
└── session-state/         # Ephemeral per-session artifacts (not committed)
```

## How to use

```bash
git clone https://github.com/akubly/.copilot.git ~/.copilot
```

Copilot CLI automatically loads configuration from `~/.copilot`. No additional setup required.

## Key concepts

### Persona Review System

Every significant output passes through three review panels running **in parallel**, each with four specialized personas:

| Panel | Personas | Focus |
|-------|----------|-------|
| **Code** | Correctness, Security, Performance, Maintainability | Does the code work and is it safe? |
| **Design** | Scope, Architecture, Simplicity, Testability | Is this the right change at the right layer? |
| **Writing** | Clarity, Precision, Tone, Audience | Will the reader understand and trust this? |

Personas act as silent critics — they surface issues *before* output reaches the user, not after.

### Mandatory Workflow Gates

Two hard gates that the AI cannot skip:

- **Decision-Point Gate** — When multiple approaches exist, present the options with trade-offs *before* choosing one. No silent decisions.
- **Pre-Output Persona Review Gate** — All three panels must run before any non-trivial output is delivered. No "I'll review it later."

### "First Thought Might Be Wrong"

The foundational reasoning discipline. Before committing to an approach:

1. Generate at least one alternative
2. Explore implications of each
3. *Then* choose — and explain why

This prevents the AI from anchoring on its first instinct, which is often a plausible-but-suboptimal solution.

### Code Review Agent

A multi-source review architecture that layers three signal sources:

1. **Personal review rules** — Patterns extracted from 2,670 real review comments, encoded as structured heuristics
2. **Built-in AI review** — Standard static analysis and pattern matching
3. **Code Panel personas** — The four Code Panel reviewers from the persona system

Only issues that *genuinely matter* surface. No style nits. No formatting complaints. High signal-to-noise ratio.

### Voice Calibration

Review comments, PR descriptions, and commit messages are calibrated to match the author's actual communication patterns — derived from statistical analysis of 2,670 real review comments. The AI writes *as* the developer, not *for* the developer.

### Memory-First Learning

A knowledge graph (via MCP memory server) persists discoveries across sessions:

- **Before acting**: Search memory for prior solutions to avoid re-deriving known answers
- **After solving**: Record discoveries immediately — sessions can end abruptly
- **Self-improvement**: Detect when a solution existed in memory but wasn't found, then improve search triggers

The goal is cumulative expertise: every hard-won insight makes future sessions faster.

## Philosophy

This isn't prompt engineering. It's building a *system* — with gates, reviewers, and feedback loops — that makes AI-assisted development reliable enough to trust. The AI earns autonomy by proving it can reason carefully, not by being told to "be careful."

## License

[MIT](LICENSE)
