import os
import numpy as np
from astropy.io import fits
import matplotlib.pyplot as plt
from ginga.util.zscale import zscale
import matplotlib.patheffects as path_effects

def read_wfc3(filename):
    '''
    Read a full-frame IR image and return the datacube plus integration times for each read.
    Requires the path to a RAW full-frame IR image fits file (filename).

    Parameters
    ----------
    filename : str
        Path to a RAW full-frame IR image fits file.

    Returns
    -------
    cube : array-like
        1024x1024xNSAMP datacube of the IR image in ascending time order, 
        where NSAMP is the number of samples taken.
  
    integ_time : array-like
        Integration times associated with the datacube in ascending order.    
    '''
    
    with fits.open(filename) as f:
        hdr = f[0].header
        NSAMP = hdr['NSAMP']
        hdr1 = f[1].header
        cube = np.zeros((hdr1['NAXIS1'],hdr1['NAXIS2'],NSAMP), dtype = float)
        integ_time = np.zeros(shape = (NSAMP))

        for i in range(1, NSAMP+1):
            cube[:,:,i-1] = f[('SCI', i)].data
            integ_time[i-1] = f[('TIME', i)].header['PIXVALUE']

        cube = cube[:,:,::-1]
        integ_time = integ_time[::-1]
    return cube, integ_time



def compute_diff_imas(cube, integ_time, diff_method):
    
    '''
    Compute the difference in signal between reads of a WFC3 IR IMA file.
    
    Parameters
    ----------
    cube : array-like
       1024x1024xNSAMP datacube of the IR image in ascending time order, 
       where NSAMP is the number of samples taken.

    integ_time : array-like
       Integration times associated with the datacube in ascending order.

    diff_method: str
       The method of finding the difference between reads. 
       Either "instantaneous" or "cumulative".
           
    Returns
    --------
    diff : array-like
        1024x1024x(NSAMP-1) datacube of the differebce between IR IMA reads in ascending time order, 
        where NSAMP is the number of samples taken.
    '''
    
    if diff_method == 'instantaneous':
        ima_j = cube[:, :, 1:]
        ima_j_1 = cube[:,:,0:-1]
        t_0 = integ_time[0]
        t_j = integ_time[1:]
        t_j_1 = integ_time[0:-1]
        
        diff = ((ima_j*(t_j-t_0))-(ima_j_1*(t_j_1-t_0)))/(t_j-t_j_1)
        
    elif diff_method == 'cumulative':
        diff = cube[:,:,0:-1] - cube[:,:,1:]
        
    else: # if an incorrect method is chosen raise an error
        raise ValueError(f"{diff_method} is an invalid method. The allowed methods are 'instantaneous' and 'cumulative'.")

    return diff


def get_median_fullframe_lhs_rhs(cube, lhs_region, rhs_region):
    
    '''
    Compute the median in the full-frame image, the user-defined left side region, and the user-defined right side region. 

    Parameters
    ----------
    cube : array-like
       1024x1024xNSAMP datacube of the IR image in ascending time order, 
       where NSAMP is the number of samples taken.

    lhs_region:  dict
       The four corners (x0, x1, y0, y1) of the left hand region.

    rhs_region : dict
       The four corners (x0, x1, y0, y1) of the right hand region.
           
    Returns
    -------
    median_full_frame : array of floats
        The median signal of the full frame of each read, clipped by 5 pixels around the border to exclude any bad pixel regions.
        
    median_lhs : array of floats
        The median signal of the left side of each read.
        
    median_rhs : array of floats
        The median signal of the right side of each read. 
    '''
    
    
    median_full_frame = np.nanmedian(cube[5:-5,5:-5,:], axis = (0,1))
    median_lhs = np.nanmedian(cube[lhs_region['y0']:lhs_region['y1'],
                                      lhs_region['x0']:lhs_region['x1'],:], axis = (0,1))
    median_rhs = np.nanmedian(cube[rhs_region['y0']:rhs_region['y1'],
                                      rhs_region['x0']:rhs_region['x1'],:], axis = (0,1))
    
    
    return median_full_frame, median_lhs, median_rhs

