#!/bin/bash
_owner="$1"
_repo="$2"

echo "Retrieving PRs from ${_owner}/${_repo}..."

_response=$(gh api --include -H "Accept: application/vnd.github+json" \
  "repos/$_owner/$_repo/pulls?per_page=100&state=open&direction=asc" --cache 1h)
_last_page_nr=$(rg --only-matching --pcre2 '\d*(?=>; rel="last")' <<< "$_response")
_pr_numbers="$(jq '.[] | select((.draft == false)) | .number' <<< \
  "$(tail --lines=1 <<< "$_response")")"
   
if test "$_last_page_nr" -gt "1"
then
  for _page in $(seq 2 "$_last_page_nr")
  do
    _response=$(gh api --include -H "Accept: application/vnd.github+json" \
      "repos/$_owner/$_repo/pulls?per_page=100&page=$_page&state=open&direction=asc" --cache 1h)
    _pr_numbers="$(jq '.[] | select((.draft == false)) | .number' <<< \
      "$(tail --lines=1 <<< "$_response")")$(printf "\n%s" "$_pr_numbers")"
  done
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

  echo "== SUMMARY =="
  echo "Number of PRs checked $_total_prs_checked/$_pr_count"
  echo "Conflicting PRs (${#_conflicting_prs[*]}) :" "${_conflicting_prs[@]}"
  echo "Checks faiure PRs (${#_check_fail_prs[*]}) :" "${_check_fail_prs[@]}"
  echo "Unmergeable with master PRs (${#_unmergeable_with_master_prs[*]}) :" "${_unmergeable_with_master_prs[@]}"
  echo ""
  echo "Checking whether $_local_branch conflicts with PR #${arr[0]}..."

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
