# Shared Session DB Schema

Cross-skill data contracts for the session database. Skills produce and consume
data through these shared tables, enabling pipeline orchestration.

## Observability Tables (auto-created)

See `_shared/observability.sql`. These tables are created automatically by the
`skill-lifecycle` hook (or manually by each skill until the hook is deployed):

- `skill_execution_log` — tracks skill start/complete/fail with timestamps
- `session_config` — scalar key-value pairs (environment, paths, preferences)
- `error_breadcrumbs` — error context across skill boundaries

**Rule:** Use `session_config` for scalar values only. For structured data,
create a typed table (below).

## Pipeline Tables

### Source → Build Pipeline

| Table | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `topic_branch_files` | `identify-topic-branch-changes` | `build-topic-branch-artifacts`, `find-tests-for-topic-branch-changes`, `map-source-to-product-binaries` | Files changed on the topic branch |
| `build_artifacts` | `build-topic-branch-artifacts` | `sign-binary`, `patch-vm-binary-with-sfpcopy` | Built DLLs and their paths |
| `binary_map` | `map-source-to-product-binaries` | `build-topic-branch-artifacts`, `patch-vm-binary-with-sfpcopy` | Source file → product DLL mapping |

### VM Lifecycle

| Table | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `vm_credentials` | `create-nebula-test-vm` | `deploy-taef-framework`, `enable-topic-branch-features-on-vm`, `patch-vm-binary-with-sfpcopy`, `run-tests-on-vm` | VM name, IP, credentials |
| `vm_snapshots` | `manage-vm-snapshots` | `create-nebula-test-vm` (restore), `regression-bisection` (restore between iterations) | Named checkpoint metadata |

### Test Execution

| Table | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `test_runs` | `run-tests-on-vm` | `analyze-test-results`, `investigate-test-failure`, `continuous-feature-validation` | Test execution results summary |
| `test_failures` | `analyze-test-results` | `investigate-test-failure`, `regression-bisection` | Individual failure details |

### PR & Release

| Table | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `pr_readiness` | `pre-pr-readiness-check` | `create-pull-request` | Readiness gate results + test evidence for PR description |
| `containment_actions` | `add-containment` | `validate-feature-containment`, `governance-audit` hook | Feature flag instrumentation records |

### Investigation

| Table | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `rca_trace` | `root-cause-analysis` | `fix-scoping` | Causal chain from symptom to root cause |
| `failure_investigations` | `investigate-test-failure` | `pre-pr-readiness-check` | Investigation findings per test failure |
| `fix_iterations` | `investigate-test-failure` (autonomous mode) | `regression-bisection` | Fix-rebuild-retest iteration tracking |
| `telemetry_assert_buckets` | `investigate-telemetry-asserts` | *(standalone report)* | Assert buckets with source locations |

### Feature Validation

| Table | Producer | Consumer | Purpose |
|-------|----------|----------|---------|
| `feature_validation_results` | `continuous-feature-validation` | `pre-pr-readiness-check` | Feature-on vs feature-off test comparison |

## session_config Key Conventions

| Key | Value | Set By |
|-----|-------|--------|
| `current_vm_name` | VM name string | `create-nebula-test-vm` |
| `current_vm_ip` | VM IP address | `create-nebula-test-vm` |
| `upstream_branch` | Official branch name | `identify-topic-branch-changes` |
| `topic_branch` | Topic branch name | `identify-topic-branch-changes` |
| `active_orchestrator` | Currently running orchestrator skill | orchestrator skills |
| `orchestrator_goal` | Purpose of orchestration (fix-bug, implement-feature, etc.) | orchestrator skills |
| `generated_testlist_path` | Path to generated .testlist file | `find-tests-for-topic-branch-changes` |
| `mcp_server_path` | Path to MCP server directory | `build-mcp-server` |
| `mcp_tool_names` | Comma-separated MCP tool names | `build-mcp-server` |


