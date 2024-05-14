import os
import glob
import shutil
import tarfile
import urllib
from IPython.display import clear_output
import numpy
from numpy import percentile
import matplotlib
import matplotlib.pyplot
from matplotlib.colors import LogNorm
from matplotlib.patches import Rectangle
from astroquery.mast import Observations
import astropy
from astropy.io import fits
from astropy.table import Table, QTable
from astropy.modeling import models
from astropy.modeling import fitting
from astropy.visualization import simple_norm
from astropy.stats import sigma_clipped_stats
from astropy.stats import SigmaClip
import photutils
from photutils.detection import find_peaks
from photutils.detection import DAOStarFinder
from photutils.centroids import centroid_com
from photutils.aperture import aperture_photometry
from photutils.aperture import CircularAperture
from photutils.aperture import CircularAnnulus
from photutils.aperture import ApertureStats
from photutils.psf import PSFPhotometry
from photutils.psf import SourceGrouper
from photutils.psf import IntegratedGaussianPRF
from photutils.psf import GriddedPSFModel
from photutils.psf import STDPSFGrid
from photutils.psf import stdpsf_reader
from photutils.psf import FittableImageModel
from scipy.ndimage import shift
import drizzlepac
from drizzlepac import tweakreg
from drizzlepac import astrodrizzle


def save_figure(figure, filename, show_figure):

    '''
    Save the current figure and display or close the file.
    '''

    figure.tight_layout()
    matplotlib.pyplot.savefig(filename)
    if (show_figure == True):
        matplotlib.pyplot.show()
    if (show_figure == False):
        matplotlib.pyplot.close()

    return print('\nFigure saved as: '+filename)


def setup_matplotlib(size, multiplier):

    '''
    Change the default matplotlib parameters to improve figures.
    The size parameter sets the overall image size, while the
    multiplier parameter increases the fontsize and line widths.
    '''

    #import matplotlib
    matplotlib.pyplot.rcdefaults() # restore default values
    matplotlib.pyplot.rcParams["font.family"] = "STIXGeneral"
    matplotlib.pyplot.rcParams["mathtext.fontset"] = "stix"
    matplotlib.pyplot.rcParams['text.usetex'] = True
    default_thickness_frame = 0.66
    default_thickness_lines = 1.00
    default_fontsize = 10
    
    if (size == 'notebook'):
        my_scale       = 1.0
        my_figure_size = (11.0, 11.0)
    else:
        my_scale       = multiplier
        my_figure_size = (size, size)
        
    my_scale = (my_scale * multiplier)
    matplotlib.pyplot.rcParams["figure.figsize"]  = my_figure_size
    matplotlib.pyplot.rcParams["font.size"]       = default_fontsize * my_scale
    matplotlib.pyplot.rcParams["axes.linewidth"]  = default_thickness_frame * my_scale
    matplotlib.pyplot.rcParams["lines.linewidth"] = default_thickness_lines * my_scale
    matplotlib.pyplot.rcParams['xtick.major.width'] = default_thickness_frame * my_scale
    matplotlib.pyplot.rcParams['xtick.minor.width'] = default_thickness_frame * my_scale
    matplotlib.pyplot.rcParams['ytick.major.width'] = default_thickness_frame * my_scale
    matplotlib.pyplot.rcParams['ytick.minor.width'] = default_thickness_frame * my_scale
    matplotlib.pyplot.rcParams['xtick.major.size'] = 3.0 * my_scale
    matplotlib.pyplot.rcParams['ytick.major.size'] = 3.0 * my_scale
    matplotlib.pyplot.rcParams['xtick.minor.size'] = 1.5 * my_scale
    matplotlib.pyplot.rcParams['ytick.minor.size'] = 1.5 * my_scale
    my_fontsize = matplotlib.pyplot.rcParams["font.size"]
        
    return my_figure_size, my_fontsize