def get_std_fullframe_lhs_rhs(cube, lhs_region, rhs_region):
     
    '''
    Compute the standard deviation of the signal in the full-frame image, the user-defined left side region, 
    and the user-defined right side region. 

    Parameters
    ----------
    cube : array-like
       1024x1024xNSAMP datacube of the IR image in ascending time order, 
       where NSAMP is the number of samples taken.

    lhs_region:  dict
       The four corners (x0, x1, y0, y1) of the left hand region.

    rhs_region : dict
       The four corners (x0, x1, y0, y1) of the right hand region.


    Returns
    -------
    standard_dev_fullframe : array of floats
        The standard deviation of the signal of the full frame of each read, clipped by 5 pixels around the border to exclude any bad pixel regions.
        
    standard_dev_lhs : array of floats
        The standard deviation of the signal of the left side of each read.
        
    standard_dev_rhs : array of floats
        The standard deviation of the signal of the right side of each read. 
    '''
    
    
    standard_dev_fullframe = np.nanstd(cube[5:-5,5:-5,:], axis = (0,1))
    standard_dev_lhs = np.nanstd(cube[lhs_region['y0']:lhs_region['y1'],
                                      lhs_region['x0']:lhs_region['x1'],:], axis = (0,1))
    standard_dev_rhs = np.nanstd(cube[rhs_region['y0']:rhs_region['y1'],
                                      rhs_region['x0']:rhs_region['x1'],:], axis = (0,1))
    
    
    return standard_dev_fullframe, standard_dev_lhs, standard_dev_rhs
        

def plot_ramp(ima, integ_time, median_diff_fullframe, median_diff_lhs, median_diff_rhs):
    
    '''
    Plots the signal accumulation ramp of an IMA image. Each point is the median signal (in e-/s) of 
        the difference between subsequent reads. The median signal difference is plotted for the full 
        frame image, and the left and right sides. 
    
    Parameters
    -----------
    ima: str
        Name of the IMA file.

    integ_time : array-like
        Integration times associated with the datacube in ascending order.

    median_diff_full_frame: array-like
        The median difference in signal between each full-frame read.

    median_diff_lhs: array-like
        The median difference in signal between the left side of each read.

    median_diff_rhs: array-like
        The median difference in signal between the right side of each read.
    '''
    
    plt.plot(integ_time[2:], median_diff_fullframe[1:], 's', markersize = 25, label = 'Full Frame',  color = 'black')
    plt.plot(integ_time[2:], median_diff_lhs[1:], '<', markersize = 20, label = 'LHS', color = 'orange')
    plt.plot(integ_time[2:], median_diff_rhs[1:], '>', markersize = 20, label = 'RHS', color = 'green')
    ax = plt.gca()
    for spine in ['top', 'bottom', 'left', 'right']: ax.spines[spine].set_visible(False)
    plt.grid()
    plt.xlabel('SAMPTIME [s]')
    plt.ylabel('$\mu$ [e-/s]')
    plt.legend(loc = 0)
    plt.title(ima)
        
        
