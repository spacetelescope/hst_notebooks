"""Reduce a time series of WFC3/UVIS G280 2D spectra to a light curve.

The functions include cosmic ray removal (temporal and spatial), subarray 
embedding, spectral trace fitting, spectrum extraction, and light curve 
generation.

Authors
-------
    Munazza Alam, 2025
    Fred Dauphin, 2025

Use
---
    This module is intended to be imported in a Jupyter notebook:

    >>> import g280_transit_tools

"""

import os
import shutil
import tqdm

import numpy as np
import scipy.ndimage as ndi
from astropy.io import fits

import grismconf
    
    
def remove_cosmic_rays_time(time_series, n_sigma=4, n_iter=4):
    """Remove temporal cosmic rays.

    Parameters
    ----------
    time_series : np.array
        Array of images with shape (n_spectra, y, x).
    n_sigma : float, default=4
        Number of sigma above RMSE for outlier detection.
    n_iter : int, default=4
        Number of iterations for outlier removal.

    Returns
    -------
    time_series_cr_time : np.array
        Array of images with temporal outliers removed with shape 
        (n_spectra, y, x).
    mask_outliers_time : np.array
        Array of masks for temporal outliers with shape (n_spectra, y, x).
    """

    # Create temporal cosmic ray corrected images and masks
    time_series_cr_time = time_series.copy()
    mask_outliers_time = np.zeros_like(time_series_cr_time).astype(bool)

    # Iteratively remove temporal outliers
    for i in tqdm.tqdm(range(n_iter), total=n_iter):
        
        # Compute root mean squared error (RMSE) image from median image
        median = np.median(time_series_cr_time, axis=0)
        rmse = np.sqrt(np.mean((time_series_cr_time - median) ** 2, axis=0))

        # Detect outliers as n_sigma * RMSE above absolute deviation image
        abs_deviation = np.abs(time_series_cr_time - median)
        mask_outliers = abs_deviation > n_sigma * rmse

        # Update temporal outliers mask
        mask_outliers_time = mask_outliers_time | mask_outliers

        # Change outliers to median pixel values
        time_series_cr_time = np.where(
            mask_outliers, median, time_series_cr_time
        )

    return time_series_cr_time, mask_outliers_time


def ndi_std_filter(input, size):
    """Calculate a multidimensional standard deviation filter.

    Parameters
    ----------
    input : np.array
        The input array.
    size : int
        Filter kernel size.
    
    Returns
    -------
    std_filter : np.array
        Filtered array. Has the same shape as input.
    """
    
    # Calculate mean filter on input
    input_mean = ndi.uniform_filter(input, size=size)

    # Calculate mean filter on squared input
    input_sq_mean = ndi.uniform_filter(input ** 2, size=size)

    # Calculate standard deviation filter from mean filters
    std_filter = np.sqrt(input_sq_mean - input_mean ** 2)

    return std_filter


def remove_cosmic_rays_space(time_series, n_sigma=3, size=3):
    """Remove spatial cosmic rays.

    Parameters
    ----------
    time_series : np.array
        Array of images with shape (n_spectra, y, x).
    n_sigma : float, default=3
        Number of sigma above standard deviation for outlier detection.
    size : int, default=3
        Filter kernel size.

    Returns
    -------
    time_series_cr_space : np.array
        Array of images with spatial outliers removed with shape 
        (n_spectra, y, x).
    mask_outliers_space : np.array
        Array of masks for spatial outliers with shape (n_spectra, y, x).
    """

    # Create spatial cosmic ray corrected images
    n_spectra = time_series.shape[0]
    time_series_cr_space = time_series.copy()
    mask_outliers_space = np.zeros_like(time_series_cr_space).astype(bool)
    
    # Loop through each exposure
    for i in tqdm.tqdm(range(n_spectra), total=n_spectra):

        # Compute median and standard deviation filters
        median_filter = ndi.median_filter(time_series_cr_space[i], size=size)
        std_filter = ndi_std_filter(time_series_cr_space[i], size=size)

        # Detect outliers as n_sigma * STD above absolute deviation image
        abs_deviation = np.abs(time_series_cr_space[i] - median_filter)
        mask_outliers = abs_deviation > n_sigma * std_filter

        # Update spatial outliers mask
        mask_outliers_space[i] = mask_outliers

        # Change outliers to median pixel values
        time_series_cr_space[i] = np.where(
            mask_outliers, median_filter, time_series_cr_space[i]
        )
    
    return time_series_cr_space, mask_outliers_space


