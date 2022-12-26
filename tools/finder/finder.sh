#!/usr/bin/env bash

set -e

# change this for another iOS version
readonly IOS='iOS;19'

for string in $(curl -sL https://api.appledb.dev/ios/ | jq --raw-output ".[] | select(. | startswith(\"${IOS}\"))"); do
  curl -sL "https://api.appledb.dev/ios/${string}.json" | jq --raw-output 'try .sources[].links[].url' | while read -r line; do
    match=$(./pzb -l "${line}" | { grep -oE 'kernelcache.development.' || true; })
    ([[ -n "${match}" ]] && printf "%-20s%-190s%s\n" "${string}" "${line}" "${match}") || true
  done
done

exit 0
