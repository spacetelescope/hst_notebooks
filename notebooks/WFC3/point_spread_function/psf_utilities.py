"""
Name
----
psf_utilities.py

Purpose
-------
This module contains functions for creating Point Spread Function (PSF) 
models for HST WFC3 images by extracting and stacking stellar sources. 
It also contains plotting functions for generating and saving figures.

Use
---
This module is intended to be imported within a python Jupyter notebook:

    >>> import psf_utilities

Author
------
Mitchell Revalski
Created: 15 Apr 2024
Updated: 23 May 2024
"""

import os
import shutil
import urllib
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
from astropy.io import fits
from astropy.visualization import simple_norm
from astropy.stats import sigma_clipped_stats
from photutils.detection import find_peaks
from photutils.centroids import centroid_com
from photutils.aperture import CircularAperture
from scipy.ndimage import shift


def save_figure(figure, filename, show_figure):

    """
    Save the current figure and display or close the file.

    Parameters
    ----------
    figure : matplotlib.figure.Figure
        The matplotlib image that the user would like to save.
    filename : str
        The full filepath including the desired filename to save.
    show_figure : bool
        The figure will be shown in the notebook if set to True.

    Returns
    -------
    filename : str
        Prints the file location of where the figure was saved.
    """

    figure.tight_layout()
    plt.savefig(filename)
    if (show_figure is True):
        plt.show()
    if (show_figure is False):
        plt.close()

    return print('\nFigure saved as: '+filename)


def setup_matplotlib(size, multiplier):

    """
    Change the default matplotlib parameters to improve figures.
    The size parameter sets the overall image size, while the
    multiplier parameter increases the fontsize and line widths.

    Parameters
    ----------
    size : tuple
        A tuple with the desired image size in inches. There is
        a shortcut option of 'notebook' that will set the size 
        to (11, 11) inches, which fills the width of a notebook.
    multiplier : float
        The value by which the default fontsizes and line widths 
        are multiplied by in order to produce bolder graphics. 
        The value can be greater than or less than one.

    Returns
    -------
    my_figure_size : tuple
        A tuple with the user-specified image size in inches.
    my_fontsize : float
        The user-specified fontsize in standard point units.
    """

    plt.rcdefaults() # restore default values
    plt.rcParams["font.family"] = "STIXGeneral"
    plt.rcParams["mathtext.fontset"] = "stix"
    plt.rcParams['text.usetex'] = False
    default_thickness_frame = 0.66
    default_thickness_lines = 1.00
    default_fontsize = 10
    
    if (size == 'notebook'):
        my_scale = 1.0
        my_figure_size = (11.0, 11.0)
    else:
        my_scale = multiplier
        my_figure_size = (size, size)
        
    my_scale = (my_scale * multiplier)
    plt.rcParams["figure.figsize"] = my_figure_size
    plt.rcParams["font.size"] = default_fontsize * my_scale
    plt.rcParams["axes.linewidth"] = default_thickness_frame * my_scale
    plt.rcParams["lines.linewidth"] = default_thickness_lines * my_scale
    plt.rcParams['xtick.major.width'] = default_thickness_frame * my_scale
    plt.rcParams['xtick.minor.width'] = default_thickness_frame * my_scale
    plt.rcParams['ytick.major.width'] = default_thickness_frame * my_scale
    plt.rcParams['ytick.minor.width'] = default_thickness_frame * my_scale
    plt.rcParams['xtick.major.size'] = 3.0 * my_scale
    plt.rcParams['ytick.major.size'] = 3.0 * my_scale
    plt.rcParams['xtick.minor.size'] = 1.5 * my_scale
    plt.rcParams['ytick.minor.size'] = 1.5 * my_scale
    my_fontsize = plt.rcParams["font.size"]
        
    return my_figure_size, my_fontsize


