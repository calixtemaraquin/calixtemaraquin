#!/usr/bin/env bash
set -euo pipefail

today="$(TZ=Europe/Paris date +%F)"
midnight="$(TZ=Europe/Paris date +%Y-%m-%dT00:00:00%:z)"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

payload="$(jq -nc \
  --arg login "$GH_LOGIN" \
  --arg from "$midnight" \
  --arg to "$now" \
  '{query:"query($login: String!, $from: DateTime!, $to: DateTime!) { user(login: $login) { contributionsCollection(from: $from, to: $to) { contributionCalendar { totalContributions } } } }", variables:{login:$login,from:$from,to:$to}}')"

response="$(curl --fail --silent --show-error --retry 3 \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H 'Accept: application/vnd.github+json' \
  -H 'Content-Type: application/json' \
  --data "$payload" \
  https://api.github.com/graphql)"

count="$(jq -er 'if ((.errors // []) | length) > 0 then error("GitHub GraphQL returned errors") else .data.user.contributionsCollection.contributionCalendar.totalContributions end' <<< "$response")"
if (( count > 0 )); then
  echo "Found $count public contribution(s) for $today; no check-in needed."
  exit 0
fi

if grep -qF -- "- $today —" AUTOMATED_CHECKINS.md; then
  echo "Automated check-in for $today already exists."
  exit 0
fi

printf '%s\n' "- $today — Automated check-in; no other public contribution was visible when this ran." >> AUTOMATED_CHECKINS.md
git config user.name 'Calixte Maraquin'
git config user.email '269727959+calixtemaraquin@users.noreply.github.com'
git add AUTOMATED_CHECKINS.md
git commit -m "Automated check-in for $today"
git push origin HEAD:main
