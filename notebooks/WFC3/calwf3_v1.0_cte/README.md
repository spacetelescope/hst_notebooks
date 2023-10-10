This directory, once cloned from the repository, should contain this
`README.md`, the Jupyter Notebook `calwf3_with_v1.0_PCTE.ipynb`, a file
called `archived_drkcfiles.txt` and a subdirectory `example/`.

**In order to run this Jupyter Notebook you must have created a virtual
conda environment that includes `calwf3` v3.5.2.** Version 3.5.2 of `calwf3` 
is available in HSTCAL release 2.5.0. To create an environment with
`calwf3` v3.5.2 try this from the terminal:

```
$ conda config --add channels http://ssb.stsci.edu/astroconda

$ conda create -n v1_PCTE hstcal==2.5.0 python=3.7 ginga stsci-hst notebook
```

In general, users wanting to use the v1.0 pixel-based CTE correction
within `calwf3` should use `calwf3` v3.5.2. This version will provide the
most up-to-date calibration procedures such as time-dependent photometric
corrections and zeropoints, while also including the v1.0 correction.

Questions or concerns should be sent to the [HST Help Desk](https://stsci.service-now.com/hst).
---------------------------------------------------------------------