def create_mask(data, cutout_size, xcenter, ycenter):

    """
    A function that accepts an array of science data, a cutout size in 
    pixels, and xcenter and ycenter locations. The function returns a 
    mask that is compatible with the daofind function so that source 
    searches are only conducted on a portion of the overall image.

    Parameters
    ----------
    data : array
        The np.ndarray for masking, typically a science image array.
    cutout_size : int
        The desired width and height of the unmasked region in pixels.
    xcenter : int
        The desired x-centroid location in pixels for the unmasked data.
    ycenter : int
        The desired y-centroid location in pixels for the unmasked data.

    Returns
    -------
    mask : array
        A np.ndarray of boolean values where True will be masked by daofind.
    """
    
    # Create a mask array that is the same size as the science image.
    # Next, mask the upper, lower, left, and right regions with True.
    mask = np.zeros(data.shape, dtype=bool)
    mask[ycenter+int(cutout_size/2):np.shape(data)[0], 0:np.shape(data)[1]] = True
    mask[0:ycenter-int(cutout_size/2), 0:np.shape(data)[1]] = True
    mask[0:np.shape(data)[0], 0:xcenter-int(cutout_size/2)] = True
    mask[0:np.shape(data)[0], xcenter+int(cutout_size/2):np.shape(data)[1]] = True

    return mask


def plot_apertures(data, xcenter, ycenter, cutout_size, apertures_stellar, apertures_annulus):

    """
    A function that takes an image, x and y center locations, cutout size, and 
    stellar and background photometric apertures that were calculated with the 
    photutils CircularAperture and CircularAnnulus functions, respectively. 
    The function then creates a figure showing the apertures over the data.

    Parameters
    ----------
    data : np.ndarray
        The np.ndarray for masking, typically a science image array.
    xcenter : int
        The desired x-centroid location in pixels for the resulting figure.
    ycenter : int
        The desired y-centroid location in pixels for the resulting figure.
    cutout_size : int
        The desired width and height of the unmasked region in pixels.
    apertures_stellar : photutils.aperture.circle.CircularAperture
        The circular apertures being used to measure stellar fluxes.
    apertures_annulus : photutils.aperture.circle.CircularAnnulus
        The circular annuli being used to measure background fluxes.

    Returns
    -------
    figure : matplotlib.figure.Figure
        A figure with stellar and background annuli shown plotted on the data.
    """
    
    # Create a figure with the data, identified stars, and photometry apertures.
    my_figure_size, my_fontsize = setup_matplotlib('notebook', 1.2)
    figure, axes = plt.subplots(1, 3, figsize=(11.0, 11.0/3))
    norm = simple_norm(data, 'sqrt', percent=99.8)

    for ax in axes:
        ax.imshow(data, origin='lower', aspect='equal', interpolation='nearest', norm=norm)
        ax.set_xlim([xcenter-cutout_size/2, xcenter+cutout_size/2])
        ax.set_ylim([ycenter-cutout_size/2, ycenter+cutout_size/2])

    apertures_stellar.plot(ax=axes[1], color='lime', alpha=1.0)
    apertures_stellar.plot(ax=axes[2], color='lime', alpha=1.0)
    apertures_annulus.plot(color='white')

    axes[0].set_title('Original Data')
    axes[1].set_title('Identified Stars')
    axes[2].set_title('Photometry Apertures')
    axes[0].set_ylabel('Y (pixels)')
    axes[1].set_xlabel('X (pixels)')
    plt.tight_layout()

    return figure


