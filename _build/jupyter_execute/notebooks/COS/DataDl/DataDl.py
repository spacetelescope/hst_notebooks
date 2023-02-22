#!/usr/bin/env python
# coding: utf-8

# <a id="topD"></a>
# 
# # Downloading COS Data
# 
# # Learning Goals
# <font size="5"> This Notebook is designed to walk the user (<em>you</em>) through: <b>Downloading existing Cosmic Origins Spectrograph (<em>COS</em>) data from the online archive</b></font>
# 
# **0. [Introduction](#introDl)**
# 
# \- 0.1. [A one-cell summary of this Notebook's key points](#onecellDl) 
# 
# **1. [Using the web browser interface](#mastD)**
# 
# \- 1.1. [The HST-specific Web Search](#mastD)
# 
# \- 1.2. [Searching for a Series of Observations on the HST-specific Web Search](#WebSearchSeriesD)
# 
# \- 1.3. [The MAST Portal](#mastportD)
# 
# \- 1.4. [Searching for a Series of Observations on the MAST Portal](#mastportSeriesD)
# 
# **2. [Using the `Python` module `Astroquery`](#astroqueryD)**
# 
# \- 2.1. [Searching for a single source with Astroquery](#Astroquery1D)
# 
# \- 2.2. [Narrowing Search with Observational Parameters](#NarrowSearchD)
# 
# \- 2.3. [Choosing and Downloading Data Products](#dataprodsD)
# 
# \- 2.4. [Using astroquery to find data on a series of sources](#Astroquery2D)
# 

# ## Choosing how to access the data
# 
# **This Notebook explains three methods of accessing COS data hosted by the STScI Mikulski Archive for Space Telescopes (MAST).**
# You may read through all three, or you may wish to focus on a particular method which best suits your needs. 
# **Please use the table below to determine which section on which to focus.**
# 
# ||The [HST-specific Search (Web Interface)](https://mast.stsci.edu/search/ui/#/hst)|The [MAST Portal (Web Interface)](https://mast.stsci.edu/portal/Mashup/Clients/Mast/Portal.html)|The [`Astroquery` (`Python` Interface)](http://astroquery.readthedocs.io/)|
# |-|-|-|-|
# ||- User-friendly point-and-click searching|- User-friendly point-and-click searching|- Requires a bit of `Python` experience|
# ||- Advanced **mission-specific** search parameters, including: central wavelength, detector, etc.|- Lacks some mission-specific search parameters but has non-HST data|- Allows for programmatic searching and downloads|
# ||- Easy to select and download specific datasets|- Easy to select and download specific datasets|- Best for downloading very large datasets|
# |||||
# |***Use this method if...***   |*...You're unfamiliar with `Python` and need to search for data by cenwave*|*...You're exploring the data from multiple observatories and you don't need to search by cenwave*|*...You know `Python` and have an idea of what data you're looking for, or you have a lot of data*|
# |***Described in...***|*[Section 1.1](#mastD)*|*[Section 1.3](#mastportD)*|*[Section 2.1](#astroqueryD)*|
# 
# *Note* that these are only recommendations, and you may prefer another option. For most purposes, the writer of this tutorial recommends exploring your data first with one of the Web interfaces. Then, if repeatability is important to your application, you can implement this using the `Astroquery` `Python` interface.
# 

# <a id=introDl></a>
# 
# # 0. Introduction
# **The Cosmic Origins Spectrograph ([*COS*](https://www.nasa.gov/content/hubble-space-telescope-cosmic-origins-spectrograph)) is an ultraviolet spectrograph on-board the Hubble Space Telescope([*HST*](https://www.stsci.edu/hst/about)) with capabilities in the near ultraviolet (*NUV*) and far ultraviolet (*FUV*).**
# 
# **This tutorial aims to prepare you to access the existing COS data of your choice by walking you through downloading a processed spectrum, as well as various calibration files obtained with COS.**
# 
# - For an in-depth manual to working with COS data and a discussion of caveats and user tips, see the [COS Data Handbook](https://hst-docs.stsci.edu/display/COSDHB/).
# - For a detailed overview of the COS instrument, see the [COS Instrument Handbook](https://hst-docs.stsci.edu/display/COSIHB/).
# 

