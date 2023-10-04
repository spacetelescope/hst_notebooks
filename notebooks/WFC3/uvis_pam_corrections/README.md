This notebook shows how to perform pixel area map (PAM) corrections on FLT or FLC observations by walking you through the steps of applying this correction. Finally, the notebook presents a comprehensive function that will take science data and output the PAM corrected data. 

By the end of this tutorial you will: 
- Locate and download example images in each subarray size (512x512, 1024x1024, and 2048x2048)
- Learn where to find (and how to retrieve) the primary header, the science header, and the science data from the FLT (or FLC) file.
- Learn how to use the header information to find the pixel coordinates of the four corners of the science image.
- Apply PAM (cut to fit the science image) to the FLT or FLC data. 