def plot_psf_results(sci_data, resid, xcenter, ycenter, cutout_size):

    """
    A function that creates a figure showing the
    provided data, PSF model, and model residuals.

    Parameters
    ----------
    sci_data : np.ndarray
        The np.ndarray containing the array of science data.
    resid : np.ndarray
        A residual image created by psfphot.make_residual_image().
    xcenter : int
        The desired x-centroid location in pixels for the figure.
    ycenter : int
        The desired y-centroid location in pixels for the figure.
    cutout_size : int
        The desired width and height of the display region in pixels.

    Returns
    -------
    figure : matplotlib.figure.Figure
        A figure showing the data, PSF model, and residuals.
    """

    # Make a figure showing the data, model, and residuals.
    my_figure_size, my_fontsize = setup_matplotlib('notebook', 1.2)
    figure, axes = plt.subplots(1, 3, figsize=(11.0, 11.0/3))

    norm = simple_norm(sci_data, 'sqrt', percent=99.8)
    axes[0].imshow(sci_data, origin='lower', norm=norm, aspect='equal', interpolation='nearest')
    axes[1].imshow(sci_data - resid, origin='lower', norm=norm, aspect='equal', interpolation='nearest')
    axes[2].imshow(resid, origin='lower', norm=norm, aspect='equal', interpolation='nearest')
    axes[0].set_title('Data')
    axes[1].set_title('Model')
    axes[2].set_title('Residuals')
    axes[0].set_ylabel('Y (pixels)')
    axes[1].set_xlabel('X (pixels)')    
    for ax in axes: 
        ax.set_xlim([xcenter-cutout_size/2, xcenter+cutout_size/2])
        ax.set_ylim([ycenter-cutout_size/2, ycenter+cutout_size/2])

    return figure


def download_psf_model(file_path, detector, filter):

    """
    Download a PSF model from the WFC3 website and validate the file.

    Parameters
    ----------
    file_path : str
        The desired filepath where the PSF model will be saved.
    detector : str
        The HST instrument name with options of 'WFC3UV', 'WFC3IR', 'ACSWFC'.
    filter : str
        The HST photometric filter, valid for all filters with empirical 
        models as listed on the WFC3 PSF webpage. Models are generally 
        available for all wide and most medium band filters, but are not 
        available for the specialized narrow or quadrant filters.

    Returns
    -------
    psf_name : str
        The filename of the PSF model that was downloaded.
    """

    if (detector not in ['WFC3UV', 'WFC3IR', 'ACSWFC']):
        print('The valid detector options are: WFC3UV, WFC3IR, or ACSWFC')

    psf_name = f'PSFSTD_{detector}_{filter}.fits'
    psf_path = f'{file_path}/{psf_name}'
    psf_url = 'https://www.stsci.edu/files/live/sites/www/files/home/hst/instrumentation/wfc3/data-analysis/psf/_documents/'

    # Download the PSF file if it doesn't exist.
    if not os.path.exists(psf_path):
        print('Downloading:', psf_url+psf_name)
        urllib.request.urlretrieve(psf_url+psf_name, psf_path)

    # Copy the PSF file to the working directory.
    if not os.path.exists(psf_name):
        print('Copying', psf_name, 'to the current directory.')
        shutil.copy(psf_path, '.')

    # Confirm that the file can be opened successfully.
    try:
        hdul = fits.open(psf_name, ignore_missing_end=True)
        hdul.close()
        print('Validation complete, the PSF file is readable.')
    except IOError:
        raise IOError('ERROR: Unable to open', psf_name)
    except Exception as e:
        raise Exception(e)

    return psf_name


