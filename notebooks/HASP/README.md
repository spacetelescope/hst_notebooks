![STScI Logo](../../_static/stsci_header.png)

# HASP Notebooks 

## Jupyter Notebook Walkthroughs of Hubble Advanced Spectral Products (HASP) Data
The [Hubble Advanced Spectral Products](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/cos/documentation/instrument-science-reports-isrs/_documents/ISR2024-01.pdf) (HASP) transforms the way the MAST community accesses and utilizes [Hubble Space Telescope](https://www.stsci.edu/hst/about) (HST) spectroscopic data. HASP offers an innovative and automated approach to coadding and combining data to obtain high-quality one-dimensional spectra from HST's [Cosmic Origins Spectrograph](https://www.stsci.edu/hst/instrumentation/cos) (COS) and the [Space Telescope Imaging Spectrograph](https://www.stsci.edu/hst/instrumentation/stis) (STIS). Products are automatically updated when new data come in or new calibrations are made available, ensuring users always have access to the latest insights.

The ultimate goal of HASP is to simplify and enhance access to HST spectroscopic data by providing high-quality 1-D spectra that are both robust and flexible. By default, combinations of different gratings, central wavelengths (CENWAVEs), or apertures for individual programs are not provided, necessitating users to manually coadd spectra for scientific analyses. HASP generates two crucial data products: coadds and abutments, created at both the visit and program levels. Coadded spectra result from combining data from a common grating, while abutments involve merging spectra from different gratings and/or instruments. HASP not only automatically coadds most datasets but also provides tools for users to create custom coadds, offering further flexibility and control over the coaddition process. These notebooks explore these data products and tools. 


## Before Running a Notebook
Before running these examples you **must** follow the general instructions on creating an environment that can run the notebooks, shown in STScI HST Notebook Repository HQ page under [**Installation Instructions**](https://spacetelescope.github.io/hst_notebooks/index.html).


## Current Notebooks

If you don't want to run the Notebooks for yourself but just want to see rendered html versions of the Notebooks, *(with outputs,)* you may use the rendered `html` file.

|Name|Topic|Notebook file (`ipynb`)|Rendered file (`html`)|
|-|-|-|-|
|Setup|Setting up an environment to work with HASP data|[Setup.ipynb](https://github.com/spacetelescope/hst_notebooks/blob/main/notebooks/HASP/Setup/Setup.ipynb)|[Setup.html](https://spacetelescope.github.io/hst_notebooks/notebooks/HASP/Setup/Setup.html)|
|CoaddTutorial|Downloading and using the HASP co-add script|[CoaddTutorial.ipynb](https://github.com/spacetelescope/hst_notebooks/blob/main/notebooks/HASP/CoaddTutorial/CoaddTutorial.ipynb)|[CoaddTutorial.html](https://spacetelescope.github.io/hst_notebooks/notebooks/HASP/CoaddTutorial/CoaddTutorial.html)|
|FluxScaleTutorial|Handling input spectra with different fluxes with the HASP co-add script|[FluxScaleTutorial.ipynb](https://github.com/spacetelescope/hst_notebooks/blob/main/notebooks/HASP/FluxScaleTutorial/FluxScaleTutorial.ipynb)|[FluxScaleTutorial.html](https://spacetelescope.github.io/hst_notebooks/notebooks/HASP/FluxScaleTutorial/FluxScaleTutorial.html)|
|DataDiagnostic|How to examine the input spectra for the HASP co-add code and determine what was and was not included in the coadded data product output|[DataDiagnostic.ipynb](https://github.com/spacetelescope/hst_notebooks/blob/main/notebooks/HASP/DataDiagnostic/DataDiagnostics.ipynb)|[DataDiagnostic.html](https://spacetelescope.github.io/hst_notebooks/notebooks/HASP/DataDiagnostic/DataDiagnostic.html)|
|WavelengthAdjustment|Making wavelength adjustments to COS and STIS data when running the HASP co-add script|[WavelengthAdjustment.ipynb](https://github.com/spacetelescope/hst_notebooks/blob/main/notebooks/HASP/WavelengthAdjustment/WavelengthAdjustment.ipynb)|[WavelengthAdjustment.html](https://spacetelescope.github.io/hst_notebooks/notebooks/HASP/WavelengthAdjustment/WavelengthAdjustment.html)|


### For Notebooks with exercises, you can find worked solutions at the end of the Notebook.


## Contributing

New contributions and feedback are very welcomed! Please open a new [issue](https://github.com/spacetelescope/hst_notebooks/issues) or new pull request for bugs, feedback, or new features you would like to see. If there is an issue you would like to work on, please leave a comment and we will be happy to assist. Questions can also be sent to the COS team through the [HST Help Desk](https://stsci.service-now.com/hst).

