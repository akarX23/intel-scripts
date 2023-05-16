#!/bin/bash

# Function to set up ZSH for a specific user
setup_zsh_for_user() {
  local user="$1"
  local home_dir=$(eval echo "~$user")

  # Install ZSH
  sudo apt-get update -y
  sudo apt-get install -y zsh

  source /etc/profile.d/proxy_setup.sh
  sudo chmod 777 /etc/profile.d/proxy_setup.sh

  # Install Oh-My-Zsh
  yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  source /etc/profile.d/proxy_setup.sh

  # Configure Oh-My-Zsh with Jonathan theme and plugins
  sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="jonathan"/g' "$home_dir/.zshrc"
  sed -i 's/plugins=(git)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/g' "$home_dir/.zshrc"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$home_dir/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  git clone https://github.com/zsh-users/zsh-autosuggestions.git "$home_dir/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

  # Set ZSH as the default shell for the user
  sudo chsh -s $(which zsh) "$user"

  # Set up proxy setup script
  echo "source /etc/profile.d/proxy_setup.sh" >> "$home_dir/.zshrc"
  sudo chown -R "$user:$user" "$home_dir/.oh-my-zsh" "$home_dir/.zshrc"
}

# Install ZSH for all users if specified
if [ "$1" == "--all-users" ]; then
  for user in $(ls /home); do
    setup_zsh_for_user "$user"
  done
else
  # Check if user argument is provided
  if [ -z "$1" ]; then
    echo "Please provide a user as an argument or use the --all-users flag to install ZSH for all users."
    exit 1
  fi

  # Check if the user exists
  if id "$1" >/dev/null 2>&1; then
    setup_zsh_for_user "$1"
  else
    echo "User $1 does not exist."
    exit 1
  fi
fi

echo "ZSH setup complete."