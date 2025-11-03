DrizzlePac Notebooks
=================

An updated set of HST drizzling and alignment tutorials are now available and compatible with the latest STScI distributed software environment [stenv](https://stenv.readthedocs.io/en/latest/). These notebooks include a new recommended workflow for MAST data retrieved after December 2019, which includes updated astrometric information included as additional FITS extensions.  Alternatively, the new World Coordinate System (WCS) solutions may be downloaded directly from MAST as small 'headerlet' files and applied to existing data. For example, the Hubble Advanced Product 'Single Visit Mosaics' may have improved relative alignment for different filters acquired in the same visit. These headerlets may be used to update the WCS in the FITS images prior to drizzling. For details on the alignment of HST data in MAST, see Section 4.5 [Absolute Astrometry](https://hst-docs.stsci.edu/drizzpac/chapter-4-astrometric-information-in-the-header/4-5-absolute-astrometry) in the DrizzlePac Handbook.  

## Before Running a Notebook

Before running these examples you **must** follow the general instructions on creating an environment that can run the notebooks, shown in STScI HST Notebook Repository HQ page under [Installation Instructions](https://spacetelescope.github.io/hst_notebooks/index.html).

## Contents

In each notebook, a sample WFC3 or ACS dataset is used to demonstrate how to download the calibrated data, inspect the quality of the alignment and test whether the observations need to be realigned before combining the data with `AstroDrizzle`. Different workflows are illustrated to enhance the scientific value of the drizzled data products using advanced reprocessing techniques. These notebooks highlight different use cases, e.g. images acquired using small sub-pixel dithers to optimally sample the PSF versus those acquired in multiple pointings to generate large mosaics on the sky.

The notebooks available in this repository include:

Alignment Workflows:
- [Improving Absolute and Relative Astrometry Using Alternate WCS Solutions](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/using_updated_astrometry_solutions/using_updated_astrometry_solutions.html)
- [Aligning HST images to an Absolute Reference Catalog](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/align_to_catalogs/align_to_catalogs.html)
- [Aligning Deep Exposures of Sparse Fields](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/align_sparse_fields/align_sparse_fields.html)
- [Aligning Multiple HST Visits](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/align_multiple_visits/align_multiple_visits.html)
- [Using DS9 Regions for Source Inclusion/Exclusion](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/use_ds9_regions_in_tweakreg/use_ds9_regions_in_tweakreg.html)

Drizzling Features:
- [Optimizing the Image Sampling for Sub-pixel dithers](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/optimize_image_sampling/optimize_image_sampling.html)
- [Creating HST mosaics observed with multiple detectors](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/align_mosaics/align_mosaics.html)
- [Using Sky Matching features for HST mosaics](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/sky_matching/sky_matching.html)
- [Masking satellite trails prior to drizzling](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/mask_satellite/mask_satellite.html)
- [Drizzling new WFPC2 flt data products](https://spacetelescope.github.io/hst_notebooks/notebooks/DrizzlePac/drizzle_wfpc2/drizzle_wfpc2.html)


For more information, see the [DrizzlePac Handbook](https://hst-docs.stsci.edu/drizzpac) and the [readthedocs](https://drizzlepac.readthedocs.io/en/latest/) software documentation. For additional assistance with DrizzlePac tools, users may submit a ticket to the [STScI Help Desk](https://stsci.service-now.com/hst?id=hst_index) and should select the DrizzlePac category.


## Contributing

New contributions and feedback are very welcomed! Please open a new [issue](https://github.com/spacetelescope/hst_notebooks/issues) or new pull request for bugs, feedback, or new features you would like to see. If there is an issue you would like to work on, please leave a comment and we will be happy to assist. Questions can also be sent to the DrizzlePac team through the [HST Help Desk](https://stsci.service-now.com/hst).

