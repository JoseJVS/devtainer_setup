# Container Setup

## Requirements

Tested on Ubuntu 26.04:

* ``fuse3`` [3.18.2]
* ``fuse-overlayfs`` [1.14]
* ``apptainer`` [1.5.5]

Run ```build_devtainer.sh``` once to build the image and ```run_isolated_container.sh```
to generate the isolation directory structure as well as testing the image.

Building the image and the isolation directory structure are done using absolute
paths within ```$HOME/Apptainer``` with the goal of then being able to add
```run_isolated_container.sh``` to the user binaries and work from anywhere
within the host system:

```shell
ln -s $PWD/run_isolated_container.sh $HOME/.local/bin/devtainer
```

(Make sure ```$HOME/.local/bin``` is within ```$PATH```
for ```devtainer``` to be findable).

## Isolated Structure Hierarchy

The container is run in isolation with a read only system image file i.e.
partitions like ```/var```, ```/etc```, ```/usr```, are immutable.
Apptainer bindings are used to allow for persistent changes as well as setting up
directories in which both the host system and the container can interact.
```run_isolated_container.sh``` takes care of creating the directory structure necessary
for the bindings of the container.

The following structure is the binding hierarchy created by run_isolated_container.sh:

```txt
state
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

## Homebrew

* On container side see [brew.sh](https://brew.sh/):

```/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"```

Then follow installer instructions to set up ```.bashrc```.

### Install Development Applications

* On container side:

```shell
# Check hombrew installation success
brew doctor

# Update brew indexes
brew update

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
    uv
```

## Enabling Tmux Configuration

* On container side (if already on tmux,
otherwise configuration is loaded next time tmux is opened):

```tmux source-file $HOME/.config/tmux/tmux.conf```

* Then in tmux session, to install plugins (only needs to be done once):

```<ctrl-b>I```

(This operation requires some time, tmux will display a notification when done.)

## Enabling Neovim Configuration

On container side open ```nvim``` (or with ```vim``` alias),
then accept plugin installation and wait for all LSPs to finish installing.
