[![Developed For: ACS](https://img.shields.io/badge/developed%20for-ACS-orange.svg?style=flat)](http://www.stsci.edu/hst/acs) [![Powered By: STScI](https://img.shields.io/badge/powered%20by-STScI-blue.svg?colorA=707170&colorB=3e8ddd&style=flat)](http://www.stsci.edu/)

# acs-notebook

This repository contains downloadable versions of several *HST*/ACS webpages with basic Python examples. These code examples are simple and only designed for a limited scope. Users are advised to visit the [ACS website](http://www.stsci.edu/hst/acs), [Instrument Handbook](http://www.stsci.edu/hst/acs/documents/handbooks/current/cover.html), and [Data Handbook](http://www.stsci.edu/hst/acs/documents/handbooks/currentDHB/acs_cover.html) for more information about the the current status of ACS, instrument specifications, and data analysis.

Users who need help transitioning from IRAF/PyRAF to Python should see the [stak-notebooks](https://github.com/spacetelescope/stak-notebooks) repository. 

For examples of workflows with *HST* data, please see the CSI notebooks repository (coming soon).

## About ACS

ACS is a third generation HST instrument that was installed during Servicing Mission 3B in March, 2002. The instrument is comprised of three cameras: the already mentioned WFC, another CCD called the High Resolution Channel (HRC), and a near-UV MAMA detector called the Solar Blind Channel (SBC). In January 2007, an electronics failure caused the WFC and HRC detectors to go offline. New electronics were installed in May 2009 during Servicing Mission 4, and while the WFC was successfully recovered, the HRC remains unavailable since the failure.

The ACS/WFC detector is comprised of two butted CCDs with a 30 pixel gap between them, and the detector provides the largest field of view of any HST instrument at 202 x 202 arcseconds with a spatial resolution of approximately 0.05 arcseconds/pixel. The CCDs are designed to have optimal quantum efficiency (QE) in the middle of the optical spectrum, which complements well the WFC3/UVIS QE that better observes in the near-UV and near-IR. The wavelength coverage of the ACS/WFC is from 3500 - 11,000 Angstroms. The ACS/WFC is capable of broad-, medium-, and narrow-band imaging, tunable wavelength imaging using ramp filters, wide-field slitless spectroscopy with a grism, and it is the only space-based instrument capable of studying polarized optical light.

The ACS/HRC detector is quite similar to the ACS/WFC in its capabilities, however it can measure light farther into the UV (1700 - 11,000 Angstroms). The HRC uses a single 1024 x 1024 CCD with a 26 x 29 arcsecond field of view and with approximately twice the spatial resolution of the WFC (~0.025 arcseconds/pixel). The HRC and WFC share filters, though some filters were designed specifically for the HRC. The use of HRC-specific filters with the WFC is possible, but causes vignetting in the images. The HRC is additionally capable of coronography using either coronographic spots or an occulting finger. **As a reminder, the HRC has been unavailable for new observations since January 27, 2007.**

The ACS/SBC detector is a flight-spare STIS MAMA detector capable of NUV imaging (approximately 1150 - 1700 Angstroms) and prism spectroscopy. Images from the SBC are 1024 x 1024 pixels with a spatial resolution of approximately 0.03 arcseconds/pixel. The field of view of the SBC is 34.6 x 30.5 arcseconds. The SBC prisms provide a resolving power of R = 300 - 350 at 1200 Angstroms decreasing to R = 140 - 160 at near 1700 Angstroms.

More information about the ACS instrument and data from it can be found in the [ACS Instrument Handbook](http://www.stsci.edu/hst/acs/documents/handbooks/current/cover.html) and [ACS Data Handbook](http://www.stsci.edu/hst/acs/documents/handbooks/currentDHB/acs_cover.html).

## Getting Help

If you have questions about HST data analysis, calibration software, instrument capabilities, and/or the methods discussed in this notebook, please visit the [HST Help Desk](http://hsthelp.stsci.edu). Through the help desk portal, you can explore the HST Knowledge Base and request additional help from experts.

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
