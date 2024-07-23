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
Fred Dauphin, February 2024
"""

import requests
from astroquery.mast import Mast


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


def download_request(payload, filename, download_type="file"):
    """
    Performs a get request to download a specified file from the MAST server.

    The load and download limits for a single query are 50,000 and 500,000, 
    respectively. It is recommended to download all files as a .tar.gz:
    ```
    download_requests(payload=payload, 
                      filename='filename.tar.gz',
                      download_type='bundle.tar.gz')
    ```

    Parameters
    ----------
    payload : list
        The dataURIs to be downloaded.
    filename : str
        The name of the downloaded file. To download a .tar.gz (recommended), 
        include '.tar.gz' as the file extension.
    download_type : str, default="file"
        The type of file to download. To download a .tar.gz (recommended), use
        'bundle.tar.gz'.
    
    Returns
    -------
    filename : str
        The name of the downloaded file.
    """
    request_url = 'https://mast.stsci.edu/api/v0.1/Download/' + download_type
    resp = requests.post(request_url, data=payload)
 
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
    if type(detector) is not str:
        raise TypeError('detector must be a string.')
    if type(filts) is not list:
        raise TypeError('filts must be a list.')
    if type(columns) is not list:
        raise TypeError('columns must be a list.')
    
    # Check detectors
    valid_detectors = ['UVIS', 'IR', 'WFPC2']
    detector = detector.upper()
    if detector not in valid_detectors:
        raise ValueError(f'{detector} is not a valid detector. ' 
                         f'Choose from {valid_detectors}.')
    
    # Determine service for database
    service_base = 'Mast.Catalogs.Filtered'
    if detector == 'UVIS':
        database = 'Wfc3Psf.Uvis'
    elif detector == 'IR':
        database = 'Wfc3Psf.Ir'
    else:
        database = 'Wfpc2Psf.Uvis'
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


def make_dataURIs(obs, detector, file_suffix, sizes={'unsat': 51, 'sat': 101}):
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
        The file suffixes to prepare for download.
    sizes : dict, default={'unsat':51, 'sat':101}
        The sizes for unsaturated (qfit>0;n_sat_pixels==0) and saturated 
        (qfit==0;n_sat_pixels>0) cutouts.
    
    Returns
    -------
    dataURIs : list
        The dataURIs made from the queried sources as ('uri', dataURI).
    """
    # Check type
    if type(file_suffix) is not list:
        raise TypeError('detector must be a list.')
    if type(sizes) is not dict:
        raise TypeError('sizes must be a dictionary.')
    
    # Check suffixes (make sure there isn't a wrong suffix)
    valid_suffixes = ['raw', 'd0m', 'flt', 'c0m', 'flc']
    for suffix in file_suffix:
        if suffix not in valid_suffixes:
            raise ValueError(f'{suffix} is not a valid suffix. '
                             f'Choose from {valid_suffixes}.')

    # Check sizes (make sure unsat and sat are in sizes)
    valid_sizes = ['unsat', 'sat']
    for size in valid_sizes:
        if size not in sizes.keys():
            raise ValueError(f'{size} needs to be included. '
                             f'Choose an appropriate value.')
    
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
    pixel_offset = 1 # centers sources
    mask_full_frame = (obs['subarray'] == 0).data # only support full frame
    for row in obs[mask_full_frame]:
        # Unpack values
        iden = row['id']
        root = row['rootname']
        if detector == 'WFPC2':
            filt = row['filter_1']
        else:
            filt = row['filter']
        x = row['psf_x_center'] - pixel_offset
        y = row['psf_y_center'] - pixel_offset
        chip = row['chip']
        qfit = row['qfit']
        if qfit > 0:
            size = sizes['unsat']
        else:
            size = sizes['sat']
            
        # If UVIS use chip to asign correct sci ext
        if detector == 'UVIS':
            if chip == '2':
                sci_ext = 1
            elif chip == '1':
                sci_ext = 4
                if y >= 2051:
                    y -= 2051 - 3 # another offset to center UVIS1 sources
        # Else chip is the correct sci ext
        else:
            sci_ext = chip
            
        # Make dataURIs for each suffix
        for suffix in file_suffix:
            file_read = f'red={root}_{suffix}[{sci_ext}]'
            cutout = f'size={size}&x={x}&y={y}&format=fits'
            file_save = f'{root}_{iden}_{filt}_{suffix}_cutout.fits'
            dataURI = f'{dataURI_base}?{file_read}&{cutout}/{file_save}'
            dataURIs.append(("uri", dataURI))
    
    n_subarray_sources = (~mask_full_frame).sum()
    print(f'Found {n_subarray_sources} subarray sources in queried data.')
    return dataURIs
