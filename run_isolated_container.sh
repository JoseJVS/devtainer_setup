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

mkdir -pv "$software" "$overlay" "$home" "$data" "$work" "$tmp"

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
        --home "$home:/home" \
        --bind "$tmp:/tmp:rw" \
        --bind "$work:/work:rw" \
        --bind "$data:/data:ro" \
        --bind "$software:/software:ro" \
        --bind "/etc/resolv.conf:/etc/resolv.conf:ro" \
        --overlay "$overlay" \
        --cwd /home \
        --env TMPDIR=/tmp \
        "${gpu_environment[@]}" \
        --nv \
        "$apptainer_image" \
        /bin/bash --noprofile --rcfile /home/.bashrc
