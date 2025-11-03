[![Notebook Execution and Validation](https://github.com/spacetelescope/hst_notebooks/actions/workflows/ci_runner.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/ci_runner.yml)
[![Scheduled Notebook Execution](https://github.com/spacetelescope/hst_notebooks/actions/workflows/ci_nightly.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/ci_nightly.yml)
[![Weekly broken link check](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_broken_link_finder.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_broken_link_finder.yml)
[![Weekly HTML Accessibility Check](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_html_accessibility_check.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_html_accessibility_check.yml)
[![Weekly PEP8 Style Checks](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_pep8_style_check.yml/badge.svg)](https://github.com/spacetelescope/hst_notebooks/actions/workflows/weekly_pep8_style_check.yml)

[![DOI](https://zenodo.org/badge/605151805.svg)](https://zenodo.org/badge/latestdoi/605151805)

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
See [this website](https://spacetelescope.github.io/hst_notebooks/)

To download and execute the notebooks, we recommend you clone
the `hst_notebooks <https://github.com/spacetelescope/hst_notebooks>`_
repository to your local computer. 

You can also click the "Download ZIP" option for the entire repository listed under the green "Code" button at the top of the repository landing page. You are also able to download individual notebooks, but it is not as straight forward or recommended, so we do not provide details here.

Most notebooks have additional associated files in their folder,
including a requirements file that lists packages necessary to run the notebooks.
The packages in the requirements file can be installed using `pip <https://pip.pypa.io/en/stable/>`_ . 

Any version dependencies are contained in the requirements file in 
each notebook folder. Please use at least the minimum supported
version of the Python language in your active environment.

Some notebooks use the HSTCAL package. The folders for these notebooks will also contain a shell
script that contains the command to pull the hstcal package from conda-forge instead of pypi.


Clone the Repository
--------------------

Once you've changed to the directory where you cloned this repository, and go to
the notebook directory you are interested in using, and go to your selected 
notebook, as below:

    git clone https://github.com/spacetelescope/hst_notebooks.git
    cd hst_notebooks/notebooks/ACS/acs_cte_forward_model

You can then proceed to install the requirements for the specific notebook you are interested in using.


Run the notebook in an appropriate environment
----------------------------------------------

Once you are in the directory of the notebook you want to use, make sure you have a populated environment that contains the required pacages::

    cd hst_notebooks/notebooks/<notebook-name>

You may want to consider installing your notebooks in a new conda/mamba environment
to avoid version conflicts with other packages you may have installed, for example::

    conda create -n hstnb python pip jupyter
    conda activate hstnb


In the case that there is no pre-requirements.sh file:

    conda create --name hstnb python pip jupyter
    conda activate hstnb
    pip install -r requirements.txt
    

In the case that there is a pre-requirements.sh file, this file is likely
only used to install hstcal. You can either install hstcal in the `hstnb`
environment you created above... 
    
    conda install --yes -c conda-forge hstcal


or you can create the appropriate environment starting 
with hstcal using the following:

    conda create --yes -n hstcal -c conda-forge hstcal
    conda activate hstcal
    pip install -r requirements.txt
    pip install jupyter


It's possible that you also have the `stenv` environment available locally.
In this case, `stenv` should already have hstcal installed. You
can activate the environment, and then update it to use the notebooks requirements file:

    conda activate stenv
    pip install -r requirments.txt
 
If pip reports conflicts, then you might need to follow the above instructions to create
a new, isolated environment instead of using `hstcal`


Help
====
If you uncover any issues or bugs, you can [open an issue on GitHub](https://github.com/spacetelescope/hst_notebooks/issues/new).  
For faster responses, however, we encourage you to submit an [HST Help Desk Ticket](https://hsthelp.stsci.edu).



Contributing
============

New contributions and feedback are very welcomed! Please open a new issue or new 
pull request for bugs, feedback, or new features you would like to see. If there 
is an issue you would like to work on, please leave a comment and we will be happy 
to assist. Questions can also be sent through the [HST Help Desk](https://stsci.service-now.com/hst).

If you wish to contribute new notebooks or major reworks of existing notebooks, see [contributing instructions](https://github.com/spacetelescope/hst_notebooks/blob/main/CONTRIBUTING.md).