def make_cutouts(image, star_ids, xis, yis, rpix, scale_stars=True, sub_pixel=True, show_figs=True, verbose=True):

    """
    A function that extracts postage stamps or cutouts of
    sources from a science image provided an image, list of
    source IDs, x and y detector coordinates, and several 
    optional parameters. The scale_stars parameter normalizes 
    the peak flux of each source to unity, which is required 
    when taking the mean or median in subsequent steps. The 
    subpixel option aligns the cutouts at the subpixel level, 
    rather than using integer array values, utilizing user 
    provided x and y coordinates. The show_figs and verbose 
    options allow users to toggle diagnostic figures and 
    messages on or off depending on the number of sources.

    Parameters
    ----------
    image : np.ndarray
        The np.ndarray containing the array of science data.
    star_ids : list
        A list of the integer stellar IDs from a catalog or arange.
    xis : list
        A list of the x-centroids of each star, assumed to be exact.
    yis : list
        A list of the y-centroids of each star, assumed to be exact.
    rpix : int
        An integer number of pixels for the cutout length and width.
    scale_stars : bool
        If True then the value of each pixel is divided by the maximum. 
        This should generally be set to True to avoid improper weighting.
    sub_pixel : bool
        If True then a sub-pixel recentering is completed, using the
        values provided by the user in the xis and yis lists, so that 
        the stars centroid is located at exactly (rpix, rpix). This 
        should generally be set to True.
    show_figs : bool
        If True then each cutout will be shown in the notebook.
    verbose : bool
        If True then additional diagnostic information is printed.

    Returns
    -------
    image_array : np.ndarray
        The np.ndarray containing a subimage centered on the star.
    """

    image_array = []

    # Create a loop over all stars.
    for i in range(len(xis)):
        
        # Convert to integer and round to nearest value.
        xi = int(np.rint(xis[i]))
        yi = int(np.rint(yis[i]))
        star_id = star_ids[i]
        
        # Print the (x, y) coordinates and extract each star image.
        print(f'Star ID {star_id}: (x,y) = ({xi}, {yi})')
        if (verbose is True):
            print('The read in x, y are:', xis[i], yis[i])

        # Python switches the "slow" axis so reverse x and y.
        subimage = image[yi-rpix-1:yi+rpix, xi-rpix-1:xi+rpix]        

        # Calculate sub-pixel shift based on catalog coordinates and integer array values.
        if (sub_pixel is True):
            x_shift = round(xi - xis[i], 5)
            y_shift = round(yi - yis[i], 5)        
            if (verbose is True):
                print('x_shift, y_shift =', x_shift, y_shift)

            """
            Calculate the center of mass of the inner 5 pixels similar to hst1pass.
            This provides a centroid for comparison with the user provided values.
            In general, the values should be very close to rpix but not equal exactly.
            Shift the image by the sub-pixel offset for sub-pixel alignment accuracy.
            """
            
            mask = np.array([[True, False, True], [False, False, False], [True, False, True]])
            xcom, ycom = centroid_com(subimage[rpix-1:rpix+2, rpix-1:rpix+2], mask=mask)

            if (verbose is True):
                print('Before shift centroid =', round(xcom+rpix-1, 4), round(ycom+rpix-1, 4))
            my_shift = [y_shift, x_shift]
            subimage = shift(subimage, my_shift, mode='mirror')
            xcom, ycom = centroid_com(subimage[rpix-1:rpix+2, rpix-1:rpix+2], mask=mask)

            if (verbose is True):
                print('After shift centroid = ', round(xcom+rpix-1, 4), round(ycom+rpix-1, 4))
        else:
            if (verbose is True):
                print('Warning: The function is not aligning at the sub-pixel level. Is this intended?')

        # # If desired we can recentroid. This would be false using hst1pass and true for approximate centroids.
        # if (recentroid is True):
        #     print('Recalculating centroid based on 5-pixel center of mass.')
        #     print('Using:', subimage[rpix-1:rpix+2, rpix-1:rpix+2])
        #     mask=np.array([[True, False, True], [False, False, False], [True, False, True]]) # true = masked.
        #     print('Before shift centroid =', centroid_com(subimage[rpix-1:rpix+2, rpix-1:rpix+2], mask=mask))
        #     #my_shift = [y_shift, x_shift] # ensure correct positive and negative.
        #     #subimage = scipy.ndimage.shift(subimage, my_shift, mode='mirror')
        #     print('After shift centroid = ', centroid_com(subimage[rpix-1:rpix+2, rpix-1:rpix+2], mask=mask)) # Should be very very close to rpix but not equal exactly.
        
        # Determine the location of the maximum flux.
        peak_location = np.unravel_index(np.argmax(subimage, axis=None), subimage.shape)
        if (verbose is True):
            print(f'The subimage peak flux (x,y) = ({peak_location[1]}), {peak_location[0]})')
        
        # Scale to maximum flux so all stars peak at unity.
        if (scale_stars is True):
            print('Scaling the stars peak flux to unity...')
            subimage = (subimage/np.amax(subimage))
            
        # Protect against peak_finder results that do not contain a star.
        if (peak_location[1] == 0 and peak_location[0] == 0):
            print('This object is outside the data region and will be excluded.\n')
            
        if (peak_location[1] != 0 and peak_location[0] != 0):
            image_array.append(subimage)

            if (show_figs is True):
                plot_cutouts(data=subimage, rpix=rpix)
        else:
            print('The peak flux is too close to the edge of the subimage.')

    return image_array


