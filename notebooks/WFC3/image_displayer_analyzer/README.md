In this tutorial, we present `display_image`, a tool for displaying full images with metadata, individual WFC3/UVIS chip images, 
a section of an image with various colormaps/scaling, and individual WFC3/IR `ima` reads. In addition, we present 
`row_column_stats`, a tool for computing row and column statistics for the types of WFC3 images previously mentioned.

This directory, once unzipped, should contain this `README.md`,
the image displayer tool `display_image.py`, the row and column statistic
tool `row_column_stats.py`, a `requirements.txt` file for creating a virtual 
environment, and the Jupyter Notebook tutorial `wfc3_imageanalysis.ipynb`. 
These tools are meant to be used inside a Jupyter Notebook.

To run this Jupyter Notebook, you must have created a virtual environment that contains (at minimum) the packages listed in the 
requirements.txt file that is included within the repository. We recommend creating a new conda environment using the requirements file:

```
$ conda create -n img_disp python=3.11
$ conda activate img_disp
$ pip install -r requirements.txt
```

The tools in this notebook (specifically `display_image`) look much
better in Jupyter Lab rather than in the classic Jupyter Notebook. If your
environment has Jupyter Lab installed it's recommended you use that to run the
.ipynb file. See the [Jupyter website](https://jupyter.org/install) for more info.

Please submit any questions or comments to the [WFC3 Help Desk](https://stsci.service-now.com/hst).
---------------------------------------------------------------------