# <a id=onecellDl></a>
# 
# ### 0.1. A one-cell summary of this Notebook's key points:
# 
# While the rest of this Notebook will walk you through each step and decision made when downloading COS data, the following code cell serves as a summary for the Notebook. It contains the key material condensed into a single code cell, without much explanation. In the rest of this Notebook, we explain other methods of downloading data which require less `Python` experience and which may be more useful for exploring data when you don't know *exactly* what you're looking for.
# 
# If this cell is all the help you need, great! If you still have questions, read on!

# In[1]:


# This code cell condenses the key material of the Notebook into a single cell summary.
# 1. Import the necessary libraries:
# For searching and downloading from the MAST archive:
from astroquery.mast import Observations
# For handling system paths:
from pathlib import Path

# 2. Download an example dataset using astroquery:
# 2.1. Find all the observations from a single HST Proposal:
# We'll search for a program with Proposal ID 15366
# A list of search criteria can be found by running: Observations.get_metadata('observations')
obs_from_proposal = Observations.query_criteria(proposal_id="15366")

# 2.2. Find all the data products for these observations:
# These include all the files associated with your observation, from raw data to fully-calibrated spectra or images
products_from_proposal = Observations.get_product_list(obs_from_proposal)

# 2.3. Tell the user how many total files were found:
print(f"Found {len(products_from_proposal)} data products")

# 2.4. Filter to a specific subset of these products:
# Here we filter to (I) the X1DSUM files, which are the final 1-dimensional extracted spectra,
# and (II) the association files, which list related exposures which were combined into the X1DSUM
products_to_download = Observations.filter_products(
    products_from_proposal,
    productSubGroupDescription=["X1DSUM", "ASN"] # Filters to only the X1DSUM and ASN files
)

# 2.5. Download the filtered products:
download_table = Observations.download_products(products_to_download)

# 2.6. Gather the downloaded files:
# Turn string paths to the files into python pathlib.Path objects
# Then make lists of these local paths, aggregated by type of file, and print to the user.
onecell_x1dsum_products = [Path(local_path) for local_path in \
                           download_table["Local Path"] if "x1dsum" in local_path]
onecell_asn_products = [Path(local_path) for local_path in \
                        download_table["Local Path"] if "asn" in local_path]
print("Downloaded X1DSUM Files: \n", onecell_x1dsum_products,
      "\nDownloaded ASN Files: \n", onecell_asn_products)


# ### Now, returning to our more detailed walkthrough...
# 
# <font size="5"> We will define a few directories in which to place our data.</font>
# 
# And to create new directories, we'll import `pathlib.Path`:

# In[2]:


# Import for: working with system paths
from pathlib import Path

# This will be an important directory for the Notebook, where we save data
data_dir = Path('./data/')
data_dir.mkdir(exist_ok=True)


# <a id="downloadD"></a>
# # 1. Downloading the data through the browser interface
# 
# One can search for COS data from both a browser-based Graphical User Interface (*gui*) and a `Python` interface. This Section (1) will examine two web interfaces. [Section 2](#astroqueryD) will explain the `Python` interface.
# 
# *Note, there are other, more specialized ways to query the mast API not discussed in this Notebook. An in-depth MAST API tutorial can be found [here](https://mast.stsci.edu/api/v0/MastApiTutorial.html).*

# <a id="mastD"></a>
# ## 1.1 The HST-specific Web Search
# **The browser gui for searching *specifically* through [HST archival data can be found here](https://mast.stsci.edu/search/ui/#/hst).** 
# Full documentation of the HST-specific search can be found [here](https://outerspace.stsci.edu/display/MASTDOCS/Mission+Search+Guide). In this section of the Notebook, we'll show examples of searching for COS data using the HST-specific form. A more general MAST gui, which allows access to data from other telescopes such as TESS, but does not offer all HST-specific search parameters, will be discussed in [Section 1.3](#mastportD).

