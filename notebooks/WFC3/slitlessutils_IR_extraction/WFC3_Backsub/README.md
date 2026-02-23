WFC3 Backsub is a Python script that estimates and subtracts a three-component (Zodiacal, HeI from Earth, and Scattered light) background model from WFC3 IR grism data (G102/G141). WFC3 Backsub still uses `calwf3` for certain calibration steps so `hstcal` and `wfc3tools` must be installed. 

The primary document explaining the multi-component model is WFC3 ISR [2020-04](https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/documentation/instrument-science-reports-isrs/_documents/2020/WFC3_IR_2020-04.pdf).

Example run: `python back_sub.py "*_raw.fits"  --grism='G102' --ipppss='All' --grey_flat=True` 
