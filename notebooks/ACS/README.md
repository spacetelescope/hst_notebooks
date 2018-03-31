# acs-notebook

This repository contains downloadable versions of several *HST*/ACS webpages with basic Python examples. These code examples are simple and only designed for a limited scope. Before running these examples, you must install or update to the latest version of [AstroConda](https://astroconda.readthedocs.io/en/latest/).

Users who need help transitioning from IRAF/PyRAF to Python should see the [stak-notebooks](https://github.com/spacetelescope/stak-notebooks) repository. 

For examples of workflows with *HST* data, please see the CSI notebooks repository (coming soon).

## Getting Started

To download the notebooks in this repository, simply open a terminal, go to the directory where you would like the notebooks to be, and type
```
git clone https://github.com/spacetelescope/acs-notebook.git
```
which will create a new acs-notebook/ directory containing the contents of this repository.

Jupyter Notebooks allow code to be packaged with formatted text to create illustrative examples. Users who are unfamiliar with Jupyter Notebooks should also see the [short guide](https://jupyter-notebook-beginner-guide.readthedocs.io/en/latest/) for how to use these tools.

## Active Notebooks

* **acs_zeropoints.ipynb**: A description of the ACS photometric systems, header keywords, and topics related to photometrically calibrating ACS data. 


* **acs_subarray_cte.ipynb**: Instructions for how to use the `acs_destripe_plus` code to calibrate, de-stripe, and correct ACS subarray observations for charge transfer efficiency (CTE).

## Contributing

If you have feedback concerning our documentation or examples presented here, please open an [issue](https://github.com/spacetelescope/acs-notebook/issues). For questions about the ACS instrument or data, please contact the ACS Branch at STScI via the [Hubble Space Telescope Help Desk portal](http://hsthelp.stsci.edu). 
