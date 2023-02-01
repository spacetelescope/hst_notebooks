This notebook is the first in a new Drift And SHift (DASH) pipeline workflow developed to ease the process of reducing DASH data. The pipeline is customizable, able to be changed according to scientific goals of the user, and this first tutorial walks the user from data download to a finished product ready for science analysis.

Installation
------------
`wfc3_dash` requires `lacosmicx` to be installed in the `wfc3_env` virtual environment. `lacosmicx` implements the Laplacian cosmic ray detection algorithm and is needed to reduce dash data. Follow the steps below to install the package:

1. Activate the `wfc3_env` virtual environment in a terminal window:
```
>>> conda activate wfc3_env
```
2. First install `cython` to allow the installation of `lacosmicx`:
```
>>> conda install cython
```
3. Go to https://github.com/cmccully/lacosmicx and clone the repository in the current directory:
```
>>> git clone https://github.com/cmccully/lacosmicx.git
```
4. Change directory to the `lacosmicx` repository:
```
>>> cd lacosmicx
```
5. Install the `lacosmicx` package:
```
>>> python setup.py develop
```
6. **The package is installed; now you will be able to complete the WFC3 Dash notebook.**
