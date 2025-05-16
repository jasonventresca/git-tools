#!/bin/bash
set -eu

# Important: You need to be on main first, so that the
# 'git branch --merged ...' command shows you what's merged into *main*.
git checkout main

for b in $(git branch --remote --merged | grep -v '\borigin/main\b' | sed 's#origin/##')
do
    echo "deleting remote branch: $b ..."
    # remove the 'echo' to actually pull the trigger!
    echo git push --delete origin $b
done
