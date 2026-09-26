# .agents — shared guidance for AI coding agents

Single source of truth for how agents (Claude Code, Codex, Cursor, etc.) work in this repo.
Entry points: [`../AGENTS.md`](../AGENTS.md) and [`../CLAUDE.md`](../CLAUDE.md) both point here.

| File | Read it when |
|---|---|
| [flutter-best-practices.md](flutter-best-practices.md) | Writing or reviewing any Dart/Flutter code |
| [architecture.md](architecture.md) | Adding a feature, command, or service; deciding where code lives |
| [android-launcher.md](android-launcher.md) | Touching the manifest, Kotlin, permissions, or app listing/launching |
| [testing-and-quality.md](testing-and-quality.md) | Writing tests, running checks, before declaring work done |
| [archive/](archive/plan-through-phase-9.3.md) | You want the *why* behind an old decision: the full plan and dated changelog of Phases 0–9.3. History, not instructions |

## Precedence
1. Direct user instructions.
2. `../plan.md` (what is left to build, in what order, and what was left out). Agents may improve it as they go; note changes in its changelog, and archive it again once most of it is done.
3. These guides.
4. Flutter/Dart defaults.

If a guide is wrong or outdated, fix it in the same change. Keep guides short; delete rules nobody follows.