def embedsub_uvis(path, sub_dir):
    """Embed a UVIS subarray onto a UVIS chip.

    This function is a derivative of 
    https://github.com/spacetelescope/wfc3tools/blob/main/wfc3tools/embedsub.py
    where we embed the subarray with header keywords from the SCI extension
    instead of _spt.fits files.

    Parameters
    ----------
    path : str
        Path to _flt.fits file.
    sub_dir : str
        Path to subdirectory to save full frame file.
    
    Returns
    -------
    path_f : str
        Path to _f_flt.fits file.
    """

    # Define axes
    y_axis = 2051
    x_axis = 4096
    
    # Make a copy of the file
    file_f = os.path.basename(path.replace('flt.fits', 'f_flt.fits'))
    path_f = f'{sub_dir}/{file_f}'
    shutil.copyfile(path, path_f)

    # Update the copy
    with fits.open(path_f, mode='update') as hdu:

        # Make full frame extensions
        sci = np.zeros((y_axis, x_axis), dtype=np.float32)
        err = np.zeros((y_axis, x_axis), dtype=np.float32)
        dq = np.zeros((y_axis, x_axis), dtype=np.int16) + 4

        # Extract header keyword values
        naxis1 = hdu['SCI', 1].header['NAXIS1']
        naxis2 = hdu['SCI', 1].header['NAXIS2']
        ltv1 = hdu['SCI', 1].header['LTV1']
        ltv2 = hdu['SCI', 1].header['LTV2']
        crpix1 = hdu['SCI', 1].header['CRPIX1']
        crpix2 = hdu['SCI', 1].header['CRPIX2']

        # Find min/max pixels
        y_min = int(-ltv2)
        y_max = y_min + naxis2
        x_min = int(-ltv1)
        x_max = x_min + naxis1

        # Embed subarray onto full frame extensions
        sci[y_min:y_max, x_min:x_max] = hdu['SCI', 1].data
        err[y_min:y_max, x_min:x_max] = hdu['ERR', 1].data
        dq[y_min:y_max, x_min:x_max] = hdu['DQ', 1].data

        # Update SIZAXIS values
        hdu['SCI', 1].header['SIZAXIS1'] = x_axis
        hdu['SCI', 1].header['SIZAXIS2'] = y_axis

        # Update CRPIX and LTV values
        for ext in ['SCI', 'ERR', 'DQ']:
            if 'CRPIX1' in hdu[ext, 1].header:
                hdu[ext, 1].header['CRPIX1'] = crpix1 + x_min
                hdu[ext, 1].header['CRPIX2'] = crpix2 + y_min
            if 'LTV1' in hdu[ext, 1].header:
                hdu[ext, 1].header['LTV1'] = 0.0
                hdu[ext, 1].header['LTV2'] = 0.0

        # Update SUBARRAY value
        hdu[0].header['SUBARRAY'] = False
        
        # Update data
        hdu['SCI', 1].data = sci
        hdu['ERR', 1].data = err
        hdu['DQ', 1].data = dq

    return path_f


