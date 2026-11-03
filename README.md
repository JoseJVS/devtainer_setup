# Container Setup

## Bash Runtime Configuration

```cp minimal-bashrc [[CONTAINER_HOME]]/.bashrc```

## CMake

To pin CMake to 3.31.10 (otherwise, install via homebrew):

```shell
wget https://github.com/Kitware/CMake/releases/download/v3.31.10/cmake-3.31.10-linux-x86_64.tar.gz
tar -xzf cmake-3.31.10-linux-x86_64.tar.gz && rm cmake-3.31.10-linux-x86_64.tar.gz
ln -s $PWD/cmake-3.31.10-linux-x86_64 $HOME/cmake
echo >> $HOME/.bashrc
echo 'export PATH=$HOME/cmake/bin:$PATH' >> $HOME/.bashrc
```

## Homebrew

```/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"```

## Applications

```shell
# Claude
brew install --cask claude-code

# DEV Tools
brew install \
    tmux \
    neovim \
    ripgrep \
    fd \
    fzf \
    lazygit \
    bat \
    gdu \
    btop \
    tree-sitter-cli \
    ranger \
    uv

#GDB Dashboard
wget -P ~ https://github.com/cyrus-and/gdb-dashboard/raw/master/.gdbinit
```
