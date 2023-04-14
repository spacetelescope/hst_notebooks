# STIS-Notebooks

## Jupyter Notebook Tutorials for Working with Space Telescope Imaging Spectrograph (STIS) Data and observation planning.
The [Space Telescope Imaging Spectrograph](https://www.stsci.edu/hst/instrumentation/stis) (STIS) is an instrument on board the [Hubble Space Telescope](https://www.stsci.edu/hst/about) (HST). This is a repository of interactive tutorials for working with STIS data and planning observations.  A complete list of available tools can be found on the [STIS data and software tools website](https://www.stsci.edu/hst/instrumentation/stis/data-analysis-and-software-tools).

The current operational notebooks with a short description:

### STIS Coronagraphic Visualization Tool
Jupyter Notebook that assists users in planning and preparing STIS coronagraphic observations.
### STIS DrizzlePac Tutorial
Jupyter Notebook for aligning and combining STIS images with [DrizzlePac](https://www.stsci.edu/scientific-community/software/drizzlepac.html). 
### View data
The tutorial introduces handling STIS Data extensions, including examining Data Quality Flags. Several strategies explore how to visually examine STIS Data within a notebook to reproduce plots and tables. A section on using TIME-TAG mode data shows how to construct a flux plot and generate ACCUM images from TIME-TAG data with the stistools with the int_tag tool. A section on the STIS Gratings Echelle mode data shows how to display the echelle image and plot echelles by spectral order.
### Calstis 2D CCD
An introductory Jupyter Notebook that provides background for the different calibration steps for the CCD from the raw fits file to the flat fielded (flt) file.  This also shows why there is often negative counts (or flux) values in STIS data.  The six calibration steps shown are initializing the data quality array, large scale bias and overscale subtraction, small scale bias subtraction, cosmic ray correction, dark signal subtraction, and flat field correction.
### 1D extraction
An introductory Jupyter Notebook that shows how to visualize the 1-D extraction. This is useful for cases where a user may want to do a custom extraction or background subtraction.  It shows how to find the important keywords and plot the extraction and background regions used for the extraction to generate x1d data.  The notebook contains an example with a first order spectrum and with echelle data.
### Imaging Acquisition
An introductory Jupyter Notebook that shows how to visualize and obtain information about a target acquisition. It provides examples for a successful acquisition and several typical failure cases.
### Cross-Correlation
A complementary Jupyter Notebook to the Acquisition Notebook, that shows how to find and correct the zero point spectral shift using cross-correlation.
### Custom CCD Darks
An introductory Jupyter Notebook showing how to create a custom CCD dark reference file by making the baseline dark and then the week dark using the refstis package.

Each folder has a HTML file that can be opened in a browser after cloning this repository. The HTML file is identical to the notebook, except they contain output plots and tables.

## Basic Requirements
The following sections are based on and have been adapted from the [COS-Notebooks README](https://github.com/spacetelescope/notebooks/blob/master/notebooks/COS/README.md).

### Computer requirements
These Notebooks have been tested primarily on `Unix` and `Unix`-`like` systems, (i.e. **MacOS**). As such **Users may encounter issues when run on Windows computers**. If you are unable to run a particular Notebook from a Windows device, please reach out to us (see [Getting Help](#ch4)) and we will work to fix the problem. The first solution to try if the Notebooks are failing because of a Windows incompatibility is using the [Windows Sub-System for Linux](https://docs.microsoft.com/en-us/windows/wsl/) (WSL), which will allow you to run a Linux computer environment from your Windows device.


### Downloading the Notebooks

Users can run most of the Notebooks with only the `ipynb` file downloaded, or clone the repository. To clone (which means download, in the language of `git`,) the repository with all the STIS-Notebooks, run the following command from a terminal in the directory where you would like to download the Notebook repository. 

```bash
git clone https://github.com/spacetelescope/STIS-Notebooks.git
```

### Using Jupyter Notebooks
If you have never used Jupyter/IPython Notebooks before, please see the [Jupyter/IPython Notebook Quick Start Guide](https://jupyter-notebook-beginner-guide.readthedocs.io/en/latest/).

#### Installing Jupyter

You need to be able to run Jupyter Notebooks and install python packages. If you don't have Jupyter installed, continue reading, or see the [Jupyter Docs](https://jupyterlab.readthedocs.io/en/stable/getting_started/installation.html) for much more detailed installation instructions.

If you have `pip` or `conda` installed:


|`pip`|`conda`|
|-----|--------------------------------|
|`pip install jupyterlab`|`conda install -c conda-forge jupyterlab`|


### Python environment
STScI has recently replaced `astroconda` with `stenv`.  See [stenv](https://stenv.readthedocs.io/) for more details on how to set up and install this environment.

We also provide the environment that was used when testing the introductory notebooks in `stis_env.yml`.


#### Running Jupyter

From a new terminal (*make sure that the current working directory encompasses your Notebook directory*), simply run either:

`jupyter notebook` to begin a Notebook kernel (*recommended for new users*)

*OR*

`jupyter lab` to begin a lab kernel (*more versatile for advanced users*)

Either of the previous commands should open up a new window in your default web browser (with an address like `localhost:8888/`). From there you can navigate to a Notebook and open it.

If you don't have experience installing packages, you should begin with the **COS introductory Notebook** [Setup.ipynb](https://github.com/spacetelescope/notebooks/blob/master/notebooks/COS/Setup/Setup.ipynb) on setting up an environment for running astronomical Python code. If you do not yet have Jupyter up-and-running, you can read the pre-rendered (`.html`) version [here](https://spacetelescope.github.io/COS-Notebooks/Setup.html).

<a id=ch3></a>
## Notes for those new to `Python`/`Jupyter`/Coding:

Tips are from COS-Notebooks.
- You will frequently see exclamation points (**\!**) or dollar signs (**\$**) at the beginning of a line of code. These are not part of the actual commands. The exclamation points tell a Jupyter Notebook to pass the following line to the command line, and the dollar sign merely indicates the start of a terminal prompt. 
- Similarly, when a variable or argument in a line of code is surrounded by sharp brackets, like \<these words are\>, this is an indication that the variable or argument is something which you should change to suit your data.

- If you install the full Anaconda distribution with the [*Anaconda Navigator* tool](https://docs.anaconda.com/anaconda/navigator/), (see Section 1 of the `Setup.ipynb` COS Notebook) you will also have access to a graphical interface (AKA a way to use windows and a point-and-click interface instead of the terminal for installing packages and managing environments).
  
<a id = ch4></a>
## Getting Help

If you have an issue using these Notebooks, believe you have discovered an error in a Notebook or have suggestions for future Notebooks, please reach out to the [HST Help Desk](https://stsci.service-now.com/hst).