def plot_cutouts(data, rpix):

    """
    Given a 2D array of values such as the image of a star, create a 
    figure with four different scalings. The size of the resulting cutout 
    is set by 'rpix' and the red markers show the center value of 'rpix'.

    Parameters
    ----------
    data : np.ndarray
        The np.ndarray containing the array of science data, generally 
        after being cropped to a subarray using the make_cutouts() function.
    rpix : int
        An integer number of pixels for the cutout length and width.

    Returns
    -------
    figure : matplotlib.figure.Figure
        A figure showing each star on linear, lognorm, and log10 scales.
    """
    
    figure, mysubplot = plt.subplots(1, 4, figsize=(11, 11), sharex=True, sharey=True)
    mysubplot[0].imshow(data, vmin=0.0, vmax=np.amax(data), origin='lower', aspect='equal')
    mysubplot[1].imshow(data, vmin=0.0, vmax=np.amax(data)/100.0, origin='lower', aspect='equal')
    mysubplot[2].imshow(data, norm=LogNorm(vmin=np.percentile(data, 0.0), vmax=np.percentile(data, 98.5)), origin='lower', aspect='equal')
    mysubplot[3].imshow(np.log10(data), origin='lower', aspect='equal')
    mysubplot[0].set_title(r'100% Max')
    mysubplot[1].set_title(r'1% Max')
    mysubplot[2].set_title('LogNorm')
    mysubplot[3].set_title('Log10')
    for idx in range(4):
        mysubplot[idx].scatter(rpix, rpix, c='red', marker='+')
    plt.tight_layout()
    plt.show()

    return figure


def stack_cutouts(input_array, rpix, stack_type='median', scale_flux=True, export_file=''):

    """
    Given an array containing 2D arrays with centered images of stars, 
    create and mean or median stack. The 'rpix' parameter sets the size 
    of the resulting array, and a 'median' stack_type is generally recommended 
    for stars so that outliers and contaminants are rejected. The scale_flux 
    option allows users to normalize the total integrated flux (area under the 
    2D curve) to unity, which is typically required for PSF models that will 
    be used for PSF fitting or PSF matching with convolution kernels.

    Parameters
    ----------
    input_array : np.ndarray
        The np.ndarray containing the array of science data, generally 
        after being cropped to a subarray using the make_cutouts() function.
    rpix : int
        An integer number of pixels for the cutout length and width.
    stack_type : str
        The mathematical averaging function, either median or mean. 
        In general, median is recommended for rejecting contaminants.
    scale_flux : bool
        If True then the value of each pixel is divided by the maximum. 
        This should generally be set to True to avoid improper weighting.
    export_file : str
        The desired filename for saving the stacked PSF model. If an 
        empty string then no file will be saved to the directory.

    Returns
    -------
    stacked_image : np.ndarray
        The np.ndarray containing the array of stacked data, generally 
        stars extracted from science images or downloaded from MAST.
    figure : matplotlib.figure.Figure
        The matplotlib image showing the stacked PSF model.
    """

    print('Calling stack_cutouts with', len(input_array), 'sources.')

    if (stack_type == 'mean'):
        stacked_image = np.mean(input_array, axis=0)
    elif (stack_type == 'median'):
        stacked_image = np.median(input_array, axis=0)
    else:
        raise ValueError('stack_type must be mean or median.')

    print(f'Creating a {stack_type} image stack.')

    # Scale the stack to have a total flux of unity.
    if (scale_flux is True):
        print('Scaling the total flux to one.')
        stacked_image = (stacked_image/np.sum(stacked_image))
    
    print('The total image flux is =', np.around(np.sum(stacked_image), decimals=2))
    
    figure = plot_cutouts(data=stacked_image, rpix=rpix)
    
    if (export_file != ''):
        my_psf = fits.PrimaryHDU(stacked_image)
        my_psf.writeto(export_file, overwrite=True)
    
    return stacked_image, figure


