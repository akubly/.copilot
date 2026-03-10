---
applyTo: "**"
description: "Guide AI agents to use memory MCP server for persistent learning, knowledge recall, and discovery recording across sessions"
title: "Memory MCP Agent Learning"
version: "1.0.0"
owner: "Agentic Engineering System"
---

# Memory MCP Agent Learning

## Purpose

Guide AI agents to leverage the memory MCP server for persistent knowledge management—recalling prior discoveries before exploration and recording new learnings after successful problem resolution.

## Context

AI agents have frozen training and limited context windows. The memory MCP server provides a knowledge graph that persists across sessions. Use this to:
- Avoid re-discovering solutions already found in previous sessions
- Build cumulative expertise from trial-and-error exploration
- Share knowledge across different conversation threads
- Maintain awareness of workspace-specific patterns, gotchas, and proven approaches

## Instructions

### First Principle: Memory is Compute Savings

**Memory recall is not optional—it is a cost and efficiency optimization.** Every tool invocation, every trial-and-error iteration, every re-derivation of a known solution wastes compute cycles. The memory MCP server exists to eliminate this waste.

**Apply memory-first thinking to ALL problems**, including ones that seem trivial:
- Determining correct arguments for build commands
- Authoring PowerShell one-liners for file manipulation
- Constructing git commands to examine staged changes
- Formatting regex patterns for `grep_search`
- Remembering workspace-specific paths or conventions

These "simple" tasks often consume 3-5 iterations to get right. A single memory lookup costs far less than repeated trial-and-error.

### Session Start: Recall Before Acting

**Memory recall follows other priority instructions.** If other instruction files specify startup actions (e.g., `#engineering_copilot` for codebase discovery), complete those first. Memory recall augments external context with internal learnings—it does not replace gathering situational awareness.

**After priority startup actions, before attempting tasks that involve tool usage or commands:**
1. Use `mcp_memory_search_nodes` with relevant keywords from the user's request
2. If matches found, use `mcp_memory_open_nodes` to retrieve full entity details
3. Apply recalled knowledge directly—do not re-derive known solutions

**Cost threshold awareness:** Memory lookup has overhead. For tasks where you are highly confident of success in 1-2 iterations (e.g., simple file reads, basic navigation), the memory round-trip may cost more than just attempting the task. Apply judgment—but err toward searching when uncertain.

**Skip memory search for**:
- Reading files by known path
- Standard git commands: `git status`, `git log`, `git add`
- Basic navigation: `list_dir`, simple `file_search`
- Trivial file creation from explicit user input

**Always search memory for**:
- Tools with complex syntax: `grep_search` regex, PowerShell pipelines, `sed`/`awk`
- Build commands with flags or arguments
- Debugging errors, especially cryptic codes
- Unfamiliar technologies or frameworks
- User says "again" or "like before" (implies prior session knowledge)

**Search query patterns:**
- Include technology names: "React hooks", "Windows kernel", "Python async"
- Include problem types: "build failure", "memory leak", "authentication"
- Include tool names: "git diff", "PowerShell", "grep_search"
- Include component names from the workspace or codebase

**Multi-task sessions:** When user presents multiple distinct tasks, extract keywords for each and search in parallel rather than sequentially.

**Decision tree:**
- Memory hit with relevant solution → Apply it directly, cite the source entity
- Memory hit with partial relevance → Use as starting point, extend if needed
- No memory hit → Proceed with exploration, prepare to record findings
- **Conflicting memories** → Prefer the most specific match; if equally specific, prefer most recently updated

### Citing Memory to Users

**When applying recalled knowledge, cite succinctly:**
- Good: "Based on prior discovery (Git-Staged-Diff-Syntax), using `git diff --cached`..."
- Good: "Recalling Windows-LNK2019-Common-Causes: checking TARGETLIBS in sources file..."
- Bad: Dumping full entity contents into response
- Bad: "I found this in memory..." without entity name

**Citation pattern:** `(Entity-Name)` inline or "Recalling Entity-Name:" prefix.

### During Work: Identify Recordable Knowledge

**Mark knowledge for recording when you:**
- Discover ANY solution through trial and error—even for "simple" tasks
- Finally get command-line arguments or syntax correct after iterations
- Find a workaround for a tool limitation or bug
- Learn a codebase-specific pattern or convention
- Uncover a dependency or configuration requirement
- Identify a common mistake and its resolution

