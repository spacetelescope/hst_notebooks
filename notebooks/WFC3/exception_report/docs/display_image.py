#! /usr/bin/env python

import numpy as np
import sys

from astropy.io import fits
from ginga.util import zscale
import matplotlib.pyplot as plt

def display_image(filename,
                  colormaps=['Greys_r','Greys_r','inferno_r'],
                  scaling=[(None,None),(None,None),(None,None)],
                  printmeta=False,
                  ima_multiread=False,
                  figsize=(18,18),
                  dpi=200):

    """ A function to display the 'SCI', 'ERR/WHT', and 'DQ/CTX' arrays
        of any WFC3 fits image. This function returns nothing, but will display
        the requested image on the screen when called.

    Authors
    -------
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

    colormaps: List
        List of colormaps strings for the SCI, ERR, and DQ arrays. The first
        element in the list is for the SCI array the second is for the ERR array
        and the third element in the list is for the DQ extension. If no
        colormaps are given the default maps will be 'Greys_r','Greys_r', and
        'inferno_r'. All three colormaps must be provided even if only
        changing 1-2 maps.

    scaling: List
        List of real numbers to act as scalings for the SCI, ERR, and DQ arrays.
        The first element in the list is for the SCI array the second is for the
        ERR array and the third element in the list is for the DQ extension. If
        no scalings are given the default scaling will use
        ginga.util.zscale.zscale(). All three scalings must be provided even if
        only changing 1-2 scalings. E.g. to change SCI array scaling:
        scaling = [(5E4,8E4),(None,None),(None,None)]

    printmeta: Bool
        A boolean switch to turn on or off the printing of file infomation.
        If printmeta is True various header keywords are printed to the screen
        such as the filter, target name, date observed, brightness units and more.

    ima_multiread:  Bool
       If ima_multiread is set to True each indiviual read of the ima will be
       plotted. If ima_multiread is set to False only the final read of the ima
       (ext 1) will be plotted.

    figsize: (Float,Float)
        The width, height of the figure. Default is (18,18).

    dpi: Float
        The resolution of the figure in dots-per-inch. Default is 200.

    Returns
    -------
    N/A

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

    with fits.open(imagename) as hdu:
        h = hdu[0].header
        h1 = hdu[1].header
        h2 = hdu[2].header
        h3 = hdu[3].header

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

    bunit = get_bunit(h1)
    detector = h['detector']
    issubarray = h['subarray']
    si = h['primesi']
    fname = h['filename']
    naxis1 = h1["NAXIS1"]
    naxis2 = h1["NAXIS2"]

    if len(colormaps) < 3 or len(colormaps) > 3:
        sys.exit(f"{len(colormaps)} colormaps proived. Must input all three")

    if len(scaling) < 3 or len(scaling) > 3:
        sys.exit(f"{len(scaling)} scalings provided. Must input all three")

    if printmeta:
        print(f"\t{si}/{detector} {fname} ")
        print('-'*44)
        print(f"Filter = {h['filter']}, Date-Obs = {h['date-obs']} T{h['time-obs']},\nTarget = {h['targname']}, Exptime = {h['exptime']}, Subarray = {issubarray}, Units = {h1['bunit']}\n")


    if detector == 'UVIS':
        if ima_multiread == True:
            sys.exit("keyword argument 'ima_multiread' can only be set to True for 'ima.fits' files")
        try:
            if all_pixels:
                xstart = 0
                ystart = 0
                xend = naxis1   # full x size
                yend = naxis2*2 # full y size

            with fits.open(imagename) as hdu:
                uvis2_sci = hdu["SCI",1].data
                uvis2_err = hdu[2].data
                uvis2_dq = hdu[3].data
                uvis1_sci = hdu["SCI",2].data
                uvis1_err = hdu[5].data
                uvis1_dq = hdu[6].data

            try:
                fullsci = np.concatenate([uvis2_sci,uvis1_sci])
                fulldq = np.concatenate([uvis2_dq,uvis1_dq])
                fullerr = np.concatenate([uvis2_err,uvis1_err])

                fullsci = fullsci[ystart:yend,xstart:xend]
                fulldq  = fulldq[ystart:yend,xstart:xend]
                fullerr = fullerr[ystart:yend,xstart:xend]

                make1x3plot(scaling, colormaps, fullsci, fullerr, fulldq,
                            xstart, xend, ystart, yend,
                            detector, fname, h1, h2, h3,
                            figsize, dpi)

            except ValueError:
                fullsci = np.concatenate([uvis2_sci,uvis1_sci])
                fullsci = fullsci[ystart:yend,xstart:xend]

                z1_sci, z2_sci = get_scale_limits(scaling[0],fullsci,'SCI')

                fig, ax1 = plt.subplots(1,1,figsize=figsize,dpi=dpi)
                im1 = ax1.imshow(fullsci,origin='lower',extent=(xstart,xend,ystart,yend),cmap=colormaps[0],vmin=z1_sci, vmax=z2_sci)
                if len(fname) > 18:
                    ax1.set_title(f"WFC3/{detector} {fname}\n{h1['extname']} ext")
                else:
                    ax1.set_title(f"WFC3/{detector} {fname} {h1['extname']} ext")
                fig.colorbar(im1, ax=ax1,shrink=.75,pad=.03)

        except (IndexError,KeyError):

            if all_pixels:
                    xstart = 0
                    ystart = 0
                    xend = naxis1  # full x size
                    yend = naxis2  # full y size

            with fits.open(imagename) as hdu:
                uvis_ext1 = hdu[1].data
                uvis_ext2 = hdu[2].data
                uvis_ext3 = hdu[3].data

            try:
                uvis_ext1 = uvis_ext1[ystart:yend,xstart:xend]
                uvis_ext2 = uvis_ext2[ystart:yend,xstart:xend]
                uvis_ext3 = uvis_ext3[ystart:yend,xstart:xend]

                make1x3plot(scaling, colormaps, uvis_ext1, uvis_ext2, uvis_ext3,
                            xstart, xend, ystart, yend,
                            detector, fname, h1, h2, h3,
                            figsize, dpi)

            except (TypeError,IndexError,AttributeError):

                z1_sci, z2_sci = get_scale_limits(scaling[0],uvis_ext1,'SCI')
                fig, ax1 = plt.subplots(1,1,figsize=figsize,dpi=dpi)
                im1 = ax1.imshow(uvis_ext1,origin='lower',extent=(xstart,xend,ystart,yend),cmap=colormaps[0],vmin=z1_sci, vmax=z2_sci)
                if len(fname) > 18:
                    ax1.set_title(f"WFC3/{detector} {fname}\n{h1['extname']} ext")
                else:
                    ax1.set_title(f"WFC3/{detector} {fname} {h1['extname']} ext")
                fig.colorbar(im1, ax=ax1,shrink=.75,pad=.03)


    if detector == 'IR' and '_ima.fits' not in fname:
        if ima_multiread == True:
            sys.exit("keyword argument 'ima_multiread' can only be set to True for 'ima.fits' files")
        if all_pixels:
            xstart = 0
            ystart = 0
            xend =  naxis1 # full x size
            yend =  naxis2 # full y size

        try:
            with fits.open(imagename) as hdu:
                data_sci = hdu[1].data
                data_err = hdu[2].data
                data_dq = hdu[3].data

            data_sci = data_sci[ystart:yend,xstart:xend]
            data_err = data_err[ystart:yend,xstart:xend]
            data_dq  = data_dq[ystart:yend,xstart:xend]

            make1x3plot(scaling, colormaps, data_sci, data_err, data_dq,
                        xstart, xend, ystart, yend,
                        detector, fname, h1, h2, h3,
                        figsize, dpi)

        except (AttributeError, TypeError, ValueError):
                z1_sci, z2_sci = get_scale_limits(scaling[0],data_sci,'SCI')
                fig, ax1 = plt.subplots(1,1,figsize=figsize,dpi=dpi)
                im1 = ax1.imshow(data_sci,origin='lower',extent=(xstart,xend,ystart,yend),cmap=colormaps[0],vmin=z1_sci, vmax=z2_sci)
                if len(fname) > 18:
                    ax1.set_title(f"WFC3/{detector} {fname}\n{h1['extname']} ext")
                else:
                    ax1.set_title(f"WFC3/{detector} {fname} {h1['extname']} ext")
                fig.colorbar(im1, ax=ax1,shrink=.75,pad=.03)


    if '_ima.fits' in fname:
        if all_pixels:
            xstart = 0
            ystart = 0
            xend =  naxis1 # full x size
            yend =  naxis2 # full y size

        if ima_multiread == True:
            nsamps = h['NSAMP']
            for ext in reversed(range(1,nsamps+1)):
                with fits.open(imagename) as hdu:
                    data_sci = hdu['SCI',ext].data
                    data_err = hdu['ERR',ext].data
                    data_dq  = hdu['DQ',ext].data

                data_sci = data_sci[ystart:yend,xstart:xend]
                data_err = data_err[ystart:yend,xstart:xend]
                data_dq  = data_dq[ystart:yend,xstart:xend]

                makeIR1x3plot(scaling, colormaps, data_sci, data_err, data_dq,
                                xstart, xend, ystart, yend,
                                detector, fname, h1, h2, h3, nsamps, ext,
                                figsize, dpi)

        if ima_multiread == False:
            with fits.open(imagename) as hdu:
                data_sci = hdu['SCI',1].data
                data_err = hdu['ERR',1].data
                data_dq  = hdu['DQ',1].data

            data_sci = data_sci[ystart:yend,xstart:xend]
            data_err = data_err[ystart:yend,xstart:xend]
            data_dq  = data_dq[ystart:yend,xstart:xend]

            make1x3plot(scaling, colormaps, data_sci, data_err, data_dq,
                        xstart, xend, ystart, yend,
                        detector, fname, h1, h2, h3,
                        figsize, dpi)


def get_bunit(ext1header):
    """ Get the brightness unit for the plot axis label.

    Parameters
    ----------
    ext1header: Header
        The extension 1 header of the fits file being displayed. This is the
        extension that contains the brightness unit keyword.

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


