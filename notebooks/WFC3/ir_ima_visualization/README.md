The main purpose of this notebook is to familiarize users with the structure of the WFC3/IR IMA files, to visualize individual reads and the difference between reads, and to plot the cumulative signal and count rate throughout the MULTIACCUM exposure. These visualization tools may be used to identify issues with the data, for example, a guidestar (GS) failure, a satellite trail in a specific read, or time variable background, which may take the form of scattered light or He I 10830 Å airglow line emission. 

This notebook walks through:

- Exploring WFC3/IR IMA Data Structure;
- How to find and select individual reads in an IMA file;
- How to show individual read as images;
- Plotting the signal ramp through subsequent reads;
- Plotting the difference in signal between reads using two different methods.

Installation Instruction:

- Please refer to the instructions found on the main [WFC3 Library github page](https://github.com/spacetelescope/WFC3Library). No other installations are required. 