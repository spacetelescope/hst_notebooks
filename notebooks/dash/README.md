This notebook is the first in a new Drift And SHift (DASH) pipeline workflow developed to ease the process of reducing DASH data. The pipeline is customizable, able to be changed according to scientific goals of the user, and this first tutorial walks the user from data download to a finished product ready for science analysis.

Installation
------------
`wfc3_dash` requires `lacosmicx` to be installed in the environment from [WFC3 Library's](https://github.com/spacetelescope/WFC3Library) installation instructions. `lacosmicx` implements the Laplacian cosmic ray detection algorithm and is needed to reduce dash data. After activating the virtual environment, follow the steps below to install the package:

1. Install `cython` to allow the installation of `lacosmicx`:
```
>>> conda install cython
```
2. Go to https://github.com/cmccully/lacosmicx and clone the repository in the current directory:
```
>>> git clone https://github.com/cmccully/lacosmicx.git
```
3. Change directory to the `lacosmicx` repository:
```
>>> cd lacosmicx
```
4. Install the `lacosmicx` package:
```
>>> python setup.py develop
```
5. **The package is installed; now you will be able to complete the WFC3 Dash notebook.**