# The search page  of the HST-specific interface is laid out as in Fig 1.1:
# ### Fig 1.1
# <center><img src=./figures/new_hst_search_login.png width ="900" title="New HST-specific search website"> </center>
# 
# If you are accessing proprietary data, you will need to make an account or log in at the top right under "MY ST" (boxed in red in Fig 1.1). If you are accessing non-proprietary data, you may continue without logging in.
# 

# Figure 1.2 shows a filled-in search form, which will query the MAST archive for observations which:
# * Fall within 3 arcminutes of either of the resolved stars: AV75 or AV80
# * Are spectroscopic observations, rather than images
# * Have exposure times of greater than 1000 seconds
# * Are taken with the COS instrument, using the G160M grating and either the 1533 or the 1577 cenwave setting
# 
# ### Fig 1.2
# <center><img src=figures/new_hst_search_query.png width ="900" title="New HST-specific website search filled out with a COS data query"> </center>

# The above search results in the table shown in Fig 1.3. 
# 
# ### Fig 1.3
# <center><img src =figures/new_hst_search_results.png width ="900" title="Results from new HST-specific search website query"> </center>
# 
# If you need to change some parameters in your search - for instance, to also find data from the G130M grating - click on "Edit Search" (red dashed box in Fig 1.3).
# 
# If you are happy with your search, you may now select all the observations whose data you would like to download. Do this by clicking on the checkbox for those observations (blue box), and then clicking "Download Data" (green oval).
# 
# 

# Most COS spectra have preview images (simple plots of flux by wavelength) which can be viewed before downloading the data. Clicking the dataset name (blue dashed oval) will take you to a page which shows the preview image, as well as some basic information about the data and whether there were any known failures during the operation. An example of such a page is shown in Fig 1.4.
# 
# ### Fig 1.4
# <center><img src=figures/preview_spectrum_small.png width ="900" title="Preview spectrum page"> </center>

# Returning to the results page shown in Fig 1.3 and clicking "Download Data" opens a window as shown in Fig 1.5. You can choose to show/hide certain types of data such as the uncalibrated data (red box), search for filetypes using the search bar, and unselect/select all the data products shown in the filtered list (green circle). 
# 
# ### Fig 1.5
# <center><img src =figures/new_hst_search_downloading.png width ="900" title="Choosing what to download in the new HST search website"> </center>
# 
# When all of your desired data products are checked, click "Start Download" (yellow dashed box). This will download a compressed "zipped" folder of all of your data, divided into subdirectories by the observation. Most operating systems can decompress these folders by default. For help decompressing the `Zip`ped files, you can follow these links for: [Windows](https://support.microsoft.com/en-us/windows/zip-and-unzip-files-8d28fa72-f2f9-712f-67df-f80cf89fd4e5) and [Mac](https://support.apple.com/guide/mac-help/zip-and-unzip-files-and-folders-on-mac-mchlp2528/mac). There are numerous ways to do this on Linux, however we have not vetted them.

# Let's briefly return to the initial HST-specific search form to discuss another way to find data.
# Rather than specifying parameters about the data we're searching for, we can instead search by a dataset's ID (see Fig 1.6). As an example of this, we rather arbitrarily select **`LCXV13050`** because of its long exposure time, taken under an observing program described as:
# > "Project AMIGA: Mapping the Circumgalactic Medium of Andromeda"
# 
# This is a Quasar known as [3C48](http://simbad.u-strasbg.fr/simbad/sim-basic?Ident=3c48&submit=SIMBAD+search), one of the first quasars discovered.
# 
# ### Fig 1.6
# 
# <center><img src=figures/new_hst_search_query2_small.png width ="900" title="New HST-specific website search filled out with a specific dataset ID"> </center>

# <font size="5"> <b>Well done making it this far!</b></font>
# 
# You can attempt the exercise below for some extra practice.

# ### Exercise 1: *Searching the archive for TRAPPIST-1 data*
# 
# [TRAPPIST-1](https://en.wikipedia.org/wiki/TRAPPIST-1) is a cool red dwarf with a multiple-exoplanet system. 
# - Find its coordinates using the [SIMBAD Basic Search](http://simbad.u-strasbg.fr/simbad/sim-fbasic).
# - Use those coordinates in the [HST web search](https://mast.stsci.edu/search/ui/#/hst) or the [MAST portal](https://mast.stsci.edu/portal/Mashup/Clients/Mast/Portal.html) to find all COS exposures of the system.
# - Limit the search terms to find the COS dataset taken in the COS far-UV configuration with the grating G130M.
# 
# **What is the dataset ID, and how long was the exposure?**
# 
# Place your answer in the cell below.

