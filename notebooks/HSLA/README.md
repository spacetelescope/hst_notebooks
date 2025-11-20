![STScI Logo](../../_static/stsci_header.png)

# HSLA Notebooks 

## Jupyter Notebook Walkthroughs of Hubble Spectroscopic Legacy Archive (HSLA) Data
The new [Hubble Spectroscopic Legacy Archive](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/cos/documentation/instrument-science-reports-isrs/_documents/COS_ISR_2025_18.pdf) (HSLA) provides scientifically validated coadded spectra of individual targets that have been observed with the [Cosmic Origins Spectrograph](https://www.stsci.edu/hst/instrumentation/cos) (COS) and the [Space Telescope Imaging Spectrograph](https://www.stsci.edu/hst/instrumentation/stis) (STIS) over their operating lifetime. HSLA uses data available in the [Mikulski Archive for Space Telescopes](https://archive.stsci.edu) (MAST) and automatically produces coadds whenever new data become publicly available, or when there is newly recalibrated data. This is a repository of interactive walkthrough guides to HSLA data procedures. It is intended for any and all COS data users: from undergraduates, to professional astronomers, to the general public.

A key feature of the new HSLA is that it automatically defines individual targets, groups multiple observations of a single target into associations, and produces a classification for each target. Target associations make use of the dataset coordinates accounting for proper motions, and uses SIMBAD, NED and the Phase II observing proposals to determine which datasets should be associated with each unique target. Then, using the SIMBAD, NED, or Phase II keywords, a detailed classification is determined for an object to aid in the spectroscopic study of classes of astrophysical objects. The HSLA has spectra for over 3000 individual stars and over 2000 individual galaxies.


## Before Running a Notebook
Before running these examples, you **must** follow the general instructions on creating an environment that can run the notebooks, shown in STScI HST Notebook Repository HQ page under [**Installation Instructions**](https://spacetelescope.github.io/hst_notebooks/index.html).


## Current Notebooks

If you don't want to run the Notebooks for yourself but just want to see rendered html versions of the Notebooks, *(with outputs,)* you may use the rendered `html` file.

|Name|Topic|Notebook file (`ipynb`)|Rendered file (`html`)|
|-|-|-|-|
|Setup|Setting up an environment to work with HSLA data|[Setup.ipynb](https://github.com/spacetelescope/hst_notebooks/blob/main/notebooks/HSLA/Setup/Setup.ipynb)|[Setup.html](https://spacetelescope.github.io/hst_notebooks/notebooks/HSLA/Setup/Setup.html)|
|Intro|Explores the standard HSLA data files returned by MAST|[Intro.ipynb](https://github.com/spacetelescope/hst_notebooks/blob/master/notebooks/HSLA/Intro/Intro.ipynb)|[Intro.html](https://spacetelescope.github.io/hst_notebooks/notebooks/HSLA/Intro/Intro.html)|
|COSLifetimePositions|Explores how the COS line-spread function (LSF) varies with LP and CENWAVE|[COSLifetimePositions.ipynb](https://github.com/spacetelescope/hst_notebooks/blob/master/notebooks/HSLA/COSLifetimePositions/COSLifetimePositions.ipynb)|[COSLifetimePositions.html](https://spacetelescope.github.io/hst_notebooks/notebooks/HSLA/COSLifetimePositions/COSLifetimePositions.html)|


### For Notebooks with exercises, you can find worked solutions at the end of the Notebook.


## Contributing

New contributions and feedback are very welcomed! Please open a new [issue](https://github.com/spacetelescope/hst_notebooks/issues) or new pull request for bugs, feedback, or new features you would like to see. If there is an issue you would like to work on, please leave a comment and we will be happy to assist. Questions can also be sent to the COS team through the [HST Help Desk](https://stsci.service-now.com/hst).