**Do NOT record:**
- Information already in your training that required no iteration to recall
- User-specific preferences (unless explicitly requested)
- Temporary workarounds that will become obsolete
- Raw data dumps or large code blocks

**NEVER store in memory:**
- Passwords, API keys, tokens, or secrets
- Personally identifiable information (PII)
- File contents containing credentials or sensitive config
- Internal URLs with embedded auth tokens
- Any data the user marks as confidential

### Record Discoveries Immediately

**Record as soon as knowledge crystallizes—do not wait for session end.** Sessions may end abruptly. Record after:
- Successful build/test after multiple failures
- Workaround discovered for tool limitation
- Correct syntax finally achieved after iterations

**Create entities with `mcp_memory_create_entities`:**
- `name`: Descriptive, searchable identifier (e.g., "Windows-Razzle-Build-PATH-Fix")
- `entityType`: Category for filtering (e.g., "Solution", "Pattern", "Gotcha", "Tool-Usage")
- `observations`: Array of concise, actionable statements

**Entity naming conventions:**
- Use PascalCase with hyphens: `React-UseEffect-Cleanup-Pattern`
- Include scope prefix for workspace-specific knowledge: `OsRepo-Sources-File-Syntax`
- Include technology/domain: `Python-Async-Context-Manager-Pattern`

**Scope tagging for cross-pollination:**
- **Generalizable knowledge** (no prefix): Patterns that apply broadly—record without scope prefix so they surface in any context. Example: `Git-Staged-Diff-Syntax`
- **Workspace-specific knowledge** (with prefix): Quirks, paths, or conventions unique to a codebase—include scope prefix to avoid polluting unrelated searches. Example: `OsRepo-Razzle-Build-Flags`
- When recalling, filter by scope relevance: a hit on `OsRepo-*` in a React project is likely noise

**Observation quality standards:**
- Each observation is one actionable fact or instruction
- Include the "why" when non-obvious
- Include failure modes or edge cases discovered
- Keep under 200 characters per observation

**Create relations with `mcp_memory_create_relations`:**
- Link related entities: `{from: "Entity-A", to: "Entity-B", relationType: "depends-on"}`
- Use active voice relation types: "requires", "extends", "supersedes", "conflicts-with"

### Maintenance: Keep Knowledge Current

**Update existing entities with `mcp_memory_add_observations`:**
- Add new observations when extending prior knowledge
- Do not duplicate existing observations

**Prune outdated knowledge:**
- Use `mcp_memory_delete_observations` to remove obsolete facts
- Use `mcp_memory_delete_entities` for entirely superseded knowledge
- Use `mcp_memory_delete_relations` when relationships change

**Versioning approach:**
- Add observation with date when knowledge changes: "As of 2024-03: API v2 deprecated"
- Create new entity and "supersedes" relation for major revisions

### Self-Improvement: Learn from Memory Failures

**Detect re-solving patterns:**
After completing any task that required iteration, perform a retrospective memory search:
1. Search memory with keywords from the problem you just solved
2. If a relevant entity exists that you failed to find earlier → you have a **recall failure**
3. If no entity exists → record the solution (standard workflow)

**When a recall failure occurs:**
1. Analyze why the search failed:
   - Wrong keywords? → Add aliases to the entity's observations
   - Too narrow search? → Record the broader search pattern that would have matched
   - Didn't search at all? → This is a process failure; note the trigger that should have prompted a search

2. Update the entity to improve future discoverability:
   ```
   mcp_memory_add_observations({
     observations: [{
       entityName: "Existing-Entity-Name",
       contents: [
         "Also searchable via: [alternative keywords that should have matched]",
         "Trigger: search when [describe the situation that should prompt recall]"
       ]
     }]
   })
   ```

3. Consider creating a "Search-Trigger" entity for systematic gaps:
   ```
   mcp_memory_create_entities({
     entities: [{
       name: "Search-Trigger-Git-Staged-Changes",
       entityType: "Meta-Knowledge",
       observations: [
         "When user asks about staged/uncommitted changes → search 'git diff staged'",
         "When constructing git commands with flags → search 'git [subcommand] syntax'",
         "Past failure: spent 4 iterations on 'git diff --cached' when entity existed"
       ]
     }]
   })
   ```

**Meta-knowledge entity types:**
- `Search-Trigger`: Situations that should prompt memory search
- `Keyword-Alias`: Alternative terms for existing entities
- `Process-Gap`: Patterns where memory-first thinking was skipped
- `Instruction-Gap`: Deficiencies in instruction files that caused suboptimal behavior

