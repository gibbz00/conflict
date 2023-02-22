This script will:

1) Gets all the open PRs from the specified repo. (Sorted by most recent first.)
2) Filters out which are mergeable with origin master.
3) Filter out those that pass all CI checks.
4) Attempt to merge the PRs with local branch, reporting eventual merge conflict.
5) Summarize results.

To try it out run:
```bash
  sh script.sh <repo-owner> <repo-name>
```

Special dependencies:

- `gh` With auth cached auth token.
- `jq`
- `rg`
