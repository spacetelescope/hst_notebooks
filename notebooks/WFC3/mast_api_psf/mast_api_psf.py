"""
Name
----
WFC3 and WFPC2 PSF MAST Database Module

Purpose
-------
This module contains functions for querying sources and downloading
source cutouts from the WFC3 and WFPC2 PSF databases.

Use
---
This module is intended to be imported in a Jupyter notebook:

    >>> import mast_api_psf

Author
------
Fred Dauphin, July 2024
"""

import datetime
import multiprocessing
import os
import requests

import tqdm
from astropy.io import fits
from astroquery.mast import Mast

REQUEST_URL_PREFIX = 'https://mast.stsci.edu/api/v0.1/Download'


# Helper functions from https://mast.stsci.edu/api/v0/pyex.html
def set_filters(parameters):
    """
    Some filtering queries require human-unfriendly syntax. 
    This allows you to enter your filter criteria as a dictionary, 
    which will then be parsed into correct format for searching.
    """
    return [{"paramName": p, "values": v} for p, v in parameters.items()]


def set_min_max(min, max):
    """
    Some parameters require minimum and maximum acceptable values: 
    for example, both RA and Dec must be given as a range. 
    This is a convenience function to format such a query correctly.
    """
    return [{'min': min, 'max': max}]


# Downloading functions
def download_request_file(dataURI_filename):
    """
    Performs a get request to download a specified file from the MAST server.

    This function is intended for downloading single cutouts. The load and
    download limits for a single query are 50,000 and 500,000, respectively.
    The file is intended to be downloaded as a .fits:

    Parameters
    ----------
    dataURI_filename : list
        The dataURI to be downloaded and the name of the downloaded fits file.
        This is one parameter instead of two so a progress bar can be applied
        to multiprocessing.
    
    Returns
    -------
    filename : str
        The name of the downloaded file.
    """
    dataURI = dataURI_filename[0]
    filename = dataURI_filename[1]

    # Specify download type
    download_type = 'file'
    request_url = f'{REQUEST_URL_PREFIX}/{download_type}'

    # Request payload
    payload = {'uri': dataURI}
    resp = requests.get(request_url, params=payload)
    
    # Write response to filename
    with open(filename, 'wb') as FLE:
        FLE.write(resp.content)
 
    return filename


def download_request_pool(dataURIs, cpu_count=0):
    """
    Performs a get request to download a specified file from the MAST server.

    This function is intended for downloading multiple cutouts. The load and
    download limits for a single query are 50,000 and 500,000, respectively.
    This function is optimized by pooling and shows a progress bar.

    Parameters
    ----------
    dataURIs : list
        The dataURIs to be downloaded.

    cpu_count : int, default=0
        The number of cpus for multiprocessing. If 0, set to all available cpus.

    Returns
    -------
    path_dir : str
        The directory path to the downloaded cutouts.
    """
    # Make PSF directory if necessary for downloads
    now = datetime.datetime.now().strftime('MAST_%Y-%m-%dT%H%M')
    if 'WFC3' in dataURIs[0]:
        ins_psf = 'WFC3PSF'
    else:
        ins_psf = 'WFPC2PSF'
    path_dir = f'{now}/{ins_psf}'
    if not os.path.isdir(path_dir):
        os.makedirs(path_dir)
    
    # Prepare arguments for pooling
    filenames = [f'{path_dir}/{dataURI.split("/")[-1]}' for dataURI in dataURIs]
    args = zip(dataURIs, filenames)
    
    # Pool using a progress bar
    if cpu_count == 0:
        cpu_count = os.cpu_count()
    total = len(filenames)
    pool = multiprocessing.Pool(processes=cpu_count)
    _ = list(tqdm.tqdm(pool.imap(download_request_file, args), total=total))
    pool.close()
    pool.join()

    return path_dir