# In[3]:


# Your answer here


# <a id=WebSearchSeriesD></a>
# ## 1.2. Searching for a Series of Observations on the HST-specific Web Search
# 
# Now let's try using the HST-specific web interface's [file upload form](http://archive.stsci.edu/hst/search.php?form=fuf) to search for a series of observations by their dataset IDs. We're going to look for three observations of the same object, the white dwarf WD1057+719, taken with three different COS gratings. Two are in the FUV and one in the NUV. The dataset IDs are
# - LDYR52010
# - LBNM01040
# - LBBD04040
# 
# So that we have an example list of datasets to input to the web search, we make a comma-separated-value txt file with these three obs_ids, and save it as `obsId_list.txt`.
# You can also search by right ascension and declination, instead of by dataset ID.

# In[4]:


# The three observation IDs we want to gather
obsIdList = ['LDYR52010', 'LBNM01040', 'LBBD04040']
obsIdList_length = len(obsIdList)

with open('./obsId_list.txt', 'w') as f:  # Open up this new file in "write" mode
    # The first line tells the search what type of parameter we're searching
    # Here, it's the dataset ID, but it could be RA, DEC. In that case each row has two values
    f.write("Dataset_id\n")
    # We want a newline after each obs_id except the last one
    for i, item in enumerate(obsIdList):
        if i < obsIdList_length - 1:
            f.writelines(item + "," + '\n')
        # Make sure we don't end the file with a blank line (below)
        if i == obsIdList_length - 1:
            f.writelines(item)


# Then we can click **Upload List of Objects** on the HST-specific search form, and then choose `obsId_list.txt` under the browse menu which opens.
# Because we are searching by Dataset ID, we don't need to specify any additional parameters to narrow down the data.
# 
# ### Fig 1.7
# <center><img src =figures/new_search_file_list_small.png width ="900" title="File Upload Search Form"> </center>
# 

# We now can access all the datasets specified in `obsId_list.txt`, as shown in Fig. 1.8:
# 
# ### Fig 1.8
# <center><img src =figures/new_search_file_list_res_small.png width ="900" title="Upload List of Objects Search Results"> </center>
# 
# We can select and download their data products as before.

# <a id = mastportD></a>
# ## 1.3. The MAST Portal
# 
# STScI hosts another web-based gui for accessing data, the [MAST Portal](https://mast.stsci.edu/portal/Mashup/Clients/Mast/Portal.html). This is a newer interface which hosts data from across many missions and allows the user to visualize the target in survey images, take quick looks at spectra or lightcurves, and manage multiple search tabs at once. Additionally, it handles downloads in a slightly more beginner-friendly manner than the current implementation of the Classic HST Search. This guide will only cover the basics of accessing COS data through the MAST Portal; you can find more in-depth documentation in the form of helpful video guides on the [MAST YouTube Channel](https://www.youtube.com/user/STScIMAST).
# 
# **Let's find the same data we found in Section 1.1, on the QSO 3C48:**
# 
# Navigate to the MAST Portal at <https://mast.stsci.edu/portal/Mashup/Clients/Mast/Portal.html>, and you will be greeted by a screen where the top looks like Fig. 1.9. 
# ### Fig 1.9
# <center><img src =figures/mastp_top.png width ="900" title="Top of MAST Portal Home"> </center>
# 
# Click on "Advanced Search" (boxed in red in Fig. 1.9). This will open up a new search tab, as shown in Fig. 1.10:
# ### Fig 1.10
# <center><img src =figures/mastp_adv.png width ="900" title="The advanced search tab"> </center>
# 
# Fig 1.10 (above) shows the default search fields which appear. Depending on what you are looking for, these may or may not be the most helpful search fields. By unchecking some of the fields which we are not interested in searching by right now (boxed in green), and then entering the parameter values by which to narrow the search into each parameter's box, we generate Fig. 1.11 (below). One of the six fields (Mission) by which we are narrowing is boxed in a dashed blue line. The list of applied filters is boxed in red. A dashed pink box at the top left indicates that 2 records were found matching all of these parameters. To its left is an orange box around the "Search" button to press to bring up the list of results
# 
# Here we are searching by:
# 
# |**Search Parameter**|**Value**|
# |-|-|
# |Mission|HST|
# |Instrument|COS/FUV|
# |Filters|G160M|
# |Target Name|3C48|
# |Observation ID|LCXV\* (*the star is a "wild card" value, so the search will find any file whose `obs_id` begins with LCXV*)|
# |Product Type|spectrum|
# 
# ### Fig 1.11
# <center><img src =figures/mastp_adv_2.png width ="900" title="The advanced search tab with some selections"> </center>
# 
# 

