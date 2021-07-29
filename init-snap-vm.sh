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

echo "### Installing GCC 10..."
sudo add-apt-repository --yes ppa:ubuntu-toolchain-r/test
sudo apt-get update
sudo apt install gcc-10 g++-10
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 20 --slave /usr/bin/g++ g++ /usr/bin/g++-10

echo "### Installing CMake..."
CMAKE_VER=3.21.1
wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}-linux-x86_64.tar.gz
sudo tar -xvf cmake-${CMAKE_VER}-linux-x86_64.tar.gz -C /usr/local --strip 1
rm cmake-${CMAKE_VER}-linux-x86_64.tar.gz

echo "### Installing Flex..."
FLEX_VER=2.6.1
wget https://github.com/westes/flex/releases/download/v${FLEX_VER}/flex-${FLEX_VER}.tar.xz
tar -xvf flex-${FLEX_VER}.tar.xz
(
    cd flex-${FLEX_VER}
    ./configure
    make
    sudo make install
)
rm -rf flex-${FLEX_VER}*

echo "### Installing Bison..."
BISON_VER=3.7
wget http://ftp.gnu.org/gnu/bison/bison-${BISON_VER}.tar.xz
tar -xvf bison-${BISON_VER}.tar.xz
(
    cd bison-${BISON_VER}
    ./configure
    make
    sudo make install
)
rm -rf flex-${BISON_VER}*

echo "### Installing GTest..."
git clone https://github.com/google/googletest.git
(
    cd googletest
    mkdir build
    cd build
    cmake ..
    make -j
    sudo make install
)
rm -rf googletest

echo "### Installing VS Code..."
wget https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64 -O vscode.deb
sudo dpkg -i vscode.deb
rm -f vscode.deb

echo "### Setting up SSH..."
mkdir -p ~/.ssh || true
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
curl https://github.com/jgus.keys >> ~/.ssh/authorized_keys
uniq -i ~/.ssh/authorized_keys
chmod 400 ~/.ssh/authorized_keys

echo "### System prep complete; SSH available at:"
ip a | grep inet
