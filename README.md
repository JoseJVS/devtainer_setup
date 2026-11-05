# Container Setup

## Isolated structure hierarchy

The container is run in isolation with a read only system image file i.e.
partitions like ```/var```, ```/etc```, ```/usr```, are immutable.
Apptainer bindings are used to allow for persistent changes as well as setting up
directories in which both the host system and the container can interact.
```run_isolated_container.sh``` takes care of creating the directory structure necessary
for the bindings of the container.

The following structure is the binding hierarchy created by run_isolated_container.sh:

```txt
|-- state
    |-- devtainer
        |-- home [rw]
        |-- software [ro]
        |-- overlay [rw]
        |-- data [ro]
        |-- tmp [rw]
        |-- work [rw]

[ro] -> read only
[rw] -> read and write
```

In the following sections, double square brackets point to bind paths generated
by ```run_isolated_container.sh``` as seen by the host.

## Bash Runtime Configuration

* On host side:

```shell
cp minimal-bashrc [[CONTAINER_HOME]]/.bashrc
cp minimal-bash-profile [[CONTAINER_HOME]]/.bash_profile
```

## CMake

To pin CMake to 3.31.10 (otherwise, install via homebrew), on host side:

```shell
cd [[CONTAINER_SOFTWARE]]
wget https://github.com/Kitware/CMake/releases/download/v3.31.10/cmake-3.31.10-linux-x86_64.tar.gz
tar -xzf cmake-3.31.10-linux-x86_64.tar.gz && rm cmake-3.31.10-linux-x86_64.tar.gz
echo >> [[CONTAINER_HOME]]/.bashrc
echo 'export PATH=/software/cmake-3.31.10-linux-x86_64/bin:$PATH' >> [[CONTAINER_HOME]]/.bashrc
```

## Homebrew

* On container side see [brew.sh](https://brew.sh/):

```/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"```

## Applications

* On container side:

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

echo >> $HOME/.bashrc
echo 'alias gdu="gdu-go"' >> $HOME/.bashrc
```

## Neovim Configuration

```shell
mkdir -pv $HOME/.config
git clone --single-branch --depth 1 -b main \
    https://github.com/JoseJVS/nvim_config.git \
    $HOME/.config/nvim

echo >> $HOME/.bashrc
echo 'alias vim="nvim"' >> $HOME/.bashrc
echo 'alias vimdiff="nvim -d"' >> $HOME/.bashrc
```

## Tmux Configuration

* On host side:

```shell
mkdir -pv [[CONTAINER_HOME]]/.config/tmux
cp tmux.conf [[CONTAINER_HOME]]/.config/tmux
```

* On container side (if already on tmux,
otherwise configuration is loaded next time tmux is opened):

```tmux source-file $HOME/.config/tmux/tmux.conf```

* Then to install plugins (during a tmux session, only needs to be done once):

```<ctrl-b>I```