def create_mask(data, cutout_size, xcenter, ycenter):

    '''
    A function that accepts an array of image data, a cutout size 
    in pixels, and xcenter and ycenter locations. The function returns 
    a mask that is compatible with the daofind function so that source 
    searches are only conducted on a portion of the overall image.
    '''
    
    # Create a mask array that is the same size as the science image and mask the upper, lower, left, and right regions.
    mask = numpy.zeros(data.shape, dtype=bool)
    mask[ycenter+int(cutout_size/2):numpy.shape(data)[0], 0:numpy.shape(data)[1]] = True
    mask[0:ycenter-int(cutout_size/2), 0:numpy.shape(data)[1]] = True
    mask[0:numpy.shape(data)[0], 0:xcenter-int(cutout_size/2)] = True
    mask[0:numpy.shape(data)[0], xcenter+int(cutout_size/2):numpy.shape(data)[1]] = True

    return mask


def plot_apertures(data, xcenter, ycenter, cutout_size, apertures_stellar, apertures_annulus):

    '''
    A function that takes an image, x and y center locations, image size, and 
    stellar and background photometric apertures that were calculated with 
    the photutils CircularAperture and CircularAnnulus functions, respectively.
    '''
    
    # Create a figure with the data, identified stars, and photometry apertures.
    my_figure_size, my_fontsize = setup_matplotlib('notebook', 1.2)
    figure, axes = matplotlib.pyplot.subplots(1, 3, figsize=(11.0, 11.0/3))
    current_width = 1.2 * matplotlib.pyplot.rcParams["lines.linewidth"]
    for ax in [0, 1, 2]:
        axes[ax].imshow(data, origin='lower', aspect='equal', interpolation='nearest', norm=simple_norm(data, 'sqrt', percent=99.8))
    apertures_stellar.plot(ax=axes[1], color='lime', alpha=1.0)
    apertures_stellar.plot(ax=axes[2], color='lime', alpha=1.0)
    apertures_annulus.plot(color='white')
    axes[0].set_title('Original Data')
    axes[1].set_title('Identified Stars')
    axes[2].set_title('Photometry Apertures')
    axes[0].set_ylabel('Y (pixels)')
    axes[1].set_xlabel('X (pixels)')
    for ax in [0, 1, 2]: 
        axes[ax].set_xlim([xcenter-cutout_size/2, xcenter+cutout_size/2])
        axes[ax].set_ylim([ycenter-cutout_size/2, ycenter+cutout_size/2])
    matplotlib.pyplot.tight_layout()

    return figure


def plot_psf_results(sci_data, resid, xcenter, ycenter, cutout_size):

    '''
    A function that creates a figure showing the
    provided data, PSF model, and model residuals.
    '''    

    # Make a figure showing the data, model, and residuals.
    my_figure_size, my_fontsize = setup_matplotlib('notebook', 1.2)
    figure, axes = matplotlib.pyplot.subplots(1, 3, figsize=(11.0, 11.0/3))
    current_width = 1.2 * matplotlib.pyplot.rcParams["lines.linewidth"]
    norm=simple_norm(sci_data, 'sqrt', percent=99.8)
    axes[0].imshow(sci_data, origin='lower', norm=norm, aspect='equal', interpolation='nearest')
    axes[1].imshow(sci_data - resid, origin='lower', norm=norm, aspect='equal', interpolation='nearest')
    axes[2].imshow(resid, origin='lower', norm=norm, aspect='equal', interpolation='nearest')
    axes[0].set_title('Data')
    axes[1].set_title('Model')
    axes[2].set_title('Residuals')
    for x in [0, 1, 2]: 
        axes[x].set_xlim([xcenter-cutout_size/2, xcenter+cutout_size/2])
        axes[x].set_ylim([ycenter-cutout_size/2, ycenter+cutout_size/2])

    return figure