def get_scale_limits(scaling, array, extname):
    """ Get the scale limits to use for the image extension being displayed.

    Parameters
    ----------
    scaling: List
        List of real numbers to act as scalings for the SCI, ERR, and DQ arrays.
        The first element in the list is for the SCI array the second is for the
        ERR array and the third element in the list is for the DQ extension. If
        no scalings are given the default scaling will use
        ginga.util.zscale.zscale(). All three scalings must be provided even if
        only changing 1-2 scalings. E.g. to change SCI array scaling:
        scaling = [(5E4,8E4),(None,None),(None,None)]

    array : Array
        The ImageHDU array that is being displayed.

    extname: String {"SCI", "ERR", "DQ"}
        The name of the extension of which the scale is being determined.

    Returns
    -------
    z1: Float
        The minimum value for the image scale.

    z2: Float
        The maximum value for the image scale.

    """
    if extname == 'DQ':
        if scaling[0] == None and scaling[1] == None:
            z1, z2 = array.min(), array.max()
        elif scaling[0] == None and scaling[1] != None:
            z1 = array.min()
            z2 = scaling[1]
        elif scaling[0] != None and scaling[1] == None:
            z1 = scaling[0]
            z2 = array.max()
        elif scaling[0] != None and scaling[1] != None:
            z1 = scaling[0]
            z2 = scaling[1]

    elif extname == 'SCI' or extname == 'ERR':
        if scaling[0] == None and scaling[1] == None:
            z1, z2 = zscale.zscale(array)
        elif scaling[0] == None and scaling[1] != None:
            z1 = zscale.zscale(array)[0]
            z2 = scaling[1]
        elif scaling[0] != None and scaling[1] == None:
            z1 = scaling[0]
            z2 = zscale.zscale(array)[1]
        elif scaling[0] != None and scaling[1] != None:
            z1 = scaling[0]
            z2 = scaling[1]
    else:
        print("`extname` must be set to either `SCI`, `ERR`, or `DQ`")
        return

    return z1, z2


