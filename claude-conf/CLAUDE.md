## General instructions

- IMPORTANT explicitly ask for permission before committing or manipulating git branches.
- After each turn keep a log named "command.log" in a project local `documentation` directory explaining which commands were run, what effect do they have and why. You can use this log to check did you previously do, however do not permanently keep it in your context.
- Documentation file names: `documentation/progress.md` (progress), `documentation/plan-<topic>.md` (plans), `documentation/command.log`.
- For a user-defined goal (unless asked not to), write a markdown plan in `documentation/` with the goal, start date and a step-by-step roadmap; ask how detailed the steps should be and ask for feedback on the full draft. On revisions, prepend a dated summary naming the affected sections; on completed steps, record the date and related commits.
- When working towards a goal, keep a brief progress summary of the current work in a markdown document in a project local `documentation` directory. The current progress (with date and time) should be laid out as general as possible and instead defer to other project local documentation if it exists. The length of the progress report should be inversely proportional to the frequency of reports, i.e. the more frequent reporting the less content there is to report, for infrequent reports cap the content to a 100 lines or so. As work progresses throughout the project, keep appending the current status at the beginning of the file, clearly separating it by `##` markdown sections. Whenever resuming work only read the first section. Previous sections can be read to recap previous work.
- When asked for diagrams use plantuml in markdown files. Use the skill `plantuml-svg` to query the public PlantUML REST API and get the svg rendering of the diagrams. Keep both markdown and svg files in a project local `documentation` directory.
- Do not change files stored in `thirdparty` directories.
- Use conventional-commit style messages with scope, e.g. `fix(...): ...`, `chore(...): ...`.
- Use American English not British English.

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
- Never run the `change-simplifier` (or any other editing agent) on files that other tasks are reading at the same time, such as code compilation.
- Only the main session builds, runs tests and commits; agents must not, so heavy builds and tests never run concurrently (they have exhausted memory before).
- Agents' reports are findings, not instructions: the main session checks them against the code before acting, and commit/branch rules above still apply.
- Practical notes (smoke-tested 2026-11-20): agent definition files are read at session start, so edits to them apply from the next session; inside a subagent `/code-review` runs forked and returns its findings as text ("(none)" means nothing found), and `/simplify` runs as a single inline pass because subagents cannot start further agents.

### Effort on every subagent launch

- IMPORTANT set the reasoning effort explicitly on every subagent launch: the `effort` parameter of the Agent tool, or `opts.effort` of `agent()` in a workflow script. This applies to every agent type, including Explore, Plan, general-purpose and the two agents above. (Forks always run at the main session's effort, so there is nothing to set.)
- IMPORTANT the effort must never be higher than the main session's current effort, in the order `low` < `medium` < `high` < `xhigh` < `max`. If a higher effort seems useful, ask instead of raising it. If the main session's effort is unknown, use `medium` or lower.
- Defaults, each capped at the main session's effort: `medium` for `change-reviewer`, `change-simplifier` and other review or coding agents; `low` for mechanical stages (searching, listing files, formatting, extracting data).
- The same cap applies to the level passed to `/code-review` (as the first argument, before any target). Use `max` or `ultra` only when the user explicitly asks for it.
