#!/opt/homebrew/bin/bash
set -eu

declare -A MDX_BLOG_ROOT_PATHS=(
    ["mdx-blog-fork"]="$HOME/dev/mdx-blog-fork"
    ["tinkering-tuna"]="$HOME/dev/tinkering-tuna"
    ["tab2do-website"]="$HOME/dev/tab2do-website"
    ["podswitch-web"]="$HOME/dev/podcast-sharing-app/web-app/podswitch-web"
)

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <project_name> <mode> <commit_sha1> [commit_sha2] ..."
    echo "Available projects: ${!MDX_BLOG_ROOT_PATHS[@]}"
    echo "Available modes: copy, edit, commit, status, blow-away"
    exit 1
fi

project_name="$1"
mode="$2"
shift 2
commit_shas=("$@")

# Validate project name
if [[ ! -v MDX_BLOG_ROOT_PATHS["$project_name"] ]]; then
    echo "Error: Project '$project_name' not found in MDX_BLOG_ROOT_PATHS"
    echo "Available projects: ${!MDX_BLOG_ROOT_PATHS[@]}"
    exit 1
fi

# Validate mode
if [[ "$mode" != "copy" && "$mode" != "edit" && "$mode" != "commit" && "$mode" != "status" && "$mode" != "blow-away" ]]; then
    echo "Error: Mode must be one of: copy, edit, commit, status, blow-away"
    exit 1
fi

project_path="${MDX_BLOG_ROOT_PATHS["$project_name"]}"

# Change to the source project directory
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

# Create a combined patch for all source commits
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

# Function to handle copy mode for a single file
copy_file_mode() {
    local relative_file_path="$1"
    local src_file_path="$2"

    if [[ -f "$src_file_path" ]]; then
        echo "Copying file: $relative_file_path"

        for proj_key in "${!MDX_BLOG_ROOT_PATHS[@]}"; do
            # Skip the source project
            if [[ "$proj_key" == "$project_name" ]]; then
                continue
            fi

            proj_path="${MDX_BLOG_ROOT_PATHS[$proj_key]}"
            dest_file_path="$proj_path/$relative_file_path"

            # Create directory if it doesn't exist
            dest_dir=$(dirname "$dest_file_path")
            mkdir -p "$dest_dir"

            # Copy the file
            cp "$src_file_path" "$dest_file_path"
            echo "  -> $proj_key: $dest_file_path"
        done
        echo
    else
        echo "Warning: Source file not found: $src_file_path"
    fi
}

# Function to handle edit mode for a single destination project
edit_file_mode() {
    local dest_project_key="$1"
    local dest_project_path="$2"

    # Edit mode: open vim with patch and corresponding files
    vim_args=("$patch_file")

    # First, add all source files
    for file in "${modified_files_set[@]}"; do
        # Strip the project prefix to get the file path relative to a common structure
        if [[ -n "$project_prefix" && "$file" == "$project_prefix"* ]]; then
            relative_file_path="${file#$project_prefix}"
        else
            relative_file_path="$file"
        fi

        # Add source file
        src_file_path="$project_path/$relative_file_path"
        if [[ -f "$src_file_path" ]]; then
            vim_args+=("$src_file_path")
        fi
    done

    # Then, add all destination files
    for file in "${modified_files_set[@]}"; do
        # Strip the project prefix to get the file path relative to a common structure
        if [[ -n "$project_prefix" && "$file" == "$project_prefix"* ]]; then
            relative_file_path="${file#$project_prefix}"
        else
            relative_file_path="$file"
        fi

        # Add destination file
        dest_file_path="$dest_project_path/$relative_file_path"
        if [[ -f "$dest_file_path" ]]; then
            vim_args+=("$dest_file_path")
        fi
    done

    # Only run vim if we have files to edit beyond just the patch
    if [ ${#vim_args[@]} -gt 1 ]; then
        echo "Opening vim for source project '$project_name' and destination project '$dest_project_key' ..."
        echo
        #sleep 3
        echo vim "${vim_args[@]}"
        echo
        echo "---"
        echo
    fi
}

# Function to handle git add and commit for a single project
commit_project() {
    local proj_key="$1"
    local proj_path="$2"

    echo "Working on repository: $proj_key ($proj_path)"
    echo "---"

    cd "$proj_path"
    git add -p
    git commit

    echo
    echo "Finished with $proj_key"
    echo
}

# Function to handle git status for a single project
status_project() {
    local proj_key="$1"
    local proj_path="$2"

    echo "Status for repository: $proj_key ($proj_path)"
    echo "---"

    cd "$proj_path"
    git status

    echo
}

# Function to handle git checkout -f for a single project
blow_away_project() {
    local proj_key="$1"
    local proj_path="$2"

    echo "Blowing away changes in repository: $proj_key ($proj_path)"
    echo "---"

    cd "$proj_path"
    git checkout -f

    echo "Changes blown away in $proj_key"
    echo
}

# For each modified file, either copy or edit based on mode
if [[ "$mode" == "copy" ]]; then
    # Copy mode: iterate over files
    for file in "${modified_files_set[@]}"; do
        # Strip the project prefix to get the file path relative to a common structure
        if [[ -n "$project_prefix" && "$file" == "$project_prefix"* ]]; then
            relative_file_path="${file#$project_prefix}"
        else
            relative_file_path="$file"
        fi

        #echo "Original file: $file"
        #echo "Relative file path: $relative_file_path"

        copy_file_mode "$relative_file_path" "$project_path/$relative_file_path"
    done

elif [[ "$mode" == "edit" ]]; then
    # Edit mode: iterate over destination projects
    for proj_key in "${!MDX_BLOG_ROOT_PATHS[@]}"; do
        # Skip the source project
        if [[ "$proj_key" == "$project_name" ]]; then
            continue
        fi

        proj_path="${MDX_BLOG_ROOT_PATHS[$proj_key]}"
        edit_file_mode "$proj_key" "$proj_path"
    done

elif [[ "$mode" == "commit" ]]; then
    # Commit mode: loop through each git repo to stage and commit changes
    echo "========================================="
    echo "Now staging and committing changes in each repository..."
    echo "========================================="
    echo

    for proj_key in "${!MDX_BLOG_ROOT_PATHS[@]}"; do
        proj_path="${MDX_BLOG_ROOT_PATHS[$proj_key]}"
        commit_project "$proj_key" "$proj_path"
    done

    echo "All repositories processed!"

elif [[ "$mode" == "status" ]]; then
    # Status mode: loop through each git repo to get status
    echo "========================================="
    echo "Now getting status for each repository..."
    echo "========================================="
    echo

    for proj_key in "${!MDX_BLOG_ROOT_PATHS[@]}"; do
        proj_path="${MDX_BLOG_ROOT_PATHS[$proj_key]}"
        status_project "$proj_key" "$proj_path"
    done

    echo "All repositories processed!"

elif [[ "$mode" == "blow-away" ]]; then
    # Blow away mode: loop through each git repo to blow away changes
    echo "========================================="
    echo "Now blowing away changes in each repository..."
    echo "========================================="
    echo

    for proj_key in "${!MDX_BLOG_ROOT_PATHS[@]}"; do
        proj_path="${MDX_BLOG_ROOT_PATHS[$proj_key]}"
        blow_away_project "$proj_key" "$proj_path"
    done

    echo "All repositories processed!"
fi