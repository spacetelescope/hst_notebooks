import ipywidgets


def side2(server, img1, img2, width=500):

    v1 = server.get_viewer('v1')
    v2 = server.get_viewer('v2')

    v1.load(img1)
    v2.load(img2)

    box = ipywidgets.HBox()
    h1 = ipywidgets.HTML()
    h2 = ipywidgets.HTML()

    h1.value = v1.embed(height=650, width=width)._repr_html_()
    h2.value = v2.embed(height=650, width=width)._repr_html_()

    box.children = [h1, h2]

    return box


def side3(server, img1, img2, img3, width=300, xcen=None, ycen=None, zoom_x=5, zoom_y=5,
          offset=25, cutlevel=[0, 200]):

    v1 = server.get_viewer('v1')
    v2 = server.get_viewer('v2')
    v3 = server.get_viewer('v3')

    v1.load(img1)
    v2.load(img2)
    v3.load(img3)

    objs = [v1, v2, v3]

    for i, obj in enumerate(objs):
        if xcen is not None:
            if ycen is not None:
                obj.set_pan(xcen[i]+offset, ycen[i])

        obj.scale_to(zoom_x, zoom_y)

        obj.cut_levels(cutlevel[0], cutlevel[1])

        canvas = obj.add_canvas()
        Circle = canvas.get_draw_class('circle')
        canvas.add(Circle(xcen[i], ycen[i], radius=20, color='cyan'))

    box = ipywidgets.HBox()
    h1 = ipywidgets.HTML()
    h2 = ipywidgets.HTML()
    h3 = ipywidgets.HTML()

    h1.value = v1.embed(height=650, width=width)._repr_html_()
    h2.value = v2.embed(height=650, width=width)._repr_html_()
    h3.value = v3.embed(height=650, width=width)._repr_html_()

    box.children = [h1, h2, h3]

    return box