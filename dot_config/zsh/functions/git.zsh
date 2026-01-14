#!/usr/bin/env zsh

# Easy git checkout with branch creation using fzf
function gch() {
  # If a branch name is provided (and it's not --all), try to checkout or create
  if [[ -n "$1" && "$1" != "--all" ]]; then
    local branch_name="$1"

    # Try to checkout existing branch first (including remote tracking)
    if git checkout "$branch_name" 2>/dev/null; then
      return 0
    fi

    # If checkout failed, check if it's because branch doesn't exist
    local git_error
    git_error=$(git checkout "$branch_name" 2>&1)

    if [[ "$git_error" == *"did not match any file(s) known to git"* ]] || \
       [[ "$git_error" == *"pathspec"*"did not match"* ]]; then
      # Branch doesn't exist - create it
      echo "Branch '$branch_name' doesn't exist. Creating new branch..."
      git checkout -b "$branch_name"
      return $?
    else
      # Other error (like uncommitted changes) - show the actual error
      echo "ERROR: $git_error"
      return 1
    fi
  fi

  # Original fzf behavior when no branch name provided
  local branches branch

  if [[ "$1" == "--all" ]]; then
    # Include remote branches
    branches=$(git branch -a | grep -v HEAD | sed 's/remotes\/origin\///')
  else
    # Local branches only
    branches=$(git branch)
  fi

  branch=$(echo "$branches" | fzf | tr -d ' *')

  if [[ -n "$branch" ]]; then
    git checkout "$branch"
  fi
}

# Undo git commits
function git-undo() {
  local count=${1:-1}     # Default to undoing 1 commit if no argument provided
  local mode=${2:-'soft'} # Default to 'soft' reset if no mode is specified

  if [[ $mode != "hard" && $mode != "soft" ]]; then
    echo "Invalid mode specified. Use 'hard' or 'soft'."
    return 1
  fi

  git reset --$mode "HEAD~$count"
}

# Smart git checkout with branch creation
function gct() {
    local branch_name="$1"
    local create_flag="$2"
    local color_red=$(tput setaf 1)
    local color_green=$(tput setaf 2)
    local color_yellow=$(tput setaf 3)
    local color_reset=$(tput sgr0)

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "${color_red}ERROR!${color_reset} Not in a git repository"
        return 1
    fi

    # Validate branch name input
    if [[ -z "$branch_name" ]]; then
        echo "${color_red}ERROR!${color_reset} ${color_green}You must provide the branch name${color_reset}"
        return 1
    fi

    # If explicit create flag is used, force create new branch
    if [[ "$create_flag" == "--create" ]] || [[ "$create_flag" == "-c" ]]; then
        echo "${color_green}Creating new branch '$branch_name'...${color_reset}"
        git checkout -b "$branch_name"
        return $?
    fi

    # Try to checkout existing branch first (including remote tracking)
    if git checkout "$branch_name" 2>/dev/null; then
        echo "${color_green}Switched to branch '$branch_name'${color_reset}"
        return 0
    fi

    # If checkout failed, check if it's because branch doesn't exist
    local git_error
    git_error=$(git checkout "$branch_name" 2>&1)

    if [[ "$git_error" == *"did not match any file(s) known to git"* ]] || \
       [[ "$git_error" == *"pathspec"*"did not match"* ]]; then
        # Branch doesn't exist - create it implicitly
        echo "${color_yellow}Branch '$branch_name' doesn't exist. Creating new branch...${color_reset}"
        git checkout -b "$branch_name"
        return $?
    else
        # Other error (like uncommitted changes) - show the actual error
        echo "${color_red}ERROR!${color_reset} $git_error"
        return 1
    fi
}
