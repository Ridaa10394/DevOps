# Session 5 — Git / GitHub

**Name:** Ridaa Mirza
**Enrollment No:** 24BCS10394

Every command below was executed for real. Full raw transcript: [`commands-output.txt`](commands-output.txt).

---

## Task 1 — `git commit -a -m` vs `git commit -m`

### The difference

| | `git commit -m "msg"` | `git commit -a -m "msg"` |
|---|---|---|
| Commits staged changes | Yes | Yes |
| Auto-stages **modified tracked** files | No | **Yes** |
| Auto-stages **deleted tracked** files | No | **Yes** |
| Auto-stages **new untracked** files | No | **No** |
| Needs `git add` first | Yes | Only for new files |

`-a` is shorthand for "run `git add -u` first". The critical limitation: **it only touches files git already knows about.** A brand-new file is invisible to `-a` and still requires an explicit `git add`.

### Demonstration

Starting state — one tracked file modified, one new untracked file:

```
$ git status --short
 M app.txt
?? untracked.txt
```

**Attempt 1 — plain `git commit -m` with nothing staged:**

```
$ git commit -m "try without -a"
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   app.txt

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	untracked.txt

no changes added to commit (use "git add" and/or "git commit -a")
```

Nothing was committed. The modification was never staged, so git had nothing to record.

**Attempt 2 — `git commit -a -m`:**

```
$ git commit -a -m "Update app.txt using commit -a -m"
[main 6d4d5d7] Update app.txt using commit -a -m
 1 file changed, 1 insertion(+), 1 deletion(-)
```

This succeeded — `-a` staged the modified tracked file automatically.

**But checking what was left behind:**

```
$ git status --short
?? untracked.txt
```

`untracked.txt` is **still uncommitted**. This is the observable difference, and the reason `-a` is not a safe blanket substitute for `git add .` — it silently skips new files.

### Conclusion

Use `-a` as a convenience when you are only editing files that are already tracked. Any time you have created new files, you still need `git add`. Committing with `-a` and assuming everything got in is a common way to push a broken build.

---

## Task 2 — Git Cherry-Pick

### Step 1 — Create commits on `main`

```
$ git log --oneline
de7cce5 main: commit number 4
0be5196 main: commit number 3
4d6f3c1 main: commit number 2
6d4d5d7 Update app.txt using commit -a -m
3093bd9 Initial commit: add app.txt
```

Five commits on `main`.

### Step 2 — Create a new branch and commit to it

```
$ git checkout -b feature
Switched to a new branch 'feature'
```

Three commits were made on `feature`, each adding a file:

```
$ git log --oneline
4fc8caf feature: add beta.txt
58158ad feature: add bugfix.txt (THIS ONE WILL BE CHERRY-PICKED)
db98737 feature: add alpha.txt
de7cce5 main: commit number 4
0be5196 main: commit number 3
4d6f3c1 main: commit number 2
6d4d5d7 Update app.txt using commit -a -m
3093bd9 Initial commit: add app.txt
```

### Step 3 — Identify the specific commit with `git log`

```
$ git log --oneline --grep=bugfix
58158ad feature: add bugfix.txt (THIS ONE WILL BE CHERRY-PICKED)
```

Target commit: `58158add711db70938ec3a178537e167486d9311`

The goal is to bring **only** this bugfix to `main`, leaving `alpha.txt` and `beta.txt` behind on the feature branch — the exact situation cherry-pick exists for.

### Step 4 — Cherry-pick into `main`

```
$ git checkout main
Switched to branch 'main'

$ ls    # before cherry-pick
app.txt

$ git cherry-pick 58158add711db70938ec3a178537e167486d9311
[main efd1e37] feature: add bugfix.txt (THIS ONE WILL BE CHERRY-PICKED)
 Date: Wed Sep 2 17:18:30 2026 +0000
 1 file changed, 1 insertion(+)
 create mode 100644 bugfix.txt
```

### Step 5 — Verify the change is on `main`

```
$ ls    # after cherry-pick
app.txt
bugfix.txt

$ cat bugfix.txt
BUGFIX applied
```

`bugfix.txt` is now on `main`. `alpha.txt` and `beta.txt` are **not** — only the selected commit came across.

```
$ git log --oneline
efd1e37 feature: add bugfix.txt (THIS ONE WILL BE CHERRY-PICKED)
de7cce5 main: commit number 4
0be5196 main: commit number 3
4d6f3c1 main: commit number 2
6d4d5d7 Update app.txt using commit -a -m
3093bd9 Initial commit: add app.txt
```

### Step 6 — The branch graph

```
$ git log --oneline --all --graph
* 4fc8caf feature: add beta.txt
* 58158ad feature: add bugfix.txt (THIS ONE WILL BE CHERRY-PICKED)
* db98737 feature: add alpha.txt
| * efd1e37 feature: add bugfix.txt (THIS ONE WILL BE CHERRY-PICKED)
|/
* de7cce5 main: commit number 4
* 0be5196 main: commit number 3
* 4d6f3c1 main: commit number 2
* 6d4d5d7 Update app.txt using commit -a -m
* 3093bd9 Initial commit: add app.txt
```

This graph is the most instructive part of the exercise. The same commit message appears **twice**, on two diverged branches, with **two different hashes**:

- `58158ad` — the original, still on `feature`
- `efd1e37` — the copy, now on `main`

### What I understood

**Cherry-pick copies a commit, it does not move it.** Git replays the *diff* of the chosen commit on top of the current branch and creates a **new commit object** with a new hash — because the parent commit differs, and a commit's hash is derived from its content plus its parent.

Practical consequences:

- The original commit stays on the source branch. Cherry-picking is non-destructive.
- Later merging `feature` into `main` may show the change as already applied, and can produce conflicts if the copy was modified. Cherry-picking then merging the same work is a common source of confusion.
- If the change does not apply cleanly, cherry-pick stops and asks you to resolve conflicts, then continue with `git cherry-pick --continue` (or abandon with `--abort`).

**When to use it:** pulling a single urgent hotfix from a development branch into production without dragging along unfinished features — precisely what this exercise modelled.

### Useful cherry-pick options

| Command | Purpose |
|---|---|
| `git cherry-pick <hash>` | Copy one commit |
| `git cherry-pick <h1> <h2>` | Copy several specific commits |
| `git cherry-pick A..B` | Copy a range (excluding A) |
| `git cherry-pick A^..B` | Copy a range (including A) |
| `git cherry-pick -n <hash>` | Apply changes but do **not** commit |
| `git cherry-pick -x <hash>` | Record the source hash in the message |
| `git cherry-pick --continue` | Resume after resolving conflicts |
| `git cherry-pick --abort` | Cancel and restore the previous state |
