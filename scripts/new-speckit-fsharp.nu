# new-speckit-fsharp.nu — nushell wrappers for scaffolding a Speckit F#
# library. Two flavors, one per harness:
#
#     new-speckit-fsharp-codex MyLibrary     # → Codex integration
#     new-speckit-fsharp-claude MyLibrary    # → Claude Code integration
#
# Source from ~/.config/nushell/config.nu (appended once, persists):
#
#     source ~/projects/speckit-fsharp-tooling/scripts/new-speckit-fsharp.nu
#
# Both flavors accept the same flags:
#
#     new-speckit-fsharp-claude MyLibrary --framework net10.0
#     new-speckit-fsharp-codex MyLibrary --skip-solution
#
# Requires: nushell >= 0.104 (for `path self`), dotnet SDK, specify CLI,
# the speckit-fsharp-lib dotnet new template, and git.

const SELF_PATH = path self
const SPECKIT_FSHARP_TOOLING = ($SELF_PATH | path dirname | path dirname)

# Shared scaffolding body. The `integration` parameter is passed straight
# through to `specify init --integration` and decides which harness gets
# the /speckit.* commands written into the new project. Both `codex` and
# `claude` install their respective skills/commands by default — no
# --ai-skills flag needed.
def --env _new-speckit-fsharp-impl [
    name: string
    integration: string       # specify integration key — "codex" or "claude"
    framework: string
    skip_solution: bool
] {
    if ($name | path exists) {
        error make { msg: $"'($name)' already exists; refusing to overwrite" }
    }

    print $"→ [1/5] dotnet new speckit-fsharp-lib -n ($name)"
    if $skip_solution {
        dotnet new speckit-fsharp-lib -n $name -o $name --Framework $framework --SkipSolution
    } else {
        dotnet new speckit-fsharp-lib -n $name -o $name --Framework $framework
    }

    cd $name

    print $"→ [2/5] specify init --integration ($integration)"
    # --force: dotnet new already populated the dir, so specify init would
    # otherwise prompt "not empty, continue? [y/N]".
    specify init . --integration $integration --force

    print "→ [3/5] specify preset add (fsharp-opinionated)"
    specify preset add --dev $"($SPECKIT_FSHARP_TOOLING)/presets/fsharp-opinionated"

    print "→ [4/5] specify extension add (evidence)"
    specify extension add --dev $"($SPECKIT_FSHARP_TOOLING)/extensions/evidence"

    print "→ [5/5] git init + initial commit"
    if not (".git" | path exists) { git init -q }
    git add -A
    try {
        git -c commit.gpgsign=false commit -qm "Initial Speckit F# scaffold"
    } catch {
        print "  (nothing to commit — working tree was already clean)"
    }

    let cwd = (pwd)
    print ""
    print $"✓ ($name) scaffolded at ($cwd) — harness: ($integration)"
    print ""
    print "Next:"
    print "  /speckit.constitution    — fill constitution placeholders"
    print "  /speckit.specify         — draft the first feature spec"
    print "  /speckit.plan            — turn it into a plan"
    print "  /speckit.tasks           — emit tasks.md + tasks.deps.yml"
    print "  /speckit.implement       — implement with [S] discipline"
    print "                             the evidence audit fires on completion"
}

# `def --env` so `cd` at the end of the function propagates to the caller's
# shell — otherwise you'd land in the new project but the shell would still
# be in the parent directory.

def --env "new-speckit-fsharp-codex" [
    name: string                     # Project directory name
    --framework: string = "net10.0"  # Target framework (net8.0|net9.0|net10.0)
    --skip-solution                  # Omit the .sln file (useful inside a monorepo)
] {
    _new-speckit-fsharp-impl $name "codex" $framework $skip_solution
}

def --env "new-speckit-fsharp-claude" [
    name: string                     # Project directory name
    --framework: string = "net10.0"  # Target framework (net8.0|net9.0|net10.0)
    --skip-solution                  # Omit the .sln file (useful inside a monorepo)
] {
    _new-speckit-fsharp-impl $name "claude" $framework $skip_solution
}
