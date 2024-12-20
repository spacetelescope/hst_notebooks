[![Notebook Execution and Validation](https://github.com/spacetelescope/hst_notebooks/actions/workflows/ci_runner.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/ci_runner.yml)
[![Scheduled Notebook Execution](https://github.com/spacetelescope/hst_notebooks/actions/workflows/ci_nightly.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/ci_nightly.yml)
[![Weekly broken link check](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_broken_link_finder.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_broken_link_finder.yml)
[![Weekly HTML Accessibility Check](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_html_accessibility_check.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_html_accessibility_check.yml)
[![Weekly PEP8 Style Checks](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_pep8_style_check.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_pep8_style_check.yml)


Summary and Description
=======================
The ``hst_notebooks`` repository contains notebooks illustrating workflows for post-pipeline analysis of Hubble Space Telescope (HST) data. Some of the notebooks also illustrate generic analysis workflows that are applicable to data from other observatories as well. This repository and the notebooks are one component of STScI's larger Data Analysis Tools Ecosystem.

The following [page](https://spacetelescope.github.io/hst_notebooks/) summarizes and links to the material currently available.

Instrument Documentation
------------------------
Here, you can find detailed documentation for each instrument the Hubble Space Telescope uses.

- [Advanced Camera for Surveys (ACS)](https://www.stsci.edu/hst/instrumentation/acs)

- [Cosmic Origins Spectrograph (COS)](https://www.stsci.edu/hst/instrumentation/cos)

- [DrizzlePac](https://www.stsci.edu/scientific-community/software/drizzlepac)

- [Near Infrared Camera and Multi-Object Spectrometer (NICMOS)](https://www.stsci.edu/hst/instrumentation/legacy/nicmos)

- [Space Telescope Imaging Spectrograph (STIS)](https://www.stsci.edu/hst/instrumentation/stis)

- [Wide Field Camera 3 (WFC3)](https://www.stsci.edu/hst/instrumentation/wfc3)
  

Installation Instructions
=========================

You can view rendered versions of the notebooks in this repository,
it requires no special tools beyond your web browser.

To download and execute the notebooks, we recommend you clone
the `hst_notebooks <https://github.com/spacetelescope/hst_notebooks>`_
repository to your local computer. You can also click the "Download ZIP"
option for the entire repository listed under the green "Code" button at
the top of the repository landing page. You could download individual notebooks,
but it is not as straight forward or recommended, so we do not provide details here.

Most notebooks have additional associated files in their folder,
including a requirements document that lists packages necessary to run the notebooks.
These packages can be installed using `pip <https://pip.pypa.io/en/stable/>`_. 
The version dependencies are listed in the environment.yaml and in the requirements file in 
each notebook folder. Please use the minimum supported version of the Python language.

Create Your Local Environment and Clone the Repo
------------------------------------------------

You may want to consider installing your notebooks in a new virtual or conda environment
to avoid version conflicts with other packages you may have installed, for example::

    conda create -n hst-nb python=3.11
    conda activate hst-nb

Once you've changed to the directory where you cloned this repository, as below:

    git clone https://github.com/spacetelescope/hst_notebooks.git

You can then proceed to install the requirements for the specific notebook you are interested in using.

Pip Install Notebook Requirements
---------------------------------

Next, move into the directory of the notebook you want to install and set up the requirements::

    cd hst_notebooks/notebooks/<whatever-notebook>
    pip install -r pre-requirements.txt (if necessary)
    pip install -r requirements.txt
    pip install jupyter
    jupyter notebook
    ## Alternatively, you can use jupyter lab
    
Help
====
If you uncover any issues or bugs, you can [open an issue on GitHub](https://github.com/spacetelescope/hst_notebooks/issues/new).  
For faster responses, however, we encourage you to submit an [HST Help Desk Ticket](https://hsthelp.stsci.edu): 



Contributing
============

New contributions and feedback are very welcomed! Please open a new issue or new 
pull request for bugs, feedback, or new features you would like to see. If there 
is an issue you would like to work on, please leave a comment and we will be happy 
to assist. Questions can also be sent through the [HST Help Desk](https://stsci.service-now.com/hst).

If you wish to contribute new notebooks or major reworks of existing notebooks, see [contributing instructions](https://github.com/spacetelescope/hst_notebooks/blob/main/CONTRIBUTING.md).
