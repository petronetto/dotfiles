#!/usr/bin/env zsh

# Enable Touch ID for sudo commands in Terminal
# This allows using fingerprint authentication instead of typing password

echo "Configuring Touch ID for sudo commands..."

PAM_FILE="/etc/pam.d/sudo"
PAM_LINE="auth       sufficient     pam_tid.so"

# Check if pam_tid.so is already configured
if grep -q "pam_tid.so" "$PAM_FILE" 2>/dev/null; then
  echo "Touch ID for sudo is already configured"
else
  echo "Adding Touch ID support to $PAM_FILE..."

  # Create a temporary file with the new content
  # The line needs to be added as the first auth line, right after the comment
  TEMP_FILE=$(mktemp)

  # Read the original file and add our line after the first comment line
  awk '
    NR==1 { print; print "auth       sufficient     pam_tid.so"; next }
    { print }
  ' "$PAM_FILE" > "$TEMP_FILE"

  # Replace the original file with sudo
  sudo cp "$TEMP_FILE" "$PAM_FILE"
  rm "$TEMP_FILE"

  echo "Touch ID for sudo has been enabled successfully!"
  echo "You can now use your fingerprint for sudo commands in new Terminal sessions"
fi