# Click the "Search" button (boxed in orange), and you will be brought to a page resembling Fig. 1.12. 
# 
# ### Fig 1.12
# <center><img src =figures/mastp_res1.png width ="900" title="Results of MAST Portal search"> </center>

# <font size="4"> <b>Above, in Fig 1.12</b>:</font>
# - The yellow box to the right shows the AstroView panel, where you can interactively explore the area around your target:
#   - click and drag to pan around
#   - scroll to zoom in/out
# - The dashed-blue box highlights additional filters you can use to narrow your search results.
# - The red box highlights a button you can click with *some* spectral datasets to pull up an interactive spectrum.
# - The green box highlights the "Mark" checkboxes for each dataset. 
# - The black circle highlights the single dataset download button:
#    - **If you only need to download one or two datasets, you may simply click this button for each dataset**
#    - Clicking the single dataset download button will attempt to open a "pop-up" window, which you must allow in order to download the file. Some browsers will require you to manually allow pop-ups.
# 

# <a id="mastportSeriesD"></a>
# ## 1.4. Searching for a Series of Observations on the MAST Portal
# 
# <font size="4"> <b>To download multiple datasets</b>:</font>
# The MAST portal acts a bit like an online shopping website, where you add your *data products* to the checkout *cart*/*basket*, then open up your cart to *checkout* and download the files.
# 
# Using the checkboxes, mark all the datasets you wish to download (in this case, we'll download both LCXV13040 and LCXV13050). Then, click the "Add data products to Download Basket" button (circled in a dashed-purple line), which will take you to a "Download Basket" screen resembling Fig 1.13:

# ### Fig 1.13
# <center><img src =figures/mastp_cart2.png width ="900" title="MAST Portal Download Basket"> </center>
# 
# Each dataset contains *many* files, most of which are calibration files or intermediate processing files. You may or may not want some of these intermediate files in addition to the final product file.
# In the leftmost "Filters" section of the Download Basket page, you can narrow which files will be downloaded (boxed in red).
# By default, only the **minimum recommended products** (*mrp*) will be selected. In the case of most COS data, this will be the final spectrum `x1dsum` file and association `asn` file for each dataset. The mrp files for the first dataset (`LCXV13040`) are highlighted in yellow. These two mrp filetypes are fine for our purposes here; however if you want to download files associated with specific exposures, or any calibration files or intermediate files, you can select those you wish to download with the checkboxes in the file tree system (boxed in dashed-green).

# **For this tutorial, we simply select "Minimum Recommended Products" at the top left. With this box checked, all of the folders representing individual exposures are no longer visible.**
# Check the box labelled "HST" to select all files included by the filters, and click the "Download Selected Items" button at the top right (dashed-black circle). This will bring up a small window asking you what format to download your files as. For datasets smaller than several Gigabytes, the `Zip` format will do fine. Click Download, and a pop-up window will try to open to download the files. If no download begins, make sure to enable this particular pop-up, or allow pop-ups on the MAST page.
# 
# **Your files should now be downloaded as a compressed `Zip` folder.**

# <a id = astroqueryD></a>
# # 2. The Python Package `astroquery.mast`
# Another way to search for and download archived datasets is from within `Python` using the module [`astroquery.mast`](https://astroquery.readthedocs.io/en/latest/mast/mast.html). We will import one of this module's key submodules: `Observations`.
# 
# *Please note* that the canonical source of information on this package is the [`astroquery` docs](https://astroquery.readthedocs.io/en/latest/) - please look there for the most up-to-date instructions.

