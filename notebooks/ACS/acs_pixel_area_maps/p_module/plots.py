from astropy.io import fits

import plotly
import plotly.graph_objs as go
import numpy as np


def drizzle_rms_plot(pixfrac, rms_med):

    data = go.Scatter(x=pixfrac, y=rms_med, name='Data', mode='markers', marker=dict(size=10))

    layout = go.Layout(yaxis=dict(title='Drizzle pixfrac', showline=True, ticks='inside', mirror=True),
                       xaxis=dict(title='RMS/Median', showline=True, ticks='inside', mirror=True),
                       shapes=[dict(type='line', x0=0, x1=1.1, y0=0.2, y1=0.2, line=dict(color='rgb(255, 40, 0)'))],
                       title='Drizzle pixfrac Optimization',
                       autosize=False,
                       height=600, width=900)

    fig = go.Figure(data=[data], layout=layout)

    return fig


def star_2d(img, y, x, size=50, low=10, high=150, spacing=20):

    with fits.open(img) as hdu:
        img_data = hdu[0].data[y-size: y+size, x-size: x+size]

    data = go.Contour(z=img_data,
                      y=np.arange(y-size, y+size+1),
                      x=np.arange(x-size, x+size+1),
                      autocontour=False,
                      colorscale='Jet',
                      contours=dict(start=low, end=high, size=spacing))

    layout = go.Layout(autosize=False,
                       height=600, width=600)

    fig = go.Figure(data=[data], layout=layout)

    return fig