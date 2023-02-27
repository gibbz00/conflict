## Summary

This script will:

1) Get all the open PRs from a GitHub repo.
2) Check which are mergeable with origin HEAD (usually master).
3) Check which pass all CI checks.
4) Check which are mergeable with local branch.
5) Summarize results.

### Example output:

[![asciicast](https://asciinema.org/a/561863.svg)](https://asciinema.org/a/561863?t=28)

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