def download_request_bundle(dataURIs, filename):
    """
    Performs a get request to download a specified file from the MAST server.

    This function is intended for downloading multiple cutouts. The load and
    download limits for a single query are 50,000 and 500,000, respectively.
    The file downloaded is a .tar.gz:

    Parameters
    ----------
    dataURIs : list
        The dataURIs to be downloaded.
    filename : str
        The name of the downloaded '.tar.gz' file.
    
    Returns
    -------
    filename : str
        The name of the downloaded file.
    """
    # Specify download type
    download_type = 'bundle.tar.gz'
    request_url = f'{REQUEST_URL_PREFIX}/{download_type}'

    # Request payload
    payload = [("uri", dataURI) for dataURI in dataURIs]
    resp = requests.post(request_url, data=payload)
    
    # Write response to filename
    with open(filename, 'wb') as FLE:
        FLE.write(resp.content)
 
    return filename


# Main functions
def mast_query_psf_database(detector, filts, columns=['*']):
    """
    Query the WFC3/WFPC2 PSF databases on the MAST Portal using the MAST API.
    
    Both WFC3 channels (UVIS and IR) are accessible.
    
    The allowed columns (i.e. fields) are documented here:
    https://mast.stsci.edu/api/v0/_w_f_c3__p_s_ffields.html
    
    Note: WFPC2's field for 'filter' (e.g. F606W) is called 'filter_1' so use 
    that accordingly.
    
    Parameters
    ----------
    detector : str
        The detector of the database to query. Allowed values are UVIS, IR, and 
        WFPC2.
    filts : list of dicts
        The filters applied to the query. Can be made using `set_filters`.
    columns : list, default=['*']
        The columns to return for the query. If '*' is in `columns`, then all 
        columns are returned.
        
    Returns
    -------
    obs : astropy.table.Table
        A table of the queried sources' metadata with specific filters and 
        columns applied.
    """
    # Check types
    if not isinstance(detector, str):
        raise TypeError('detector must be a string.')
    if not isinstance(filts, list):
        raise TypeError('filts must be a list.')
    if not isinstance(columns, list):
        raise TypeError('columns must be a list.')
    
    # Determine service for database
    detector = detector.upper()
    service_base = 'Mast.Catalogs.Filtered'
    detector_databases = {
        'UVIS': 'Wfc3Psf.Uvis', 
        'IR': 'Wfc3Psf.Ir', 
        'WFPC2': 'Wfpc2Psf.Uvis'
    }
    try:
        database = detector_databases[detector]
    except KeyError:
        valid_detectors = list(detector_databases.keys())
        raise ValueError(f'{detector} is not a valid detector. ' 
                         f'Choose from {valid_detectors}.')
    service = f'{service_base}.{database}'
    
    # If WFPC2, change filter to filter_1
    if detector == 'WFPC2':
        if 'filter' in columns:
            index = columns.index('filter')
            columns[index] = 'filter_1'
        for param in filts:
            if 'filter' in param.values():
                param['paramName'] = 'filter_1'

    # Determine columns to query
    if '*' in columns:
        cols = '*'
    else:
        cols = ','.join(columns)
    
    # Set parameters and query database
    params = {'columns': cols,
              'filters': filts}
    obs = Mast.service_request(service, params)
    
    return obs


