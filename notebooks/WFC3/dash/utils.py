#! /usr/bin/env python

""" Tools to help with reducing DASH/IR data. 

Authors
------- 
    Rosalia O'Brien 2019
    Catherine Martlin 2018/2019
    Iva Momcheva 2018
    Mario Gennaro 2018

"""
import os

from astropy.io import fits
from urllib.request import urlretrieve 


def get_flat(file_name):
    '''
    Will check if user has proper reference file directories 
    and files. Will also return flat field file appropriate for 
    the input file. 

    Parameters
    ----------
    file_name : string
        File name of input IMA. 

    Returns
    ----------
    reffile_name : string
        File name of flat field for that file. 

    '''
    os.environ['iref'] = 'iref/'
    if not os.path.exists('iref'):
        os.mkdir('iref')
    
    base_url = 'https://hst-crds.stsci.edu/unchecked_get/references/hst/'
    
    with fits.open(file_name) as fitsfile:
        reffile_name = fitsfile[0].header['PFLTFILE'].replace('$', '/')
        if not os.path.exists(reffile_name):
            urlretrieve(base_url + os.path.basename(reffile_name), reffile_name)

    return reffile_name

def get_IDCtable(file_name):
    '''
    Will check if user has proper reference file directories 
    and files. Will also return Instrument Distortion Calibration 
    reference file appropriate for the input file. 

    Parameters
    ----------
    file_name : string
        File name of input IMA. 

    Returns
    ----------
    reffile_name : string
        File name of Instrument Distortion Calibration reference file 
        for that file. 

    '''

    os.environ['iref'] = 'iref/'
    if not os.path.exists('iref'):
        os.mkdir('iref')
    
    base_url = 'https://hst-crds.stsci.edu/unchecked_get/references/hst/'
    
    with fits.open(file_name) as fitsfile:
        reffile_name = fitsfile[0].header['IDCTAB'].replace('$', '/')
        if not os.path.exists(reffile_name):
            urlretrieve(base_url + os.path.basename(reffile_name), reffile_name)

    return reffile_name