# ## We will import the following packages:
# 
# - `astroquery.mast`'s submodule `Observations` for finding and downloading data from the [MAST](https://mast.stsci.edu/portal/Mashup/Clients/Mast/Portal.html) archive
# - `csv`'s submodule `reader` for reading in/out from a csv file of source names.

# In[5]:


# Downloading data from archive
from astroquery.mast import Observations

# Reading in multiple source names from a csv file
from csv import reader


# <a id=Astroquery1D></a>
# ## 2.1. Searching for a single source with Astroquery
# 
# There are *many* options for searching the archive with astroquery, but we will begin with a very general search using the coordinates we found for WD1057+719 in the last section to find the dataset with the longest exposure time using the COS/FUV mode through the G160M filter. We could also search by object name to have it resolved to a set of coordinates, with the function `Observations.query_object(objectname = '3C48')`.
# - Our coordinates were:      (11:00:34.126 +71:38:02.80). 
#     - We can search these coordinates as sexagesimal coordinates, or convert them to decimal degrees.

# In[6]:


query_1 = Observations.query_object(
    "11:00:34.126 +71:38:02.80", radius="5 sec")


# This command has generated a table of objects called **"query_1"**. We can see what information we have on the objects in the table by printing its *`keys`*, and see how many objects are in the table with `len(query_1)`.

# In[7]:


print(f"We have table information on {len(query_1)} "+
      "observations in the following categories/columns:\n")
q1_keys = (query_1.keys())
q1_keys


# <a id=NarrowSearchD></a>
# ## 2.2. Narrowing Search with Observational Parameters
# Now we narrow down a bit with some additional parameters and sort by exposure time.
# The parameter limits we add to the search are:
# - *Only look for sources in the coordinate range between right ascension 165 to 166 degrees and declination +71 to +72 degrees*
# - *Only find observations in the UV*
# - *Only find observations taken with the COS instrument (either in its FUV or NUV configuration).*
# - *Only find spectrographic observations*
# - *Only find observations made using the COS grating "G160M"*

# In[8]:


query_2 = Observations.query_criteria(s_ra=[165., 166.], s_dec=[+71., +72.],
                                      wavelength_region="UV", instrument_name=["COS/NUV", "COS/FUV"],
                                      dataproduct_type="spectrum", filters='G160M')

# Next lines simplifies the columns of data we see to some useful data we will look at right now
limq2 = query_2['obsid', 'obs_id', 'target_name', 'dataproduct_type', 'instrument_name',
                'project', 'filters', 'wavelength_region', 't_exptime']
# This is the index list in order of exposure time, increasing
sort_order = query_2.argsort('t_exptime')
print(limq2[sort_order])
chosenObs = limq2[sort_order][-1]  # Grab the last value of the sorted list
print(f"\n\nThe longest COS/FUV exposure with the G160M filter is:"+
      f"\n\n{chosenObs}")


# <font size="5">Caution! </font>
#     
# <img src=./figures/warning.png width ="60" title="CAUTION"> 
# 
# Please note that these queries are `Astropy` tables and do not always respond as expected for other data structures like `Pandas DataFrames`. For instance, the first way of filtering a table shown below is correct, but the second will consistently produce the *wrong result*. You *must* search and filter these tables by masking them, as in the first example below.

# In[9]:


# Searching a table generated with a query
# First, correct way using masking
mask = (query_1['obs_id'] == 'lbbd01020')  # NOTE, obs_id must be lower-case
print("Correct way yields: \n", query_1[mask]['obs_id'], "\n\n")

# Second INCORRECT way
print("Incorrect way yields: \n",
      query_1['obs_id' == 'LBBD01020']['obs_id'], "\nwhich is NOT what we're looking for!")


# <a id=dataprodsD></a>
# ## 2.3. Choosing and Downloading Data Products
# 
# **Now we can choose and download our data products from the archive dataset.**
# 
# We will first generate a list of data products in the dataset: `product_list`. This will generate a large list, but we will only show the first 10 values.

