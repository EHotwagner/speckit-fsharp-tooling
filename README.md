# speckit-fsharp-tooling

Opinionated Speckit customization for pure-F# projects. One monorepo
holds four artifacts:

| Artifact | Path | Install |
|---|---|---|
| Preset | `presets/fsharp-opinionated/` | `specify preset add <path>` |
| Evidence extension | `extensions/evidence/` | `specify extension add <path>` |
| Codex skills | `~/.codex/skills/speckit-merge/`, `~/.codex/skills/speckit-debug-loop/` | copy or symlink |
| `dotnet new` template | `templates/speckit-fsharp-lib/` | `dotnet new install <path>` |

## What each piece does

### Preset — `fsharp-opinionated`

Ships the shared F# constitution (six LOCKED principles) and overrides
three core Speckit commands:

- `/speckit.constitution` — fills placeholders, respects LOCKED markers.
- `/speckit.tasks` — emits `tasks.md` + `tasks.deps.yml` in lockstep.
- `/speckit.implement` — teaches the agent the `[S]` synthetic-marking
  discipline from constitutional Principle IV.

Templates:

- `constitution-template.md` — six principles, LOCKED/TAILORABLE/REQUIRED
  markers so per-project amendments don't silently dilute shared doctrine.
- `tasks-template.md` — five-state legend (`[ ] [X] [S] [F] [-]`);
  `[S*]` is computed, never written.
- `tasks.deps-template.yml` — sibling dependency topology, seeds with the
  skeleton edges.

### Evidence extension — `evidence`

Adds two new Speckit commands and auto-registers two hooks:

- `speckit.graph.compute` — validates the DAG (acyclic, no dangling
  refs), auto-injects phase-checkpoint edges, computes synthetic
  propagation (`[S]` → `[S*]`), writes `readiness/task-graph.{json,md}`.
  Registered as `before_implement` — refuses to start implement on a
  broken graph.
- `speckit.evidence.audit` — runs graph compute plus a diff-scan against
  `audit-patterns.yml` (TODO / not-implemented / mock-stub-fake
  identifiers / skipped tests / commented assertions). Registered as
  `after_implement`. Strictness is **block on both** — any `[S]`/`[S*]`
  or any blocking diff-scan hit produces NEEDS-EVIDENCE.

Escape hatch: `run-audit.sh --accept-synthetic "justification"` records
the override to `readiness/synthetic-evidence.json` but the audit still
reports failure. The override is a human decision, not a silenced gate.

### Codex skills

Global skills, installed to `~/.codex/skills/`:

- `speckit-merge` — squash-merge all feature branches onto trunk (`main`
  or `master` auto-detected), delete them, push. For repos with packable
  `.fsproj` files, bump patch version, `dotnet pack`, and clear NuGet
  caches.
- `speckit-debug-loop` — bounded iterate loop: run verify, parse
  failures, fix minimally, re-run. Safety rails: never weaken asserts,
  never `[<Skip>]` a failing test, never `--no-verify`, never delete a
  test. Writes `readiness/debug-loop.log.md`.

### `dotnet new` template — `speckit-fsharp-lib`

Minimal F# library scaffold aligned with the preset's principles:

- `Directory.Build.props` promotes FS0078 (access-modifier-in-file-with-fsi)
  to error, enforcing Principle II.
- `src/Lib/Library.fsi` + `Library.fs` — the visibility-via-signature
  pattern.
- `tests/Lib.Tests/` — Expecto, semantic tests calling the public surface.
- `scripts/prelude.fsx` — FSI entry point for Principle I.

## One-time installation (per machine)

```bash
# 1. Clone this repo somewhere durable.
git clone <this-repo> ~/projects/speckit-fsharp-tooling
cd ~/projects/speckit-fsharp-tooling

# 2. Install the dotnet new template pack.
dotnet new install ./templates/speckit-fsharp-lib

# 3. Install the Codex skills globally.
# (Skills aren't in this repo directly — copy from your authoring
#  location, or clone them from their own repo if you publish them.)
# Example if you keep local copies under ./skills/ in this repo:
#   mkdir -p ~/.codex/skills
#   cp -r ./skills/speckit-merge ~/.codex/skills/ 2>/dev/null || true
#   cp -r ./skills/speckit-debug-loop ~/.codex/skills/ 2>/dev/null || true

# 4. Add the shell wrapper to your shell rc file.
```

