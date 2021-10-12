#! /usr/bin/env python

import sys
import numpy as np

from astropy.io import fits
import matplotlib.pyplot as plt
from scipy.stats import mode as mode

def get_bunit(ext1header):
    """ Get the brightness unit for the plot axis label

    Parameters
    ----------
    ext1header: Header
        The extension 1 header of the fits file being displayed. This is the
        extension that contains the brightness unit keyword

    Returns
    -------
    The string of the brightness unit for the axis label
        {'counts', 'counts/s','e$^-$', 'e$^-$/s'}

    """
    units = ext1header['bunit']

    if units == 'COUNTS':
        return 'counts'
    elif units == 'COUNTS/S':
        return 'counts/s'
    elif units == 'ELECTRONS':
        return 'e$^-$'
    elif units == 'ELECTRONS/S':
        return 'e$^-$/s'
    else:
        return units

def get_yaxis_and_label(stat, scidata, axes):
    """ Get the y-axis values and the y axis label for the plot

    Parameters
    ----------
    stat: String {median', 'mean', 'mode', 'stddev'}
        The statistic that is being computed.

    scidata: Array
        The image array which is being measured. If an image section is
        being displayed the array has already been indexed prior to calling this
        function.

    axes: Integer {0, 1}
        The axis over which to compute the statistc. For column stats axes = 0
        for row stats axes = 1

    Returns
    -------
    yaxis: Array
        The array of statistical values requested

    ylabel: String
        The string of the statistic being computed to be used as the axis label

    """
    if stat == 'median':
        yaxis = np.nanmedian(scidata, axis=axes)
        ylabel = 'Median'
    elif stat == 'mean':
        yaxis = np.nanmedian(scidata, axis=axes)
        ylabel = 'Mean'
    elif stat == 'mode':
        yaxis = mode(scidata, axis=axes)[0]
        ylabel = 'Mode'
    elif stat == 'stddev':
        yaxis = np.nanstd(scidata, axis=axes)
        ylabel = "Standard Dev."
    else:
        sys.exit("keyword argument 'stat' must be 'median', 'mean', 'mode', or 'stddev'")

    return yaxis, ylabel

def makeplot(xaxis, yaxis, axlabel, ylabel,
             bunit,detector, fname, h1, ylim,
             figsize, dpi):
    """ Make and display the plot for WFC3 UVIS or IR images

    Parameters
    ----------
    xaxis: Range
        Range from 1 to the total number of rows or columns. If image section
        range will go from x1 to x2

    yaxis: Array
        The statistical values being plotted

    axlabel: String {"Row", "Column"}
        The axis which the statistc was computed over

    bunit: String
        The string of the brightness unit for the axis label

    detector: String {"UVIS", "IR"}
        The detector used for the image

    fname: String
        The name of the file being plotted

    h1: Header
        The extension 1 header of the fits file being displayed.

    ylim: (float,float)
        The minimum and maximum values for y axis scale.

    figsize: (float,float)
        The width, height of the figure. Default is (9,6)

    dpi: float
        The resolution of the figure in dots-per-inch. Default is 120

    Returns
    -------
    N/A

    """
    fig, ax1 = plt.subplots(1, 1, figsize = figsize, dpi=dpi)
        # ax1.scatter(xaxis,yaxis,10,alpha=0.75)
    ax1.plot(xaxis,yaxis,marker='o',markersize=5,ls='-',alpha=0.75)

    ax1.set_xlabel(f"{axlabel} Number",size=13)
    ax1.set_ylabel(f"{axlabel} {ylabel} [{bunit}]",size=13)
    ax1.grid(alpha=.75)
    ax1.minorticks_on()
    ax1.yaxis.set_ticks_position('both'),ax1.xaxis.set_ticks_position('both')
    ax1.tick_params(axis='both',which='minor',direction='in',labelsize = 12,length=4)
    ax1.tick_params(axis='both',which='major',direction='in',labelsize = 12,length=7)
    if len(fname) > 18:
        ax1.set_title(f"WFC3/{detector} {fname}\n {h1['extname']} ext",size=14)
    else:
        ax1.set_title(f"WFC3/{detector} {fname} {h1['extname']} ext",size=14)
    if ylim != None:
        ax1.set_ylim(ylim[0],ylim[1])

