This notebook replaces `pysynphot` examples from the 2018 version of the Data Handbook and demonstrates how to use `stsynphot` for several use cases:

- Compute the inverse sensitivity, zeropoint, and encircled energy correction for any WFC3 'obsmode'
- Renormalize a spectrum to 1 count/sec in a given bandpass and output the predicted magnitude or flux for a different bandpass
- Determine the color transformation between two bandpasses for a given spectrum
- Compute color terms for UV filters for a blue versus a red standard star observed on UVIS2

Note that the fourth example in the notebook requires the fits files found in the `example_spectra` subdirectory.
