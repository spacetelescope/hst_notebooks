# WFC3/IR Time Variable Background (TVB)
Here are brief descriptions of WFC3 Notebooks for WFC3/IR TVB:

## WFC3/IR IMA Visualization Tools with an Example of Time Variable Background
We present tools to familiarize users with the structure of the WFC3/IR IMA 
files, to visualize individual reads and the difference between reads, and to 
plot the cumulative signal and count rate throughout the MULTIACCUM exposure. 
These visualization tools may be used to identify issues with the data, for 
example, a guidestar (GS) failure, a satellite trail in a specific read, or time 
variable background, which may take the form of scattered light or He I 10830 A 
airglow line emission. 

## Manual Recalibration of Images using `calwf3`: Turning off the WFC3/IR Linear Ramp Fit
We present `calwf3` reprocessing examples to improve calibrated WFC3/IR images 
affected by TVB. The notebook shows how to diagnose images with poor-quality 
ramp fits and rerun `calwf3` with the 'CRCORR' step turned off. This method is 
described as the 'Last-minus-first' technique 
[WFC3 ISR 2016-16](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/documentation/instrument-science-reports-isrs/_documents/2016/WFC3-2016-16.pdf). 
See Section 3.5.2 of the [WFC3 Data Handbook](https://hst-docs.stsci.edu/wfc3dhb) 
for more information.

## Correcting for Helium Line Emission Background in WFC3/IR Exposures using the "Flatten-Ramp" Technique
We present different ways to identify IR exposures with time variable Helium 
(1.083 micron) line emission background, and how to correct for it using the 
"flatten-ramp" technique described in 
[WFC3 ISR 2016-16](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/documentation/instrument-science-reports-isrs/_documents/2016/WFC3-2016-16.pdf). 
This method can be used to correct images affected by a sky background that does 
not vary across the field of view.

## Correcting for Scattered Light in WFC3/IR Exposures: Manually Subtracting Bad Reads
We present a method to correct for TVB due to scattered light from observing 
close to the Earth's limb. This method illustrates how to manually subtract any 
bad reads from the final exposure read of the WFC3/IR IMA data. 

Please note that the FLT products in this notebook are really 'corrected IMA' 
files and therefore do not include the 'ramp fitting' step in `calwf3`. The 
final images will therefore still contain cosmic rays, and these artifacts may 
be removed using software such as AstroDrizzle when combining multiple exposures.

## Correcting for Scattered Light in WFC3/IR Exposures: Using `calwf3` to Mask Bad Reads
We present a method to correct for TVB due to scattered light from observing 
close to the Earth's limb. This method illustrates how to mask bad reads in the 
RAW image and then reprocess with `calwf3`, and it may be used for rejecting 
anomalous reads occurring either at the beginning or at the end of an exposure.