def panel_plot(cube, integ_time, median_diff_full_frame, median_diff_lhs, median_diff_rhs,
               standard_dev_fullframe, standard_dev_lhs, standard_dev_rhs, diff_method):
    '''
    Plot the difference between individual reads of an IMA image file in a
    panel plot up to 4x4 in size (i.e. SCI[16]-SCI[15], SCI[15]-SCI[14], SCI[14]-SCI[15], etc.).
    
    Parameters
    ----------
    cube : array-like
       1024x1024xNSAMP datacube of the IR image in ascending time order, 
       where NSAMP is the number of samples taken.
       
    integ_time : array-like
        Integration times associated with the datacube in ascending order.

    median_diff_full_frame: array-like
        The median difference in signal between each full-frame read.

    median_diff_lhs: array-like
        The median difference in signal between the left side of each read.

    median_diff_rhs: array-like
        The median difference in signal between the right side of each read.
     
    standard_dev_fullframe : array of floats
        The standard deviation of the signal of the full frame of each read.
        
    standard_dev_lhs : array of floats
        The standard deviation of the signal of the left side of each read.
        
    standard_dev_rhs : array of floats
        The standard deviation of the signal of the right side of each read. 
        
    diff_method: str
        The method of finding the difference between reads. 
        Either "instantaneous" or "cumulative".
    
    Returns:
    --------
    
    fig: figure object
        Panel plot with subplots showing the difference between subsequent IMA reads. 
        Above each panel, we print the median difference $\mu$ in the count rate over the entire image. 
        Below each panel, we list the IMSET difference, along with the time interval between the two IMSETs.
        The statistics in orange (on the left and right side of each panel) give the median rate and 
        standard deviation of each side of the image, respectively. The value in green 'delta' is the 
        difference between the left and right side of the image. 
        The value in white "Ratio" gives the ratio of the median difference in orange 
        for the left versus the right side. 
    '''
    
    
    xlabel_list = ["SCI[16-15]","SCI[15-14]","SCI[14-13]","SCI[13-12]","SCI[12-11]",
                 "SCI[11-10]","SCI[10-9]","SCI[9-8]","SCI[8-7]","SCI[[7-6]]","SCI[6-5]",
                "SCI[5-4]","SCI[4-3]","SCI[3-2]","SCI[2-1]"]
    
    fig, axarr = plt.subplots(4, 4)
    fig.set_size_inches(40, 40)
    fig.set_dpi(40)
    itime = integ_time[0:-1] - integ_time[1:]
    
    diff = compute_diff_imas(cube, integ_time, diff_method = diff_method)
 
    
    for i, ax in enumerate(axarr.reshape(-1)):
        if (i < cube.shape[-1]-2):
            i=i+1
            
            diff_i = diff[:,:,i]
            vmin = 0
            vmax = 2
            im = ax.imshow(np.abs(diff_i), cmap='Greys_r', origin='lower',
                           vmin = vmin, vmax = vmax)
            ax.set_title(f'$\mu = ${median_diff_full_frame[i]:.2f}±{standard_dev_fullframe[i]:.2f} e-/s', fontsize = 30)
            
            text = ax.text(50, 500, f'{median_diff_lhs[i]:.3f}\n±\n{standard_dev_lhs[i]:.3f}', color='Orange', fontsize=30)
            text.set_path_effects([path_effects.Stroke(linewidth=15, foreground='black'),
                   path_effects.Normal()])
            text = ax.text(700, 500, f'{median_diff_rhs[i]:.3f}\n±\n{standard_dev_rhs[i]:.3f}', color='Orange', fontsize=30)
            text.set_path_effects([path_effects.Stroke(linewidth=15, foreground='black'),
                   path_effects.Normal()])
            text = ax.text(200, 900, f'Ratio = {median_diff_lhs[i]/median_diff_rhs[i]:.2f}', color='White', fontsize=30)
            text.set_path_effects([path_effects.Stroke(linewidth=15, foreground='black'),
                   path_effects.Normal()])
            text = ax.text(300, 300, f'$\Delta = ${median_diff_lhs[i]-median_diff_rhs[i]:.2f}', color='#32CD32', fontsize=30)
            text.set_path_effects([path_effects.Stroke(linewidth=15, foreground='black'),
                   path_effects.Normal()])
          
            cbar = plt.colorbar(im, ax = ax)
            cbar.ax.tick_params(labelsize = 20)
            
            
            ax.set_yticklabels([])
            ax.set_xticklabels([])
            ax.set_xlabel(f'{xlabel_list[i]}, $\Delta t = ${np.abs(itime[i]):.2f} sec', fontsize = 30)
            

        else:

            ax.set_axis_off()
    
    return fig
    
    
def plot_ima_subplots(ima_filename, vmin, vmax):
    '''
    Build a simple panel plot of individual IMA reads.
    
    Parameters
    ----------
    ima_filename : str
        Path to a RAW full-frame IR image fits file.
        
    vmin: float
        Minimum magnitude for scaling the data range that the colormap covers.
    
    vmax: float
        Maximum magnitude for scaling the data range that the colormap covers.      
    '''
    
    path, filename = os.path.split(ima_filename)

    cube, integ_time = read_wfc3(ima_filename)

    fig_panel1, axarr = plt.subplots(4, 4)
    fig_panel1.set_size_inches(40, 40)
    fig_panel1.set_dpi(40)
    plt.rcParams.update({'font.size':40})
    itime = integ_time[0:-1] - integ_time[1:]
    read_title=np.arange(16,0,-1)
    for i, ax in enumerate(axarr.reshape(-1)):

        im = ax.imshow(cube[:,:,i], cmap = 'Greys_r', origin = 'lower', vmin = vmin , vmax = vmax) 

        cbar=plt.colorbar(im, ax = ax)
        cbar.ax.tick_params(labelsize = 20)
        ax.set_title(f'SCI, {read_title[i]}', fontsize = 40)
        ax.set_yticklabels([])
        ax.set_xticklabels([])

    _=fig_panel1.suptitle(filename, fontsize = 40)
    plt.subplots_adjust(bottom = 0.3, right = 0.9, top = 0.95)
    
    
