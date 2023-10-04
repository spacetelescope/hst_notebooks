This notebook presents one of two available methods to correct for a time variable background (TVB) due to scattered light from observing close to the Earth's limb. This method illustrates how to manually subtract any bad reads from the final exposure read of the WFC3/IR IMA data. 

This notebook walks through the following:

- Computing and ploting the difference between IMA reads to identify those affected by TVB.
- Correcting a single exposure in which the first few reads are affected by scattered light by subtracting those "bad" reads from the final IMA read.
- Comparing the original FLT to the reprocessed FLT image.

Please note that the FLT products in this notebook are really 'corrected IMA' files and therefore do not include the 'ramp fitting' step in `calwf3`. The final images will therefore still contain cosmic rays, and these artifacts may be removed using software such as AstroDrizzle when combining multiple exposures.

Installation Instructions:

Please refer to the instructions found on the main [WFC3 Library github](https://github.com/spacetelescope/WFC3Library) page. No other installations are required.