# In[10]:


product_list = Observations.get_product_list(chosenObs)
product_list[:10]  # Not the whole dataset, just first 10 lines/observations


# Now, we will download *just the* **minimum recommended products** (*mrp*) which are the fully calibrated spectrum (denoted by the suffix `_x1d` or here `x1dsum`) and the association file (denoted by the suffix `_asn`). We do this by setting the parameter `mrp_only` to True. The association file contains no data, but rather the metadata explaining which exposures produced the `x1dsum` dataset. The `x1dsum` file is the final product summed across all of the [fixed pattern noise positions](https://hst-docs.stsci.edu/cosdhb/chapter-1-cos-overview/1-1-instrument-capabilities-and-design#id-1.1InstrumentCapabilitiesandDesign-GratingOffset(FP-POS)GratingOffsetPositions(FP-POS)) (`FP-POS`). The `x1d` and `x1dsum<n>` files are intermediate spectra. Much more information can be found in the [COS Instrument Handbook](https://hst-docs.stsci.edu/display/COSIHB/).
# 
# We would set `mrp_only` to False, if we wanted to download ***all*** the data from the observation, including: 
# - support files such as the spacecraft's pointing data over time (`jit` files).
# - intermediate data products such as calibrated TIME-TAG data (`corrtag` or `corrtag_a`/`corrtag_b` files) and extracted 1-dimensional spectra averaged over exposures with a specific `FP-POS` value (`x1dsum<n>` files).
# 
# <img src=./figures/warning.png width ="60" title="CAUTION">
# 
# However, use caution with downloading all files, as in this case, setting `mrp_only` to False results in the transfer of **7 Gigabytes** of data, which can take a long time to transfer and eat away at your computer's storage! In general, only download the files you need. On the other hand, often researchers will download only the raw data, so that they can process it for themselves. Since here we only need the final `x1dsum` and `asn` files, we only need to download 2 Megabytes.

# In[11]:


downloads = Observations.download_products(product_list, download_dir=str(
    data_dir), extension='fits', mrp_only=True, cache=False)


# ### Exercise 2: *Download the raw counts data on TRAPPIST-1*
# 
# In the previous exercise, we found an observation COS took on TRAPPIST-1 system. In case you skipped Exercise 1, the observation's Dataset ID is `LDLM40010`.
# 
# Use `Astroquery.mast` to download the raw `TIME-TAG` data, rather than the x1d spectra files. See the [COS Data Handbook Ch. 2](https://hst-docs.stsci.edu/cosdhb/chapter-2-cos-data-files/2-4-cos-data-products) for details on TIME-TAG data files. Make sure to get the data from both segments of the FUV detector (i.e. both `RAWTAG_A` and `RAWTAG_B` files). If you do this correctly, there should be five data files for each detector segment.
# 
# *Note that some of the obs_id may appear in the table as slightly different, i.e.: ldlm40alq and ldlm40axq, rather than ldlm40010. The main obs_id they fall under is still ldlm40010, and this will still work as a search term. They are linked together by the association file described here in section 2.3.*

# In[12]:


# Your answer here


# <a id=Astroquery2D></a>
# ## 2.4. Using astroquery to find data on a series of sources
# In this case, we'll look for COS data around several bright globular clusters:
# - Omega Centauri
# - M5
# - M13
# - M15
# - M53
# 
# We will first write a comma-separated-value (csv) file `objectname_list.csv` listing these sources by their common name. This is a bit redundant here, as we will immediately read back in what we have written; however it is done here to deliberately teach both sides of the writing/reading process, and as many users will find themselves with a csv sourcelist they must search.

# In[13]:


# The 5 sources we want to look for
sourcelist = ['omega Centauri', 'M5', 'M13', 'M15', 'M53']
# measures the length of the list for if statements below
sourcelist_length = len(sourcelist)

with open('./objectname_list.csv', 'w') as f:  # Open this new file in "write" mode
    # We want a comma after each source name except the last one
    for i, item in enumerate(sourcelist):
        if i < sourcelist_length - 1:
            f.writelines(item + ",")
        if i == sourcelist_length - 1:  # No comma after the last entry
            f.writelines(item)


