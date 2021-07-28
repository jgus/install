#!/bin/bash -e

# bash <(curl -s https://jgus.github.io/install/init-snap-vm.sh)

echo "### Adding packages..."
PACKAGES=(
    curl
    open-vm-tools-desktop
    zsh
    git
    fonts-powerline
    cloud-guest-utils
    ssh
    python-pip
    python3-pip
)
# apt-add-repository -y universe
sudo apt update
sudo apt upgrade --yes
sudo apt install --yes "${PACKAGES[@]}"

echo "### Fixing partition..."
sudo growpart /dev/sda 2
sudo resize2fs /dev/sda2

echo "### Setting up zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
chsh -s /usr/bin/zsh
cat << EOF >~/.zshrc
[[ -f ~/.profile ]] && . ~/.profile
export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(
  common-aliases
  git
  rsync
)
source \$ZSH/oh-my-zsh.sh
EOF

echo "### Setting up Git..."
git config --global user.name "Josh Gustafson"
git config --global user.email jgustafson@snap.com

echo "### Setting up SSH..."
mkdir -p ~/.ssh || true
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
curl https://github.com/jgus.keys >> ~/.ssh/authorized_keys
uniq -i ~/.ssh/authorized_keys
chmod 400 ~/.ssh/authorized_keys

echo "### System prep complete; SSH available at:"
ip a | grep inet
