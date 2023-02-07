This notebook shows how to use the WFC3/IR persistence model to flag pixels affected by persistence in the calibrated (FLT) science images. When the images are sufficiently dithered to step over the observed persistence artifacts, AstroDrizzle may be used to exclude those flagged pixels when combining the FLT frames. 

By the end of this tutorial, you will:

- Download images and persistence products from MAST
- Flag affected pixels in the data quality arrays of the FLT images
- Redrizzle the FLT images to produce a 'clean' DRZ combined product

Dependencies: 

The environment from [WFC3 Library's](https://github.com/spacetelescope/WFC3Library) installation instructions contains the packages you need. However if you would like to run this notebook from a different environment, then refer to the instructions below:

Two astropy packages must be installed in your conda environment before downloading the data. To do this, type the following command in the terminal before starting the notebook:

    conda install -c astropy astroquery ccdproc