def make_ima_plot(xaxis, yaxis, axlabel, ylabel,
                  bunit, detector, fname,h1, ylim, nsamps, ext,
                  figsize, dpi):
    """ Make and display the plot for WFC3 IR IMA images

    Parameters
    ----------
    xaxis: Range
        Range from 1 to the total number of rows or columns. If image section
        range will go from x1 to x2

    yaxis: Array
        The statistical values being plotted

    axlabel: String {"Row", "Column"}
        The axis which the statistc was computed over

    bunit: String
        The string of the brightness unit for the axis label

    detector: String {"UVIS", "IR"}
        The detector used for the image

    fname: String
        The name of the file being plotted

    h1: Header
        The extension 1 header of the fits file being displayed.

    ylim: (float,float)
        The minimum and maximum values for y axis scale.

    nsamps: Integer
        The number of samples (readouts) contained in the file

    ext: Integer
        The extension to be displayed. Ranges from 1 to nsamp

    figsize: (float,float)
        The width, height of the figure. Default is (9,6)

    dpi: float
        The resolution of the figure in dots-per-inch. Default is 120

    Returns
    -------
    N/A

    """
    fig, ax1 = plt.subplots(1,1,figsize=figsize,dpi=dpi)
        # ax1.scatter(xaxis,yaxis,10,alpha=0.75)
    ax1.plot(xaxis,yaxis,marker='o',markersize=5,ls='-',alpha=0.75)

    ax1.set_xlabel(f"{axlabel} Number",size=13)
    ax1.set_ylabel(f"{axlabel} {ylabel} [{bunit}]",size=13)
    ax1.grid(alpha=.75)
    ax1.minorticks_on()
    ax1.yaxis.set_ticks_position('both'),ax1.xaxis.set_ticks_position('both')
    ax1.tick_params(axis='both',which='minor',direction='in',labelsize = 12,length=4)
    ax1.tick_params(axis='both',which='major',direction='in',labelsize = 12,length=7)
    if len(fname) > 18:
        ax1.set_title(f"WFC3/{detector} {fname}\n {h1['extname']} read {(nsamps+1)-ext}",size=14)
    else:
        ax1.set_title(f"WFC3/{detector} {fname} {h1['extname']} read {(nsamps+1)-ext}",size=14)
    if ylim != None:
        ax1.set_ylim(ylim[0],ylim[1])

