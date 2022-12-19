In this Jupyter Notebook tutorial, we will learn about the IMA file type for WFC3/IR observations, and use a set of tools (imported from `tools.py`) to visualize different FITS extensions and save output.

This directory, once downloaded, should contain this README.md, the tutorial Jupyter Notebook easy_ima_viewer.ipynb, an `html` copy of the notebook, a `pdf` copy of the notebook, and the `tools.py` script.

In order to run this Jupyter notebook, you must have the following packages installed in your environment:
1. numpy
2. imageio
3. ipywidgets
4. IPython
5. astropy
6. matplotlib
7. ipympl

We recommend using a virtual environment based on the [stenv-stable.yml](https://github.com/spacetelescope/stenv/blob/main/stenv-stable.yml) environment file.
After copying or downloading this YAML file, you can use it to create a fresh environment.
All but one of the required packages will be installed.
The final dependency (`ipympl`) can then be `pip` installed.

To create a new environment called `ima_env` using the `stenv-stable.yml` file in the current working directory and pip installing `ipympl`, execute the following:

```
conda env create -n ima_env --file stenv-stable.yml

conda activate ima_env

pip install ipympl
```

After changing to the directory hosting this notebook, you can launch the Jupyter notebook with
```
jupyter notebook
```

Please submit any questions or comments to the [WFC3 Help Desk](https://stsci.service-now.com/hst).
