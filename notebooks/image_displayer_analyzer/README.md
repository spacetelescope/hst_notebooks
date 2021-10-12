In this notebook, we demonstrate `display_image`, a tool that can display full images with metadata, individual WFC3/UVIS chip images, a section of the image with various colormaps/scaling, and individual WFC3/IR ima reads. In addition, we demonstrate `row_column_stats`, a tool for quickly computing WFC3 statistics, such as the row and column statistics for a full image, individual WFC3/UVIS chips, a section of an image, and individual ima reads.

This directory, once unzipped, should contain this `README.md`,
the image displayer tool `display_image.py`, the row and column statistic
tool `row_column_stats.py`, and the Jupyter Notebook tutorial
`wfc3_imageanalysis.ipynb`. Both of these tools are meant to be used inside of
a Jupyter Notebook.

In order to run the Jupyter Notebook you must have created the virtual
environment in WFC3 Library's (https://github.com/spacetelescope/WFC3Library)
installation instructions. No additional packages are required to run this
Jupyter Notebook.

These tools (specifically `display_image`) look much better in Jupyter Lab
rather than the classic Jupyter Notebook.  If your environment has Jupyter Lab
installed it's recommended you use that to run the `.ipynb` file. If you're
interested in adding Jupyter Lab to your environment see the install
instructions on the Jupyter website: https://jupyter.org/install.

Questions or concerns should be sent to the HST Help Desk
(https://stsci.service-now.com/hst).
---------------------------------------------------------------------
