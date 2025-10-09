# Photometry

Here are brief descriptions of WFC3 Notebooks for photometry:

## WFC3/UVIS Filter Transformations with `stsynphot`
We present how to calculate photometric transformation coefficients between 
WFC3/UVIS wide-band filters and any other non-HST filter system for a given 
object spectrum, using the latest WFC3 synthetic throughput tables. For more 
detail on photometric transformations to other systems, see 
[WFC3 ISR 2014-16](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/documentation/instrument-science-reports-isrs/_documents/2014/WFC3-2014-16.pdf).

## Flux Unit Conversions with `synphot` and `stsynphot`
We present a framework for users to convert between multiple magnitude and flux 
unit systems, and plot the results on the selected spectrum. This notebook is 
based on the NICMOS unit conversion form and replaces a previous web-hosted HST 
unit conversion tool developed in 2014. The updated tool incorporates the 
latest WFC3/UVIS ([WFC3 ISR 2021-04](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/documentation/instrument-science-reports-isrs/_documents/2021/WFC3_ISR_2021-04.pdf)) and 
WFC3/IR ([WFC3 ISR 2024-13](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/documentation/instrument-science-reports-isrs/_documents/2024/WFC3-ISR-2024-13.pdf)) 
photometric 
calibration as well as recent changes in the Vega spectrum of up to ~1.5% 
([Bohlin et al. 2020](https://iopscience.iop.org/article/10.3847/1538-3881/ab94b4)). See Section 9.5.2 of the [WFC3 Data Handbook](https://hst-docs.stsci.edu/wfc3dhb) for more 
information.

## Synthetic Photometry Examples for WFC3
This notebook replaces `pysynphot` examples from the 2018 version of the Data 
Handbook and demonstrates how to use `stsynphot` for a few use cases:

- Compute the inverse sensitivity, zeropoint, and encircled energy correction for any WFC3 'obsmode'
- Renormalize a spectrum to 1 count/sec in a given bandpass and output the predicted magnitude or flux for a different bandpass
- Determine the color transformation between two bandpasses for a given spectrum
- Compute color terms for UV filters for a blue versus a red standard star observed on UVIS2

## WFC3/UVIS Time-dependent Photometry
For UVIS images retrieved after October 15, 2020, new time-dependent photometry 
keyword values (PHOTFLAM, PHTFLAM1, PHTFLAM2 and PHTRATIO) are populated in the 
image header and must be applied separately for each observation epoch. This is 
a change from prior calibration, where a single set of keyword values were 
provided for each filter, independent of date. For more detail on the new 
calibration, see 
[WFC3 ISR 2021-04](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/documentation/instrument-science-reports-isrs/_documents/2021/WFC3_ISR_2021-04.pdf).

In this tutorial, we show how to use the time-dependent calibration to compute 
aperture photometry on UVIS calibrated, CTE-corrected images (flc.fits, 
hereafter FLC) obtained at three epochs, spanning a total range of ~8 years and 
showing a loss in sensitivity of ~2%.

Alternately, the FLC science arrays may be 'equalized' to account for 
sensitivity changes prior to computing photometry, where a reference set of 
keywords may be then used for all images. This photometric 'equalization' must 
be performed before combining any set of FLC images with AstroDrizzle which span 
multiple epochs in time.

## Calculating WFC3 Zeropoints with `stsynphot`
We present how to calculate photometric zeropoints using `stsynphot` for any 
WFC3 detector, filter, date, or aperture. This tutorial is especially useful for 
calculating Vegamag zeropoints, which require an input spectrum. The notebook is 
also useful for computing time-dependent WFC3/UVIS zeropoints for any 
observation date, as the values listed in 
[WFC3 ISR 2021-04](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/documentation/instrument-science-reports-isrs/_documents/2021/WFC3_ISR_2021-04.pdf) 
are defined for the reference epoch. As of mid-2021, the WFC3/IR zeropoints are 
time-independent.

## WFC3/UVIS Pixel Area Map Corrections for Subarrays
We present how to apply pixel area map (PAM) corrections on FLT or FLC 
observations. The notebook also provides a comprehensive function that takes 
science data and outputs the PAM corrected data. 
