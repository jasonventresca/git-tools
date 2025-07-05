#!/bin/bash
set -eu

# Initialize dry_run flag
dry_run=false

print_help() {
    echo "Usage: $(basename "$0") [--dry-run] [-h|--help]"
    echo ""
    echo "Deletes local and remote branches that have been merged into main."
    echo ""
    echo "Options:"
    echo "  --dry-run  Print the commands that would be executed, but don't actually execute them."
    echo "  -h, --help Show this help message and exit."
    exit 0
}

# Parse command-line options
for arg in "$@"
do
    case $arg in
        --dry-run)
        dry_run=true
        shift # Remove --dry-run from processing
        ;;
        -h|--help)
        print_help
        ;;
        *)
        # Unknown option
        echo "Unknown option: $arg"
        print_help
        ;;
    esac
done

# Important: You need to be on (the latest) main first, so that the
# 'git branch --merged ...' command shows you what's merged into *main*.
git checkout main
git pull origin main
echo '---'

# Delete merged local branches
echo "Processing local branches..."
$dry_run && echo "Dry run: would have run the following commands:"
for b in $(git branch --merged | grep -v '\bmain\b')
do
    cmd="git branch -D $b"
    if [ "$dry_run" = true ]; then
        echo "    $cmd"
    else
        echo "Deleting local branch: $b ..."
        eval "$cmd"
    fi
done

echo '---'

# Delete merged remote branches
echo "Processing remote branches..."
echo "-> Fetching and pruning origin, to get an up-to-date picture before comparison."
git fetch
git remote prune origin

echo "-> Comparing remote (origin) branches against the 'main' branch."
$dry_run && echo "Dry run: would have run the following commands:"
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

echo '---'
echo "Done."