def plot_cutout_grid(cutouts, path_data, max_cutouts, verbose=False):

    """
    A function that displays a grid of MAST PSF cutouts that have 
    been retrieved using the functions from mast_api_psf.py written 
    by Fred Dauphin. The function accepts a list of 2D arrays 
    corresponding to cutouts and generates a gris plot with a 
    maximum of max_cutouts displayed in the figure.

    Parameters
    ----------
    cutouts : np.ndarray
        An np.ndarray containing the cutouts downloaded from MAST.
    path_data : list
        A list of the filepaths to the cutouts downloaded from MAST.
    max_cutouts : int
        The maximum number of cutouts to display on screen. The code 
        will adapt, but intervals of five make for easier displaying.
    verbose : bool
        If True then the code will print additional diagnostics.

    Returns
    -------
    figure : matplotlib.figure.Figure
        The matplotlib image showing the grid of stars from MAST.
    """
    
    ncol = 5
    num_cutouts = ncol*int(len(cutouts) / ncol)

    if (max_cutouts % 5 != 0):
        max_cutouts = max_cutouts + (5 - max_cutouts % 5)
        print('Setting max_cutouts to a multiple of five:', max_cutouts)

    if (max_cutouts > len(cutouts)):
        max_cutouts = ((len(cutouts) % 5 + 5)*5)
        print('Setting max_cutouts to', max_cutouts, 'so it is less than the number of', len(cutouts), 'cutouts.')
    
    if (num_cutouts < ncol):
        nrow = 1
    elif (num_cutouts > max_cutouts):
        nrow = int(max_cutouts / ncol)
        print(f'Displaying a maximum of {max_cutouts} cutouts.')
    else:
        nrow = int(len(cutouts) / ncol)

    # Create the figure with cutouts.
    my_figure_size, my_fontsize = setup_matplotlib('notebook', 1.2)
    figure, axes = plt.subplots(nrow, ncol, figsize=(2.75*ncol, 2.75*nrow))
    current_width = 1.2 * plt.rcParams["lines.linewidth"]
    axes = axes.flatten()

    for ax, cutout in enumerate(cutouts):
        if (ax < max_cutouts):
            file = os.path.basename(path_data[ax])
            if (verbose is True):
                print('Plotting', file)
            # Create a figure for the cutout.
            axes[ax].set_title(file.split('_flc_cutout.fits')[0], fontsize=my_fontsize)
            axes[ax].imshow(np.log10(cutout), origin='lower', aspect='equal', interpolation='nearest', norm=None)                
            # Find peaks in image.
            mean, median, std = sigma_clipped_stats(cutout, sigma=3.0)
            threshold = median + (10.0 * std)
            tbl = find_peaks(cutout, threshold, box_size=5)
            # Overplot sources.            
            positions_cutout = np.transpose((tbl['x_peak'], tbl['y_peak']))
            apertures_cutout = CircularAperture(positions_cutout, r=4.0)
            apertures_cutout.plot(ax=axes[ax], color='lime', lw=current_width, alpha=1.0)
        else:
            if (verbose is True):
                print('Only showing the first', max_cutouts, 'cutouts.')
            break
        
    plt.tight_layout()

    return figure