def fit_spectral_trace(
    path_config, source_x, source_y, order, wl_min=2000, wl_max=8000
):
    """Fit spectral trace to a 2D spectrum.
    
    Parameters
    ----------
    path_config : str
        Path to GRISMCONF configuration file.
    source_x : float
        X pixel position of the source in the direct image.
    source_y : float
        Y pixel position of the source in the direct image.
    order : str
        Spectral order for trace fitting.
    wl_min : float, default=2000
        Minimum wavelength for spectrum extraction.
    wl_max : float, default=8000
        Maximum wavelength for spectrum extraction.

    Returns
    -------
    trace_x : np.array
        X positions of the spectral trace.
    trace_y : np.array
        Y positions of the spectral trace.
    wavelength : np.array
        Wavelength of the 1D extracted spectrum in Angstroms.
    sensitivity : np.arrray
        Sensitivity function for selected spectral order.
    """
    
    # Read in GRISMCONF configuration file 
    config_file = grismconf.Config(path_config)

    # X dispersion polynomial
    disp_x = config_file.DISPX(order, source_x, source_y, np.array([0, 1]))
    disp_x = np.sort(disp_x)
    disp_x = np.arange(disp_x[0], disp_x[1], 1)
    
    # Compute spectral trace 
    trace = config_file.INVDISPX(order, source_x, source_y, disp_x)
    
    # Y dispersion polynomial
    disp_y = config_file.DISPY(order, source_x, source_y, trace)
    
    # Get wavelength solution 
    wavelength = config_file.DISPL(order, source_x, source_y, trace)
    
    # Trim wavelength range
    mask_wl = (wavelength >= wl_min) & (wavelength <= wl_max)
    disp_x = disp_x[mask_wl]
    disp_y = disp_y[mask_wl]
    wavelength = wavelength[mask_wl]
    
    # Get trace location
    trace_x = disp_x + source_x
    trace_y = disp_y + source_y

    # Get sensitivity profile 
    sensitivity_profile = config_file.SENS[order]
    fs = sensitivity_profile.f
    sensitivity = fs(wavelength)
    
    return trace_x, trace_y, wavelength, sensitivity
    
    
def extract_spectrum(path, y_min, y_max, trace_x):
    """Extract 1D spectrum from a 2D spectrum.

    Parameters
    ----------
    path : str
        Path to full frame 2D spectrum.
    y_min : float
        Minimum y pixel coordinate for the aperture extraction box.
    y_max : float
        Maximum y pixel coordinate for the aperture extraction box.
    trace_x : np.array
        X positions of the spectral trace.

    Returns
    -------
    counts : np.array
        1D spectrum counts.
    counts_err : np.array 
        1D spectrum count error.
    """

    # Extract data
    data = fits.getdata(path, 'SCI', 1)
    err = fits.getdata(path, 'ERR', 1)

    # Slice data
    y_min = int(y_min)
    y_max = int(y_max)
    x_min = int(np.min(trace_x))
    x_max = int(np.max(trace_x)) + 1
    data_aperture_trace = data[y_min:y_max, x_min:x_max]
    err_aperture_trace = err[y_min:y_max, x_min:x_max]

    # Get spectral counts and error
    counts = np.sum(data_aperture_trace, axis=0)
    counts_err = np.sqrt(np.sum(err_aperture_trace ** 2, axis=0))
    
    return counts, counts_err
    
    
def make_light_curve(wavelength, time_series_counts, wl_min=2000, wl_max=8000):
    """Generate a transit light curve from a time-series of extracted 1D stellar 
    spectra.
    
    Parameters
    ----------
    wavelength : np.array
        Wavelength of the 1D extracted spectrum in Angstroms.
    time_series_counts : np.array
        Time series of 1D spectrum counts.
    wl_min : float, default=2000
        Minimum wavelength for counts measurement.
    wl_max : float, default=8000
        Maximum wavelength for counts measurement.

    Returns
    ------- 
    lc_counts : np.array
        Light curve counts.
    lc_counts_err : np.array
        Light curve count error.
    """

    # Mask wavelengths
    mask_wl = (wavelength > wl_min) & (wavelength < wl_max)

    # Compute light curves counts from spectra
    lc_counts = np.sum(time_series_counts.T[mask_wl], axis=0)

    # Approximate light curve count errors
    lc_counts_err = np.sqrt(lc_counts) / lc_counts
    
    return lc_counts, lc_counts_err
