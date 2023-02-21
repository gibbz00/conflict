#!/bin/bash
OWNER="$1"
REPO="$2"

export total_prs_checked=0
export conflicting_prs=()
export skipped_prs=()

# Get all open and non draft pull requests
gh api -H "Accept: application/vnd.github+json" \
  "repos/${OWNER}/${REPO}/pulls?per_page=100&state=open" --cache 1h \
   --jq '.[] | select((.draft == false)) | .number | tostring + " "' |
xargs -I{} gh api -H "Accept: application/vnd.github+json" \
  "repos/${OWNER}/${REPO}/pulls/{}" --cache 1h \
   --jq 'select(.mergeable != false) | [.number, .head.sha] | join(" ")' |
while read -r pr_num_n_sha
do
  read -a arr <<< "$pr_num_n_sha"
  echo "On PR ${arr[0]}..."
  if test $(gh api -H "Accept: application/vnd.github+json" "repos/${OWNER}/${REPO}/commits/${arr[1]}/check-runs" --cache 1h --jq '.check_runs | [.[] | .conclusion] | all(. == "success")') = "true"
  then
    git fetch --quiet origin "pull/${arr[0]}/head:TEMP_BRANCH_NAME" 1>/dev/null
    if test $(git merge --no-commit --no-ff "TEMP_BRANCH_NAME" 2>&1 | rg --quiet "Automatic merge went well; stopped before committing as requested")
    then   
      conflicting_prs+=("${arr[0]}")
    fi
    git merge --abort 1>/dev/null
    git branch --quiet --delete --force  "TEMP_BRANCH_NAME"
  else
    echo "PR is not passing checks, skipping..."
    skipped_prs+=("${arr[0]}")
  fi
  total_prs_checked=$((total_prs_checked + 1))

  echo "== SUMMARY =="
  echo "Number of PRs checked $total_prs_checked"
  echo "Nuber of PRs with conflicts ${#conflicting_prs[*]}"
  echo "Conflicting PRs: " "${conflicting_prs[@]}"
  echo "Skipped PRs: " "${skipped_prs[@]}"
  echo ""
done
