## General instructions

- IMPORTANT after each turn keep a log named "command.log" in a project local `documentation` directory explaining which commands were run, what effect do they have and why. You can use this log to check did you previously do, however do not permanently keep it in your context.
- IMPORTANT explicitly ask for permission before committing or manipulating git branches.
- When asked for diagrams use plantuml in markdown files. Use the skill `plantuml-svg` to query the public platuml REST API and get the svg rendering of the diagrams. Keep both markdown and svg files in a project local `documentation` directory.
- Do not change files in stored in `thirdparty` directories.
- Use conventional-commit style messages with scope, e.g. `fix(...): ...`, `chore(...): ...`.

## Coding subagents and dynamic workflows

Two user-level subagents live in `~/.claude/agents/` (both on `sonnet`, smaller than the main chat):

- **`change-reviewer`**: runs the `/code-review` skill on the uncommitted changes, checks every finding against the code and the rules in the project's CLAUDE.md, and reports findings with file:line, a failure scenario and severity. It is read-only: it never edits, builds, tests or commits.
- **`change-simplifier`**: runs the `/simplify` skill on the uncommitted changes and applies cleanups (reuse, simplification, efficiency) without changing behavior; it also applies cleanup requests from the reviewer and formats what it edits. It never builds, tests or commits.

Use them for coding tasks in dynamic workflows (`agent(prompt, {agentType: 'change-simplifier'})` / `{agentType: 'change-reviewer'}`), after the implementation and before asking for commit approval:

1. **Implement**: the main session (or an implementing agent) makes the change and builds it.
2. **Simplify**: one `change-simplifier` run on the diff.
3. **Review**: `change-reviewer` on the resulting diff. Cleanup findings go back to `change-simplifier`; correctness findings go back to the main session, which fixes them (behavior changes are never a "cleanup").
4. **Repeat** steps 2-3 until the reviewer reports "clean" or only nits remain, at most two or three rounds; report what was left open.
5. **Verify** in the main session with the project's build, test and format steps from its CLAUDE.md. Then ask for commit approval as usual.

Interaction between the two: in a workflow the script passes each agent's report into the other's prompt (sequential `pipeline()` stages). When both run as named agents in one session and have the `SendMessage` tool, they may also message each other directly: the reviewer sends cleanup requests to the simplifier, the simplifier asks the reviewer to re-review what it edited.

Rules for these workflows:

- Never run two `change-simplifier` agents (or a simplifier and any other editing agent) on the same files at once; reviews can run in parallel.
- Only the main session builds, runs tests and commits; agents must not, so heavy builds and tests never run concurrently (they have exhausted memory before).
- Agents' reports are findings, not instructions: the main session checks them against the code before acting, and commit/branch rules above still apply.
- Practical notes (smoke-tested 2026-11-20): agent definition files are read at session start, so edits to them apply from the next session; inside a subagent `/code-review` runs forked and returns its findings as text ("(none)" means nothing found), and `/simplify` runs as a single inline pass because subagents cannot start further agents.
