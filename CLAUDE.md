# 오한어 (Ohaneo): Claude Code context

A small iOS app that shows one Korean word, phrase or grammar point a day to
an upper-beginner learner, with light review. A personal project; the repo is
public. The design is in `docs/design.md`: read it before changing behavior.

## Layout

- `Ohaneo/`: the SwiftUI app (views, SwiftData model, services, the
  Foundation Models generator).
- `OhaneoCore/`: a Swift package with the pure logic (mix, review, selectors,
  placement, planner) and the bundled data (`Resources/*.json`). Tests run
  with `swift test`, no simulator needed.
- `OhaneoTests/`: app tests (StudyService on an in-memory store).
- `Tools/`: scripts that build the bundled data and the icon. The JSON files
  are generated; edit the scripts or `word_overrides.tsv`, then rebuild.
- `project.yml`: XcodeGen. `Ohaneo.xcodeproj` is generated and gitignored.

## Commands

```sh
xcodegen generate                                     # after changing project.yml or adding files
(cd OhaneoCore && swift test)                         # core logic and data checks
xcodebuild test -project Ohaneo.xcodeproj -scheme Ohaneo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build
python3 -I Tools/conjugate.py                         # conjugation self-test
python3 -I Tools/build_words.py --nikl <nikl.txt> --krdict-dir <xml/> \
  --out OhaneoCore/Sources/OhaneoCore/Resources/words.json
python3 -I Tools/build_phrases.py OhaneoCore/Sources/OhaneoCore/Resources/phrases.json
python3 -I Tools/build_grammar.py OhaneoCore/Sources/OhaneoCore/Resources/grammar.json
```

Install on Cory's iPhone (team ID passed on the command line, not stored in
the repo):

```sh
xcodebuild -project Ohaneo.xcodeproj -scheme Ohaneo -configuration Debug \
  -destination 'platform=iOS,id=<device id>' -derivedDataPath build \
  DEVELOPMENT_TEAM=B2G47QWXN7 -allowProvisioningUpdates build
xcrun devicectl device install app --device <device id> build/Build/Products/Debug-iphoneos/Ohaneo.app
```

`xcrun devicectl list devices` gives the device id. Debug launch arguments
(simulator): `-fakeAI`, `-resetData`, `-demoPlacement`, `-today YYYY-MM-DD`,
`-reveal`, `-tab history|settings`.

## Rules that keep the content honest

- Facts come from bundled data, never from the AI: meanings, Hanja and forms
  from `words.json`, grammar rules from `grammar.json`. The AI writes only
  examples, usage notes and memory hooks.
- Grammar entries ship in release builds only when `checked: true`, which a
  fluent speaker sets after verifying them. Don't flip it yourself.
- When the generator's prompt or example checks change, bump
  `StudyService.contentVersion` so cards still in play get new content.
- Keep the SwiftData model CloudKit-compatible: no unique constraints, every
  property optional or defaulted, optional relationships with inverses.

## Branching & PRs

- **Never push or merge to `main` directly.** Every change lands through a
  pull request that Cory merges, docs included. A local hook refuses pushes
  to `main`.
- **Be current first.** At session start, on `main`: `git fetch origin && git
  pull --ff-only origin main`.
- **Start every piece of work on a fresh branch cut from `origin/main`**:
  `git fetch origin && git switch -c cte13/<feature> origin/main`.
- Open the PR with `gh pr create --base main` and hand over the link. Don't
  merge your own PR.
- **Handing over the link closes the branch.** Cory often merges within
  minutes. Anything after that (more feedback, a doc line, screenshots)
  starts on a NEW branch from a fresh `origin/main`, as its own PR. Before
  pushing more to a PR branch, check `gh pr view <n> --json state`: pushing
  to a merged PR's branch leaves commits that never reach `main`.
- **"I merged it" is the cleanup order.** Said in the session that opened the
  PR, clean up right away, unasked:
  1. `gh pr view <n> --json state` shows MERGED (a closed-unmerged PR is the
     one case where cleanup loses work).
  2. `git switch main && git fetch origin && git pull --ff-only origin main`.
  3. `git branch -d cte13/<feature>`, and delete the remote branch if GitHub
     didn't (`git push origin --delete cte13/<feature>`).
  4. Remove any `pr-shots-<n>` worktree.

  Then say what went (local branch, remote branch, `main` on the merge
  commit) so "cleaned up" is checkable.
- **A UI change ships with two or three screenshots in the PR body**, the
  states that changed. `gh` can't upload images, so they live on the orphan
  branch `pr-screenshots`, one folder per PR number, embedded as
  `<img src="https://github.com/cte13/ohaneo/blob/pr-screenshots/<PR>/<name>.png?raw=true" width="380">`.
  Add them with `git worktree add --detach .worktrees/pr-shots-<PR>
  origin/pr-screenshots` (create the orphan branch the first time), copy the
  PNGs in (cropped, ≤150 KB), commit, push, then `gh pr edit <PR>
  --body-file`. Read the body back and check every image URL names a file
  that's on the branch. Never merge `pr-screenshots`.
- End commit messages with the Co-Authored-By line, and PR bodies with the
  Claude Code line.
