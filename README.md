## Summary

This script will:

1) Get all the open PRs from the specified repo.
2) Check which are mergeable with origin master.
3) Check which pass CI checks.
4) Check which are mergeable with local branch.
5) Summarize results.

### Example output:

```
== SUMMARY (28/279) ==

Conflicting PRs (8): 
#5411 #5435 #5436 #5491 #5523 #5577 #5608 #5621

Skipped because of failing CI checks (2):
#5635 #5636

Skipped for being unmergeable with master (7): 
#5390 #5472 #5492 #5531 #5534 #5535 #5581

Checking if 'unify-config' conflicts with PR #5645...
```

## Useage 
  
To try it out, run:
```bash
  # in repo directory
  sh git-conflict.sh <repo-owner> <repo-name>
```

Special dependencies:

- `gh` With cached auth token.
- `jq`
- `rg`