def make1x3plot(scaling, colormaps, fullsci, fullerr, fulldq,
                xstart, xend, ystart, yend,
                detector, fname, h1, h2, h3,
                figsize=(9,6), dpi=100):
    """ Make a 3 column figure to display any WFC3 image or image section.

    Parameters
    ----------
    scaling: List
        List of real numbers to act as scalings for the SCI, ERR, and DQ arrays.
        The first element in the list is for the SCI array the second is for the
        ERR array and the third element in the list is for the DQ extension. If
        no scalings are given the default scaling will use
        ginga.util.zscale.zscale(). All three scalings must be provided even if
        only changing 1-2 scalings. E.g. to change SCI array scaling:
        scaling = [(5E4,8E4),(None,None),(None,None)]

    colormaps: List
        List of colormaps strings for the SCI, ERR, and DQ arrays. The first
        element in the list is for the SCI array the second is for the ERR array
        and the third element in the list is for the DQ extension. If no
        colormaps are given the default maps will be 'Greys_r','Greys_r', and
        'inferno_r'. All three colormaps must be provided even if only
        changing 1-2 maps.

    fullsci: Array
        The 2d array of science pixels ('SCI' array). If an image section is
        being displayed the array has already been indexed prior to calling this
        function.

    fullerr: Array
        The 2d array of error pixels ('ERR' array). If an image section is
        being displayed the array has already been indexed prior to calling this
        function.

    fulldq: Array
        The 2d array of data quality pixels ('DQ' array). If an image section is
        being displayed the array has already been indexed prior to calling this
        function.

    xstart: Integer
        The starting index value for the x-axis of the image.

    xend: Integer
        The ending index value for the x-axis of the image.

    ystart: Integer
        The starting index value for the y-axis of the image.

    yend: Integer
        The ending index value for the y-axis of the image.

    detector: String {"UVIS", "IR"}
        The detector used for the image.

    fname: String
        The name of the file being plotted.

    h1: Header
        The extension 1 header of the fits file being displayed.

    h2: Header
        The extension 2 header of the fits file being displayed.

    h3: Header
        The extension 3 header of the fits file being displayed.

    figsize: (float,float)
        The width, height of the figure. Default is (9,6).

    dpi: float
        The resolution of the figure in dots-per-inch. Default is 100.

    Returns
    -------
    N/A

    """

    z1_sci, z2_sci = get_scale_limits(scaling[0],fullsci,'SCI')
    z1_err, z2_err = get_scale_limits(scaling[1],fullerr,'ERR')
    z1_dq, z2_dq   = get_scale_limits(scaling[2],fulldq,'DQ')

    fig, [ax1,ax2,ax3] = plt.subplots(1,3,figsize=figsize,dpi=dpi)

    im1 = ax1.imshow(fullsci,origin='lower',extent=(xstart,xend,ystart,yend),cmap=colormaps[0],vmin=z1_sci, vmax=z2_sci)
    im2 = ax2.imshow(fullerr,origin='lower',extent=(xstart,xend,ystart,yend),cmap=colormaps[1],vmin=z1_err, vmax=z2_err)
    im3 = ax3.imshow(fulldq, origin='lower',extent=(xstart,xend,ystart,yend),cmap=colormaps[2],vmin=z1_dq, vmax=z2_dq)

    if len(fname) > 18:
        ax1.set_title(f"WFC3/{detector} {fname}\n{h1['extname']} ext")
        ax2.set_title(f"WFC3/{detector} {fname}\n{h2['extname']} ext")
        ax3.set_title(f"WFC3/{detector} {fname}\n{h3['extname']} ext")
    else:
        ax1.set_title(f"WFC3/{detector} {fname} {h1['extname']} ext")
        ax2.set_title(f"WFC3/{detector} {fname} {h2['extname']} ext")
        ax3.set_title(f"WFC3/{detector} {fname} {h3['extname']} ext")
    fig.colorbar(im1, ax=ax1,shrink=.25,pad=.03)
    fig.colorbar(im2, ax=ax2,shrink=.25,pad=.03)
    fig.colorbar(im3, ax=ax3,shrink=.25,pad=.03)

