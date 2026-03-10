-- Shared Observability Tables
-- Referenced by all skills via: preamble: _shared/observability.sql
-- These tables are created automatically by the skill-lifecycle hook.
-- Until the hook is deployed, skills should include this preamble manually.

-- Track skill execution lifecycle across all skills in a session
CREATE TABLE IF NOT EXISTS skill_execution_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    skill TEXT NOT NULL,
    started_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    status TEXT DEFAULT 'running' CHECK (status IN ('running', 'done', 'failed')),
    error TEXT
);

-- Persist environment discovery and scalar session state
-- Rule: use session_config for scalar key-value pairs ONLY.
-- For structured data, create a typed table (vm_credentials, build_artifacts, etc.)
CREATE TABLE IF NOT EXISTS session_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    source TEXT,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Capture errors across skill boundaries for post-session analysis
CREATE TABLE IF NOT EXISTS error_breadcrumbs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    skill TEXT NOT NULL,
    step TEXT,
    error_type TEXT,
    error_message TEXT,
    context TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- Usage:
-- At skill start:
--   INSERT INTO skill_execution_log (skill, status) VALUES ('<skill-name>', 'running');
--
-- At skill completion:
--   UPDATE skill_execution_log SET completed_at = datetime('now'), status = 'done'
--   WHERE id = (SELECT MAX(id) FROM skill_execution_log WHERE skill = '<skill-name>' AND status = 'running');
--
-- On error:
--   UPDATE skill_execution_log SET completed_at = datetime('now'), status = 'failed', error = '<error>'
--   WHERE id = (SELECT MAX(id) FROM skill_execution_log WHERE skill = '<skill-name>' AND status = 'running');
--   INSERT INTO error_breadcrumbs (skill, step, error_type, error_message) VALUES ('<skill>', '<step>', '<type>', '<msg>');
