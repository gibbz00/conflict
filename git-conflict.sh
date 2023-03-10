#!/bin/bash
_owner="$1"
_repo="$2"

if test "$_owner" = "" && test "$_repo" = ""
then
  url=$(git remote get-url origin)
  upstream=$(rg --only-matching --pcre2 '(?<=github\.com\/).*' <<< "$url")
  if test $upstream = ""
  then
    echo "ERROR: Failed to find upstream GitHub URL from a remote named 'origin'
Retry by explicitly passing the owner and repo name as program arguments:

  \$ git-conflict <owner> <repo_name>
"
  else
    read -a temp_arr <<< $(sed 's/\// /' <<< "$upstream")
    _owner="${temp_arr[0]}"
    _repo="${temp_arr[1]}"
  fi
fi

echo "Retrieving PRs from $_owner/$_repo..."

_response=$(gh api --include -H "Accept: application/vnd.github+json" \
  "repos/$_owner/$_repo/pulls?per_page=100&state=open" --cache 1h)
_last_page_nr=$(rg --only-matching --pcre2 '\d*(?=>; rel="last")' <<< "$_response")
_pr_numbers="$(jq '.[] | select((.draft == false)) | .number' <<< \
  "$(tail --lines=1 <<< "$_response")")"
   
if test "$_last_page_nr" 
then
  for _page in $(seq 2 "$_last_page_nr")
  do
    _response=$(gh api --include -H "Accept: application/vnd.github+json" \
      "repos/$_owner/$_repo/pulls?per_page=100&page=$_page&state=open&direction=asc" --cache 1h)
    _pr_numbers="$(jq '.[] | select((.draft == false)) | .number' <<< \
      "$(tail --lines=1 <<< "$_response")")$(printf "\n%s" "$_pr_numbers")"
  done
fi

if test -z "$_pr_numbers"
then
  echo "No open PRs found in $_owner/$_repo! Aborting..."
  exit
fi

_pr_count="$(wc -l <<< "$_pr_numbers")"
echo "Found $_pr_count open PRs..."

_total_prs_checked=0
_conflicting_prs=()
_unmergeable_with_master_prs=()
_check_fail_prs=()
_local_branch=$(git rev-parse --abbrev-ref HEAD)

echo "$_pr_numbers" |
xargs -I{} gh api -H "Accept: application/vnd.github+json" \
  "repos/$_owner/$_repo/pulls/{}" --cache 1h \
   --jq '[.number, .head.sha, .mergeable] | join(" ")' |
while read -r data
do
  # [pr_number, head_sha, mergeable_with_master]
  read -a arr <<< "$data"

  echo "=== SUMMARY for $_owner/$_repo, ($_total_prs_checked/$_pr_count) PRs checked ===

Conflicting PRs (${#_conflicting_prs[*]}): 
${_conflicting_prs[@]}

Skipped because of failing CI checks (${#_check_fail_prs[*]}):
${_check_fail_prs[@]}

Skipped for not being mergeable with origin HEAD (${#_unmergeable_with_master_prs[*]}): 
${_unmergeable_with_master_prs[@]}

Checking if '$_local_branch' conflicts with PR #${arr[0]}...
"

  if test "${arr[2]}" = "false"
  then 
    _unmergeable_with_master_prs+=("#${arr[0]}")
  else
    if test "$(gh api -H "Accept: application/vnd.github+json" "repos/$_owner/$_repo/commits/${arr[1]}/check-runs" --cache 1h \
      --jq '.check_runs | [.[] | .conclusion] | all(. == "success")')" = "true"
    then
      git fetch --quiet origin "pull/${arr[0]}/head:TEMP_BRANCH_NAME" 1>/dev/null
      if test "$(git merge --no-commit --no-ff "TEMP_BRANCH_NAME" 2>&1 | rg "CONFLICT")"
      then   
        _conflicting_prs+=("#${arr[0]}")
      fi
      git merge --abort
      git branch --quiet --delete --force  "TEMP_BRANCH_NAME"
      git prune
    else
      _check_fail_prs+=("#${arr[0]}")
    fi
  fi

  _total_prs_checked=$((_total_prs_checked + 1))
  clear -x
done
