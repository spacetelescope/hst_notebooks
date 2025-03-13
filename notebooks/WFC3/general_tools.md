# General Tools
Here are brief descriptions of WFC3 Notebooks for general tools:

## WFC3 Image Displayer and Analyzer
We present `display_image`, a tool for displaying full images 
with metadata, individual WFC3/UVIS chip images, a section of an image with 
various colormaps/scaling, and individual WFC3/IR `ima` reads. In addition, we 
present `row_column_stats`, a tool for computing row and column statistics for 
the types of WFC3 images previously mentioned.

## Exception Report Checklist - WFC3
We present the steps that should be taken when an observer receives a WFC3 
Exception Report Email.

## Processing WFC3/UVIS Data with `calwf3` Using the v1.0 CTE-Correction
We compare `calwf3` v1.0 CTE correction versus v2.0, and explore
when each version is useful. v1.0 will provide the most up-to-date calibration 
procedures such as time-dependent photometric corrections and zeropoints, while 
also including the v1.0 CTE correction.

## Masking Persistence in WFC3/IR Images
We present how to use the WFC3/IR persistence model to flag pixels affected by 
persistence in the calibrated (FLT) science images. When the images are 
sufficiently dithered to step over the observed persistence artifacts, 
AstroDrizzle may be used to exclude those flagged pixels when combining the FLT 
frames. 

## Analyzing WFC3/UVIS G280 Exoplanet Transit Observations
We present the reduction and analysis of exoplanet transit observations of the 
hot Jupiter HAT-P-41b taken with the WFC3/UVIS G280 grism. The notebook
demonstrates source finding, background subtraction, cosmic ray rejection, 
subarray embedding, spectral trace fitting, spectum extraction, and light curve
generation.
