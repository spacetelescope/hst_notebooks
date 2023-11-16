"""Tools for creating radial profile diagnostic information.

This class is used in the computation of radial profiles, that
is the pixel values vs the distance from the centroid of the source.
This class can make plots, fit a Moffat function to the profile,
and recenter the source position as the profile is sensitive to the
centroid position.  Various attributes such as the full width at
half maximum and centroid positions can easily be accessed via the
usual . syntax.

https://github.com/spacetelescope/wfc3_photometry/blob/master/photometry_tools/rad_prof.py

Authors
-------
    - Varun Bajaj, May 2018
Use
---
    from rad_prof import RadialProfile
    my_prof = RadialProfile(x, y, data) # Simplest case
    print(my_prof.fwhm) # Print FWHM of Moffat fit
    my_prof.show_profile() # Show plot of profile
    
    # Use larger area, recompute centroid
    my_prof = RadialProfile(x, y, data, r=7, recenter=True)
    print(my_prof.x, my_prof.y)
    
    # Can get shifts:
    print(my_prof.x - my_prof.old_x)
    
    # Show the profile
    my_prof = RadialProfile(x, y, data, show=True)
    plt.show()
    
    # OR:
    my_prof = RadialProfile(x, y, data)
    my_prof.show_profile()
    plt.show()
"""

import numpy as np
import matplotlib.pyplot as plt

from photutils.centroids import centroid_com, centroid_1dg, centroid_2dg
from photutils.aperture import CircularAperture
from scipy.optimize import curve_fit

