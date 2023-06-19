WFC3Library
===========

Here the user will find the latest Python-based software notebooks for the Wide
Field Camera 3 (WFC3) on the Hubble Space Telescope (HST). For our primary WFC3
user-support tools, see [wfc3tools](https://github.com/spacetelescope/wfc3tools) and 
[WFC3 Software Tools](https://www.stsci.edu/hst/instrumentation/wfc3/software-tools).

WFC3Library is the primary repository for Jupyter notebooks, including general tools, 
WFC3/IR, time variable background (TVB), and photometry. This repository contains the 
complementary notebooks mentioned in the [WFC3 Data Handbook](https://hst-docs.stsci.edu/wfc3dhb). 
These notebooks include:

General Tools:
- WFC3 Image Displayer and Analyzer
- Exception Report Checklist - WFC3
- Processing WFC3/UVIS Data with `calwf3` Using the v1.0 CTE-Correction

WFC3/IR:
- Masking Persistence in WFC3/IR Images
- How to use `wfc3_dash` on DASH data

WFC3/IR Time Variable Background (TVB):
- WFC3/IR IMA Visualization Tools with an Example of Time Variable Background
- Manual Recalibration of Images using `calwf3`: Turning off the WFC3/IR Linear Ramp Fit
- Correcting for Helium Line Emission Background in WFC3/IR Exposures using the "Flatten-Ramp" Technique
- Correcting for Scattered Light in WFC3/IR Exposures: Manually Subtracting Bad Reads
- Correcting for Scattered Light in WFC3/IR Exposures: Using `calwf3` to Mask Bad Reads

Photometry:
- WFC3/UVIS Filter Transformations with `stsynphot`
- Flux Unit Conversions with `synphot` and `stsynphot`
- Synthetic Photometry Examples for WFC3
- WFC3/UVIS Time-dependent Photometry
- Calculating WFC3 Zeropoints with `stsynphot`
- WFC3/UVIS Pixel Area Map Corrections for Subarrays

Each folder in `notebooks` has an individual `README.md` with further 
details and a HTML file that can be opened in a browser after cloning this 
repository. The HTML file is identical to the notebook, except they contain 
output plots and tables.

Installation
------------

All notebooks require the virtual environment `stenv-stable` (last stable 
version used for review was December 2022), which contains libraries necessary
for processing and analyzing data from the Hubble Space Telescope (HST) and the
James Webb Space Telescope (JWST).

To install, see [stenv readthedocs](https://stenv.readthedocs.io/en/latest/)
or [stenv GitHub](https://github.com/spacetelescope/stenv). 

In addition, the individual `README.md` files in `notebooks` may have 
further installation instructions. Please read them to run the notebooks 
properly.

With the environment activated and additional libraries installed based on the
individual `README.md` files, you will be able to complete the notebooks.

Installation (Legacy Environment)
---------------------------------

**WARNING: `wfc3_env` is a legacy environment, meaning it is deprecated**
**and no longer maintained. We recommend using `stenv-stable` in all cases.**

All notebooks used to require the same anaconda virtual environment named 
`wfc3_env`. To create the virtual environment, run this line in a terminal 
window:

    conda env create -f wfc3_env_legacy.yml

To activate `wfc3_env`, run this line in a terminal window:

    conda activate wfc3_env

You can also create and activate `wfc3_env_no_builds`, which is `wfc3_env` 
but without the build specifications to avoid platform specific conflicts.

Please read the individual `README.md` files in `notebooks` for further 
installation instructions.

Contributing
------------

Please open a new issue or new pull request for bugs, feedback, or new features
you would like to see. If there is an issue you would like to work on, please
leave a comment and we will be happy to assist. New contributions and
contributors are very welcome!

WFC3Library follows the 
[Astropy Code of Conduct](https://www.astropy.org/code_of_conduct.html)
and strives to provide a welcoming community to all of our users and 
contributors.

Want more information about how to make a contribution?  Take a look at
the the `astropy` 
[contributing](https://www.astropy.org/contribute.html)
and [developer](https://docs.astropy.org/en/stable/index.html#developer-documentation) 
documentation.


License
-------

WFC3Library is licensed under a 3-clause BSD style license (see the `LICENSE.txt` file).
