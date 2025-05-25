#!/opt/homebrew/bin/bash
set -eu

declare -A MDX_BLOG_ROOT_PATHS=(
    ["mdx-blog-fork"]="$HOME/dev/mdx-blog-fork"
    ["tinkering-tuna"]="$HOME/dev/tinkering-tuna"
    ["tab2do-website"]="$HOME/dev/tab2do-website"
    ["podswitch-web"]="$HOME/dev/podcast-sharing-app/web-app/podswitch-web"
)

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <project_name> <commit_sha1> [commit_sha2] ..."
    echo "Available projects: ${!MDX_BLOG_ROOT_PATHS[@]}"
    exit 1
fi

project_name="$1"
shift
commit_shas=("$@")

# Validate project name
if [[ ! -v MDX_BLOG_ROOT_PATHS["$project_name"] ]]; then
    echo "Error: Project '$project_name' not found in MDX_BLOG_ROOT_PATHS"
    echo "Available projects: ${!MDX_BLOG_ROOT_PATHS[@]}"
    exit 1
fi

project_path="${MDX_BLOG_ROOT_PATHS["$project_name"]}"

# Change to the specified project directory
cd "$project_path"

# Find the git repository root and calculate the relative path from repo root to project directory
git_repo_root=$(git rev-parse --show-toplevel)
if [[ "$project_path" == "$git_repo_root" ]]; then
    # Project is at git repo root, no prefix to strip
    project_prefix=""
else
    # Calculate relative path from git repo root to project directory
    project_prefix="${project_path#$git_repo_root/}/"
fi

echo "Git repo root: $git_repo_root"
echo "Project path: $project_path"
echo "Project prefix to strip: '$project_prefix'"

# Get list of modified files across all commits
modified_files_set=()
for commit in "${commit_shas[@]}"; do
    while IFS= read -r file; do
        if [[ -n "$file" && ! " ${modified_files_set[*]} " =~ " $file " ]]; then
            modified_files_set+=("$file")
        fi
    done <<< "$(git diff --name-only "${commit}^" "$commit")"
done

# Create patch file in $HOME
patch_hash=$(echo "${commit_shas[*]}" | md5sum | cut -d' ' -f1 | cut -c1-8)
patch_file="$HOME/patch_${project_name}_${patch_hash}.patch"

# Create a combined patch for all specified commits
if [ ${#commit_shas[@]} -eq 1 ]; then
    # Single commit - use format-patch
    git format-patch --stdout "${commit_shas[0]}^..${commit_shas[0]}" > "$patch_file"
else
    # Multiple commits - create combined patch using format-patch with range
    # Sort commits to find the range (assumes they're in chronological order)
    first_commit="${commit_shas[0]}"
    last_commit="${commit_shas[-1]}"
    git format-patch --stdout "${first_commit}^..${last_commit}" > "$patch_file"
fi

echo "Created patch file: $patch_file"
echo "Modified files:"
printf '  %s\n' "${modified_files_set[@]}"
echo

# For each modified file, open vim with patch and corresponding files from all projects
for file in "${modified_files_set[@]}"; do
    vim_args=("$patch_file")

    # Strip the project prefix to get the file path relative to a common structure
    if [[ -n "$project_prefix" && "$file" == "$project_prefix"* ]]; then
        relative_file_path="${file#$project_prefix}"
    else
        relative_file_path="$file"
    fi

    #echo "Original file: $file"
    #echo "Relative file path: $relative_file_path"

    # Add the file from each project (including the source project)
    for proj_key in "${!MDX_BLOG_ROOT_PATHS[@]}"; do
        proj_path="${MDX_BLOG_ROOT_PATHS[$proj_key]}"
        file_path="$proj_path/$relative_file_path"
        #echo "file_path: $file_path"
        if [[ -f "$file_path" ]]; then
            vim_args+=("$file_path")
        fi
    done
    #echo "vim_args: ${vim_args[@]}"

    # Only run vim if we have files to edit beyond just the patch
    if [ ${#vim_args[@]} -gt 1 ]; then
        echo "Opening vim across projects to help you apply the patch for file: $relative_file_path ..."
        echo
        #sleep 3
        echo vim "${vim_args[@]}"
        echo
        echo "---"
        echo

    fi
done