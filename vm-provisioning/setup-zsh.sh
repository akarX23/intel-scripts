#!/bin/bash

# Install ZSH
apt-get update -y
apt-get install -y zsh

source /etc/profile.d/proxy_setup.sh
chmod 777 /etc/profile.d/proxy_setup.sh

# Install Oh-My-Zsh
Y | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

source /etc/profile.d/proxy_setup.sh

# Configure Oh-My-Zsh with Jonathan theme and plugins
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="jonathan"/g' /root/.zshrc
sed -i 's/plugins=(git)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions)/g' /root/.zshrc
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git /root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions.git /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# Set ZSH as the default shell for all users
chsh -s $(which zsh) root
for user in $(ls /home); do
  cp /root/.zshrc /home/$user/
  cp -r  /root/.oh-my-zsh /home/$user/
  echo "source /etc/profile.d/proxy_setup.sh" >> /home/$user/.zshrc
  chown $user:$user /home/$user/.oh-my-zsh 
  chown $user:$user /home/$user/.zshrc
  chsh -s $(which zsh) $user
done

echo "source /etc/profile.d/proxy_setup.sh" >> /root/.zshrc
