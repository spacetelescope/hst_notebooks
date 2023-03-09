import numpy as np
from astropy.io import fits
import matplotlib.pyplot as plt


def read_wfc3(filename):
    '''
    This function reads in the full-frame IR image and returns the datacube plus the 
    integration time for each read. 
    Requires the path to a RAW full-frame IR image file name (filename)

    Input:
       -  filename : str, path to a RAW full-frame IR image fits files

    Output:
       -   cube : 1024x1024xNSAMP datacube of the IR image in ascending time order
       -  integ_time : NSAMP length array of integration times associated with the 
                datacube in ascending time order
    '''
    with fits.open(filename) as f:
        hdr = f[0].header
        NSAMP = hdr['NSAMP']
        hdr1 = f[1].header
        cube = np.zeros((hdr1['NAXIS1'],hdr1['NAXIS2'],NSAMP), dtype=float)
        integ_time = np.zeros(shape=(NSAMP))

        for i in range(1, NSAMP+1):
            cube[:,:,i-1] = f[('SCI', i)].data
            integ_time[i-1] = f[('TIME', i)].header['PIXVALUE']

        cube = cube[:,:,::-1]
        integ_time = integ_time[::-1]
    return cube, integ_time


def getmedlhsrhs(cube, lhs_region, rhs_region):
    
    '''
    This function computes the median signal in the full frame image, the user-defined left side region,
    and user-defined right side region. 

    Input:
        - cube : 1024x1024xNSAMP datacube of the IR image in ascending time order
                
        - lhs_region, rhs_region :  Each region must be a specified as dictionary including the four 
                "corners" (x0, x1, y0, and y1) of the region you would like to select.
             

    Output:
        - medlvl, lhs, rhs : The median signal of the full frame, left side, 
                 and right side of each read. 
    '''
    
    medlvl = []
    lhs = []
    rhs = [] 
    
    for img in range(cube.shape[2]):
        medlvl.append(np.nanmedian(cube[:,:,img]))
        lhs.append(np.nanmedian(cube[lhs_region['y0']:lhs_region['y1'],lhs_region['x0']:lhs_region['x1'],img]))
        rhs.append(np.nanmedian(cube[rhs_region['y0']:rhs_region['y1'],rhs_region['x0']:rhs_region['x1'],img]))
        
    return np.array(medlvl), np.array(lhs), np.array(rhs)

def instantaneous_diff(cube, integ_time, lhs_region, rhs_region):
    '''
    This function computes the median signal of the difference between reads, in the full frame image, the 
    user-defined left side region, and user-defined right side region, using the "instantaneous"
    difference method to take the difference between reads. 

    Input:
        - cube : 1024x1024xNSAMP datacube of the IR image in ascending time order
                lhs_region, rhs_region -  Each region must be a specified as dictionary including the four 
                "corners" (x0, x1, y0, and y1) of the region you would like to select.
                
        -  integ_time : NSAMP length array of integration times associated with the 
                datacube in ascending time order
                
        - lhs_region, rhs_region :  Each region must be a specified as dictionary including the four 
                "corners" (x0, x1, y0, and y1) of the region you would like to select.

    Output:
        -  md,ld,rd: The median difference in signal between each read, for the full frame, 
                left side, and right side of the image. 
        -  ffstd,lstd,rstd: The standard deviation of the difference in signal between each read, 
                for the full frame, left side, and right side of the image. 
    '''
    md = []
    ld = []
    rd = []
    
    diff=((cube[:,:,1:]*(integ_time[1:]-integ_time[0]))-\
          (cube[:,:,0:-1]*(integ_time[0:-1]-integ_time[0])))/(integ_time[1:]-integ_time[0:-1])

    lstd = []
    ffstd = []
    rstd = []
    
    for img in range(diff.shape[2]):
        md.append(np.nanmedian(diff[:,:,img]))
        ld.append(np.nanmedian(diff[lhs_region['y0']:lhs_region['y1'],
                                                 lhs_region['x0']:lhs_region['x1'],img]))
        rd.append(np.nanmedian(diff[rhs_region['y0']:rhs_region['y1'],
                                                 rhs_region['x0']:rhs_region['x1'],img]))
        ffstd.append(np.nanstd(diff[:,:,img]))
        lstd.append(np.nanstd(diff[lhs_region['y0']:lhs_region['y1'],
                                                 lhs_region['x0']:lhs_region['x1'],img]))
        rstd.append(np.nanstd(diff[rhs_region['y0']:rhs_region['y1'],
                                                 rhs_region['x0']:rhs_region['x1'],img]))
    

    return np.array(md), np.array(ld), np.array(rd), np.array(ffstd), np.array(lstd), np.array(rstd)\

