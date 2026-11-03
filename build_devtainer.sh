#!/bin/bash

source set_cache_tmp.sh && apptainer build devtainer.sif devtainer.def |& tee build.log
