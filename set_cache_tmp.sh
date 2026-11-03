#!/bin/bash

export APPTAINER_CACHEDIR="$HOME/Apptainer/build_cache"
export APPTAINER_TMPDIR="$HOME/Apptainer/build_tmp"

mkdir -pv "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"
