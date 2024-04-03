WFC3 Notebooks
==============

WFC3 Notebooks is the primary repository for analyzing data from the 
[Wide Field Camera 3](https://www.stsci.edu/hst/instrumentation/wfc3) on the 
Hubble Space Telescope. The Jupyter notebooks include tools for general data analysis, 
WFC3/IR time variable background (TVB), and photometry. This repository contains the 
complementary notebooks mentioned in the [WFC3 Data Handbook](https://hst-docs.stsci.edu/wfc3dhb).
These notebooks include:

General Tools:
- [WFC3 Image Displayer and Analyzer](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/image_displayer_analyzer/wfc3_image_displayer_analyzer.html)
- [Exception Report Checklist - WFC3](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/exception_report/wfc3_exception_report.html)
- [Processing WFC3/UVIS Data with `calwf3` Using the v1.0 CTE-Correction](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/calwf3_v1.0_cte/calwf3_with_v1.0_PCTE.html)
- [Masking Persistence in WFC3/IR Images](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/persistence/wfc3_ir_persistence.html)

WFC3/IR Time Variable Background (TVB):
- [WFC3/IR IMA Visualization Tools with an Example of Time Variable Background](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/ir_ima_visualization/IR_IMA_Visualization_with_an_Example_of_Time_Variable_Background.html)
- [Manual Recalibration of Images using `calwf3`: Turning off the WFC3/IR Linear Ramp Fit](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/calwf3_recalibration/calwf3_recal_tvb.html)
- [Correcting for Helium Line Emission Background in WFC3/IR Exposures using the "Flatten-Ramp" Technique](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/tvb_flattenramp/TVB_flattenramp_notebook.html)
- [Correcting for Scattered Light in WFC3/IR Exposures: Manually Subtracting Bad Reads](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/ir_scattered_light_manual_corrections/Correcting_for_Scattered_Light_in_IR_Exposures_by_Manually_Subtracting_Bad_Reads.html)
- [Correcting for Scattered Light in WFC3/IR Exposures: Using `calwf3` to Mask Bad Reads](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/ir_scattered_light_calwf3_corrections/Correcting_for_Scattered_Light_in_IR_Exposures_Using_calwf3_to_Mask_Bad_Reads.html)

Photometry:
- [WFC3/UVIS Filter Transformations with `stsynphot`](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/filter_transformations/filter_transformations.html)
- [Flux Unit Conversions with `synphot` and `stsynphot`](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/flux_conversion_tool/flux_conversion_tool.html)
- [Synthetic Photometry Examples for WFC3](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/photometry_examples/phot_examples.html)
- [WFC3/UVIS Time-dependent Photometry](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/uvis_time_dependent_photometry/uvis_timedep_phot.html)
- [Calculating WFC3 Zeropoints with `stsynphot`](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/zeropoints/zeropoints.html)
- [WFC3/UVIS Pixel Area Map Corrections for Subarrays](https://spacetelescope.github.io/hst_notebooks/notebooks/WFC3/uvis_pam_corrections/WFC3_UVIS_Pixel_Area_Map_Corrections_for_Subarrays.html)

See the [WFC3 Instrument Handbook](https://hst-docs.stsci.edu/wfc3ihb),
[WFC3 Data Handbook](https://hst-docs.stsci.edu/wfc3dhb),
[wfc3tools](https://github.com/spacetelescope/wfc3tools), and 
[WFC3 Software Tools](https://www.stsci.edu/hst/instrumentation/wfc3/software-tools)
for more information on instrumentation, data, calibration, and software.

Installation
------------

It is recommended to clone the entire repository. To do so, run the following
command in terminal:

```
git clone https://github.com/spacetelescope/hst_notebooks
```

`stenv` is the preferred base virtual environment for running WFC3 Noteboks since 
it contains libraries necessary for processing and analyzing data from the Hubble 
Space Telescope (HST) and the James Webb Space Telescope (JWST). To install, see 
[stenv readthedocs](https://stenv.readthedocs.io/en/latest/) or 
[stenv GitHub](https://github.com/spacetelescope/stenv). 

`hst_notebooks/notebooks_env` is the default virtual environment for HST Notebooks, 
which contains the same scientific computing libraries in `stenv`, but not the HST and
JWST libraries. This environment can also be used as a base, but is not recommended.

In addition, each notebook contains a `requirements.txt` file that needs to be
installed before running the notebooks. Some notebooks contain a `pre-requirements.sh`
file, usually to install [HSTCAL](https://github.com/spacetelescope/hstcal), which
is the calibration software for HST. Here is a common set of commands to run 
before executing the notebooks (assuming your virtual environment is activated):

```
bash pre-requirements.sh
pip install -r requirements.txt
pip install notebook
```

With the environment activated and additional libraries installed based on the
individual requirement files, you will be able to complete the notebooks.

Contributing
------------

New contributions and feedback are very welcomed! Please open a new issue or new 
pull request for bugs, feedback, or new features you would like to see. If there 
is an issue you would like to work on, please leave a comment and we will be happy 
to assist. Questions can also be sent through the [HST Help Desk](https://stsci.service-now.com/hst).

WFC3 Notebooks follows the 
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

WFC3 Notebooks is licensed under a BSD 3-Clause License (see the `LICENSE.txt` file).