def download_psf_model(file_path, detector, filter):

    '''
    Download a PSF model from the WFC3 website and validate the file.
    '''

    if (detector not in ['WFC3UV', 'WFC3IR', 'ACSWFC']):
        print('The valid detector options are: WFC3UV, WFC3IR, or ACSWFC')

    psf_name = 'PSFSTD_{}_{}.fits'.format(detector, filter)
    psf_path = '{}/{}'.format(file_path, psf_name)
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

    '''
    A function that extracts postage stamps or cutouts of
    sources from a science image provided an image, list of
    source IDs, x and y detector coordinates, and several 
    optional paramters. The scale_stars parameter noramlizes 
    the peak flux of each source to unity, which is required 
    when taking the mean or median in subsequent steps. The 
    subpixel option aligns the cutouts at the subpixel level, 
    rather than using integer array values, utilizing user 
    provided x and y coordinates. The show_figs and verbose 
    options allow users to toggle diagnostic figures and 
    messages on or off depending on the number of sources.
    '''

    # Extract a subimage centered on the star.
    image_array = []

    # Create a loop over all stars.
    for i in range(len(xis)):
        
        # Convert to integer and round to nearest value.
        xi = int(numpy.rint(xis[i]))
        yi = int(numpy.rint(yis[i]))
        star_id = star_ids[i]
        
        # Print the (x, y) coordinates and extract each star image.
        print('Star ID ' + str(int(star_id)) + ':'  + ' (x,y) = (' + str(xi) + ', ' + str(yi) + ')')
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

            '''
            Calculate the center of mass of the inner 5 pixels similar to hst1pass.
            This provides a centroid for comparison with the user provided values.
            In general, the values should be very close to rpix but not equal exactly.
            Shift the image by the sub-pixel offset for sub-pixel alignment accuracy.
            '''
            
            mask = numpy.array([[True, False, True], [False, False, False], [True, False, True]])
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
        #     mask=numpy.array([[True, False, True], [False, False, False], [True, False, True]]) # true = masked.
        #     print('Before shift centroid =', centroid_com(subimage[rpix-1:rpix+2, rpix-1:rpix+2], mask=mask))
        #     #my_shift = [y_shift, x_shift] # ensure correct positive and negative.
        #     #subimage = scipy.ndimage.shift(subimage, my_shift, mode='mirror')
        #     print('After shift centroid = ', centroid_com(subimage[rpix-1:rpix+2, rpix-1:rpix+2], mask=mask)) # Should be very very close to rpix but not equal exactly.
        
        # Determine the location of the maximum flux.
        peak_location = numpy.unravel_index(numpy.argmax(subimage, axis=None), subimage.shape)
        if (verbose is True): print('The subimage peak flux (x,y) = (' + str(peak_location[1]) + ', ' + str(peak_location[0]) + ')')
        
        # Scale to maximum flux so all stars peak at unity.
        if (scale_stars is True):
            print('Scaling the stars peak flux to unity...')
            subimage = (subimage/numpy.amax(subimage))
            
        # Protect against peak_finder results that do not contain a star.
        if (peak_location[1] == 0 and peak_location[0] == 0):
            print('This object is outside the data region and will be excluded.\n')
            
        if (peak_location[1] != 0 and peak_location[0] != 0):
            image_array.append(subimage)

            if (show_figs is True):
                figure = plot_cutouts(data=subimage, rpix=rpix)
        else:
            print('The peak flux is too close to the edge of the subimage.')

    return image_array


def plot_cutouts(data, rpix):

    '''
    Given a 2D array of values such as the image of a star, create a figure with four different scalings.
    The size of the resulting cutout is set by 'rpix' and the red markers show the center value of 'rpix'.
    '''
    
    figure, mysubplot = matplotlib.pyplot.subplots(1, 4, figsize=(11, 11), sharex=True, sharey=True)
    mysubplot[0].imshow(data, vmin=0.0, vmax=numpy.amax(data), origin='lower')
    mysubplot[1].imshow(data, vmin=0.0, vmax=numpy.amax(data)/100.0, origin='lower')
    mysubplot[2].imshow(data, norm=LogNorm(vmin=percentile(data, 0.0), vmax=percentile(data, 98.5)), origin='lower', aspect='equal')
    mysubplot[3].imshow(numpy.log10(data), origin='lower')
    mysubplot[0].set_title('100\% Max')
    mysubplot[1].set_title('1\% Max')
    mysubplot[2].set_title('LogNorm')
    mysubplot[3].set_title('Log10')
    for idx in [0,1,2,3]:
        mysubplot[idx].scatter(rpix, rpix, c='red', marker='+')
    matplotlib.pyplot.tight_layout()
    matplotlib.pyplot.show()

    return figure