def row_column_stats(filename, stat='median', axis='column', ylim=(None,None),
                     printmeta=False, ima_multiread=False, plot=True,
                     figsize=(9,6), dpi=120):
    """ A function to plot the column median vs column number for
        the 'SCI' data of any WFC3 fits image.

        Authors:
        --------
           Benjamin Kuhn, Oct 2021

        Parameters
        ----------
        filename: String
           Input image name with optional image section specification. If no image
           section is entered, the entire image is used. If full path is not given,
           file must exsist in current working directory. This can be an IR or UVIS:
           raw, rac, ima, blv, blc, crj, crc, flt, flc, drz, drc fits file.
           Image section must be entered as:

           file.fits[x1:x2,y1:y2] where

           x1 = x-axis pixel number start
           x2 = x-axis pixel number end
           y1 = y-axis pixel number start
           y2 = y-axis pixel number end

        stat: String { "mean", "median", "mode", "stddev"}
           The type of statistic to compute

        axis: String { "row", "column"}
           The axis to compute the statistic over

        ylim: Tuple
            A Tuple of two real numbers that will serve as the min a max values
            for the y-axis of the plot.

        printmeta: Bool
            A boolean switch to turn on or off the printing of file infomation.
            If printmeta is True various header keywords are printed to the
            screen such as the filter, target name, date observed, brightness
            units and more.

        ima_multiread:  Bool
           Set ima_multiread to True if you would like each indiviual read of
           the ima to be plotted. Set ima_multiread to False if you would like
           just the final read of the ima to be plotted.

        plot:  Bool
           Set plot to False if you do not want the function to plot.

        figsize: (float,float)
            The width, height of the figure. Default is (9,6)

        dpi: float
            The resolution of the figure in dots-per-inch. Default is 120

        Returns
        -------
        xaxis: Range
           Range from 1 to the total number of rows or columns

        yaxis: Array
           Array of y-axis row or column statistic values

        """

    section_start = filename.find("[")
    all_pixels = False
    if (section_start < 0):
        all_pixels = True  # just give the data to np
        imagename = filename
    elif (section_start > 0):
        imagename = filename[:section_start]
        if (filename[section_start+1].isalpha()):
            print(filename[section_start+1])
            print("Please only specify a pixel range, not an extension \
                   in the filename")
            return 0, 0

    if not all_pixels:
        # pull the section off
        section = filename[section_start+1:-1]
        comma = section.find(",")
        xsec = section[:comma]
        ysec = section[comma+1:]
        xs = xsec.find(":")
        if xs < 0:
            print("Invalid image section specified")
            return 0, 0
        try:
            xstart = int(xsec[: xs])
        except ValueError:
            print("Problem getting xstart")
            return
        try:
            xend = int(xsec[xs+1:])
        except ValueError:
            print("Problem getting xend")
            return

        ys = ysec.find(":")
        if (ys < 0):
            print("Invalid image section specified")
            return 0, 0
        try:
            ystart = int(ysec[:ys])
        except ValueError:
            print("Problems getting ystart")
            return
        try:
            yend = int(ysec[ys+1:])
        except ValueError:
            print("Problem getting yend")
            return

    with fits.open(imagename) as hdu:
        h = hdu[0].header
        h1 = hdu[1].header

    bunit = get_bunit(h1)
    detector = h['detector']
    issubarray = h['subarray']
    si = h['primesi']
    fname = h['filename']
    naxis1 = h1["NAXIS1"]
    naxis2 = h1["NAXIS2"]

    if all_pixels:
        xstart = 0
        ystart = 0
        xend = naxis1   # full x size
        yend = naxis2  # full y size

    if axis == 'column':
        axes = 0
        xaxis = range(xstart, xend)
        axlabel = 'Column'
    elif axis == 'row':
        axes = 1
        xaxis = range(ystart, yend)
        axlabel = 'Row'
    else:
        sys.exit("keyword argument 'axis' must be set to 'column' or 'row' ")

    if printmeta:
        print(f"\t{si}/{detector} {fname} ")
        print('-'*44)
        print(f"Filter = {h['filter']}, Date-Obs = {h['date-obs']} T{h['time-obs']},\nTarget = {h['targname']}, Exptime = {h['exptime']}, Subarray = {issubarray}, Units = {h1['bunit']}\n")



    if detector == 'UVIS':
        if ima_multiread == True:
            sys.exit("keyword argument 'ima_multiread' can only be set to True for 'ima.fits' files")
        try:
            with fits.open(imagename) as hdu:
                uvis1_sci = hdu['SCI',2].data
                uvis2_sci = hdu['SCI',1].data

            uvis_sci = np.concatenate([uvis2_sci,uvis1_sci])

            if all_pixels:
                uvis_sci = uvis_sci[ystart:yend*2,xstart:xend]
                if axis == 'row':
                    xaxis = range(ystart, yend*2)
            else:
                uvis_sci = uvis_sci[ystart:yend,xstart:xend]

        except KeyError:
            with fits.open(imagename) as hdu:
                uvis_sci = hdu['SCI',1].data

            if all_pixels:
                uvis_sci = uvis_sci[ystart:yend,xstart:xend]
                if axis == 'row':
                    xaxis = range(ystart, yend)
            else:
                uvis_sci = uvis_sci[ystart:yend,xstart:xend]

        yaxis, ylabel = get_yaxis_and_label(stat,uvis_sci,axes)
        if plot:
            makeplot(xaxis, yaxis, axlabel, ylabel,
                     bunit, detector, fname, h1,
                     ylim, figsize, dpi)


    if detector == 'IR':
        if ima_multiread == True:
            nsamps = fits.getheader(imagename)['NSAMP']
            for ext in reversed(range(1,nsamps+1)):
                with fits.open(imagename) as hdu:
                    scidata = hdu['SCI',ext].data

                scidata = scidata[ystart:yend,xstart:xend]

                yaxis, ylabel = get_yaxis_and_label(stat,scidata,axes)
                if plot:
                    make_ima_plot(xaxis, yaxis, axlabel, ylabel,
                                  bunit, detector, fname,h1, ylim,
                                  nsamps, ext, figsize, dpi)

        if ima_multiread == False:
            with fits.open(imagename) as hdu:
                scidata = hdu['SCI',1].data

            scidata = scidata[ystart:yend,xstart:xend]

            yaxis, ylabel = get_yaxis_and_label(stat,scidata,axes)
            if plot:
                makeplot(xaxis, yaxis, axlabel, ylabel,
                         bunit, detector, fname, h1,
                         ylim, figsize, dpi)

    return xaxis, yaxis