def plot_ramp_subplots(ima_files, difference_method, ylims, exclude_sources, lhs_region, rhs_region):
    '''
    Build a simple figure with subplots of IMA accumulation ramps. 
    
    Parameters
    ----------
    ima_files : list of str
        Paths to RAW full-frame IR image fits files.
        
    difference_method: str
       The method of finding the difference between reads. 
       Either "instantaneous" or "cumulative".
       
    ylims: list of floats
        Two floats, the first detailing the lower y-axis limit, and the second giving the 
        upper y-axis limit.
        
    exclude_sources: bool
        Set to True to exclude any sources (such as stars) and isolate the background counts. 
        
    lhs_region:  dict
       The four corners (x0, x1, y0, y1) of the left hand region.

    rhs_region : dict
       The four corners (x0, x1, y0, y1) of the right hand region.
    '''
    
    fig = plt.figure(figsize = (50, 20))
    fig
    rows = 1
    columns = 2

    subplot_titles = ['scattered', 'nominal']

    for i,ima in enumerate(ima_files):
        

        path, filename = os.path.split(ima)
        cube, integ_time = read_wfc3(ima)
        
        if exclude_sources == True:
            cube[np.abs(cube) > 3] = np.nan

        diff_cube = compute_diff_imas(cube, integ_time, diff_method = difference_method)
        median_diff_fullframe, median_diff_lhs, median_diff_rhs = get_median_fullframe_lhs_rhs(diff_cube, lhs_region = lhs_region, rhs_region = rhs_region)

        ax = fig.add_subplot(rows, columns, i+1)
        plot_ramp(ima, integ_time, median_diff_fullframe, median_diff_lhs, median_diff_rhs)
        ax.set_ylim(ylims[0],ylims[1])

        ax.tick_params(axis = "x", labelsize = 30) 
        ax.tick_params(axis = "y", labelsize = 30) 

        _=ax.set_title(f'{filename}, {subplot_titles[i]}', fontsize=50)
        
        
def plot_ima_difference_subplots(ima_filename, difference_method, lhs_region, rhs_region):
    '''
    Build a complex panel plot of the difference between individual IMA reads.
    The median difference $\mu$ in the count rate over the entire image is printed above each panel. Below each panel, 
    The IMSET difference, along with the time interval between the two IMSETs, is printed below.
    The statistics in orange (on the left and right side of each panel) give the median rate and 
    standard deviation of each side of the image, respectively. The value in green 'delta' is the 
    difference between the left and right side of the image. The value in white "Ratio" gives the 
    ratio of the median difference in orange for the left versus the right side. 
    
    Parameters
    ----------
    ima_filename : str
        Path to a RAW full-frame IR image fits file.
        
    difference_method: str
       The method of finding the difference between reads. 
       Either "instantaneous" or "cumulative".    
       
    lhs_region:  dict
       The four corners (x0, x1, y0, y1) of the left hand region.

    rhs_region : dict
       The four corners (x0, x1, y0, y1) of the right hand region.
       
    '''

    path,filename = os.path.split(ima_filename)

    cube, integ_time = read_wfc3(ima_filename)

    median_fullframe, median_lhs, median_rhs = get_median_fullframe_lhs_rhs(cube, lhs_region = lhs_region, rhs_region = rhs_region)

    diff_cube = compute_diff_imas(cube, integ_time, diff_method = difference_method)

    median_diff_fullframe, median_diff_lhs, median_diff_rhs = get_median_fullframe_lhs_rhs(diff_cube, lhs_region = lhs_region, rhs_region = rhs_region)
    standard_dev_fullframe, standard_dev_lhs, standard_dev_rhs = get_std_fullframe_lhs_rhs(diff_cube, lhs_region = lhs_region, rhs_region = rhs_region)

    fig_0 = panel_plot(cube, integ_time, median_diff_fullframe, median_diff_lhs, median_diff_rhs, standard_dev_fullframe, standard_dev_lhs, standard_dev_rhs, diff_method = difference_method)
    _=fig_0.suptitle(filename, fontsize = 40)
    plt.subplots_adjust(bottom = 0.25, right = 0.9, top = 0.95)