**Continuous improvement loop:**
1. Solve problem → 2. Retrospective search → 3. Update or create entities → 4. Record search triggers if recall failed

### Instruction File Gaps: Propose, Don't Modify

**Do NOT directly edit instruction files.** Instructions require human review to ensure consistency and prevent drift.

**When you identify an instruction gap:**
An instruction gap occurs when:
- The instructions are silent on a situation you encountered
- Following the instructions led to suboptimal outcomes
- You discovered a better approach than what instructions prescribe
- Instructions conflict with each other or with observed reality

**Built-in checkpoints—evaluate instruction quality at these moments:**
- **After task completion**: Did the instructions guide you effectively?
- **After any hesitation**: If you paused to interpret ambiguous instructions, record the ambiguity
- **After any workaround**: If you deviated from instructions, record why
- **After memory recall outperformed instructions**: If memory contained better guidance, record the divergence

**Before recording a gap, check for existing entries:**
1. Search: `mcp_memory_search_nodes({query: "Instruction-Gap [filename] [topic]"})`
2. If similar gap exists → add observation to existing entity noting rediscovery
3. If no match → create new entity

**Record instruction gaps as memory entities:**
```
mcp_memory_create_entities({
  entities: [{
    name: "Instruction-Gap-Memory-MCP-Trivial-Tasks",
    entityType: "Instruction-Gap",
    observations: [
      "File: memory-mcp-agent-learning.instructions.md",
      "Gap: No guidance on batching multiple memory searches",
      "Discovered: Parallel searches for unrelated keywords improve recall",
      "Proposed addition: 'When user request contains multiple concepts, search each independently'",
      "Impact: Medium - caused 3 extra tool calls",
      "Date identified: 2026-01-21"
    ]
  }]
})
```

**Required fields for instruction gap entities:**
- `File`: Which instruction file has the gap
- `Gap`: What situation is not covered or mishandled
- `Discovered`: What you learned through experience
- `Proposed addition`: Specific text to add or change
- `Impact`: Severity—Critical (unsafe), High (5+ wasted calls), Medium (2-4 iterations), Low (minor)
- `Date identified`: When you found this gap

**Human review workflow:**
- Periodically search: `mcp_memory_search_nodes({query: "Instruction-Gap"})`
- Review accumulated gaps with the user
- User decides whether to incorporate into instruction files
- Delete gap entities after review (accepted or rejected)

## Examples

### Example 1: Recalling Build System Knowledge

**User request:** "The build is failing with LNK2019 errors"

**Agent action before investigating:**
```
mcp_memory_search_nodes({query: "LNK2019 linker Windows build"})
```

**Memory returns entity:** "Windows-LNK2019-Common-Causes"

**Agent applies knowledge directly:** "Recalling Windows-LNK2019-Common-Causes: LNK2019 typically indicates missing library references. Checking the `sources` file for TARGETLIBS..."

### Example 2: Recording a Discovery

**After solving a problem through exploration:**

```
mcp_memory_create_entities({
  entities: [{
    name: "Razzle-Environment-Variable-Inheritance",
    entityType: "Gotcha",
    observations: [
      "Child processes in Razzle do not inherit RAZZLETOOLPATH by default",
      "Use 'cmd /c' wrapper to preserve environment when spawning subprocesses",
      "Symptom: tools like 'build.exe' not found despite correct PATH"
    ]
  }]
})
```

### Example 3: Linking Related Knowledge

```
mcp_memory_create_relations({
  relations: [{
    from: "Razzle-Environment-Variable-Inheritance",
    to: "Windows-Build-System-Basics",
    relationType: "extends"
  }]
})
```

### Example 4: Updating Existing Knowledge

**When discovering additional context for existing entity:**

```
mcp_memory_add_observations({
  observations: [{
    entityName: "Razzle-Environment-Variable-Inheritance",
    contents: [
      "Alternative fix: explicitly set RAZZLETOOLPATH in subprocess command",
      "This issue does not affect PowerShell-spawned processes"
    ]
  }]
})
```

## Integration Points

- Use alongside `#engineering_copilot` for codebase-specific searches
- Combine with workspace search tools to verify memory against current state
- Memory entities can reference file paths discovered via `file_search` or `grep_search`
- Record successful tool usage patterns (e.g., effective `grep_search` regex patterns)