In this Jupyter Notebook tutorial, we present the steps that should be taken
when an observer receives a WFC3 Exception Report Email.

This directory, once downloaded, should contain this README.md, the tutorial
Jupyter Notebook `wfc3_exception_report.ipynb`, an `html` copy of the notebook,
a `requirements.txt` file, and a subdirectory titled `docs`. The subdirectory 
should contain two `.py` files, one `.png`, and one `.gif` file that are used
in the notebook.

To run this Jupyter Notebook, you must have created a virtual environment
that contains (at minimum) the packages listed in the `requirements.txt` file
that is included within the repository. We recommend creating a new conda 
environment using the requirements file: 

  `$ conda create -n except_report python=3.11` <br>
  `$ conda activate except_report` <br>
  `$ pip install -r requirements.txt`<br>
  
Optional Note: The tools in this notebook (specifically display_image) look much
better in Jupyter Lab rather than in the classic Jupyter Notebook. If your
environment has Jupyter Lab installed it's recommended you use that to run the
.ipynb file. See the [Jupyter website](https://jupyter.org/install) for more info.

Please submit any questions or comments to the [WFC3 Help Desk](https://stsci.service-now.com/hst).
