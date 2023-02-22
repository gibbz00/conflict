## Summary

This script will:

1) Get all the open PRs from a GitHub repo.
2) Check which are mergeable with origin HEAD (usually master).
3) Check which pass all CI checks.
4) Check which are mergeable with local branch.
5) Summarize results.

### Example output:

```
=== SUMMARY for helix-editor/helix, (28/278) PRs checked ===

Conflicting PRs (14): 
#5390 #5411 #5435 #5436 #5472 #5491 #5492 #5523 #5531 #5535 #5577 #5581 #5608 #5621

Skipped because of failing CI checks (2):
#5635 #5636

Skipped for not being mergeable with origin HEAD (1): 
#5534

Checking if 'unify-config' conflicts with PR #5645...
```

## Useage 

Special dependencies: `gh` with cached auth token, `jq` and `rg`. 

Clone this repo, make sure the dependencies are set up (Arch users can use the AUR package `git-conflict-git` for this), then run:

```bash
  # in directory of repo that is to be checked
  git-conflict.sh
```

Script will automatically look for a remote named `origin` to retrieve the uprstream url from there. 
If this fails, then the owner and repo can can be passed as an optional arguments:
```bash
  git-conflict.sh gibbz00 conflict # to run on https://github.com/gibbz00/conflict
```

