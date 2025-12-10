#!/usr/bin/env zsh

# mkdir then cd
function mkcddir() {
  /bin/mkdir "$1"
  \cd "$1" || return
}

# Delete files matching pattern
function rm-all() {
  if [[ $1 != "" ]]; then
    find . -name "$1" -exec rm -rf {} \;
  else
    echo "ERROR! Type a file name"
  fi
}

# Clean Python cache files
function pyclean() {
  find . -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
}

# Display current date and time
function now() {
  date '+%e, %B (%m) %Y - %H:%M'
}

# diff with clipboard
function diffp() {
  diff <(cat $1) <(pbp)
}

# Search command history
function histsearch() {
  fc -lim "*$@*" 1
}

# Interactive history cleanup
function histclean() {
  # Get the command history and display in reverse
  local number=$(\cat -n $HISTFILE | sort -rn | fzf | awk '{print $1}')

  # Delete the specific line from the history file
  sed -i '' "${number}d" $HISTFILE

  # Reload history
  fc -R
}

# Remove the last command from history
function forget() {
  local number=$(\cat -n $HISTFILE | awk 'END{print $1-1}')

  # Delete the specific line from the history file
  sed -i '' "${number}d" $HISTFILE

  fc -R
}

# Convert between month names and numbers
function month() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    case "$1" in
    1) echo "January" ;;
    2) echo "February" ;;
    3) echo "March" ;;
    4) echo "April" ;;
    5) echo "May" ;;
    6) echo "June" ;;
    7) echo "July" ;;
    8) echo "August" ;;
    9) echo "September" ;;
    10) echo "October" ;;
    11) echo "November" ;;
    12) echo "December" ;;
    *) echo "Invalid month number" ;;
    esac
  else
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    january) echo 1 ;;
    february) echo 2 ;;
    march) echo 3 ;;
    april) echo 4 ;;
    may) echo 5 ;;
    june) echo 6 ;;
    july) echo 7 ;;
    august) echo 8 ;;
    september) echo 9 ;;
    october) echo 10 ;;
    november) echo 11 ;;
    december) echo 12 ;;
    *) echo "Invalid month name" ;;
    esac
  fi
}