# In[14]:


# Open the file we just wrote in "read" mode
with open('./objectname_list.csv', 'r', newline='') as csvFile:
    # This is the exact same list as `sourcelist`!
    objList = list(reader(csvFile, delimiter=','))[0]

print("The input csv file contained the following sources:\n", objList)

# Make a dictionary, where each source name (i.e. "M15") corresponds to a list of its observations with COS
globular_cluster_queries = {}
for obj in objList:  # each "obj" is a source name
    query_x = Observations.query_criteria(objectname=obj, radius="5 min", instrument_name=[
                                          'COS/FUV', 'COS/NUV'])  # query the area in +/- 5 arcminutes
    # add this entry to the dictionary
    globular_cluster_queries[obj] = (query_x)

globular_cluster_queries  # show the dictionary


# **Excellent! You've now done the hardest part - finding and downloading the right data.** From here, it's generally straightforward to read in and plot the spectrum. We recommend you look into our tutorial on [Viewing a COS Spectrum](https://github.com/spacetelescope/notebooks/blob/master/notebooks/COS/ViewData/ViewData.ipynb).

# ## Congratulations! You finished this Notebook!
# ### There are more COS data walkthrough Notebooks on different topics. You can find them [here](https://spacetelescope.github.io/COS-Notebooks/).

# 
# ---
# ## About this Notebook
# **Author:** Nat Kerman <nkerman@stsci.edu>
# 
# **Updated On:** 2022-09-20
# 
# > *This tutorial was generated to be in compliance with the [STScI style guides](https://github.com/spacetelescope/style-guides) and would like to cite the [Jupyter guide](https://github.com/spacetelescope/style-guides/blob/master/templates/example_notebook.ipynb) in particular.*
# 
# ## Citations
# 
# If you use `astropy`, `matplotlib`, `astroquery`, or `numpy` for published research, please cite the
# authors. Follow these links for more information about citations:
# 
# * [Citing `astropy`/`numpy`/`matplotlib`](https://www.scipy.org/citing.html)
# * [Citing `astroquery`](https://astroquery.readthedocs.io/en/latest/)
# 
# ---
# 
# [Top of Page](#topD)
# <img style="float: right;" src="https://raw.githubusercontent.com/spacetelescope/notebooks/master/assets/stsci_pri_combo_mark_horizonal_white_bkgd.png" alt="Space Telescope Logo" width="200px"/> 
# 
# <br></br>
# <br></br>
# <br></br>

# ## Exercise Solutions:
# Note, that for many of these, there are multiple ways to get an answer.

# **We will import:**
# - numpy to handle array functions
# - astropy.table Table for creating tidy tables of the data

# In[15]:


# Manipulating arrays
import numpy as np
# Reading in data
from astropy.table import Table


# In[16]:


# Ex. 1 solution:
dataset_id_ = 'LDLM40010'
exptime_ = 12403.904
print(f"The TRAPPIST-1 COS data is in dataset {dataset_id_},"+
      f" taken with an exosure time of {exptime_}")


# In[17]:


# Ex. 2 solution:
query_3 = Observations.query_criteria(obs_id='LDLM40010',
                                      wavelength_region="UV", instrument_name="COS/FUV", filters='G130M')

product_list2 = Observations.get_product_list(query_3)
rawRowsA = np.where(product_list2['productSubGroupDescription'] == "RAWTAG_A")
rawRowsB = np.where(product_list2['productSubGroupDescription'] == "RAWTAG_B")
rawRows = np.append(rawRowsA, rawRowsB)
get_ipython().system('mkdir ./data/Ex2/')
downloads2 = Observations.download_products(product_list2[rawRows], download_dir=str(
    data_dir/'Ex2/'), extension='fits', mrp_only=False, cache=True)
downloads3 = Observations.download_products(product_list2, download_dir=str(
    data_dir/'Ex2/'), extension='fits', mrp_only=True, cache=True)

asn_data = Table.read(
    './data/Ex2/mastDownload/HST/ldlm40010/ldlm40010_asn.fits', hdu=1)
print(asn_data)