def cumulative_diff(cube, integ_time, lhs_region, rhs_region):
    '''
    This function computes the median signal of the difference between reads, in the full frame image, the 
    user-defined left side region, and user-defined right side region, using the "cumulative"
    difference method to take the difference between reads. 

    Input:
        - cube : 1024x1024xNSAMP datacube of the IR image in ascending time order
                lhs_region, rhs_region -  Each region must be a specified as dictionary including the four 
                "corners" (x0, x1, y0, and y1) of the region you would like to select.
                
        -  integ_time : NSAMP length array of integration times associated with the 
                datacube in ascending time order
                
        - lhs_region, rhs_region :  Each region must be a specified as dictionary including the four 
                "corners" (x0, x1, y0, and y1) of the region you would like to select.

    Output:
        -  md,ld,rd: The median difference in signal between each read, for the full frame, 
                left side, and right side of the image. 
        -  ffstd,lstd,rstd: The standard deviation of the difference in signal between each read, 
                for the full frame, left side, and right side of the image. 
    '''
    
    md = []
    ld = []
    rd = []

    diff = cube[:,:,0:-1] - cube[:,:,1:]
    
    lstd = []
    ffstd = []
    rstd = []
    
    for img in range(diff.shape[2]):
        md.append(np.nanmedian(diff[:,:,img]))
        ld.append(np.nanmedian(diff[lhs_region['y0']:lhs_region['y1'],
                                                 lhs_region['x0']:lhs_region['x1'],img]))
        rd.append(np.nanmedian(diff[rhs_region['y0']:rhs_region['y1'],
                                                 rhs_region['x0']:rhs_region['x1'],img]))
        ffstd.append(np.nanstd(diff[:,:,img]))
        lstd.append(np.nanstd(diff[lhs_region['y0']:lhs_region['y1'],
                                                 lhs_region['x0']:lhs_region['x1'],img]))
        rstd.append(np.nanstd(diff[rhs_region['y0']:rhs_region['y1'],
                                                 rhs_region['x0']:rhs_region['x1'],img]))
    

    return np.array(md), np.array(ld), np.array(rd), np.array(ffstd), np.array(lstd), np.array(rstd)\



def plotramp(ima, integ_time, tup):
    
    '''
    Plots the signal accumulation ramp of an ima image. Each point is the median signal (in e-/s) of 
        the difference between subsequent reads. The median signal difference is plotted for the full 
        frame image, and the left and right sides. 
    
     Input:
        -  ima: str, name of ima file
                
        -  integ_time : NSAMP length array of integration times associated with the 
                datacube in ascending time order
        -  tup: (md, ld, rd) : The median difference in signal between each read, 
                    for the full frame, left side, and right side of the image. 
                    
    '''
    md, ld, rd = tup
    
    plt.plot(integ_time[2:], md[1:], 's', markersize=25, label='Full Frame',  color='black')
    plt.plot(integ_time[2:], ld[1:], '<', markersize=20, label='LHS', color='orange')
    plt.plot(integ_time[2:], rd[1:], '>', markersize=20, label='RHS', color='green')
    ax = plt.gca()
    for spine in ['top', 'bottom', 'left', 'right']: ax.spines[spine].set_visible(False)
    plt.grid()
    plt.xlabel('SAMPTIME [s]')
    plt.ylabel('$\mu$ [e-/s]')
    plt.legend(loc=0)
    plt.title(ima)