## Shell wrapper

Add to `~/.bashrc` or `~/.zshrc`:

```bash
new-speckit-fsharp() {
  local name="${1:?usage: new-speckit-fsharp <name>}"
  mkdir -p "$name" && cd "$name" || return 1

  # .NET-side scaffold.
  dotnet new speckit-fsharp-lib -n "$name"

  # Speckit-side scaffold.
  # `--preset` on `specify init` is only for catalog IDs; for local
  # development paths we use `specify preset add --dev` after init.
  specify init . --ai codex --ai-skills
  specify preset add --dev ~/projects/speckit-fsharp-tooling/presets/fsharp-opinionated
  specify extension add --dev ~/projects/speckit-fsharp-tooling/extensions/evidence

  # First commit.
  git init -q
  git add -A
  git commit -qm "Initial Speckit F# scaffold"
}
```

Usage:

```bash
new-speckit-fsharp MyLibrary
cd MyLibrary
# Now run /speckit.constitution to fill placeholders, then /speckit.specify…
```

## Per-project workflow

```
/speckit.constitution   # fills placeholders, asks about TAILORABLE sections
/speckit.specify        # draft feature spec
/speckit.plan           # plan it
/speckit.tasks          # emits tasks.md AND tasks.deps.yml
                        # before_implement hook fires speckit.graph.compute
/speckit.implement      # marks [X] / [S] per task; re-runs graph compute
                        # after_implement hook fires speckit.evidence.audit
                        # verdict must be PASS to declare merge-ready
speckit-merge skill     # squash-merge feature branches and push
```

## Updating a project when the preset or extension changes

The preset and extension are copied into each project at install time;
they do not auto-update. To refresh:

```bash
# From inside an existing project:
specify preset remove fsharp-opinionated
specify preset add --dev ~/projects/speckit-fsharp-tooling/presets/fsharp-opinionated

specify extension remove evidence --force
specify extension add --dev ~/projects/speckit-fsharp-tooling/extensions/evidence
```

LOCKED sections of the constitution will be rewritten from the new
template; TAILORABLE sections are preserved by
`/speckit.constitution`'s override prompt (it offers to refresh from
template while keeping your project's tailoring).

## Layout

```
speckit-fsharp-tooling/
├── README.md                                  ← this file
├── presets/
│   └── fsharp-opinionated/
│       ├── preset.yml
│       ├── templates/
│       │   ├── constitution-template.md
│       │   ├── tasks-template.md
│       │   └── tasks.deps-template.yml
│       └── commands/
│           ├── speckit-constitution.md
│           ├── speckit-tasks.md
│           └── speckit-implement.md
├── extensions/
│   └── evidence/
│       ├── extension.yml
│       ├── audit-patterns.yml
│       ├── commands/
│       │   ├── speckit.graph.compute.md
│       │   └── speckit.evidence.audit.md
│       └── scripts/
│           ├── python/
│           │   └── compute-task-graph.py
│           └── bash/
│               └── run-audit.sh
└── templates/
    └── speckit-fsharp-lib/                    ← dotnet new template
        ├── .template.config/template.json
        ├── Directory.Build.props
        ├── SpeckitFSharpLib.sln
        ├── src/Lib/{Lib.fsproj,Library.fsi,Library.fs}
        ├── tests/Lib.Tests/{Lib.Tests.fsproj,Tests.fs,Program.fs}
        └── scripts/prelude.fsx
```

Codex skills live globally in `~/.codex/skills/speckit-merge/` and
`~/.codex/skills/speckit-debug-loop/` — not in the monorepo itself,
because spec-kit skills are resolved from the global directory.

## Status

- [x] preset (constitution, tasks, implement, constitution prompt)
- [x] evidence extension (graph compute, audit, patterns)
- [x] Codex skills (speckit-merge, speckit-debug-loop)
- [x] dotnet new template (speckit-fsharp-lib)
- [x] end-to-end smoke test in a fresh project — confirmed `specify preset
      add --dev` + `specify extension add --dev` install cleanly, templates
      resolve to the preset, hooks register on both `before_implement` and
      `after_implement`, graph compute propagates `[S]` → `[S*]` correctly.
- [ ] publish as a preset / extension catalog for cross-machine install
