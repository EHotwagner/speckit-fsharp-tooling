# new-speckit-fsharp.sh — shell wrapper for scaffolding a Codex-targeted
# Speckit F# library.
#
# This file is sourced, not executed. Add this line to your ~/.bashrc (or
# ~/.zshrc) and the `new-speckit-fsharp` function becomes available in
# every new shell:
#
#     source ~/projects/speckit-fsharp-tooling/scripts/new-speckit-fsharp.sh
#
# Then, from anywhere:
#
#     new-speckit-fsharp MyLibrary
#     new-speckit-fsharp MyLibrary --Framework net10.0
#
# Requires: bash or zsh, dotnet SDK, specify CLI, the speckit-fsharp-lib
# dotnet new template (install once with
#   `dotnet new install <this-repo>/templates/speckit-fsharp-lib`), and
# git.

# Resolve this script's directory so the function knows the monorepo root
# regardless of where it was sourced from. Works in bash and zsh.
if [ -n "${BASH_VERSION:-}" ]; then
  __speckit_fsharp_script="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  __speckit_fsharp_script="${(%):-%x}"
else
  echo "new-speckit-fsharp.sh: unsupported shell; requires bash or zsh" >&2
  return 1 2>/dev/null || exit 1
fi

__SPECKIT_FSHARP_TOOLING="$(cd "$(dirname "$__speckit_fsharp_script")/.." && pwd)"
unset __speckit_fsharp_script

new-speckit-fsharp() {
  local name="$1"

  if [ -z "$name" ] || [ "$name" = "-h" ] || [ "$name" = "--help" ]; then
    cat <<EOF
Usage: new-speckit-fsharp <name> [dotnet-new-args…]

Scaffold a Codex-targeted Speckit F# library in a new directory.

Steps executed, in order:

  1. dotnet new speckit-fsharp-lib -n <name> -o <name> [args…]
  2. specify init . --integration codex --force
  3. specify preset add --dev <tooling>/presets/fsharp-opinionated
  4. specify extension add --dev <tooling>/extensions/evidence
  5. git init + initial commit

Extra args pass through to \`dotnet new\`. Common options:

  --Framework net10.0|net9.0|net8.0   target framework (default: net10.0)
  --SkipSolution                       omit the .sln file

Monorepo root: $__SPECKIT_FSHARP_TOOLING
EOF
    return 0
  fi

  shift

  if [ -e "$name" ]; then
    echo "new-speckit-fsharp: '$name' already exists; refusing to overwrite" >&2
    return 1
  fi

  echo "→ [1/5] dotnet new speckit-fsharp-lib -n $name"
  dotnet new speckit-fsharp-lib -n "$name" -o "$name" "$@" || {
    echo "new-speckit-fsharp: dotnet new failed" >&2
    return 1
  }

  cd "$name" || return 1

  echo "→ [2/5] specify init"
  # --force: dotnet new already populated the dir; skip the "not empty" prompt.
  # --integration codex: modern replacement for the deprecated --ai codex;
  # Codex integration installs skills by default (no --ai-skills needed).
  specify init . --integration codex --force </dev/null || {
    echo "new-speckit-fsharp: specify init failed" >&2
    return 1
  }

  echo "→ [3/5] specify preset add (fsharp-opinionated)"
  specify preset add --dev "$__SPECKIT_FSHARP_TOOLING/presets/fsharp-opinionated" || {
    echo "new-speckit-fsharp: preset add failed" >&2
    return 1
  }

  echo "→ [4/5] specify extension add (evidence)"
  specify extension add --dev "$__SPECKIT_FSHARP_TOOLING/extensions/evidence" || {
    echo "new-speckit-fsharp: extension add failed" >&2
    return 1
  }

  echo "→ [5/5] git init + initial commit"
  # specify init may have already initialised git; only init if needed.
  if [ ! -d .git ]; then
    git init -q
  fi
  git add -A
  git -c commit.gpgsign=false commit -qm "Initial Speckit F# scaffold" || {
    echo "  (nothing to commit — working tree was already clean)"
  }

  cat <<EOF

✓ $name scaffolded at $(pwd)

Next:
  /speckit.constitution    — fill constitution placeholders (Principle IV etc.)
  /speckit.specify         — draft the first feature spec
  /speckit.plan            — turn it into a plan
  /speckit.tasks           — emit tasks.md + tasks.deps.yml
  /speckit.implement       — implement with [S] discipline
                             (evidence audit fires on completion)
EOF
}