def makeIR1x3plot(scaling, colormaps, data_sci, data_err, data_dq,
                  xstart, xend, ystart, yend,
                  detector, fname, h1, h2, h3, nsamps, ext,
                  figsize=(9,6), dpi=100):
    """ Make a 3 column figure to display any WFC3 IMA image or image section.

    Parameters
    ----------
    scaling: List
        List of real numbers to act as scalings for the SCI, ERR, and DQ arrays.
        The first element in the list is for the SCI array the second is for the
        ERR array and the third element in the list is for the DQ extension. If
        no scalings are given the default scaling will use
        ginga.util.zscale.zscale(). All three scalings must be provided even if
        only changing 1-2 scalings. E.g. to change SCI array scaling:
        scaling = [(5E4,8E4),(None,None),(None,None)]

    colormaps: List
        List of colormaps strings for the SCI, ERR, and DQ arrays. The first
        element in the list is for the SCI array the second is for the ERR array
        and the third element in the list is for the DQ extension. If no
        colormaps are given the default maps will be 'Greys_r','Greys_r', and
        'inferno_r'. All three colormaps must be provided even if only
        changing 1-2 maps.

    data_sci: Array
        The 2d array of science pixels ('SCI' array). If an image section is
        being displayed the array has already been indexed prior to calling this
        function.

    data_err: Array
        The 2d array of error pixels ('ERR' array). If an image section is
        being displayed the array has already been indexed prior to calling this
        function.

    data_dq: Array
        The 2d array of data quality pixels ('DQ' array). If an image section is
        being displayed the array has already been indexed prior to calling this
        function.

    xstart: Integer
        The starting index value for the x-axis of the image.

    xend: Integer
        The ending index value for the x-axis of the image.

    ystart: Integer
        The starting index value for the y-axis of the image.

    yend: Integer
        The ending index value for the y-axis of the image.

    detector: String {"UVIS", "IR"}
        The detector used for the image.

    fname: String
        The name of the file being plotted.

    h1: Header
        The extension 1 header of the fits file being displayed.

    h2: Header
        The extension 2 header of the fits file being displayed.

    h3: Header
        The extension 3 header of the fits file being displayed.

    nsamps: Integer
        The number of samples (readouts) contained in the file.

    ext: Integer
        The extension to be displayed. Ranges from 1 to nsamp.

    figsize: (float,float)
        The width, height of the figure. Default is (9,6).

    dpi: float
        The resolution of the figure in dots-per-inch. Default is 100.

    Returns
    -------
    N/A

    """

    z1_sci, z2_sci = get_scale_limits(scaling[0],data_sci,'SCI')
    z1_err, z2_err = get_scale_limits(scaling[1],data_err,'ERR')
    z1_dq, z2_dq   = get_scale_limits(scaling[2],data_dq,'DQ')

    fig, [ax1,ax2,ax3] = plt.subplots(1,3,figsize = figsize,dpi=dpi)
    im1 = ax1.imshow(data_sci,origin='lower',extent=(xstart,xend,ystart,yend),cmap=colormaps[0],vmin=z1_sci, vmax=z2_sci)
    im2 = ax2.imshow(data_err,origin='lower',extent=(xstart,xend,ystart,yend),cmap=colormaps[1],vmin=z1_err, vmax=z2_err)
    im3 = ax3.imshow(data_dq, origin='lower',extent=(xstart,xend,ystart,yend),cmap=colormaps[2],vmin=z1_dq, vmax=z2_dq)
    fig.colorbar(im1, ax=ax1,shrink=.25,pad=.03)
    fig.colorbar(im2, ax=ax2,shrink=.25,pad=.03)
    fig.colorbar(im3, ax=ax3,shrink=.25,pad=.03)

    if len(fname) > 18:
        ax1.set_title(f"WFC3/{detector} {fname}\n  {h1['extname']} read {(nsamps+1)-ext}")
        ax2.set_title(f"WFC3/{detector} {fname}\n  {h2['extname']} read {(nsamps+1)-ext}")
        ax3.set_title(f"WFC3/{detector} {fname}\n  {h3['extname']} read {(nsamps+1)-ext}")
    else:
        ax1.set_title(f"WFC3/{detector} {fname}  {h1['extname']} read {(nsamps+1)-ext}")
        ax2.set_title(f"WFC3/{detector} {fname}  {h2['extname']} read {(nsamps+1)-ext}")
        ax3.set_title(f"WFC3/{detector} {fname}  {h3['extname']} read {(nsamps+1)-ext}")
