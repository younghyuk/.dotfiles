# Issue tracker: personal-work GitHub

Specs, tickets, triage requests, and Wayfinder maps for this repository live as issues in the private `younghyuk/personal-work` GitHub repository. The code lives in `younghyuk/.dotfiles`.

## Required scope

- Pass `--repo younghyuk/personal-work` to every `gh issue` command. Never infer the tracker from the current Git remote.
- Apply the `repo:dotfiles` label to every issue created for this repository.
- Use a heredoc for multi-line issue bodies.

## Conventions

- **Create an issue**: `gh issue create --repo younghyuk/personal-work --title "..." --body "..." --label repo:dotfiles`
- **Read an issue**: `gh issue view <number> --repo younghyuk/personal-work --comments --json number,title,body,state,labels,assignees,comments`
- **List issues**: `gh issue list --repo younghyuk/personal-work --state open --label repo:dotfiles --json number,title,body,labels,assignees,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], assignees: [.assignees[].login], comments: [.comments[].body]}]'`
- **Comment on an issue**: `gh issue comment <number> --repo younghyuk/personal-work --body "..."`
- **Apply or remove labels**: `gh issue edit <number> --repo younghyuk/personal-work --add-label "..."` / `--remove-label "..."`
- **Close an issue**: `gh issue close <number> --repo younghyuk/personal-work --comment "..."`

## Pull requests as a triage surface

**PRs as a request surface: no.**

Pull requests for code changes live in `younghyuk/.dotfiles`, not in the tracker repository. A code PR can close a tracker issue with `Fixes younghyuk/personal-work#<number>`.

## When a skill says "publish to the issue tracker"

Create an issue in `younghyuk/personal-work` with the `repo:dotfiles` label.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --repo younghyuk/personal-work --comments`.

## Wayfinding operations

The map is one issue with child issues as tickets. Every map and child carries `repo:dotfiles`.

- **Map**: create an issue with labels `wayfinder:map,repo:dotfiles`. Use the exact Wayfinder sections, in order: `## Destination`, `## Notes`, `## Decisions so far`, `## Not yet specified`, and `## Out of scope`. Open tickets are native child issues, not a list in the map body.
- **Serialize every map-body write**: GitHub issue updates replace the whole body and have no compare-and-swap guard. Before reading a map body that will be changed, acquire the fixed Git ref lock `refs/heads/wayfinder-lock/map-<map>`. Get `main_sha="$(gh api repos/younghyuk/personal-work/git/ref/heads/main --jq .object.sha)"`, then run `gh api --method POST repos/younghyuk/personal-work/git/refs -f ref="refs/heads/wayfinder-lock/map-<map>" -f sha="$main_sha"`. Reference creation is atomic: if it fails because the ref exists, another session owns the map write; do not read-modify-write, delete the ref, or wait while holding a child claim. Stop and retry in a later session. After acquisition, discard any cached map body, re-fetch it, perform all index, fog, Notes, and Out-of-scope changes, verify the final body, then release with `gh api --method DELETE repos/younghyuk/personal-work/git/refs/heads/wayfinder-lock/map-<map>`. Install an EXIT/INT/TERM trap after acquisition so ordinary failures release it. If a process crash leaves a stale ref, never remove it automatically; confirm with the user that no map writer is active before running the same DELETE command manually.
- **Child ticket**: create an issue with labels `wayfinder:<type>,repo:dotfiles`, where `<type>` is `research`, `prototype`, `grilling`, or `task`. Create it directly under the map with `gh issue create --repo younghyuk/personal-work --parent <map> ...`. To attach an issue created separately, run `child_id="$(gh api repos/younghyuk/personal-work/issues/<child> --jq .id)"`, then `gh api --method POST repos/younghyuk/personal-work/issues/<map>/sub_issues -F sub_issue_id="$child_id"`. The parent and child must both be in `younghyuk/personal-work`.
- **Blocking**: use GitHub's native issue dependencies. Get the blocker's database ID with `blocker_id="$(gh api repos/younghyuk/personal-work/issues/<blocker> --jq .id)"`, then add the edge with `gh api --method POST repos/younghyuk/personal-work/issues/<child>/dependencies/blocked_by -F issue_id="$blocker_id"`.
- **Frontier query**: fetch only this map's children, in native map order, with `gh api --paginate --slurp repos/younghyuk/personal-work/issues/<map>/sub_issues --jq '.[][] | select(.state == "open") | select(.assignees | length == 0) | select(any(.labels[]; .name == "repo:dotfiles")) | [.number, .title] | @tsv'`. For each candidate, run `gh api --paginate --slurp repos/younghyuk/personal-work/issues/<child>/dependencies/blocked_by --jq '[.[][] | select(.state == "open")] | length'` and discard it when the result is nonzero. The first remaining candidate is the frontier. Never use the repository-wide issue list to choose a map ticket.
- **Claim**: `gh issue edit <number> --repo younghyuk/personal-work --add-assignee @me`. This is the session's first write.
- **Resolve**: make the resolution comment the append-only source of truth, then close the child. Use one comment containing `<!-- wayfinder-resolution:v1 map=<map> child=<number> section=decisions -->`, an `## Answer` section, and an `## Map entry` section whose only list item is `[<ticket title>](<ticket URL>) — <one-line gist>`. Post it with `gh issue comment <number> --repo younghyuk/personal-work --body-file <resolution-comment>`, then run `gh issue close <number> --repo younghyuk/personal-work`. A child ruled out of scope uses `section=out-of-scope` and records the reason in its map entry.
- **Reconcile the map after every resolution**: acquire and hold the map-write lock above first. Treat `## Decisions so far` and resolved entries in `## Out of scope` as materialized indexes, never as their own source of truth. List this map's closed native children with `gh api --paginate --slurp repos/younghyuk/personal-work/issues/<map>/sub_issues`, then fetch each child's comments with `gh api --paginate --slurp repos/younghyuk/personal-work/issues/<child>/comments`. Rebuild the indexes from the one `wayfinder-resolution:v1` record for each closed child, preserving native child order and every non-derived part of the map body fetched after lock acquisition. Apply fog graduation and any other non-derived changes in that same locked write. Write the rebuilt body with `gh issue edit <map> --repo younghyuk/personal-work --body-file <rebuilt-body>`. Re-fetch both the complete resolution-record set and the map; release the lock only when every `(map, child, section, map entry)` record appears exactly once in the corresponding index, no stale derived entry remains, and the intended non-derived edits are present. Otherwise rebuild from the newly fetched sources and retry while still holding the lock. The atomic lock prevents full-body lost updates; the source-to-index invariant repairs stale derived content left by an interrupted older session.
