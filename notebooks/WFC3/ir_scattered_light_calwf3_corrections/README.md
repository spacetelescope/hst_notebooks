This notebook shows one of two available methods to correct for time-variable background (TVB) due to scattered light from observing close to the Earth's limb. This method illustrates how to mask bad reads in the RAW image and then reprocess with calwf3, and it may be used for rejecting anomalous reads occurring either at the beginning or at the end of an exposure.

This tutorial is a walkthrough of the following:

- Computing and plot the difference between IMA reads to identify the reads affected by TVB.
- Reprocessing a single exposure with calwf3 by excluding the first few reads which are affected by scattered light.
- Comparing the original FLT to the reprocessed FLT image.

Installation Instructions:
- Please refer to the instructions found on the main [WFC3 Library GitHub page](https://github.com/spacetelescope/WFC3Library). No other installations are required.