def stack_cutouts(input_array, rpix, stack_type='median', scale_flux=True, export_file='none'):

    '''
    Given an array containing 2D arrays with centered images of stars, create and mean or median stack.
    The 'rpix' parameter sets the size of the resulting array, and a 'median' stack_type is generally 
    recommended for stars so that outliers and contaminants are rejected. The scale_flux option allows 
    users to normalize the total integrated flux (area under the 2D curve) to unity, which is typically 
    required for PSF models that will be used for PSF fitting or PSF matching with convolution kernels.
    '''

    print('Calling stack_cutouts with', len(input_array), 'sources.')

    if (stack_type == 'mean'):
        stacked_image = numpy.mean(input_array, axis=0)
    elif (stack_type == 'median'):
        stacked_image = numpy.median(input_array, axis=0)
    else:
        return print('ERROR: stack_type must be mean or median.')

    print('Creating a '+stack_type+' image stack.')

    # Scale the stack to have a total flux of unity.
    if scale_flux == True:
        print('Scaling the total flux to one.')
        stacked_image = (stacked_image/numpy.sum(stacked_image))
    
    print('The total image flux is =', numpy.around(numpy.sum(stacked_image), decimals=2))
    
    figure = plot_cutouts(data=stacked_image, rpix=rpix)
    
    if (export_file != 'none'):
        my_psf = fits.PrimaryHDU(stacked_image)
        my_psf.writeto(export_file, overwrite=True)
    
    return stacked_image, figure


def plot_cutout_grid(cutouts, path_data, max_cutouts, verbose=False):

    '''
    A function that displays a grid of MAST PSF cutouts
    that have been retrieved using the functions from 
    mast_api_psf.py written by Fred Dauphin. The function 
    accepts a list of 2D arrays corresponding to cutouts 
    and generates a gris plot with a maximum of max_cutouts 
    displayed in the figure.
    '''
    
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
        print('Displaying a maximum of', max_cutouts, 'cutouts.')
    else:
        nrow = int(len(cutouts) / ncol)

    # Create the figure with cutouts.
    my_figure_size, my_fontsize = setup_matplotlib('notebook', 1.2)
    figure, axes = matplotlib.pyplot.subplots(nrow, ncol, figsize=(2.75*ncol, 2.75*nrow))
    current_width = 1.2 * matplotlib.pyplot.rcParams["lines.linewidth"]
    axes = axes.flatten()

    for ax, cutout in enumerate(cutouts):
        if (ax < max_cutouts):
            file = os.path.basename(path_data[ax])
            if (verbose is True):
                print('Plotting', file)
            # Create a figure for the cutout.
            axes[ax].set_title(file.split('_flc_cutout.fits')[0], fontsize=my_fontsize)
            axes[ax].imshow(numpy.log10(cutout), origin='lower', aspect='equal', interpolation='nearest', norm=None)                
            # Find peaks in image.
            mean, median, std = sigma_clipped_stats(cutout, sigma=3.0)
            threshold = median + (10.0 * std)
            tbl = find_peaks(cutout, threshold, box_size=5)
            # Overplot sources.            
            positions_cutout = numpy.transpose((tbl['x_peak'], tbl['y_peak']))
            apertures_cutout = CircularAperture(positions_cutout, r=4.0)
            apertures_cutout.plot(ax=axes[ax], color='lime', lw=current_width, alpha=1.0)
        else:
            if (verbose is True):
                print('Only showing the first', max_cutouts, 'cutouts.')
            break
        
    matplotlib.pyplot.tight_layout()

    return figure