import matplotlib.pyplot as plt
from astropy.io import fits
from astropy.visualization import (ZScaleInterval, LinearStretch,
                                   ImageNormalize)

def ds9_imitate(ax, image):
    norm = ImageNormalize(image,
                          interval=ZScaleInterval(),
                          stretch=LinearStretch())

    ax.imshow(image, cmap='bone', norm=norm)
    return

def triple_pam_plot(flt_file, pam_file, figtitle):
    fl_img = fits.getdata(flt_file, ext=1)
    pam_img = fits.getdata(pam_file)

    fig = plt.figure(figsize=(20,4))
    fig.suptitle(figtitle,fontsize=20)

    ax = fig.add_subplot(1, 3, 1)
    ds9_imitate(ax, fl_img)
    ax.set_title('Raw')

    ax2 = fig.add_subplot(1, 3, 2, yticks=[])
    ds9_imitate(ax2, pam_img)
    ax2.set_title('Pixel Area Map')

    pamd_img = fl_img*pam_img

    ax3 = fig.add_subplot(1, 3, 3, yticks=[])
    ds9_imitate(ax3, pamd_img)
    ax3.set_title('Raw x Pixel Area Map')

    plt.subplots_adjust(wspace=0.05)
    return

def calib_compare_plot(raw_image, cal_image):
    fig = plt.figure(figsize=(14,14))

    ax = fig.add_subplot(2,1,1)
    ds9_imitate(ax, raw_image)
    ax.set_title('Raw')

    ax2 = fig.add_subplot(2,1,2)
    ds9_imitate(ax2, cal_image)
    ax2.set_title('Flat-Fielded')

    return
