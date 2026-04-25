---
name: speckit-merge
description: Squash-merge all feature branches into the default branch (main or master), delete them, and push. Use when the user says "land this", "ship the feature", "merge the feature branches", "squash-merge and push", or anything that means consolidating feature work onto the trunk. After a successful merge, every packable project MUST be packed with a bumped version number.
metadata:
  short-description: Squash-merge feature branches, bump+pack, and push
---

# speckit-merge

Consolidate feature branches onto the trunk (`main` or `master`) via
squash-merge, push to origin, and — after a successful merge — bump the
patch version of every packable project and produce a local NuGet
package. The bump-and-pack step is **mandatory** whenever any packable
project is present; it is only skipped when the repo contains no
packable projects at all.

## When to use

- User says "ship it", "land this branch", "squash-merge", "merge the
  features", "land all feature branches", etc.
- After a feature has passed `/speckit.evidence.audit` with verdict PASS
  (or explicit `--accept-synthetic` override).

## Preconditions — check before doing anything destructive

1. Working tree is clean (`git status --porcelain` is empty). Refuse if
   not; ask the user to commit or stash.
2. On a git repo. Refuse if not.
3. The evidence audit, if applicable, has PASSED for each feature branch
   being merged. If `readiness/synthetic-evidence.json` exists and has an
   unlogged override, surface that to the user before proceeding.

## Steps

### 1. Detect trunk

```bash
TRUNK=""
if git show-ref --verify --quiet refs/heads/main; then TRUNK=main
elif git show-ref --verify --quiet refs/heads/master; then TRUNK=master
else
  echo "No main or master branch; ask the user which branch is the trunk."
  exit 2
fi
```

### 2. Enumerate feature branches

Every local branch that is NOT the trunk is a candidate feature branch.
List them and confirm with the user before merging more than one.

```bash
git for-each-ref --format '%(refname:short)' refs/heads/ | grep -v "^$TRUNK$"
```

### 3. Switch to trunk and pull

```bash
git checkout "$TRUNK"
git pull --ff-only origin "$TRUNK" 2>/dev/null || true
```

### 4. For each feature branch — squash-merge and delete

```bash
for BRANCH in <list>; do
  git merge --squash "$BRANCH"
  # Abort and prompt the user if there are conflicts.
  if ! git diff --cached --quiet; then
    git commit -m "Merge $BRANCH (squash)"
    git branch -D "$BRANCH"
  fi
done
```

**Conflict handling.** If a squash-merge reports conflicts, do NOT resolve
automatically. Abort with `git merge --abort`, tell the user which branch
conflicted, and ask them to resolve manually. Never take sides.

### 5. Push to origin

```bash
git push origin "$TRUNK"
```

### 6. NuGet pack — MANDATORY after a successful merge

After step 5 succeeds, this step is **required**, not optional. Skip it
only when the repo contains zero packable projects. Detect them with:

```bash
PACKABLE=$(grep -lE '<IsPackable>\s*true|<PackageId>' $(find . -name '*.fsproj'))
```

If `PACKABLE` is empty, skip. Otherwise, for **every** packable project,
you MUST:

1. Read the current `<Version>` from the `.fsproj`. If absent, insert
   `<Version>0.1.0</Version>` into the first `<PropertyGroup>`.
2. Increment the **patch** segment by 1 (always — never reuse or
   decrement). The version number must strictly increase on every
   merge so downstream FSI consumers see a fresh package.
3. Update the `<Version>` element in place.
4. Run `dotnet pack -c Release -o ~/.local/share/nuget-local`. If
   `dotnet pack` fails, stop and surface the error — do not push a
   half-bumped repo.
5. Commit the version bump: `Bump <PackageId> to <new version>`.
6. Push the bump commit.

Do not consider the merge "done" until every packable project has been
bumped, packed, committed, and pushed.

### 7. Clear NuGet caches (F# libraries only)

FSI caches resolved packages aggressively. If we just produced a new
version that downstream FSI scripts will consume, clear both caches:

```bash
dotnet nuget locals http-cache --clear
dotnet nuget locals global-packages --clear
```

## Safety rails

- NEVER force-push.
- NEVER bypass pre-commit hooks (`--no-verify`) unless the user explicitly
  requests it and owns the reason.
- NEVER delete a branch that hasn't been successfully squash-merged.
- If the trunk has diverged from origin (local `git pull --ff-only` would
  fail), stop and ask the user. Do not attempt a rebase or merge of the
  trunk automatically.
- If the version bump commit fails to push (e.g., someone else bumped
  first), stop and surface the conflict. Do not retry.

## After running

Report to the user:
- Which branches were squash-merged, in order.
- Any branches that were skipped and why (conflicts, audit failure, user
  cancelled).
- The new versions of packed projects, if any.
- Whether origin was pushed successfully.
