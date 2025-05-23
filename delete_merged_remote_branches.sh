#!/bin/bash
set -eu

# Initialize dry_run flag
dry_run=false

# Parse command-line options
for arg in "$@"
do
    case $arg in
        --dry-run)
        dry_run=true
        shift # Remove --dry-run from processing
        ;;
        *)
        # Unknown option
        ;;
    esac
done

# Important: You need to be on main first, so that the
# 'git branch --merged ...' command shows you what's merged into *main*.
git checkout main

if [ "$dry_run" = true ]; then
    echo "Dry run: would have run the following commands:"
fi

for b in $(git branch --remote --merged | grep -v '\borigin/main\b' | sed 's#origin/##')
do
    cmd="git push --delete origin $b"
    if [ "$dry_run" = true ]; then
        echo "    $cmd"
    else
        echo "Deleting remote branch: $b ..."
        eval "$cmd"
    fi
done