class RadialProfile:
    """Main function to calulate radial profiles.
    
    Computes a radial profile of a source in an array.  This function
    leverages some of the tools in photutils to cutout the small region
    around the source.  This function can first recenter the source
    via a 2d Gaussian fit (radial profiles are sensitive to centroids)
    and then fit a 1D Moffat profile to the values.  The profile
    is calculated by computing the distance from the center of each
    pixel within a box of size r to the centroid of the source in the
    box.  Additionally, the profile and the fit can be plotted.
    If fit is set to True, then the profile is fit with a 1D Moffat.
    If show is set to True, then profile (and/or fit) is plotted.
    If an axes object is provided, the plot(s) will be on that object.
    NOTE: THE POSITIONS ARE 0 INDEXED (bottom left corner pixel
    center is set to (0,0)).
    
    Parameters
    ----------
    x : float
        The x position of the centroid of the source. ZERO INDEXED.
        stored in the .x attribute.
    y : float
        The y position of the centroid of the source. ZERO INDEXED.
        stored in the .y attribute.
    data : array
        A 2D array containing the full image data.  A small box
        is cut out of this array for the radial profile.
    r : float, optional
        The size of the box used to cut out the source pixels.
        The box is typically square with side length ~ 2*r + 1.
        Default is 5 pix.
    fit:  bool
        Fit a 1D Moffat profile.  Default True.  Required for
        computation of FWHM.
    recenter : bool, optional
        Compute new centroid via 2D Gaussian fit.  Default False.
    show : bool, optional
        Plot the profile.  Default False.  See ax parameter for info.
    ax : matplotlib.axes.Axes, optional
        Axes object to make the plots on.  Default None.
        If None and show is True, an axes object will be created.
        
    Attributes
    ----------
    x : float
        The x position in pixels of the source centroid. Gets updated
        if the profile is recentered.
    y : float
        The y position in pixels of the source centroid. Gets updated
        if the profile is recentered.
    fwhm : float
        The FWHM of the fitted profile, only computed if fit=True.
    old_x : float
        The x position in pixels of the original input centroid. Only
        set if recenter = True.
    old_y : float
        The y position in pixels of the original input centroid. Only
        set if recenter = True.
    fitted : bool
        Whether the data has had a profile fit. Only True if fit=True
        and fitting was successful.
    is_empty : bool
        Whether cutout is empty or not.  True if position falls
        entirely off of data.
    cutout : array
        2D array containing small cutout of data around source.
    distances : array
        Array containing distance to each pixel in cutout from centroid.
    value : array
        Array containing all the values in the cutout.
    """
    def __init__(self, x, y, data, r=5, fit=True, recenter=False,
                 show=False, ax=None):
        self.x = x # X position
        self.y = y # Y Position
        self.r = r # radius (acutally makes a box)
        self.is_empty = False # if gets set True, cutout is empty
        self._setup_cutout(data) # Make the cutout

        if recenter:
            self.recenter_source(data) # recalculates centroid

        self.fit = fit
        self.fitted = False # Initial state, set to true if fit success
        if self.is_empty:
            self.fwhm = np.nan

        else:
            self._create_profile() # creates distances and values arrays

            if fit:
                self.fit_profile() # performs fit, updates self.fitted
            if show:
                self.show_profile(ax)

    def _create_profile(self):
        """Compute distances to pixels in cutout"""
        iY, iX = np.mgrid[self.sy, self.sx] # Pixel grid indices
        # extent = [sx.start, sx.stop-1, sy.start, sy.stop-1]

        self.distances = np.sqrt( (iX - self.x) ** 2.
                                + (iY - self.y) ** 2. ).flatten()
        self.values = self.cutout.flatten()

    def _setup_cutout(self, data):
        """Cuts out the aperture and defines slice objects.
        General setup procedure.
        """
        self.ap = CircularAperture((self.x, self.y), r=self.r)
        mask = self.ap.to_mask()
        self.sy = slice(mask.bbox.iymin,mask.bbox.iymax,None)
        self.sx = slice(mask.bbox.ixmin,mask.bbox.ixmax,None)
        self.cutout = mask.cutout(data, fill_value=np.nan)

        if self.cutout is None:
            self.is_empty = True

    def fit_profile(self):
        """Fits 1d Moffat function to measured radial profile.
        Fits a moffat profile to the distance and values of the pixels.
        Further development may allow user defined models.
        """
        try:
            amp0 = np.amax(self.values)
            bias0 = np.nanmedian(self.values)
            best_vals, covar = curve_fit(RadialProfile.profile_model,
                                        self.distances,
                                        self.values,
                                        p0 = [amp0, 1.5, 1.5, bias0],
                                        bounds = ([0., .3, .5, 0],
                                                  [np.inf, 10., 10., np.inf]))
            hwhm = best_vals[1] * np.sqrt(2. ** (1./best_vals[2]) - 1.)
            self.fwhm = 2 * hwhm
            self.amp, self.gamma, self.alpha, self.bias = best_vals
            self.fitted = True
            mod = RadialProfile.profile_model(self.distances, *best_vals)
            self.chisquared = np.nansum((self.values-mod)**2/mod)
        except Exception as e:
            print(e)
            self.amp, self.gamma, self.alpha, self.bias = [np.nan] * 4
            self.fwhm = np.nan
            self.fitted = False
            self.chisquared = np.nan

    @staticmethod
    def profile_model(r, amp, gamma, alpha, bias):
        """Returns 1D Moffat profile evaluated at r values.
        
        This function takes radius values and parameters in a simple 1D
        moffat profiles and returns the values of the profile at those
        radius values.  The model is defined as:
        model = amp * (1. + (r / gamma) ** 2.) ** (-1. * alpha) + bias
        
        Parameters
        ----------
        r : array
            The distances at which to sample the model.
        amp : float
            The amplitude of the of the model.
        gamma: float
            The width of the profile.
        alpha: float
            The decay of the profile.
        bias: float
            The bias level (piston term) of the data.  This is like a background
            value.
            
        Returns
        -------
        model : array
            The values of the model sampled at the r values.
        """
        model = amp * (1. + (r / gamma) ** 2.) ** (-1. * alpha) + bias
        return model

    def recenter_source(self, data):
        """Recenters source position in cutout and updates x,y attributes"""

        # Archive old positions.
        self.old_x = self.x
        self.old_y = self.y

        if self.is_empty:
            self.x, self.y = np.nan, np.nan

        else:
            # Fit 2D gaussian
            xg1, yg1 = centroid_2dg(self.cutout)
            dx = xg1 + self.sx.start - self.x
            dy = yg1 + self.sy.start - self.y
            dr = (dx ** 2. + dy ** 2.) ** .5
            if dr > 2.:
                print('Large shift of {},{} computed.'.format(dx, dy))
                print('Rejecting and keeping original x, y coordinates')

            else:
                self.x = xg1 + self.sx.start
                self.y = yg1 + self.sy.start
                self._setup_cutout(data)

    def show_profile(self, ax=None, show_fit=True):
        """Makes plot of radial profile.
        
        Plots the radial profile, that is pixel distance vs
        pixel value.  Can plot on an existing axes object if
        the an axes object is passed in via the ax parameter.
        The function attempts to set sensible axes limits, specifically
        half of the smallest positive value (axes are logarithmic).
        The axes object is returned by this, so that parameters can
        be set by the user later.
        
        Parameters
        ----------
        ax : matplotlib.axes.Axes, optional
            An axes object to plot the radial profile on (for integrating)
            the plot into other figures.  If not set, the script will create
            an axes object.
        show_fit : bool, optional
            Plot the fitted model.  Only done if fit was successful.
            
        Returns
        -------
        ax : matplotlib.axes.Axes
            The axes object containing the radial profile plot.
        """
        if ax is None:
            fig = plt.figure(dpi=110)
            ax = fig.add_subplot(111)

        ax.scatter(self.distances, self.values, alpha=.5,s=3)
        min_y = np.amin(self.values[self.values >0.])/2.
        #ax.set_ylim(min_y, np.nanmax(self.values)*2.)
        ax.set_ylim(0.1, np.nanmax(self.values)*2.)
        ax.set_xlim(0.)

        ax.set_yscale('log')
        ax.set_ylabel('Pixel Value',size=13)
        ax.set_xlabel('Distance from centroid [pix]',size=13)

        if self.fitted and show_fit:
            tmp_r = np.arange(0,np.ceil(np.amax(self.distances)),.1)
            model_fit = RadialProfile.profile_model(tmp_r, self.amp,
                                                    self.gamma, self.alpha,
                                                    self.bias)
            label = r'$\gamma$= {}, $\alpha$ = {}'.format(round(self.gamma,2),
                                                          round(self.alpha,2))
            label += '\nFWHM = {}'.format(round(self.fwhm, 2))
            ax.plot(tmp_r, model_fit, label=label,color='k')
            ax.legend(loc=1,prop={'size':13})
        return ax
