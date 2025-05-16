#!/bin/bash
set -eu

# Important: You need to be on main first, so that the
# 'git branch --merged ...' command shows you what's merged into *main*.
git checkout main

for b in $(git branch --merged | grep -v '\bmain\b')
do
    echo "deleting local branch: $b ..."
    # remove the 'echo' to actually pull the trigger!
    echo git branch -D $b
done
