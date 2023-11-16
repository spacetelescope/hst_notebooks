This notebook shows how to use the WFC3/IR persistence model to flag pixels affected by persistence in the calibrated (FLT) science images. When the images are sufficiently dithered to step over the observed persistence artifacts, AstroDrizzle may be used to exclude those flagged pixels when combining the FLT frames. 

By the end of this tutorial, you will:

- Download images and persistence products from MAST
- Flag affected pixels in the data quality arrays of the FLT images
- Redrizzle the FLT images to produce a 'clean' DRZ combined product

Dependencies: 

Install the necessary packages using the requirements.txt:

    pip install -r requirements.txt

If necessary, also install `jupyter notebook`:

    pip install notebook

