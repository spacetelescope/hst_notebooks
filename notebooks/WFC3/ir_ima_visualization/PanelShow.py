import numpy as np
from matplotlib import pyplot as plt
import matplotlib.patheffects as path_effects
from ginga.util.zscale import zscale


def panel_plot(cube, integ_time,md,ld,rd,ms,ls,rs, diff_method):
    '''
    This function plots the difference between individual reads of an IMA image file in a 
    panel plot up to 4x4 in size (i.e. SCI[16-15], SCI[15-14], SCI[14-13], etc.). 
    
    Input: 
    
    - cube: 1024x1024xNSAMP datacube of the IR image in ascending time order
    - integ_time: NSAMP length array of integration times associated with the 
            datacube in ascending time order
    - md,ld,rd: The median difference in signal between each read, for the full frame, left side, 
            and right side of the image. 
    - ms, ls, rs: The median signal of the full frame, left side, and right side of each read. 
    - diff_method: The difference method used: either cumulative or instantaneous
    
    Returns:
    -fig: figure object, panel plot with subplots showing the difference between subsequent ima reads. 
            -Above each panel, we print the mean difference $\mu$ in the count rate over the entire image. 
            - Below each panel, we list the IMSET difference, along with the time interval between the two 
            IMSETs.
            - The statistics in orange (on the left and right side of each panel) give the mean rate and 
            standard deviation of each side of the image, respectively. The value in green 'delta' is the 
            difference between the left and right side of the image. 
            - The value in white "Ratio" gives the ratio of the mean difference in orange 
            for the left versus the right side. 
    '''
    
    
    xlabel_list=["SCI[16-15]","SCI[15-14]","SCI[14-13]","SCI[13-12]","SCI[12-11]",
                 "SCI[11-10]","SCI[10-9]","SCI[9-8]","SCI[8-7]","SCI[[7-6]]","SCI[6-5]",
                "SCI[5-4]","SCI[4-3]","SCI[3-2]","SCI[2-1]"]
    
    fig, axarr = plt.subplots(4, 4)
    fig.set_size_inches(40, 40)
    fig.set_dpi(40)
    itime = integ_time[0:-1] - integ_time[1:]

    siglvl = (0.5,0.5)
    
    inst_diff=((cube[:,:,1:]*(integ_time[1:]-integ_time[0]))-\
             (cube[:,:,0:-1]*(integ_time[0:-1]-integ_time[0])))/(integ_time[1:]-integ_time[0:-1])
 
    
    for i, ax in enumerate(axarr.reshape(-1)):
        if (i < cube.shape[-1]-2):
            i=i+1
            text = ax.text(50, 500, f'{ld[i]:.3f}\n±\n{ls[i]:.3f}', color='Orange', fontsize=30)
            text.set_path_effects([path_effects.Stroke(linewidth=15, foreground='black'),
                   path_effects.Normal()])
            text = ax.text(700, 500, f'{rd[i]:.3f}\n±\n{rs[i]:.3f}', color='Orange', fontsize=30)
            text.set_path_effects([path_effects.Stroke(linewidth=15, foreground='black'),
                   path_effects.Normal()])
            text = ax.text(200, 900, f'Ratio = {ld[i]/rd[i]:.2f}', color='White', fontsize=30)
            text.set_path_effects([path_effects.Stroke(linewidth=15, foreground='black'),
                   path_effects.Normal()])
            text = ax.text(300, 300, f'$\Delta = ${ld[i]-rd[i]:.2f}', color='#32CD32', fontsize=30)
            text.set_path_effects([path_effects.Stroke(linewidth=15, foreground='black'),
                   path_effects.Normal()])
            
            if diff_method == "cumulative":

                diff = cube[:,:,i]-cube[:,:,i+1]
                im = ax.imshow(np.abs(diff), cmap='Greys_r', origin='lower', vmin=rd[i]-siglvl[0]*rd[i], 
                           vmax=ld[i]+siglvl[1]*ld[i])
                
            elif diff_method == "instantaneous":
                diff=inst_diff
                vmin,vmax=zscale(diff[:,:,i])
                im = ax.imshow(diff[:,:,i], cmap='Greys_r', origin='lower', vmin=vmin, 
                           vmax=vmax)
                
            cbar=plt.colorbar(im, ax=ax)
            cbar.ax.tick_params(labelsize=20)
            ax.set_title(f'$\mu = ${np.nanmedian(cube[:,:,i]-cube[:,:,i+1]):.2f}±{ms[i]:.2f} e-/s', fontsize=30)
            
            ax.set_yticklabels([])
            ax.set_xticklabels([])
            ax.set_xlabel(f'{xlabel_list[i]}, $\Delta t = ${np.abs(itime[i]):.2f} sec', fontsize=30)
            

        else:

            ax.set_axis_off()
    
    return fig
    










