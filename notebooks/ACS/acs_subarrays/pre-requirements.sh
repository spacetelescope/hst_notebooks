#! /bin/bash
conda create --yes -n hst-env python=3.11 # conda
conda activate hst-env
conda install --yes -c conda-forge hstcal
