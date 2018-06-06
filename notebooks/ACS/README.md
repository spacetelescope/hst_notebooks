[![Developed For: ACS](https://img.shields.io/badge/developed%20for-ACS-orange.svg?style=flat)](http://www.stsci.edu/hst/acs) [![Powered By: STScI](https://img.shields.io/badge/powered%20by-STScI-blue.svg?colorA=707170&colorB=3e8ddd&style=flat)](http://www.stsci.edu/) 

![ACS logo](acs_logo.png)

# acs-notebook

This repository contains Jupyter notebooks to demonstrate how to calibrate and analyze data from the *Hubble Space Telescope* (*HST*) Advanced Camera for Surveys (ACS). Users are advised to visit the [ACS website](http://www.stsci.edu/hst/acs), [Instrument Handbook](http://www.stsci.edu/hst/acs/documents/handbooks/current/cover.html), and [Data Handbook](http://www.stsci.edu/hst/acs/documents/handbooks/currentDHB/acs_cover.html) for more information about the the current status of ACS, instrument specifications, and data analysis.

Users who need help transitioning from IRAF/PyRAF to Python should see the [stak-notebooks](https://github.com/spacetelescope/stak-notebooks) repository. 

If you have questions about HST data analysis, calibration software, instrument capabilities, and/or the methods discussed in this repository, please visit the [HST Help Desk](http://hsthelp.stsci.edu). Through the help desk portal, you can explore the HST Knowledge Base and request additional help from experts.

# Getting Started

To download the notebooks in this repository, simply open a terminal, go to the directory where you would like the notebooks to be, and type
```
git clone https://github.com/spacetelescope/acs-notebook.git
```
which will create a new acs-notebook/ directory containing the contents of this repository.
 
___Warning:___ Before running these examples, you must install or update to the latest version of [AstroConda](https://astroconda.readthedocs.io/en/latest/). Additionally, `astroquery` is not currently included in the AstroConda distribution and a jupyter extension is required for some notebooks. Users will need to run the following:
```
conda install astroquery
conda install nodejs
jupyter labextension install @jupyter-widgets/jupyterlab-manager
jupyter labextension install @jupyterlab/plotly-extension
```
before using the notebooks as many of them use this tool to download datasets for the examples.

Jupyter Notebooks allow code to be packaged with formatted text to create illustrative examples. Users who are unfamiliar with Jupyter Notebooks should also see the [short guide](https://jupyter-notebook-beginner-guide.readthedocs.io/en/latest/) for how to use these tools. Users may also prefer to use [Jupyter Lab](http://jupyterlab.readthedocs.io/en/stable/), which is another helpful tool that can be used to view these tutorials, but will need to be installed in addition to AstroConda.

# Contents

## Complex Workflow Notebooks

* **acs_reduction.py**: This notebook walks a user through an example of how to: 1) download data from MAST using `astroquery`, 2) update calibration information in the FITS primary headers, 3) calibration ACS observations using `calacs`, 4) align images to a common WCS, and 5) combine images using `AstroDrizzle`.

## Simple Example Notebooks

* **acs_subarrays.ipynb**: Instructions for how to use the `acs_destripe_plus` code to calibrate, de-stripe, and correct ACS subarray observations for charge transfer efficiency (CTE). Also included are instructions for updating the `OSCNTAB` reference file to subtract the bias level from the prescan columns in user-defined subarray observations.

* **acs_zeropoints.ipynb**: A description of the ACS photometric systems, header keywords, and topics related to photometrically calibrating ACS data. 

* **pixel_area_maps.ipynb**: How to use Python to create pixel area maps (PAMs) to account for the effects of geometric distortion in distorted images. This enables users to perform photometry on distorted images if desired.

## Contributing

If you have feedback concerning our documentation or examples presented here on GitHub, please open an [issue](https://github.com/spacetelescope/acs-notebook/issues). For feedback concerning content exclusively from the ACS website, Instrument Handbook, or Data Handbook, or for questions about ACS in general, please contact the ACS Branch at STScI via the [Hubble Space Telescope Help Desk portal](http://hsthelp.stsci.edu). 