def make_dataURIs(obs, detector, file_suffix, unsat_size=51, sat_size=101):
    """
    Make dataURIs for the WFC3 and WFPC2 PSF databases' sources.
    
    The dataURIs are URLs for downloading cutouts from the MAST Portal.
    The cutouts are made using the package fitscut.
    They can retrieve: 
        - raw data with suffixes 'raw' for WFC3 and 'd0m' for WFPC2.
        - calibrated data with suffixes 'flt' for WFC3 and 'c0m' for WFPC2.
        - charge transfer efficiency (CTE) corrected data with the suffix 'flc' 
          for UVIS.
    
    Parameters
    ----------
    obs : astropy.table.Table
        A table of the queried sources' metadata with specific filters and 
        columns applied.
    detector : str
        The detector of the queried sources. Allowed values are UVIS, IR, and 
        WFPC2.
    file_suffix : list
        The file suffixes to prepare for download. Allowed values are raw, d0m, 
        flt, c0m, and flc.
    unsat_size : int, default=51
        The size for unsaturated (qfit>0;n_sat_pixels==0) cutouts.
    sat_size : int, default=101
        The size for saturated (qfit==0;n_sat_pixels>0) cutouts.
    
    Returns
    -------
    dataURIs : list
        The dataURIs made from the queried sources.
    """
    # Check type
    if not isinstance(file_suffix, list):
        raise TypeError('detector must be a list.')
    
    # Check suffixes (make sure there isn't a wrong suffix)
    valid_suffixes = ['raw', 'd0m', 'flt', 'c0m', 'flc']
    for suffix in file_suffix:
        if suffix not in valid_suffixes:
            raise ValueError(f'{suffix} is not a valid suffix. '
                             f'Choose from {valid_suffixes}.')
    
    # Determine database that was queried
    detector = detector.upper()
    wfc3_detectors = ['UVIS', 'IR']
    if detector in wfc3_detectors:
        instrument = 'WFC3'
    else:
        instrument = 'WFPC2'
    dataURI_base = f'mast:{instrument}PSF/url/cgi-bin/fitscut.cgi'

    # Loop through obs to make dataURIs
    dataURIs = []
    for row in tqdm.tqdm(obs, total=len(obs)):
        # Unpack values
        iden = row['id']
        root = row['rootname']
        if detector == 'WFPC2':
            filt = row['filter_1']
        else:
            filt = row['filter']
        chip = row['chip']
        qfit = row['qfit']
        if qfit > 0:
            size = unsat_size
        else:
            size = sat_size
        subarray = row['subarray']
        
        # If UVIS use chip to assign correct fits ext
        if detector == 'UVIS':
            if chip == '1' and subarray == 0:
                fits_ext = 4
            else:
                fits_ext = 1
        # Else chip is the correct fits ext
        else:
            fits_ext = chip
            
        # Make dataURIs for each suffix
        for suffix in file_suffix:
            if suffix in ['raw', 'd0m']:
                coord_suffix = 'raw'
            else:
                coord_suffix = 'cal'
            x = row[f'x_{coord_suffix}']
            y = row[f'y_{coord_suffix}']

            file_read = f'red={root}_{suffix}[{fits_ext}]'
            cutout = f'size={size}&x={x}&y={y}&format=fits'
            file_save = f'{root}_{iden}_{filt}_{suffix}_cutout.fits'
            dataURI = f'{dataURI_base}?{file_read}&{cutout}/{file_save}'
            dataURIs.append(dataURI)
    
    return dataURIs


def convert_dataURIs_to_dataURLs(dataURIs):
    """
    Convert dataURIs to URLs for the WFC3 and WFPC2 PSF databases' sources.

    Use the archive url, the hla folder, and the imagename parameter.
    
    Parameters
    ----------
    dataURIs : list
        The dataURIs made from the queried sources.
    
    Returns
    -------
    dataURLs : list
        The dataURLs for the queried sources.
    """
    # Convert to dataURLs
    dataURL_base = 'https://archive.stsci.edu/cgi-bin/hla'
    dataURLs = []
    for dataURI in tqdm.tqdm(dataURIs, total=len(dataURIs)):
        dataURL_split = dataURI.split('/')
        file_cutout = f'{dataURL_split[3]}&imagename={dataURL_split[4]}'
        dataURL = f'{dataURL_base}/{file_cutout}'
        dataURLs.append(dataURL)
    return dataURLs


def extract_cutouts_pool(dataURLs, cpu_count=0):
    """
    Extract cutouts from dataURLs using multiprocessing. 
    
    Parameters
    ----------
    dataURIs : list
        The dataURLs made from the queried sources.
    cpu_count : int, default=0
        The number of cpus for multiprocessing. If 0, set to all available cpus.
    
    Returns
    -------
    cutouts : list
        The queried sources.
    """
    # Pool using a progress bar
    if cpu_count == 0:
        cpu_count = os.cpu_count()
    total = len(dataURLs)
    pool = multiprocessing.Pool(processes=cpu_count)
    cutouts = list(tqdm.tqdm(pool.imap(fits.getdata, dataURLs), total=total))
    pool.close()
    pool.join()

    return cutouts
