#!/usr/bin/env bash

set -euxo pipefail

apptainer_name="devtainer"
apptainer_root="$HOME/Apptainer"
apptainer_image="$apptainer_root/$apptainer_name.sif"
apptainer_state="$apptainer_root/state/$apptainer_name"

software="$apptainer_state/software"
overlay="$apptainer_state/overlay"
home="$apptainer_state/home"
data="$apptainer_state/data"
work="$apptainer_state/work"
tmp="$apptainer_state/tmp"
home_name="$home/$apptainer_name"

# Clear tmp if it previously exist
rm -rf "$tmp"
mkdir -pv "$software" "$overlay" "$home" "$data" "$work" "$tmp" "$home_name"

if [ ! -f "$home_name/.bashrc" ]; then
    cp minimal-bashrc "$home_name/.bashrc"
fi

if [ ! -f "$home_name/.bash_profile" ]; then
    cp minimal-bash-profile "$home_name/.bash_profile"
fi

if [ ! -d "$home_name/.local/bin" ]; then
    mkdir -pv "$home_name/.local/bin"
fi

if [ ! -d "$home_name/.config/tmux" ] || [ ! -f "$home_name/.config/tmux/tmux.conf" ]; then
    mkdir -pv "$home_name/.config/tmux"
    cp tmux.conf "$home_name/.config/tmux/"
fi

if [ ! -d "$home_name/.config/nvim" ]; then
    git clone --single-branch --depth 1 -b main \
        https://github.com/JoseJVS/nvim_config.git \
        "$home_name/.config/nvim"
fi

if [ ! -d "$software/cmake-3.31.10-linux-x86_64" ]; then
    wget https://github.com/Kitware/CMake/releases/download/v3.31.10/cmake-3.31.10-linux-x86_64.tar.gz \
    && tar -xzf cmake-3.31.10-linux-x86_64.tar.gz -C "$software" \
    && rm cmake-3.31.10-linux-x86_64.tar.gz
fi

if [ ! -f "$home_name/.gdbinit" ]; then
    wget -P "$home_name" https://github.com/cyrus-and/gdb-dashboard/raw/master/.gdbinit
fi

gpu_environment=()
if [[ ${CUDA_VISIBLE_DEVICES+x} ]]; then
    gpu_environment+=(
        --env "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
    )
fi

exec env -i \
    HOME="$HOME" \
    PATH="$PATH" \
    TERM="${TERM:-dumb}" \
    apptainer exec \
        --containall \
        --cleanenv \
        --no-eval \
        --no-mount hostfs,bind-paths,cwd \
        --home "$home_name:/home/$apptainer_name" \
        --bind "$home:/home:rw" \
        --bind "$tmp:/tmp:rw" \
        --bind "$work:/work:rw" \
        --bind "$data:/data:ro" \
        --bind "$software:/software:ro" \
        --bind "/etc/resolv.conf:/etc/resolv.conf:ro" \
        --overlay "$overlay" \
        --cwd "/home/$apptainer_name" \
        --env TMPDIR=/tmp \
        "${gpu_environment[@]}" \
        --nv \
        "$apptainer_image" \
        /bin/bash --noprofile --rcfile "/home/$apptainer_name/.bashrc"
