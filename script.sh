#!/bin/bash
OWNER="$1"
REPO="$2"

export total_prs_checked=0
export conflicting_prs=()
export unmergeable_with_master_prs=()
export check_fail_prs=()

echo "Retrieving forks from ${OWNER}/${REPO}..."

PR_NUMBERS=""
RESPONSE=$(gh api --include -H "Accept: application/vnd.github+json" \
  "repos/$OWNER/$REPO/pulls?per_page=100&state=open&direction=asc" --cache 1h)
PR_NUMBERS="$(jq '.[] | select((.draft == false)) | .number' <<< \
  "$(tail --lines=1 <<< "$RESPONSE")")$(printf "\n%s" "$PR_NUMBERS")"
LAST_PAGE_NR=$(rg --only-matching --pcre2 '\d*(?=>; rel="last")' <<< "$RESPONSE")
   
if test "$LAST_PAGE_NR" -gt "1"
then
  for PAGE in $(seq 2 "$LAST_PAGE_NR")
  do
    RESPONSE=$(gh api --include -H "Accept: application/vnd.github+json" \
      "repos/$OWNER/$REPO/pulls?per_page=100&page=$PAGE&state=open&direction=asc" --cache 1h)
    PR_NUMBERS="$(jq '.[] | select((.draft == false)) | .number' <<< \
      "$(tail --lines=1 <<< "$RESPONSE")")$(printf "\n%s" "$PR_NUMBERS")"
  done
fi

echo "Found $(wc -l <<< "$PR_NUMBERS") open PRs"

echo "$PR_NUMBERS" |
xargs -I{} gh api -H "Accept: application/vnd.github+json" \
  "repos/$OWNER/$REPO/pulls/{}" --cache 1h \
   --jq '[.number, .head.sha, .mergeable] | join(" ")' |
while read -r data
do
  read -a arr <<< "$data"
  echo "Checking conflict with PR #${arr[0]}..."

  if test "${arr[2]}" = "false"
  then 
    unmergeable_with_master_prs+=("#${arr[0]}")
  else
    if test "$(gh api -H "Accept: application/vnd.github+json" "repos/$OWNER/$REPO/commits/${arr[1]}/check-runs" --cache 1h \
      --jq '.check_runs | [.[] | .conclusion] | all(. == "success")')" = "true"
    then
      git fetch --quiet origin "pull/${arr[0]}/head:TEMP_BRANCH_NAME" 1>/dev/null
      if test "$(git merge --no-commit --no-ff "TEMP_BRANCH_NAME" 2>&1 | rg "CONFLICT")"
      then   
        conflicting_prs+=("#${arr[0]}")
      fi
      git merge --abort
      git branch --quiet --delete --force  "TEMP_BRANCH_NAME"
      git prune
    else
      check_fail_prs+=("#${arr[0]}")
    fi
  fi
  
  total_prs_checked=$((total_prs_checked + 1))

  echo "== SUMMARY =="
  echo "Number of PRs checked $total_prs_checked"
  echo "Conflicting PRs (${#conflicting_prs[*]}) :" "${conflicting_prs[@]}"
  echo "Checks faiure PRs (${#check_fail_prs[*]}) :" "${check_fail_prs[@]}"
  echo "Unmergeable with master PRs (${#unmergeable_with_master_prs[*]}) :" "${unmergeable_with_master_prs[@]}"
  echo ""
done
