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

## Homebrew (optional)

* On container side see [brew.sh](https://brew.sh/):

```/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"```

Then follow installer instructions to set up ```.bashrc```.

### Install Development Applications

* On container side:

```shell
# Check hombrew installation success and update brew indexes
brew doctor && brew update

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
    uv \
    gh
```

#### Installing Ranger

* On container side:
```uv tool install ranger-fm```

### Enabling Tmux Configuration

* On container side (if already on tmux,
otherwise configuration is loaded next time tmux is opened):

```tmux source-file $HOME/.config/tmux/tmux.conf```

* Then in tmux session, to install plugins (only needs to be done once):

```<ctrl-b>I```

(This operation requires some time, tmux will display a notification when done.)

### Enabling Neovim Configuration

On container side open ```nvim``` (or with ```vim``` alias),
then accept plugin installation and wait for all LSPs to finish installing.

## Notes

* Remember to set up your GitHub author configuration on container side with:

```shell
git config user.name "Your Name"
git config user.email "you@example.com"
```

### Git Workflow

* **DO NOT** expose ssh keys or API tokens to the container environment.
* Use your keys or tokens to clone and push on the host side.
* On container side, give Claude permission to commit and manipulate branches.
(ideally always asking for approval first)

### `Perf` Workflow

To run `perf` in container it is necessary to have a
low event paranoid level on host side:

* Check paranoid level (default 4):

```shell
sysctl kernel.perf_event_paranoid
```

* Temporarily lower the paranoid level:

```shell
sudo sysctl -w kernel.perf_event_paranoid=-1
```
