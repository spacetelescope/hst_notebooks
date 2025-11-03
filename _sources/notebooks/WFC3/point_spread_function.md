# Point Spread Function (PSF)
Here are brief descriptions of the WFC3 Notebooks for Point Spread Function 
modeling.

## HST Point Spread Function
This notebook demonstrates how to generate PSF 
models for WFC3 observations. This includes retrieving empirical models 
from the [WFC3 PSF Website](https://www.stsci.edu/hst/instrumentation/wfc3/data-analysis/psf), 
generating custom models by stacking stars, and retrieving cutouts from the 
[MAST PSF Database](https://www.stsci.edu/hst/instrumentation/wfc3/data-analysis/psf/psf-search). 
The notebook includes examples of how to generate stellar catalogs, perform PSF 
fitting and subtraction, and how to utilize different types of PSF models 
depending on the available data and science goals. While the examples are 
focused on WFC3, the notebook can also be used with ACS, WFPC2, and other 
instruments.

## Downloading WFC3 and WFPC2 PSF Cutouts from MAST
The WFC3 team annually releases PSF cutouts (i.e. realizations of the PSF) of 
sources detected from [HST1PASS](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/documentation/instrument-science-reports-isrs/_documents/2022/WFC3-ISR-2022-05.pdf) 
in WFC3 and WFPC2 observations. These PSF databases contain over 83 million 
unsaturated and saturated sources, and are publicly available on the 
[MAST Portal](https://mast.stsci.edu/portal/Mashup/Clients/Mast/Portal.html). 
Here, we present a custom MAST API to query, download, and extract PSF cutouts.