 
c----------------------------------------------------------------------------
c
c hst1pass.F  (c) 2022 copyright Jay Anderson
c
c This is a FORTRAN routine written by Jay Anderson.  Its main design
c is to measure HST images with HST-designed PSFs. It is called "one pass"
c for a reason.  It doesn't do any simultaneous fitting of stars.  It
c assumes that the stars are largely isolated from one another.  The few
c stars that aren't isolated, simply aren't measured very well, and these
c stars can be rejected later in the analysis.  I realize that this strategy
c does not work for all projects, but there are a great many projects that
c can get good results this way.
c
c This is release version 1.0  2022.07.05
c
c----------------------------------------------------------------------------
c 2023.11.07: Added some flexibility for the sky annulus to use;
c             normally hst1pass uses an "optimized" annulus, finding how close
c             it can place the sky annulus to the star without the subtraction
c             of the star contributing large errors to the sky measurement.
c             But it is possible to just have the routine use a fixed sky
c             annuls, say, between SKI=5 and SKO=8.  It will subtract the
c             star using an estimate of the star's flux and the PSF model,
c             then it will find an interatively sigma-clipped mean of the
c             PSF-halo subtracted residuals in that annulus.
c
c             The following parameters have been added:
c
c             "SKYFIX=6 8", where 6 is the inner sky annuls and 8 is the
c             outer sky annulus; SKI and SKO must be integers.
c
c             You can also output column "E", which will give the effective
c             radius of the sky; this works for the default optimized sky or
c             for the specified sky; with the specification it may not be
c             exactly the same for all stars, since different pixels can get
c             sigma clipped away and the effective radius concerns the
c             specific pixels that are used.
c----------------------------------------------------------------------------
c 2023.11.03: A few minor fixes pointed out to me by Fred Dauphin on the
c             WFC3 team
c             * The chip number ("k" output parameter) was mis-mapped for
c               WFC3/UV and ACS/WFC.  It was always correctly documented in the
c               HST1PASS ISR documentation, but now it is correct in the code:
c               k=1 corresponds to the top chip (0001:4096,2049:4096)
c                   in "raw" abutted-chip coordinates
c               k=2 corresponds to the bottom chip (0001:4096,0001:2048)
c                   in "raw" abutted-chip coordinates
c             * the UVIS1-C512B-SUB subarray was previously mis-mapped into
c               the bottom chip (UVIS2), but it should have been mapped into
c               the top chip (UVIS1) (3584:4096,3587:4096); fixed
c----------------------------------------------------------------------------
c 2023.10.12: Apparently there was a limit of 80 characters for image filnames.
c             I have gone though the code and extended this to 200 characters.
c             It should work now.
c----------------------------------------------------------------------------
c 2023.08.07: In previous versions, the output subtracted image (ie, SHOW_SUB~)
c             was generated from the image that hst1pass uses to search through
c             the image. This image (which can be output by SHOW_USE+) has some
c             flags thrown into the pixel image to help the finding of saturated
c             stars and prevent the finding of stars in the vicinity of image
c             artifacts.  In response to the same user input below, I fixed the
c             routine to subtract the "found" stars from the original image, not
c             the modified image.  It makes for a nicer and easier-to-compare
c             subtraction image.
c----------------------------------------------------------------------------
c 2023.07.27: responding to a user request to run on WFC3/IR subarrays
c             (previously, it did ACS/WFC and WFC3/UVIS subarrays, but not IR)
c             seems to work well, both in terms of reading in images
c             and in terms of outputting images in a "shell"  (ie, SHOW_SUB~)
c----------------------------------------------------------------------------
c 2023.06.29: fixed a bug that wasn't populating the "z" output
c             added "f" output (frac of light in each star's central pixel)
c             added "F" output (frac of light in centered star's central pixel)
c             added "P" output (2x2 flux estimate used in finding process)
c----------------------------------------------------------------------------
c 2023.04.18: Implemented a few changes in reponse to help-desk comments/questions
c             1) PIXFIT:  a new command-line parameter; the default fitting
c                         aperture is a 5x5 square centered on the star's
c                         brightest pixel. it is now possible to have the
c                         routine fit something other than these 5x5 pixels;
c                         it can fit the central 4x4, 3x3, even 2x2.
c             2) Implemented output for some WFC3/UVIS subarrays for the
c                purposes of AS planting and masks and such.  Before, it was
c                able to output only full-frame images in shells, but now it
c                can do several subarrays.
c----------------------------------------------------------------------------
c 2022.11.25: fixed a bug that prevented subtracted images from
c             being put into a shell; implmented several subarray
c             formats to be written out in shells.
c----------------------------------------------------------------------------
c 2022.11.21: expanded the spatially variable PSF format to allow up to
c             20x20 PSFs; not really needed for HST, but could be useful
c             for JWST (eventually)
c----------------------------------------------------------------------------
c 2022.07.11: fixed a small bug that was preventing saturated stars from being
c             found (removed hardcoding of HIFLAG)
c----------------------------------------------------------------------------
 
 
 
#define _PI_    3.141592653589793238462643d0
 
 
c------------------------------------------------------------------------
c
#define _LINUX_  .true.      /* IS THE MACHINE BIG/LITTLE ENDIEN?       */
#define _NITPRT_       9     /* NUM OF ITERATIONS TO GET PRTPSF         */
#define _NPRTMX_       5     /* MAX NUMBER OF PERT ZONES                */
#define _FIELDs_      50     /* NUMBER OF OUTPUT FIELDS TO CHOOSE FROM  */
#define _NIMMXP_     400     /* MAX NUMBER OF IMAGES (FOR PERT)         */
#define _NIMMAX_   99999     /* MAX NUMBER OF IMAGES                    */
#define _NLMAX_    19999     /* MAX NUMBER OF STARS FOR PSF PERTURBN    */
#define _NSTMAX_ 1999999     /* MAX NUMBER OF STARS IN AN IMAGE         */
#define _ARTMAX_   99999     /* MAX NUMBER OF ART STARS TO INSERT       */
#define _LSTMAX_   99999     /* MAX NUMBER OF LIST STARS TO FIND/MEAS   */
#define _SKIPPX_ .false.
#define _GMAX_         1     /* MAX NUMBER OF GAIA STARS IN FIELD       */
c
c------------------------------------------------------------------------
 
 
 
      program hst1pass
      implicit none
 
      character*200 PROGNAME
 
      character*200 PSFFILE_000
      character*200 PSFFILE_INP
      character*200 PSFFILE_LIB
      character*200 PSFPERT_INP
      character*200 PSFFILE_PRT
      character*200 PSFFILE_USE
      character*200 FILENAME
      character*200 STRING200
      character*200 FILENAME_N(_NIMMAX_)
      integer       ARGNUMBR_N(_NIMMAX_)
      character*200 WCSMODE
 
      character*200 ARTFILE_INP
      character*200 LSTFILE_INP
 
      character*200 GDCFILE_000
      character*200 GDCFILE_INP
      character*200 GDCFILE_LIB
      character*200 GDCFILE_USE
 
      character SHOW_USE
      character SHOW_ART
      character SHOW_FND
      character SHOW_REF
      character SHOW_SUB
      character SHOW_MSK
 
      character*200 STRING, TEMP
 
      integer  i,  j
      integer iu
 
      integer HMIN
      real    PMAX
      real    FMIN
 
      integer iargc, NARG, NARGs
      integer LNC
 
      integer       ISIMG_NARG(999)
      character*200 STRNG_NARG(999)
 
      logical DOAPPHOT
      real    RAP
      integer SKI,SKO
 
      logical DOSATD
      logical DOSTARDB
      logical DOMODHDR
 
      integer VERBOSE
 
      integer HIFLAG
      common / HIFLAG_ / HIFLAG
      data HIFLAG / 0 /              ! this ensures that it MUST get set somewhere explicitly!
 
      integer LOFLAG
      common / LOFLAG_ / LOFLAG
      data LOFLAG / -0250 /
 
c----------------------------------
c
c here are the 9x9 fiducial PSFs
c
      integer NIM, NIMs, NIMa, NIMb
      real    QMAX
      real    CMIN, CMAX
 
      integer KSEL
 
      integer      NPERTs
      real         FOCUS_LEVELi
 
      real pertimg(501,1501)  ! can do up to 150 images...
 
      integer H, HHo, HHs
      character*249 HH(999)   ! max 999 header pages!
 
      integer       NLIST, NLISTs
      character*80  OUTLIST_NL(9)  ! the suffix of the output file
      integer       NITEMSO_NL(9)  ! the number of elements to output
 
      integer       NREGs
      character*80  OUTLIST_NR(9)  ! the suffix of the output file
      integer       NITEMSO_NR(9)  ! the number of elements to output
 
      integer IMIN, IMAX
      integer JMIN, JMAX
 
c
c----------------------------------------------------------------
c
      integer       N
      integer       Ns
      real*8        u_n(_NSTMAX_),  v_n(_NSTMAX_), mm_n(_NSTMAX_)
      real*8        x_n(_NSTMAX_),  y_n(_NSTMAX_),  m_n(_NSTMAX_)
      real*8       xx_n(_NSTMAX_), yy_n(_NSTMAX_)
      real*8       uu_n(_NSTMAX_), vv_n(_NSTMAX_)
      integer       k_n(_NSTMAX_)
      integer       h_n(_NSTMAX_)
      real*8        w_n(_NSTMAX_), ww_n(_NSTMAX_)
      real*8        r_n(_NSTMAX_),  d_n(_NSTMAX_)
      real*8       rr_n(_NSTMAX_), dd_n(_NSTMAX_)
      integer       i_n(_NSTMAX_),  j_n(_NSTMAX_)
      real          p_n(_NSTMAX_), pp_n(_NSTMAX_)
      real          f_n(_NSTMAX_), ff_n(_NSTMAX_)
      real          q_n(_NSTMAX_),  c_n(_NSTMAX_)
      real          s_n(_NSTMAX_), ss_n(_NSTMAX_)
      real*8        t_n(_NSTMAX_)
      real          z_n(_NSTMAX_)
      real         cc_n(_NSTMAX_)
      real          o_n(_NSTMAX_)
      real         oo_n(_NSTMAX_)
      real        sap_n(_NSTMAX_)
      real        map_n(_NSTMAX_,9)
      integer       n_n(_NSTMAX_)
      real          e_n(_NSTMAX_)
      real         ee_n(_NSTMAX_)
 
 
      real*8 BDRY_XR(4,4), BDRY_YR(4,4)
      real*8 BDRY_XC(4,4), BDRY_YC(4,4)
      real*8 BDRY_UG(4,4), BDRY_VG(4,4)
      real*8 BDRY_RA(4,4), BDRY_DE(4,4)
      real*8 BDRY_UU(4,4), BDRY_VV(4,4)
 
 
c
c----------------------------------------------------------------
c
 
      character*200 DIRECT
      character*200 PREFIX
      character*7   SUFFIX
 
 
c     character*200 FILEOUT
 
      character*05  FILT_N(_NIMMAX_)
      real          EXPT_N(_NIMMAX_)
      real          RDAT_N(_NIMMAX_)
      integer       PROP_N(_NIMMAX_)
      integer       INST_N(_NIMMAX_)
 
      real*8  CRPIX1_USE, CRPIX2_USE
      real*8  CRVAL1_USE, CRVAL2_USE
      real*8   CD1_1_USE,  CD1_2_USE
      real*8   CD2_1_USE,  CD2_2_USE
 
 
      integer     As
      real*8      xinp_a(_ARTMAX_)
      real*8      yinp_a(_ARTMAX_)
      real*8      minp_a(_ARTMAX_)
      character*3 ASTYPE
 
      integer     Bs
      real*8      xinp_b(_LSTMAX_)
      real*8      yinp_b(_LSTMAX_)
      real*8      minp_b(_LSTMAX_)
      character*3 BSTYPE
c
c----------------------------------------------------------------
c
      character*200 GAIADB
 
      real*8 r1, r2
      real*8 d1, d2
      real*8 rDAT
      integer G, Gs
      character*140 STR140_G(_GMAX_)
      real*8        CRPIX1_NEW, CRPIX2_NEW
      real*8        CRVAL1_NEW, CRVAL2_NEW
      real*8         CD1_1_NEW,  CD1_2_NEW
      real*8         CD2_1_NEW,  CD2_2_NEW
 
      real*8     x_g(_GMAX_),    y_g(_GMAX_)
      real*8                     m_g(_GMAX_)
      real*8    ex_g(_GMAX_),   ey_g(_GMAX_)
      real*8                    em_g(_GMAX_)
      real*8     r_g(_GMAX_),    d_g(_GMAX_)
      real*8    er_g(_GMAX_),   ed_g(_GMAX_)
      real*8    mg_g(_GMAX_),  emg_g(_GMAX_)
      real*8    mb_g(_GMAX_),  emb_g(_GMAX_)
      real*8    mr_g(_GMAX_),  emr_g(_GMAX_)
      real*8   pmr_g(_GMAX_), epmr_g(_GMAX_)
      real*8   pmd_g(_GMAX_), epmd_g(_GMAX_)
      real*8   par_g(_GMAX_), epar_g(_GMAX_)
      integer*8 id_g(_GMAX_)
 
      real*8   AG_G, BG_G, CG_G, DG_G
      real*8   GA_G, GB_G, GC_G, GD_G
      real*8   x1o_G, y1o_G
      real*8   x2o_G, y2o_G
      character*08 FIELD8
      character*70 STREAM70
 
      character*3 PIXFIT
      data PIXFIT /'5x5'/
 
c
c----------------------------------------------------------------
c
 
      GAIADB = 'SKIP'
      SKI = -1
      SKO = -1
 
      do i = 001, 0501
      do j = 001, 1501
         pertimg(i,j) = 0.
         enddo
         enddo
 
      NARGs = iargc()
 
c
c if these aren't changed from their defaults; the routine will complain
c
      HMIN = -99
      FMIN = 999999
 
c-----------------------------------------------------------------------
 
      GDCFILE_000 = 'NONE'
      GDCFILE_INP = 'NONE'
      GDCFILE_LIB = 'NONE'
      GDCFILE_USE = 'NONE'
 
      PSFFILE_000 = 'NONE'
      PSFFILE_INP = 'NONE'
      PSFFILE_LIB = 'NONE'
      PSFFILE_USE = 'NONE'
      PSFPERT_INP = 'NONE'
      PSFFILE_PRT = 'NONE'
 
      DOSATD     = .true.
      DOSTARDB   = .false.
      DOMODHDR   = .false.
 
      NPERTs       = 0
      FOCUS_LEVELi = 0.
 
      VERBOSE = 1
      As = 0
      Bs = 0
 
      KSEL       =  0
      QMAX       =  0.50
      CMIN       = -1.00
      CMAX       =  0.25
 
      SHOW_USE   = '-'
      SHOW_FND   = '-'
      SHOW_REF   = '-'
      SHOW_MSK   = '-'
      SHOW_ART   = '-'
      SHOW_SUB   = '-'
 
      WCSMODE = 'AUTO'
      NLISTs   = 0
      NREGs    = 0
 
      IMIN = -9999
      IMAX =  9999
      JMIN = -9999
      JMAX =  9999
 
      DOAPPHOT =  .false.
 
      PMAX = 99999999
 
      if (iargc().eq.0) then
         write(*,'(100(a63,/))')
     .'                                                               ',
     .'This routine takes several args (in any order, 5 required)     ',
     .'                                                               ',
     .'         (defaults are shown first for some quantities,        ',
     .'                  examples for others)                         ',
     .'                                                               ',
     .'hst1pass                                                       ',
     .'                                                               ',
     .'  REQUIRED ---                                                 ',
     .'    HMIN=5                            (integer; min isolation) ',
     .'    FMIN=1000                         (real; min centrl flx)   ',
     .'    "PSF=APPHOT 2.9 6 9"/             (psf spec)               ',
     .'         STDPSF.fits/STDPBF.fits/                              ',
     .'    IMG1.fits                         (command-line list)      ',
     .'                                      (at least one image)     ',
     .'                                                               ',
     .'  OPTIONAL ---                                                 ',
     .'    OUT=XYMpqUVrdxym                  (columns to output;      ',
     .'                                       must have at least one; ',
     .'                                       can have multiple files)',
     .'   "IMG2.fits[I1:I2,J1:J2]"           (limited regions in img) ',
     .'    FITSs=file.list                   (file list of inp images)',
     .'    GDC=NONE/STDGDC.fits              (distortn spec; def=NONE)',
     .'    REG=xy,XY,uv,rd                   (region file to output)  ',
     .'    DOSATD+/-                         (meas satd stars? def+)  ',
     .'    PMAX=9999999                      (max pixel value)        ',
     .'    QMAX= 0.5                         (PSF quality of fit; def)',
     .'    CMIN=-1.0                         (centrl-pix excess; def) ',
     .'    CMAX=+0.1                         (centrl-pix excess; def) ',
     .'    PERT=0                            (perturb PSF? default=0) ',
     .'    FOCUS=-1(find),0(mid),rF          (find/specify focus?)    ',
     .'    KSEL=0/1/2                        (restrict chip? def=no)  ',
     .'    IMIN=500 IMAX=510                 (restrict col range?)    ',
     .'    JMIN=922 JMAX=932                 (restrict row range?)    ',
     .'    ART_UVW=FILE.UVW (xym,XYM,UVW)    (add art stars)          ',
     .'    SHOW_USE-/+                       (output image searched)  ',
     .'    SHOW_FND-/+                       (output finding image)   ',
     .'    SHOW_REF-/+                       (output ref-frame img)   ',
     .'    SHOW_SUB-/+/~                     (make subtracted image;  ',
     .'                                       ~ means put into shell) ',
     .'    SHOW_ART-/+/~                     (art-star image)         ',
     .'    PIXFIT=5x5                        (allows specification of ',
     .'                                       the fitting aperture    ',
     .'                                       options: 2x2, 3x3, 4x4, ',
     .'                                                5x5=default)   ',
     .'                                                               ',
     .'OUT= options for columns to output ; can output multiple files ',
     .'     for the same finding list of stars                        ',
     .'                                                               ',
     .'   ASTROMETRY ---                                              ',
     .'     x,y = raw chip-dependent x y coord (no CTE corr)          ',
     .'     X,Y = raw chip-dependent x y coord (after CTE corr)       ',
     .'     u,v = distortion-corrected x, y coord                     ',
     .'     U,V = distortion-corrected X, Y coord (in WCS frame)      ',
     .'     r,d = RA, Dec (in degrees, from UV)                       ',
     .'     R,D = RA, Dec (GAIA DR3 corrected,future)                 ',
     .'                                                               ',
     .'   PHOTOMETRY ---                                              ',
     .'     m   = instrumental mag (no CTE corr)                      ',
     .'     M   = instrumental mag (after CTE corr)                   ',
     .'     w   = instrumental mag, M + pix area correction)          ',
     .'     W   = instrumental mag, w + exptime normalization         ',
     .'     z   = flux (no CTE corr; can be negative for forced)      ',
     .'     Z   = flux (CTE corr; can be negative for forced)         ',
     .'                                                               ',
     .'   VARIIOUS ---                                                ',
     .'     s   = sky value                                           ',
     .'     S   = sky value (with postflash/dark electrons included)  ',
     .'                                                               ',
     .'     h   = isolation index (used for HMIN finding assessment)  ',
     .'     f   = crude 2x2 flux (used for FMIN finding assessment)   ',
     .'     q   = quality of fit (0 = perfect)                        ',
     .'     c   = chisq of fit                                        ',
     .'     p   = brightest pixel value                               ',
     .'     P   = 4x4 box flux (used for finding)                     ',
     .'     f   = central PSF value (frac of light in central pixel)  ',
     .'     F   = central PSF value (for a centered star)             ',
     .'     e   = generic error estimate in mags/pixels               ',
     .'     i   = local-max column location                           ',
     .'     j   = local-max row location                              ',
     .'     k   = chip number (wfpc2: 1-4, wfc3uv/acswfc 1-2)         ',
     .'     I   = row (zero-padded with I0000, for easy grepping)     ',
     .'     J   = column (zero-padded with J0000, for easy grepping)  ',
     .'     K   = chip number (with K1, for easy grepping)            ',
     .'     n   = number of saturated pixels associated with star     ',
     .'     N   = star number N00007                                  ',
     .'     c   = chisq for star                                      ',
     .'     C   = cen-xs for star                                     ',
     .'     o   = fraction of flux in aperture from possible neighbors',
     .'     O   = super conservative value for O                      ',
     .'     t   = time of observation (fractional years, 2017.348)    ',
     .'     E   = effective radius of sky annulus                     ',
     .'                                                               ',
     .'   PBAP photometry --- PSF-Based Aperture Photometry           ',
     .'     1   = 1x1-pixel PBAP photometry                           ',
     .'     2   = 2x2-pixel PBAP photometry                           ',
     .'     3   = 3x3-pixel PBAP photometry                           ',
     .'     4   = 4x4-pixel PBAP photometry                           ',
     .'     5   = 5x5-pixel PBAP photometry                           ',
     .'     6   = 3.0-pixel-radius PBAP photometry                    ',
     .'     7   = 3.5-pixel-radius PBAP photometry                    ',
     .'     8   = 4.0-pixel-radius PBAP photometry                    ',
     .'     9   = 4.5-pixel-radius PBAP photometry                    ',
     .'     0   = sky from PBAP photometry                            ',
     .'                                                               '
         stop
         endif
 
      do H = 1, 999
         write(HH(H),'(''#'',248('' ''))')
         enddo
 
      call getarg(0,PROGNAME)
 
      write(HH(1),'(''#'')')
      write(HH(2),'(''#--------------------------------------------'')')
      write(HH(3),'(''# ARGUMENTS '')')
      write(HH(4),'(''#--------------------------------------------'')')
      write(HH(5),'(''#  ARG'',i4.4,'': '',a80)') 0,PROGNAME
      HHo = 5
 
c
c----------------------------------------------------------------
c
 
 
 
      write(*,'(''            '')')
      write(*,'(''------------------------------------------------'')')
      write(*,'(''            '')')
      write(*,'(''ARG'',i4.4,'': '',a80)') 0,PROGNAME(1:80)
      NIMs = 0
      NIMa = -1
      NIMb = -1
      do NARG = 1, NARGs
         ISIMG_NARG(NARG) = 0
         call getarg(NARG,STRING200)
         HHo = HHo + 1
         write(HH(HHo),'(''#  ARG'',i4.4,'': '',a120)')
     .         NARG,STRING200(1:120)
         STRNG_NARG(NARG) = FILENAME
         write(*,'(''ARG'',i4.4,'': '',80a)') NARG,STRING200(1:80)
         if (STRING200(1:5).eq.'HMIN=') then
            do i = 6, 80
               if (STRING200(i:i).eq.'.') then
                   print*,'  '
                   print*,' HMIN must be an integer. '
                   print*,'  '
                   stop
                   endif
               enddo
            read(STRING200(6:80),*) HMIN
            goto 555
            endif
         if (STRING200(1:5).eq.'FMIN=') then
            read(STRING200(6:80),*) FMIN
            goto 555
            endif
         if (STRING200(1:4).eq.'PSF=') then
            PSFFILE_000 = STRING200(5:200)
            PSFFILE_INP = STRING200(5:200)
            goto 555
            endif
         if (STRING200(1:5).eq.'PMAX=') then
            read(STRING200(6:80),*) PMAX
            goto 555
            endif
         if (STRING200(1:4).eq.'GDC=') then
            GDCFILE_000 = STRING200(5:200)
            goto 555
            endif
         if (STRING200(1:7).eq.'LOFLAG=') then
            read(STRING200(8:20),*) LOFLAG
            goto 555
            endif
         if (STRING200(1:7).eq.'HIFLAG=') then
            read(STRING200(8:20),*) HIFLAG
            goto 555
            endif
         if (STRING200(1:6).eq.'HIAUTO') then
            HIFLAG = 0
            goto 555
            endif
         if (STRING200(1:4).eq.'WCS=') then
            WCSMODE = STRING200(5:200)
            goto 555
            endif
         if (STRING200(1:8).eq.'VERBOSE=') then
            read(STRING200(9:15),*) VERBOSE
            goto 555
            endif
         if (STRING200(1:2).eq.'V=') then
            read(STRING200(3:10),*) VERBOSE
            goto 555
            endif
         if (STRING200(1:7).eq.'DOSATD+') then
            DOSATD = .true.
            goto 555
            endif
         if (STRING200(1:7).eq.'DOSATD-') then
            DOSATD = .false.
            goto 555
            endif
         if (STRING200(1:8).eq.'SHOW_USE') then
            SHOW_USE = STRING200(9:9)
            if (SHOW_USE.ne.'-'.and.SHOW_USE.ne.'+')
     .          stop 'SHOW_USE can only be - or + '
            goto 555
            endif
         if (STRING200(1:8).eq.'SHOW_FND') then
            SHOW_FND = STRING200(9:9)
            if (SHOW_FND.ne.'-'.and.SHOW_FND.ne.'+')
     .          stop 'SHOW_FND can only be - or + '
            goto 555
            endif
         if (STRING200(1:8).eq.'SHOW_REF') then
            SHOW_REF = STRING200(9:9)
            if (SHOW_REF.ne.'-'.and.SHOW_REF.ne.'+')
     .          stop 'SHOW_REF can only be - or + '
            goto 555
            endif
         if (STRING200(1:8).eq.'SHOW_SUB') then
            SHOW_SUB = STRING200(9:9)
            if (SHOW_SUB.ne.'-'.and.SHOW_SUB.ne.'+'
     .                         .and.SHOW_SUB.ne.'~')
     .          stop 'SHOW_SUB can only be - or + or ~'
            goto 555
            endif
         if (STRING200(1:8).eq.'SHOW_MSK') then
            SHOW_MSK = STRING200(9:9)
            if (SHOW_MSK.ne.'-'.and.SHOW_MSK.ne.'+'
     .                         .and.SHOW_MSK.ne.'~')
     .          stop 'SHOW_MSK can only be - or + or ~'
            goto 555
            endif
         if (STRING200(1:8).eq.'SHOW_ART') then
            SHOW_ART = STRING200(9:9)
            if (SHOW_ART.ne.'-'.and.SHOW_ART.ne.'+'
     .                         .and.SHOW_ART.ne.'~')
     .          stop 'SHOW_ART can only be - or + or ~'
            goto 555
            endif
         if (STRING200(1:6).eq.'FOCUS=') then
            read(STRING200(7:80),*) FOCUS_LEVELi
            if (VERBOSE.ge.2)
     .          print*,' ---> FOCUS_LEVELi: ',FOCUS_LEVELi
            goto 555
            endif
         if (STRING200(1:4).eq.'PERT') then
            if (STRING200(5:5).ne.'=') then
               print*,' '
               print*,'The 5th character of PERT arg must now be "=" '
               print*,' '
               stop
               endif
            if (STRING200(6:6).lt.'0'.or.STRING200(6:6).gt.'9') then
               print*,' '
               print*,'PERT=n MUST HAVE AN n VALUE BETWEEN 0 AND 9'
               print*,'ARG: ',STRING200(1:20)
               print*,' '
               stop
               endif
            read(STRING200(6:6),*) NPERTs
            if (VERBOSE.ge.2) print*,'         ---> NPERTs: ',NPERTs
            if (NPERTs.gt._NPRTMX_) then
                print*,'hst1pass --- '
                print*,'         --->  NPERTs : ',NPERTs
                print*,'         ---> _NPRTMX_: ',_NPRTMX_
                print*,' '
                print*,'         ---> routine not compiled '
                print*,'              to allow so many perts '
                print*,' '
                stop
                endif
            PSFPERT_INP = 'AUTO'
            goto 555
            endif
         if (STRING200(1:5).eq.'KSEL=') then
            read(STRING200(6:20),*) KSEL
            goto 555
            endif
         if (STRING200(1:5).eq.'QMAX=') then
            read(STRING200(6:20),*) QMAX
            goto 555
            endif
         if (STRING200(1:5).eq.'CMIN=') then
            read(STRING200(6:20),*) CMIN
            goto 555
            endif
         if (STRING200(1:5).eq.'CMAX=') then
            read(STRING200(6:20),*) CMAX
            goto 555
            endif
         if (STRING200(1:5).eq.'UMIN='.or.
     .       STRING200(1:5).eq.'UMAX='.or.
     .       STRING200(1:5).eq.'VMIN='.or.
     .       STRING200(1:5).eq.'VMAX=') then
             stop 'UMIN specification not working yet.'
             endif
         if (STRING200(1:5).eq.'IMIN=') then
            read(STRING200(6:80),*) IMIN
            goto 555
            endif
         if (STRING200(1:5).eq.'IMAX=') then
            read(STRING200(6:80),*) IMAX
            goto 555
            endif
         if (STRING200(1:5).eq.'JMIN=') then
            read(STRING200(6:80),*) JMIN
            goto 555
            endif
         if (STRING200(1:5).eq.'JMAX=') then
            read(STRING200(6:80),*) JMAX
            goto 555
            endif
         if (STRING200(1:7).eq.'PIXFIT=') then
            PIXFIT = STRING200(8:10)
            if (PIXFIT.ne.'2x2'.and.
     .          PIXFIT.ne.'3x3'.and.
     .          PIXFIT.ne.'4x4'.and.
     .          PIXFIT.ne.'5x5') then
                print*,' '
                print*,'STRING200(1:40): ',STRING200(1:40)
                print*,' '
                print*,'         PIXFIT: ',PIXFIT
                print*,' '
                print*,'--> only legal values are: 2x2, 3x3, 4x4, 5x5'
                print*,' '
                stop
                endif
            goto 555
            endif
         if (STRING200(1:7).eq.'GAIADB=') then
            stop 'CODE NOT QUITE READY FOR GAIADB YET'
            GAIADB = STRING200(8:200)
            goto 555
            endif
         if (STRING200(1:7).eq.'MODHDR+') then
            stop 'CODE NOT QUITE READY FOR GAIADB YET'
            DOMODHDR = .true.
            goto 555
            endif
         if (STRING200(1:7).eq.'SKYFIX=') then
            read(STRING200(8:80),*) SKI, SKO
            print*,'SKYFIX --- SKI: ',SKI,'  SKO: ',SKO
            goto 555
            endif
         if (STRING200(1:4).eq.'OUT=') then
            NLISTs = NLISTs + 1
            if (NLISTs.gt.9) stop 'NLISTs.gt.9'
            OUTLIST_NL(NLISTs) = STRING200(5:80)
            NITEMSO_NL(NLISTs) = 0
            do i = 1, 80
               if (OUTLIST_NL(NLISTs)(i:i).ne.' ') NITEMSO_NL(NLISTs)=i
               enddo
            if (VERBOSE.ge.2) then
                print*,'        --->    NLISTs = ',NLISTs
                print*,'        --->    NITEMs = ',NITEMSO_NL(NLISTs)
                print*,'        --->   OUTLIST = ',
     .                       OUTLIST_NL(NLISTs)(1:NITEMSO_NL(NLISTs))
                endif
            goto 555
            endif
         if (STRING200(1:4).eq.'REG=') then
            NREGs = NREGs + 1
            if (NREGs.gt.9) stop 'NREGs.gt.9'
            OUTLIST_NR(NREGs) = STRING200(5:80)
            NITEMSO_NR(NREGs) = 0
            do i = 1, 80
               if (OUTLIST_NR(NREGs)(i:i).ne.' ') NITEMSO_NR(NREGs)= i
               enddo
            if (VERBOSE.ge.2) then
                print*,'        --->     NREGs = ',NREGs
                print*,'        --->    NITEMs = ',NITEMSO_NR(NREGs)
                print*,'        --->   OUTLIST = ',
     .                     OUTLIST_NR(NREGs)(1:NITEMSO_NR(NREGs))
                endif
            if (NITEMSO_NR(NREGs).ne.2)
     .          stop 'can only have two positions in reg file'
            if (OUTLIST_NR(NREGs)(1:2).ne.'xy'.and.
     .          OUTLIST_NR(NREGs)(1:2).ne.'XY'.and.
     .          OUTLIST_NR(NREGs)(1:2).ne.'uv'.and.
     .          OUTLIST_NR(NREGs)(1:2).ne.'rd')
     .              stop 'CAN ONLY MAKE REGION OF xy XY uv rd'
            goto 555
            endif
         if (STRING200(1:4).eq.'ART_') then
            ASTYPE = '   '
            if (STRING200(5:7).eq.'xym') ASTYPE = 'xym'
            if (STRING200(5:7).eq.'XYM') ASTYPE = 'XYM'
            if (STRING200(5:7).eq.'UVW') ASTYPE = 'UVW'
            if (STRING200(8:8).ne.'='.or.
     .          ASTYPE.eq.'   ') then
                print*,' '
                print*,'---> INPUT: ',STRING200(1:20)
                print*,' '
                print*,'---> ASTYPE must be xy, XYM, or UVM'
                print*,'     use ARTxym=... for raw local insertion    '
                print*,'         ARTXYM=... for corr local insertion   '
                print*,'      or ARTUVW=... for for ref-frame insertion'
                print*,' '
                stop
                endif
            ARTFILE_INP = STRING200(9:80)
            open(19,file=ARTFILE_INP,status='old')
            As = 0
    1       read(19,'(a80)',end=2) STRING
            if (STRING(1:1).eq.'#') goto 1
            As = As + 1
            if (As.gt._ARTMAX_) then
                print*,' '
                print*,'The routine has not been compiled to allow for'
                print*,'more than _ARTMAX_ = ',_ARTMAX_
                print*,'artifical stars.  You should recompile with '
                print*,'a larger number in the "#define" declarations'
                print*,'at the top of the program.  Since most users '
                print*,'don''t throw in a lot of ASs, the default for'
                print*,'this is moderately low.'
                print*,' '
                endif
            read(STRING,*) xinp_a(As), yinp_a(As), minp_a(As)
            goto 1
    2       continue
            write(*,3) As, ASTYPE
    3       format(9x,'As = ',i5,' ART  STARS READ IN AS ',a3)
            close(19)
            goto 555
            endif
 
c-----------------------------------------------------------------
c
c not ready for drive/forced yet...
c
c        if (STRING200(1:6).eq.'DRIVE_'.or.
c    .       STRING200(1:6).eq.'FORCE_') then
c           if (Bs.ne.0) then
c               print*,' '
c               print*,'Strange... you have already specified a '
c               print*,'FORCED/DRIVE list.  You cannot have two!'
c               print*,' '
c               print*,'   Bs = ',Bs
c               print*,' '
c               stop
c              endif
c           BSTYPE = '   '
c           if (STRING200(7:8).eq.'xy') BSTYPE = 'xy '
c           if (STRING200(7:8).eq.'XY') BSTYPE = 'XY '
c           if (STRING200(7:8).eq.'UV') BSTYPE = 'UV '
c           if (STRING200(1:1).eq.'D') BSTYPE(3:3) = '+'
c           if (STRING200(1:1).eq.'F') BSTYPE(3:3) = '-'
c           if (STRING200(9:9).ne.'='.or.
c    .          BSTYPE.eq.'   ') then
c               print*,' '
c               print*,'---> INPUT: ',STRING200(1:20)
c               print*,' '
c               print*,'---> BSTYPE must be either XY or UV'
c               print*,'     use DRIVE_XY=... for local insertion '
c               print*,'      or DRIVE_UV=... for ref-frame insertion'
c               print*,' '
c               stop
c               endif
c           LSTFILE_INP = STRING200(10:80)
c           open(19,file=LSTFILE_INP,status='old')
c           Bs = 0
c  71       read(19,'(a80)',end=72) STRING
c           if (STRING(1:1).eq.'#') goto 71
c           Bs = Bs + 1
c           if (Bs.gt._LSTMAX_) then
c               print*,' '
c               print*,'The routine has not been compiled to allow for'
c               print*,'more than _LSTMAX_ = ',_LSTMAX_
c               print*,'artifical stars.  You should recompile with '
c               print*,'a larger number in the "#define" declarations'
c               print*,'at the top of the program.  Since most users '
c               print*,'don''t throw in a lot of ASs, the default for'
c               print*,'this is moderately low.'
c               print*,' '
c               endif
c           read(STRING,*) xinp_b(Bs), yinp_b(Bs), minp_b(Bs)
c           goto 71
c  72       continue
c           write(*,73) Bs, BSTYPE
c  73       format(9x,'Bs = ',i5,' LIST STARS READ IN AS ',a3)
c           close(19)
c           goto 555
c           endif
 
         if (STRING200(1:5).eq.'NIMa=') then
            read(STRING200(6:10),*) NIMa
            print*,'---> NIMa: ',NIMa
            goto 555
            endif
         if (STRING200(1:5).eq.'NIMb=') then
            read(STRING200(6:10),*) NIMb
            print*,'---> NIMb: ',NIMb
            goto 555
            endif
         if (STRING200(1:6).eq.'FITSs=') then
            print*,'OPEN: ',STRING200(7:80)
            open(19,file=STRING200(7:80),status='old')
  888       read(19,'(a80)',end=889) STRING
            if (STRING(1:1).eq.'#') goto 888
            iu = 0
            do i = 1, 75
               if (STRING(i:i+4).eq.'.fits') iu = i+4
               enddo
            if (iu.eq.0) stop 'FITSs FILENAME IN LIST MUST HAVE .fits'
            NIMs = NIMs + 1
            NIMa = 1
            NIMb = NIMs
            if (NIMs.gt._NIMMAX_) then
                print*,'     NIMs : ',NIMs
                print*,'  _NIMMAX_: ',_NIMMAX_
                stop 'NIMs.gt._NIMMAX_'
                endif
c           FILENAME_N(NIMs) = STRING(1:iu+4)
            TEMP = STRING
            FILENAME_N(NIMs) = STRING(1:LNC(TEMP,200))
            ARGNUMBR_N(NIMs) = NARG
            if (VERBOSE.ge.2) then
                write(*,'(''         ---> NIM'',i4.4,1x,80a)')
     .                                    NIMs,FILENAME_N(NIMs)
                endif
            goto 888
  889       continue
            print*,'---> NIMs: ',NIMs
            goto 555
            endif
 
c
c at this point, we should only have FITS images left...
c
         iu = 0
         do i = 1, 190
            if (STRING200(i:i+4).eq.'.fits') iu = i
            enddo
         if (iu.eq.0) stop 'UNRECOGNIZED PARAMETER'
 
         NIMs = NIMs + 1
         HHo  = HHo  - 1
         if (NIMs.gt._NIMMAX_) stop 'NIMs.gt._NIMMAX_'
         FILENAME_N(NIMs) = STRING200(1:LNC(FILENAME,200))
         ARGNUMBR_N(NIMs) = NARG
         if (VERBOSE.ge.2) then
             write(*,'(''         ---> NIM'',i4.4,1x,80a)')
     .                                 NIMs,FILENAME_N(NIMs)
             endif
  555    continue
         enddo
 
 
      if (NIMa.eq.-1) NIMa = 1
      if (NIMb.eq.-1) NIMb = NIMs
 
c----------------------------------------------------------
c
c everything has been read in now from the command line,
c check to make sure that we have enough information to do
c what needs to be done...
c
      if (HMIN.eq.-99) then
         print*,' '
         print*,'--> COMMAND LINE MUST INCLUDE HMIN'
         print*,' '
         stop
         endif
      if (FMIN.eq.-99) then
         print*,' '
         print*,'--> COMMAND LINE MUST INCLUDE FMIN'
         print*,' '
         stop
         endif
      if (PSFFILE_INP(1:4).eq.'NONE') then
         print*,' '
         print*,'--> COMMAND LINE MUST INCLUDE AT LEAST ONE    '
         print*,'    PSF SPECIFICATION, EFEN IF IT IS JUST FOR '
         print*,'    APERTURE PHOTOMTERY.                      '
         print*,' '
         stop
         endif
      if (NIMs.eq.0) then
         print*,' '
         print*,'--> COMMAND LINE MUST INCLUDE AT LEAST ONE IMAGE'
         print*,' '
         stop
         endif
c     if (NLISTs.eq.0) then
c        print*,' '
c        print*,'--> COMMAND LINE MUST INCLUDE AT LEAST OUTPUT FILE'
c        print*,' '
c        stop
c        endif
 
      write(*,'(''            '')')
      write(*,'(''----------------------------------------------'')')
      write(*,'(''            '')')
      write(*,'(''OUTPUT FROM PROGRAM hst1pass: '',a80)') PROGNAME
      write(*,'(''            '')')
      write(*,'(''     HMIN: '',i8  )')  HMIN
      write(*,'(''     FMIN: '',f10.1)') FMIN
      write(*,'('' PSFFILEI: '',4x,a80)')   PSFFILE_INP
      write(*,'('' GDCFILEI: '',4x,a80)')   GDCFILE_INP
      write(*,'('' DOAPPHOT: '',7x,l1)')    DOAPPHOT
      write(*,'(''   DOSATD: '',7x,l01)') DOSATD
      write(*,'(''   NPERTs: '',7x,i1)')  NPERTs
      write(*,'(''  WCSMODE: '',a80)') WCSMODE
      write(*,'(''     PMAX: '',f10.1)') PMAX
      write(*,'(''     KSEL: '',i2  )') KSEL
      write(*,'(''     QMAX: '',f6.3)') QMAX
      write(*,'(''     CMIN: '',f6.3)') CMIN
      write(*,'(''     CMAX: '',f6.3)') CMAX
      write(*,'(''     NIMs: '',i8.3)') NIMs
 
      do NIM = NIMa, NIMb
         write(*,'(20x,''NIM'',i5.5,1x,a60)') NIM,FILENAME_N(NIM)(1:60)
         enddo
      write(*,'(''           '')')
 
      if (PSFFILE_INP(1:6).eq.'APPHOT') then
          write(*,'(''#PSFFILEI: '',80a)') PSFFILE_INP
          read(PSFFILE_INP(7:80),*) RAP,SKI,SKO
          write(*,'(''# ---> APERTURE RAP: '',f8.4)') RAP
          write(*,'(''# --->    INNER SKI: '',i3)') SKI
          write(*,'(''# --->    OUTER SKO: '',i3)') SKO
          DOAPPHOT = .true.
          endif
 
      print*,'        '
      print*,'  NIMa: ',NIMa
      print*,'  NIMb: ',NIMb
      print*,'  NIMs: ',NIMs
      print*,'        '
 
      HHo = HHo + 1
      do NIM = NIMa, NIMb
         write(HH(HHo),'(''#  ARG'',i4.4,'': '',a80)')
     .         ARGNUMBR_N(NIM),
     .         FILENAME_N(NIM)
         GDCFILE_INP = GDCFILE_000
         PSFFILE_INP = PSFFILE_000
 
         write(*,'(''----------------------------------------------'')')
         write(*,'(''            '')')
         write(*,'(''NIM'',i3.3,'' CALL sub_hst2ym on image '',a80)')
     .               NIM, FILENAME_N(NIM)(1:80)
 
         call sub_hst2xym(HH,HHo,HHs,
     .                    HMIN,FMIN,PMAX,
     .                    HIFLAG,WCSMODE,DOSATD,
     .                    SHOW_USE,SHOW_FND,SHOW_ART,
     .                    SHOW_REF,SHOW_SUB,SHOW_MSK,
     .                    NPERTs,
     .                    KSEL,QMAX,CMIN,CMAX,
     .                    IMIN,IMAX,JMIN,JMAX,
     .                    FILENAME_N(NIM),NIM,NIMs,
     .                    PSFFILE_INP,
     .                    GDCFILE_INP,
     .                    Ns,  u_n,  v_n, mm_n,
     .                         x_n,  y_n,  m_n,  k_n,
     .                        xx_n, yy_n,
     .                        uu_n, vv_n,
     .                         h_n,
     .                         w_n,  ww_n,
     .                         r_n,   d_n,
     .                         i_n,   j_n,
     .                         p_n,  pp_n,                   ! J: added 2023/06/29 pp = 2x2 flux used for finding
     .                         f_n,  ff_n,                   ! J: added 2023/06/29 central value of PSF (obs/pure)
     .                         q_n,   c_n,  s_n, ss_n, t_n,
     .                         z_n,  cc_n,  o_n, oo_n,
     .                       sap_n, map_n, n_n,   e_n, ee_n,
     .                    BDRY_XR, BDRY_YR,
     .                    BDRY_XC, BDRY_YC,
     .                    BDRY_UG, BDRY_VG,
     .                    BDRY_RA, BDRY_DE,
     .                    BDRY_UU, BDRY_VV,
     .                    FILT_N(NIM),EXPT_N(NIM),
     .                    RDAT_N(NIM),PROP_N(NIM),INST_N(NIM),
     .                    CRPIX1_USE, CRPIX2_USE,
     .                    CRVAL1_USE, CRVAL2_USE,
     .                    CD1_1_USE,  CD1_2_USE,
     .                    CD2_1_USE,  CD2_2_USE,
     .                    VERBOSE,
     .                    As,xinp_a,yinp_a,minp_a,ASTYPE,
     .                    Bs,xinp_b,yinp_b,       BSTYPE,
     .                    FOCUS_LEVELi,PIXFIT,SKI,SKO)
 
         write(*,'('' '')')
         write(*,'(''NIM'',i3.3,'' BACK FROM sub_hst2ym '')')
         write(*,'('' '')')
         print*,'---> rDAT_N: ',rDAT_N(NIM),NIM
 
 
         do N = 1, Ns
            rr_n(N) = r_n(N)
            dd_n(N) = d_n(N)
            enddo
 
 
 
         call dirstrip(FILENAME_N(NIM),DIRECT,PREFIX,SUFFIX)
 
         print*,'NIM: ',NIM,' / ',NIMs
 
         if (.true.) then
            print*,'--->    NLISTs = ',NLISTs,PREFIX
            do NLIST = 1, NLISTs
               print*,'  --->    NLIST = ',NLIST,
     .                         ' NITEMs = ',NITEMSO_NL(NLIST),
     .                           OUTLIST_NL(NLIST)(1:NITEMSO_NL(NLIST))
               enddo
            endif
 
         if (NLISTs.ne.0)
     .   call output_lists(NLISTs,NITEMSO_NL,OUTLIST_NL,
     .                     PREFIX,
     .                     HH, HHs,
     .                     Ns,  u_n,  v_n,  w_n,
     .                          x_n,  y_n,  m_n,  k_n,
     .                         xx_n, yy_n, mm_n,
     .                         uu_n, vv_n, ww_n,
     .                          h_n,
     .                          r_n,  d_n, rr_n, dd_n,
     .                          i_n,  j_n,  p_n, pp_n, f_n, ff_n,
     .                          q_n,  c_n,  s_n, ss_n, t_n,
     .                          z_n,  cc_n,  o_n, oo_n,
     .                        sap_n, map_n, n_n,   e_n, ee_n)
 
 
         if (NREGs.ne.0)
     .   call output_regs(NREGs,OUTLIST_NR,
     .                    PREFIX,
     .                    Ns,  u_n,  v_n,
     .                         x_n,  y_n,  m_n,
     .                        xx_n, yy_n,
     .                         r_n,  d_n,
     .                         q_n)
 
 
 
         enddo ! NIM = 1, NIMs
 
 
      STOP
 
      end
 
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/GEN/oiojor.f"
c****                                         
c*********************************************
                                              
 
c--------------------------------------------------
c
c This routine orders the pixels by successive distance
c from each other.  If you step through the array
c like this:
c
c
c     do m = 1, 99
c        i = ixc + oi(m)
c        j = iyc + oj(m)
c        ...
c        enddo
c
c
c Then, the pixels (i,j) will be in order of increasing
c distance from the central pixel (ixc,iyc).
c
c This can be useful for many applications.
c
c
      integer function oi(m)
      implicit none
      integer m
 
      integer qm, fm
      integer im
      integer mm
      integer oim, ojm
      integer nm
 
      integer oil(91)
      data oil / 0,1,1,2,2,1,2,3,3,1,3,2,4,4,
     .               1,3,4,2,3,5,4,5,1,5,2,4,
     .           3,5,6,1,6,6,2,5,4,3,6,7,5,1,
     .               7,6,4,2,7,7,3,6,5,8,1,4,
     .           8,7,8,2,6,8,3,7,5,4,8,9,1,9,
     .                 9,7,2,6,5,8,3,9,4,9,7,
     .           9,5,8,6,8,7,8,9,6,9,7,9,8,9 /
 
      integer ojl(91)
      data ojl / 0,0,1,0,1,2,2,0,1,3,2,3,0,1,4,
     .                   3,2,4,4,0,3,1,5,2,5,4,
     .           5,3,0,6,1,2,6,4,5,6,3,0,5,7,1,
     .                   4,6,7,2,3,7,5,6,0,8,7,
     .           1,4,2,8,6,3,8,5,7,8,4,0,9,1,2,
     .                     6,9,7,8,5,9,3,9,4,7,
     .             5,9,6,8,7,8,8,6,9,7,9,8,9,9 /
 
      oi = 0
 
      qm = m+2 - 4*int((m+2)/4)
      fm = int((m+6)/4)
      if (fm.le.91) then
         if (qm.eq.0) oi =  oil(fm)
         if (qm.eq.1) oi = -oil(fm)
         if (qm.eq.2) oi = -ojl(fm)
         if (qm.eq.3) oi =  ojl(fm)
         return
         endif
 
      im = int((sqrt(1.*m-1)-1)/2)
      mm = (2*im+1)**2+1
      nm =  (m-mm)/4
      oim = nm-im
      ojm = im
 
      oi = oim
 
      if (qm.eq.0) oi =  oim
      if (qm.eq.1) oi = -oim
      if (qm.eq.2) oi = -ojm
      if (qm.eq.3) oi =  ojm
 
      return
      end
 
c----------------------------------------------------------------
c
c the y-analog to oi(m)
c
      integer function oj(m)
      implicit none
      integer m
 
      integer qm, fm
      integer im, mm, nm, oim, ojm
 
      integer oil(91)
      data oil / 0,1,1,2,2,1,2,3,3,1,3,2,4,4,
     .               1,3,4,2,3,5,4,5,1,5,2,4,
     .           3,5,6,1,6,6,2,5,4,3,6,7,5,1,
     .               7,6,4,2,7,7,3,6,5,8,1,4,
     .           8,7,8,2,6,8,3,7,5,4,8,9,1,9,
     .                 9,7,2,6,5,8,3,9,4,9,7,
     .           9,5,8,6,8,7,8,9,6,9,7,9,8,9 /
 
      integer ojl(91)
      data ojl / 0,0,1,0,1,2,2,0,1,3,2,3,0,1,4,
     .                   3,2,4,4,0,3,1,5,2,5,4,
     .           5,3,0,6,1,2,6,4,5,6,3,0,5,7,1,
     .                   4,6,7,2,3,7,5,6,0,8,7,
     .           1,4,2,8,6,3,8,5,7,8,4,0,9,1,2,
     .                     6,9,7,8,5,9,3,9,4,7,
     .             5,9,6,8,7,8,8,6,9,7,9,8,9,9 /
 
      oj = 0
 
      qm = m+2 - 4*int((m+2)/4)
      fm = int((m+6)/4)
      if (fm.le.91) then
         if (qm.eq.0) oj =  ojl(fm)
         if (qm.eq.1) oj = -ojl(fm)
         if (qm.eq.2) oj =  oil(fm)
         if (qm.eq.3) oj = -oil(fm)
         return
         endif
 
      im = int((sqrt(1.*m-1)-1)/2)
      mm = (2*im+1)**2+1
      nm =  (m-mm)/4
      oim = nm-im
      ojm = im
 
      oj = ojm
      if (qm.eq.0) oj =  ojm
      if (qm.eq.1) oj = -ojm
      if (qm.eq.2) oj =  oim
      if (qm.eq.3) oj = -oim
 
      return
      end
 
c----------------------------------------------------------------
c
c should be obvious
c
      real function orm(m)
      implicit none
      integer m
 
      integer oi, oj
 
      orm = sqrt(1.*(oi(m)**2 + oj(m)**2))
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/IMAGE/fnd_hloc_NAXIS.f"
c****                                         
c*********************************************
                                              
 
 
c---------------------------------------------
c
c given a pixel (i,j), how far out in radius do
c you have to go to find a brighter pixel?
c
      integer function fnd_hloc_NAXIS(i,j,pix,NAXIS1,NAXIS2)
      implicit none
 
      integer i, j
      integer NAXIS1
      integer NAXIS2
      real pix(NAXIS1,NAXIS2)
 
      integer m, h
      integer ooi, ooj
      integer  oi,  oj
      real    pcen
      integer ii, jj
      real    dij
 
      pcen = pix(i,j)
      do m = 2, 2510
         ooi = oi(m)
         ooj = oj(m)
         dij = ooi**2+ooj**2
         h = int(sqrt(dij)+0.5)
         ii = i + ooi
         jj = j + ooj
         if (ii.lt. 0001 ) goto 1
         if (jj.lt. 0001 ) goto 1
         if (ii.gt.NAXIS1) goto 1
         if (jj.gt.NAXIS2) goto 1
         if (pix(ii,jj).gt.pix(i,j)) goto 1
         enddo
 
 1    continue
      fnd_hloc_NAXIS = h
      return
      end
 
 
 
 
c#include "/user/jayander/FORTRAN/ROUTINES/IMAGE/fnd_ploc_NAXIS.f"
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/SORT/rbubble.f"
c****                                         
c*********************************************
                                              
 
c--------------------------------------
c
c bubble-sorts a real*4 list into ascending order
c
      subroutine rbubble(r1,NTOT)
      implicit none
      real r1(*)
      real temp
      integer NTOT
      integer n
      logical change
 777  continue
      change = .false.
      do n = 1, NTOT-1
         if (r1(n).gt.r1(n+1)) then
            temp = r1(n)
            r1(n) = r1(n+1)
            r1(n+1) = temp
            change = .true.
            endif
         enddo
      if (change) goto 777
      end
 
c--------------------------------------
c
c bubble-sorts a real*8 list into ascending order
c
      subroutine dbubble(r1,NTOT)
      implicit none
      real*8 r1(*)
      integer NTOT
      integer n
      real*8 temp
      logical change
 777  continue
      change = .false.
      do n = 1, NTOT-1
         if (r1(n).gt.r1(n+1)) then
            temp = r1(n)
            r1(n) = r1(n+1)
            r1(n+1) = temp
            change = .true.
            endif
         enddo
      if (change) goto 777
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/STAT/histmode_NAXIS.f"
c****                                         
c*********************************************
                                              
 
c-------------------------------------------------
c
c this routine uses a histogram-method to find the mode
c of a large number of pixels, those within (i1:i2,j1:j2)
c of the array pixarr (only use pixels with values that
c are between -10 and 4990)
c
      real function histmode_NAXIS(pixarr,NAXIS1,NAXIS2)
      implicit none
 
      integer NAXIS1, NAXIS2
      real    pixarr(NAXIS1,NAXIS2)
 
      integer i, j, h
      integer mhi, mlo
      real hist_summ
 
      integer hist(5000)
      integer hcum(5000)
      integer NTOT
      real root
 
      real    pcum(101)
      integer ipc
      integer imin
      real    dmin
      real    ptot
 
      integer HIFLAG
      common /HIFLAG_/HIFLAG
      integer LOFLAG
      common /LOFLAG_/LOFLAG
 
 
      if (HIFLAG.lt.  0) stop 'histmode HIFLAG.lt.000'
      if (LOFLAG.gt.100) stop 'histmode LOFLAG.lt.100'
 
      do h = 1,5000
         hist(h) = 0
         hcum(h) = 0
         enddo
 
      NTOT = 0
      PTOT = 0
      do i = 00001+5, NAXIS1-5
      do j = 00001+5, NAXIS2-5
        !if (pixarr(i,j).ge.HIFLAG) goto 2
        !if (pixarr(i,j).le.LOFLAG) goto 2
         h = int(pixarr(i,j)+10.5)
         if (h.lt.   1) goto 2
         if (h.gt.5000) goto 2
         hist(h) = hist(h) + 1
         NTOT = NTOT + 1
         PTOT = PTOT + pixarr(i,j)
 2       continue
         enddo
         enddo
 
      if (NTOT.eq.0) then
          histmode_NAXIS = 0.00
          return
          endif
 
      hcum(1) = hist(1)/2
      do h = 2, 5000
         hcum(h) = hcum(h-1) + (hist(h)+hist(h-1))/2
         ipc = int(100.*hcum(h)/NTOT + 1.5)
         do i = ipc, 101
            pcum(i) = h
            enddo
         enddo
      do ipc = 1, 101  ! goes from 0% to 100%
         pcum(ipc) = root(NTOT*(ipc-1)/100.,hcum,5000)
         enddo
 
      dmin = pcum(40+1)-pcum(1)
      imin = 1
      do i = 2, 101-40
         if (pcum(40+i)-pcum(i).lt.dmin) then
            dmin = pcum(40+i)-pcum(i)
            imin = i
            endif
         enddo
 
      mhi = int(pcum(40+imin)+3)
      mlo = int(pcum(imin)   -3)
c     print*,'--->  MLO ',mlo
c     print*,'--->  MHI ',mhi
 
      histmode_NAXIS = 0.
      hist_summ = 0.
      do h = mlo, mhi
         hist_summ = hist_summ + hist(h)
         histmode_NAXIS = histmode_NAXIS + hist(h)*(h-10)
         enddo
 
      histmode_NAXIS = histmode_NAXIS / hist_summ
c     print*,'---> HISTMODE: ',histmode_NAXIS
 
      if (hist_summ.le.0) histmode_NAXIS = PTOT / NTOT
c     print*,'--->    MLO-10: ',MLO-10
c     print*,'--->    MHI-10: ',MHI-10
 
      NTOT = 0
      PTOT = 0
      do i = 00001+5, NAXIS1-5
      do j = 00001+5, NAXIS2-5
         if (pixarr(i,j).ge.(mlo-10).and.
     .       pixarr(i,j).le.(mhi-10)) then
             NTOT = NTOT + 1
             PTOT = PTOT + pixarr(i,j)
             endif
         enddo
         enddo
      histmode_NAXIS = PTOT/NTOT
 
c     print*,'         PTOT: ',PTOT
c     print*,'         NTOT: ',NTOT
c     print*,'---> HISTMODE: ',histmode_NAXIS
 
      return
 
      end
 
 
c--------------------------------------
c
c return the value of n where list(n) = v ;
c list must be monotonic increasing
c
      real function root(v,list,NTOT)
      implicit none
      real    v
      integer list(5000)
      integer NTOT
      integer nl
 
      do nl = 1, NTOT-2
         if (v.lt.list(nl+1)) goto 3
         enddo
 3    continue
 
      root = nl
      if (list(nl).ne.list(nl+1))
     .    root = nl + 1.*(v-list(nl))/(list(nl+1)-list(nl))
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/STRING/dirstrip.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------
c
c takes a filename and splits it off into directory,
c prefix, and suffix
c
      subroutine dirstrip(FULL,DIRECT,PREFIX,SUFFIX)
      implicit none
 
      character*(*) FULL
      character*(*) DIRECT
      character*(*) PREFIX
      character*7  SUFFIX
 
      integer i
 
      integer ndir
      integer ndot
      integer nbrk
      integer nend
 
      ndir = 0
      ndot = 0
      nbrk = 0
      nend = 0
      do i = 1, 180
         if (FULL(i:i).eq.'/')  ndir = i
         if (FULL(i:i).eq.'.')  ndot = i
         if (FULL(i:i).eq.'[')  nbrk = i
         if (FULL(i:i).eq.' '.and.
     .       nend.eq.0)  then
             nend = i-1
             goto 3333
             endif
         enddo
 3333 continue
 
      if (ndot.eq.0) then
         print*,' '
         print*,'DIRSTRIP: '
         print*,' '
         print*,'THE IMAGE MUST HAVE A DOT IN ITS NAME.'
         print*,'NAME: ',FULL
         print*,' '
         stop
         endif
 
 
      DIRECT = FULL(1:ndir)
      PREFIX = FULL(ndir+1:ndot-1)
      SUFFIX = FULL(ndot+1:nend  )
 
c     print*,'FULL: ',FULL
c     print*,' ndir: ',ndir,DIRECT
c     print*,' ndot: ',ndot,DIRECT
c     print*,' nend: ',nend,SUFFIX
 
      return
      end
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/GEN/rclip.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------
c
c Returns rval if rval is between rlo and rhi,
c otherwise it returns the closer endpoint.  It
c also make sure rval is not a NaN
c
      real function rclip(rval,rlo,rhi)
      implicit none
 
      real rval
      real rlo
      real rhi
 
      rclip = rval
      if (rclip.gt.rhi) rclip = rhi
      if (rclip.lt.rlo) rclip = rlo
      if (.not.(rclip.lt.rhi).and.
     .    .not.(rclip.gt.rlo)) rclip = rhi
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/GEN/dclip.f"
c****                                         
c*********************************************
                                              
 
c-------------------------------------------
c
c same as rclip, but for double precision numbers
c
      real*8 function dclip(dval,dlo,dhi)
      implicit none
 
      real*8 dval
      real*8 dlo
      real*8 dhi
 
      dclip = dval
      if (dclip.gt.dhi) dclip = dhi
      if (dclip.lt.dlo) dclip = dlo
      if (.not.(dclip.lt.dhi).and.
     .    .not.(dclip.gt.dlo)) dclip = dhi
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/PHOT/mbar_sky_NAXIS.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------
c
c This routine will find an iteratively clipped mean sky
c value from an annulis about a point.  The point is (ixc,iyc).
c It will take the pixels between r=inr and r=ior and will
c analyze them for a robust average.
c
      real function mbar_sky_NAXIS(ixc,iyc,inr,ior,
     .                             pixarr,NAXIS1,NAXIS2)
      implicit none
 
      integer ixc, iyc
      integer inr, ior
      integer NAXIS1
      integer NAXIS2
      real pixarr(NAXIS1,NAXIS2)
 
      integer i  , j
      integer ixh, iyh
      real    rij
      integer nuse
 
      real sklist(9 999 999)
      integer nsk
      real bar, sig
 
c     integer HIFLAG
c     common / HIFLAG_ / HIFLAG
c
c     integer LOFLAG
c     common / LOFLAG_ / LOFLAG
c
c      if (LOFLAG.ge.-1.or.
c     .    HIFLAG.le. 1) then
c          print*,'---> LOFLAG: ',LOFLAG
c          print*,'---> HIFLAG: ',HIFLAG
c          stop 'mbar_sky_NAXIS HIFLAG common block undef'
c          endif
 
 
      nsk = 0
      do i = -ior+1, ior-1
      do j = -ior+1, ior-1
         rij = i**2+j**2
         if (rij.ge.ior**2) goto 333
         if (rij.lt.inr**2) goto 333
         ixh = ixc + i
         iyh = iyc + j
         if (ixh.lt. 0001 ) goto 333
         if (iyh.lt. 0001 ) goto 333
         if (ixh.gt.NAXIS1) goto 333
         if (iyh.gt.NAXIS2) goto 333
c        if (pixarr(ixh,iyh).le.LOFLAG) goto 333
c        if (pixarr(ixh,iyh).ge.HIFLAG) goto 333
         if (.not.(pixarr(ixh,iyh).ge.  -100)) goto 333
         if (.not.(pixarr(ixh,iyh).le.  1000)) goto 333
         nsk = nsk + 1
         if (nsk.gt.9 999 999) goto 333
         sklist(nsk) = pixarr(ixh,iyh)
 333     continue
         enddo
         enddo
 
      call rbarsigs(sklist,nsk,bar,sig,nuse,2.50)
 
      mbar_sky_NAXIS = bar
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/WFC.09x10/mbar_skyopt_NAXIS.f"
c****                                         
c*********************************************
                                              
 
 
c-----------------------------------------
c
c this will measure the sky *and* remove the
c star profile before it does; this way it
c can measure a sky near a star which still
c may be very slightly affected by the star
c itself
c
      real function mbar_skyopt_NAXIS(xc,yc,pix,psfloc,
     .                                SRI, SRO,
     .                                NAXIS1,NAXIS2,
     .                                rsk1, rsk2, rske)
      implicit none
 
      real*8  xc, yc
      integer NAXIS1
      integer NAXIS2
      real    pix(NAXIS1,NAXIS2)
      real    psfloc(101,101)
      integer SRI, SRO
      integer rsk1, rsk2
      real    rske
 
      real bar1, sig1
 
      integer ixc, iyc
      integer i, j
      real dx, dy
 
      real FCEN, PCEN
      real ZZZ
      common/zzz/zzz
      real SKY
      real PIXSUM
      real PSFSUM
      integer NNNSUM
      integer n1, n1u
      integer n2
      real sl1(1000)
      real rpsf_phot
      real reff
      common /reff/reff
      integer irmin, irmax
      common /SKYINFO_/irmin, irmax
 
 
      integer HIFLAG
      common / HIFLAG_ / HIFLAG
 
      integer LOFLAG
      common / LOFLAG_ / LOFLAG
 
      ixc = int(xc+0.5)
      iyc = int(yc+0.5)
 
      PCEN = 0.
      FCEN = 0.
      do i = -1, 1
      do j = -1, 1
         dx = SNGL(ixc+i-xc)
         dy = SNGL(iyc+j-yc)
         PCEN = PCEN + rpsf_phot(dx,dy,psfloc)
         FCEN = FCEN + pix(ixc+i,iyc+j)
         enddo
         enddo
 
c      print*,' '
c      print*,' IXC: ',IXC
c      print*,' IYC: ',IYC
c      print*,' '
c      print*,'pCEN: ',pix(ixc,iyc)
c      print*,'FCEN: ',FCEN
c      print*,'PCEN: ',PCEN
c      print*,'ZCEN: ',FCEN/PCEN
c      print*,' '
c      print*,' '
 
      irmin = 2
 5    continue
      irmax = irmin+1
      if (SRI.gt.0) then
          irmin = SRI
          irmax = SRO
          endif
      PIXSUM = 0.
      PSFSUM = 0.
      NNNSUM = 0
      do i = -irmax, irmax
      do j = -irmax, irmax
         dx = SNGL(ixc+i-xc)
         dy = SNGL(iyc+j-yc)
         if (i**2+j**2.ge.(irmin-0.5)**2.and.
     .       i**2+j**2.lt.(irmax+0.5)**2.and.
     .       ixc+i.ge.0001.and.ixc+i.le.NAXIS1.and.
     .       iyc+j.ge.0001.and.iyc+j.le.NAXIS1) then
             PIXSUM = PIXSUM + pix(ixc+i,iyc+j)
             PSFSUM = PSFSUM + rpsf_phot(dx,dy,psfloc)
             NNNSUM = NNNSUM + 1
             endif
         enddo
         enddo
 
      ZZZ = 0.0
 
      SKY = (PIXSUM-ZZZ*PSFSUM)/NNNSUM
      ZZZ = (FCEN-9*SKY)/PCEN
      if (ZZZ.lt.0) ZZZ = 0.
 
      SKY = (PIXSUM-ZZZ*PSFSUM)/NNNSUM
      ZZZ = (FCEN-9*SKY)/PCEN
      if (ZZZ.lt.0) ZZZ = 0.
 
      if (PSFSUM*ZZZ/NNNSUM.gt.0.03*(PIXSUM/NNNSUM+15).and.
     .   irmin.lt.16) then
         irmin = irmin + 1
         if (SRI.le.0) goto 5
         endif
 
 
 
c-------------------------------------------------
c
c ok, now we have the inner radius; where
c the star contribution is less than 10% of the
c sky brightness
c
      irmin = irmin
      irmax = irmin+3
      if (SRI.gt.0) then
          irmin = SRI
          irmax = SRO
          endif
      n1 = 0
      n2 = 0
      reff = 0.
      do i = -irmax-1, irmax+1
      do j = -irmax-1, irmax+1
         dx = SNGL(ixc+i-xc)
         dy = SNGL(iyc+j-yc)
         if (i**2+j**2.ge.(irmin-0.5)**2.and.
     .       i**2+j**2.lt.(irmax+0.5)**2.and.
     .       ixc+i.ge.0001.and.ixc+i.le.NAXIS1.and.
     .       iyc+j.ge.0001.and.iyc+j.le.NAXIS2) then
                if (n1.lt.1000) n1 = n1 + 1
                sl1(n1) = pix(ixc+i,iyc+j)
     .                   - ZZZ*rpsf_phot(dx,dy,psfloc)
                reff = reff + sqrt(dx**2+dy**2)
                endif
         enddo
         enddo
 
      reff = reff/n1
 
      call barsiggg(sl1,n1,bar1,sig1,n1u)
 
      mbar_skyopt_NAXIS = bar1
 
c     write(59,159) xc, yc, ZZZ, irmin, irmax, bar1, sig1, n1, n1u
c 159 format(1x,f8.2,1x,f8.2,1x,f9.1,1x,i2,1x,i2,
c    .       1x,f8.2,1x,f8.2,1x,i4,1x,i4)
 
      rsk1 = irmin
      rsk2 = irmax
      rske = reff
 
      return
      end
 
 
c------------------------------------------------
c
c
      subroutine barsiggg(xlist,NTOT,bar,sig,NUSE)
      implicit none
 
      integer NTOT
      real xlist(NTOT)
      real bar
      real sig
      integer NUSE
 
      integer n
      real*8    bsum, ssum
      integer nsum
      integer NIT
 
 
      bar = 0.e0
      sig = 9e9
      do NIT = 1, 20
         bsum = 0.
         ssum = 0.
         nsum = 0.
         do n = 1, NTOT
            if (abs(xlist(n)-bar).le.1.65*sig) then
               bsum = bsum + xlist(n)
               ssum = ssum + abs(xlist(n)-bar)
               nsum = nsum + 1
               endif
            enddo
         if (nsum.gt.0) bar = SNGL(bsum / nsum )
         if (nsum.gt.1) sig = SNGL(ssum/(nsum-1)*1.1)
         enddo
      NUSE = nsum
      if (nsum.le.1) sig = 0.999
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/PHOT/apphot_NAXIS.f"
c****                                         
c*********************************************
                                              
 
c----------------------------------------
c
c this routine will do simple aperture photometry
c about a pixel (i,j)
c
 
      real function apphot_NAXIS(i,j,rap,ri,ro,pix,sky,NAXIS1,NAXIS2)
      implicit none
 
      integer i, j
      real    rap
      integer ri, ro
      integer  NAXIS1,NAXIS2
      real pix(NAXIS1,NAXIS2)
      real    sky
 
 
      integer ii, jj
      real mbar_sky_NAXIS
      real    ftot, ftoth
      integer L, LL, Ls
      real    pl(1000), puse
      real    rl(1000)
      integer il(1000)
      integer jl(1000)
 
      integer Us
      real    vu(1000), vbar, vsig
      real    abs_rap
 
c------------------------------------------------
c
c special case, saturated flux added up in corral
c
      if (pix(i  ,j  ).gt.0.and.
     .    pix(i-1,j  ).eq.0.and.
     .    pix(i+1,j  ).eq.0.and.
     .    pix(i  ,j+1).eq.0.and.
     .    pix(i  ,j-1).eq.0.and.
     .    pix(i-1,j+1).eq.0.and.
     .    pix(i-1,j-1).eq.0.and.
     .    pix(i+1,j+1).eq.0.and.
     .    pix(i+1,j-1).eq.0) then
          apphot_NAXIS = pix(i,j)
          return
          endif
 
      sky = mbar_sky_NAXIS(i,j,ri,ro,pix,NAXIS1,NAXIS2)
 
      abs_rap = abs(rap)
 
      Ls = 0
      ftot = 0
      do ii = i-int(abs_rap+0.5),i+int(abs_rap+0.5)
      do jj = j-int(abs_rap+0.5),j+int(abs_rap+0.5)
         if (ii.lt. 0001 ) goto 1
         if (jj.lt. 0001 ) goto 1
         if (ii.gt.NAXIS1) goto 1
         if (jj.gt.NAXIS2) goto 1
         if ((ii-i)**2+(jj-j)**2.gt.rap**2) goto 1
         ftot = ftot + pix(ii,jj)-sky
         Ls = Ls + 1
         if (Ls.gt.1000) stop 'Ls.gt.1000 in apphot_NAXIS'
         pl(Ls) = pix(ii,jj)-sky
         rl(Ls) = sqrt(1.*(i-ii)**2+(j-jj)**2)
         il(Ls) = ii
         jl(Ls) = jj
 1       continue
         enddo
         enddo
 
      if (rap.gt.0) then
          apphot_NAXIS = ftot
          return
          endif
 
      ftoth = ftot
      ftot  = 0.
      do L  = 1, Ls
         puse = pl(L)
         if (rl(L).le.2.99) then
c            write(52,218) 1.*il(L), 1.*jl(L), 0.50
             goto 3
             endif
         Us = 0
         do LL = 1, Ls
            if (L.ne.LL) then
               if (abs(rl(L)-rl(LL)).le.0.99) then
                   Us = Us + 1
                   vu(Us) = pl(LL)
                   endif
               endif
            enddo
         call rbarsigs(vu,Us,vbar,vsig,Us,3.0)
         if (abs(pl(L)-vbar).lt.5.0*vsig) then
c            write(52,216) 1.*il(L), 1.*jl(L), 0.35
            else
             puse = vbar
c            write(52,217) 1.*il(L), 1.*jl(L), 0.50
            endif
    3    ftot = ftot + puse
         enddo
 
      apphot_NAXIS = ftot
 
c     write(51,157) ftot, ftoth, i, j
c 157 format(1x,f10.2,1x,f10.2,1x,i4,1x,i4)
      return
      end
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/query_hdr.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------
c
c This routine checks to see if the header of an image
c contains a particular keyword. If it does, it returns
c its value-string in STREAMX.
c
 
      subroutine query_hdr(filename,FIELDX,streamx)
      implicit none
 
      character*200 filename
 
      character*8  field
      character*20 stream
 
      character*8  fieldx
      character*20 streamx
 
      integer  i
      integer ios, k
 
      character*2880 buff
 
      integer nread
      integer NEXTEND
 
c-----------------------------------------------
 
      !print*,'query_hdr...',FILENAME
      !print*,'    fieldx: ',fieldx
      streamx = ' '
 
      close(10)
      open(10,file=FILENAME,status='old',iostat=ios,
     .  err=900,recl=2880,form='UNFORMATTED',
     .  access='DIRECT')
 
      streamx = 'NULL'
      i = 0
      NREAD   = 0
      NEXTEND = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios,err=901) buff
      if (ios.lt.0) goto 900
      do k = 0, 35, 1
         field  = buff(k*80+01:k*80+08)
         stream = buff(k*80+11:k*80+31)
         !print*,i,k,field,stream
         if (field.eq.'NEXTEND ') read(stream,*) NEXTEND
         if (field.eq.fieldx) streamx = stream(1:20)
         if (field.eq.'END     ') goto 101
         continue
         enddo
      goto 100
 101  continue
      NREAD = NREAD + 1
      if (NREAD.le.1.and.NEXTEND.gt.1) goto 100
      close(10)
      !print*,'    streamx: ',streamx
 
      return
 
  900 continue
      print*,' '
      print*,'query_hdr() FILE OPEN ERROR EXIT. '
      print*,' '
      print*,'ONE OF THE IMAGES WAS NOT IN STANDARD'
      print*,'HST FITS FORMAT.'
      print*,' '
      write(*,'(''PROBLEM FILE: '',a80)') FILENAME
      write(*,'(''      FIELDX: '',a08)') FIELDX
      write(*,'(''      IOSTAT: '',i4 )') IOS
      print*,' '
      stop
 
  901 continue
      print*,' '
      print*,'query_hdr() FILE READ ERROR EXIT. '
      print*,' '
      print*,'ONE OF THE IMAGES WAS NOT IN STANDARD'
      print*,'HST FITS FORMAT.'
      print*,' '
      write(*,'(''PROBLEM FILE: '',a80)') FILENAME
      write(*,'(''      FIELDX: '',a08)') FIELDX
      write(*,'(''      IOSTAT: '',i4 )') IOS
      print*,' '
      stop
 
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_i2r.f"
c****                                         
c*********************************************
                                              
 
 
      subroutine readfits_i2r(FILE,pix,NX,NY)
      implicit none
 
      character*(*) FILE
      integer NX, NY
      real*4 pix(NX,NY)
 
      character*70 INFO(10)
      common / fitsinfo / INFO
 
      integer naxes
      integer laxis(3)
 
      character*8  field
      character*20 stream
 
      real*4 pixu
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
      integer ii, jj
      integer n
      integer NXU, NYU
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer*2 ibuff(1440)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
 
      logical DIAG
      data DIAG /.false./
 
 
      character*70 HDR(25)
      common/HDR/HDR
      character*80 FILEU
 
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened'
 
      bscale = 1
      bzero  = 0
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
      do i = 1, 25
         HDR(i) = ' '
         enddo
      HDR(24) = '  1.000 '
 
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buffc
      if (DIAG) print*,'READREC: ',i
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+31)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'EXPTIME ') INFO(01) = stream
         if (field.eq.'FILTNAM1') INFO(02) = stream
         if (field.eq.'FILENAME') INFO(03) = stream
         if (field.eq.'DATE-OBS') INFO(04) = stream
         if (field.eq.'TIME-OBS') INFO(05) = stream
         if (field.eq.'DEC_TARG') INFO(06) = stream
         if (field.eq.'RA_TARG ') INFO(07) = stream
         if (field.eq.'PA_V3   ') INFO(08) = stream
         if (field.eq.'PROPOSID') INFO(09) = stream
         if (field.eq.'CCDGAIN ') INFO(10) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER1 ') HDR(22) = stream
         if (field.eq.'FILTER2 ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
 
         if (field.eq.'END     ') goto 101
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,'----------------------------------------'
         print*,'  NREAD: ',nread
         print*,'NEXTEND: ',nextend
         print*,'  NAXIS: ',naxes
         print*,'  LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,' BITPIX: ',bitpix
         print*,' BSCALE: ',bscale
         print*,'  BZERO: ',bzero
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      if (BITPIX.ne.16) then
         print*,'readfits_i2...: '
         print*,'                '
         print*,'   you called a routine to read in an'
         print*,'   unsigned i2 image, and the image you'
         print*,'   gave it has BITPIX = ',BITPIX
         print*,'   '
         print*,'   FILEU: ',FILEU
         print*,'   '
         stop
         endif
 
      nbper = 2*laxis(1)*laxis(2)
      npt   =   laxis(1)*laxis(2)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (laxis(1).gt.NX.and.laxis(2).gt.NY) then
         print*,' not enough image space! '
         print*,' '
         print*,'  laxis1: ',laxis(1)
         print*,'      NX: ',NX
         print*,' '
         print*,'  laxis2: ',laxis(2)
         print*,'      NY: ',NY
         print*,' '
         stop
         endif
 
      NXU = laxis(1)
      NYU = laxis(2)
 
      if (DIAG) then
         print*,'     NX: ',NX
         print*,'     NY: ',NY
         print*,'  NBPER: ',nbper
         print*,'  NBYT1: ',nbyte1
         print*,'  NBYT2: ',nbyte2
         print*,' IFIRST: ',ifirst
         print*,'     I1: ',i1
         print*,'     I2: ',i2
         print*,'    NPT: ',NPT
         endif
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/2 + 1
         np2 = (nbyteE-nbyte1)/2 + 1
         np2 = min(np2,npt)
         call buff2pix_i2r(buffb,ibuff,0001,1440)
         do n = np1, np2, 1
            jj = n/NXU   + 1
            ii = n-NXU*(jj-1)
            pixu = ibuff(n-np1+1)*bscale+bzero
            pix(ii,jj) = pixu
            enddo
         enddo
 
      if (DIAG) then
         print*,'  NBPER: ',nbper
         print*,'  NBYT1: ',nbyte1
         print*,'  NBYT2: ',nbyte2
         print*,' IFIRST: ',ifirst
         print*,'     I1: ',i1
         print*,'     I2: ',i2
         print*,'    NPT: ',NPT
         endif
 
 
      return
 
 900  continue
      print*,'READFITS_I2 ERROR'
      print*,'   FILEU: ',FILEU
      stop
 
      end
 
 
 
      subroutine buff2pix_i2r(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      integer*2 pix(*)
      integer n1,nt
 
      byte b(2)
      integer*2 ii
      equivalence(ii,b)
 
      integer i, npu, nbu
      logical islinux
 
      do i = 1, 1440
         npu = n1+i-1
         nbu = (i-1)*2
         if (.not.(islinux())) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            endif
         if ((islinux())) then
            b(2) = buff(nbu+1)
            b(1) = buff(nbu+2)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = ii
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_i4r.f"
c****                                         
c*********************************************
                                              
 
c--------------------------------------------------------
c
c This routine reads in images stored in integer*4 format...
c
c to use:
c
c   input parameters:
c
c         FILE     is the filename
c         NX,NY    are the dimensions of the image to be
c                  read in
c
c
c  output parameters:
c
c         pix( , ) is an integer*4 image of dimensions NX,NY
c
c
c
      subroutine readfits_i4r(FILE,pix,NX,NY)
      implicit none
 
      integer NX, NY
      character*80 FILE
      real*4 pix(NX,NY)
 
      character*70 INFO(10)
      common / fitsinfo / INFO
 
      integer naxes
      integer laxis(3)
 
      character*8  field
      character*20 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
      integer ii, jj
      integer n
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer*4 ibuff(720)
 
      integer ifirst, i1, i2
c     integer j
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
      logical LINUX
      data LINUX/.true./
      logical DIAG
      data DIAG /.false./
 
 
      character*70 HDR(25)
      common/HDR/HDR
 
      character*80 FILEU
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
      if (DIAG) then
         print*,'enter readfits...'
         print*,'FILE: ',FILE(1:60)
         endif
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened'
 
      bscale = 1
      bzero  = 0
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
      do i = 1, 23
         HDR(i) = ' '
         enddo
 
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buffc
      if (DIAG) print*,'READREC: ',i
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+31)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'EXPTIME ') INFO(01) = stream
         if (field.eq.'FILTNAM1'.and.stream(1:1).eq.'F')
     .                            INFO(02) = stream
         if (field.eq.'FILTNAM2'.and.stream(1:1).eq.'F')
     .                            INFO(02) = stream
         if (field.eq.'FILTER1 '.and.stream(1:1).eq.'F')
     .                            INFO(02) = stream
         if (field.eq.'FILTER2 '.and.stream(1:1).eq.'F')
     .                            INFO(02) = stream
         if (field.eq.'FILENAME') INFO(03) = stream
         if (field.eq.'DATE-OBS') INFO(04) = stream
         if (field.eq.'TIME-OBS') INFO(05) = stream
         if (field.eq.'DEC_TARG') INFO(06) = stream
         if (field.eq.'RA_TARG ') INFO(07) = stream
         if (field.eq.'PA_V3   ') INFO(08) = stream
         if (field.eq.'PROPOSID') INFO(09) = stream
         if (field.eq.'CCDGAIN ') INFO(10) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER1 ') HDR(22) = stream
         if (field.eq.'FILTER2 ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
 
 
         if (field.eq.'END     ') goto 101
         enddo
      goto 100
 101  continue
 
 
      if (laxis(1).ne.NX.or.laxis(2).ne.NY) then
         print*,'FITS image not the expected dimensions: '
         print*,'    input NX: ',nx
         print*,'    input NY: ',ny
         print*,'              '
         print*,'    laxis(1): ',laxis(1)
         print*,'    laxis(2): ',laxis(2)
         print*,'  '
         stop
         endif
 
      nread = nread + 1
      if (DIAG) then
         print*,'----------------------------------------'
         print*,'  NREAD: ',nread
         print*,'NEXTEND: ',nextend
         print*,'  NAXIS: ',naxes
         print*,'  LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,' BITPIX: ',bitpix
         print*,' BSCALE: ',bscale
         print*,'  BZERO: ',bzero
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      if (BITPIX.ne.32) then
         print*,'                '
         print*,'readfits_i4...: '
         print*,'                '
         print*,'   you called a routine to read in a'
         print*,'   long i*4 image, and the image you'
         print*,'   gave it has BITPIX = ',BITPIX
         print*,'   '
         print*,'   FILE: ',FILE
         print*,'   '
         stop
         endif
 
      nbper = 4*laxis(1)*laxis(2)
      npt   =   laxis(1)*laxis(2)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         np2 = min(np2,npt)
         call buff2pix_i4r(buffb,ibuff,0001,0720)
         do n = np1, np2, 1
            jj = n/NX   + 1
            ii = n-NX*(jj-1)
            pix(ii,jj) = ibuff(n-np1+1)*bscale+bzero
            enddo
         enddo
 
      if (DIAG) then
         print*,'  NBPER: ',nbper
         print*,'  NBYT1: ',nbyte1
         print*,'  NBYT2: ',nbyte2
         print*,' IFIRST: ',ifirst
         print*,'     I1: ',i1
         print*,'     I2: ',i2
         print*,'    NPT: ',NPT
         endif
 
      return
 
 900  continue
      print*,'READFITS_I4R ERROR'
      print*,' FILEU: ',FILEU
      stop
 
      end
 
 
      subroutine buff2pix_i4r(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      integer*4 pix(*)
      integer n1,nt
 
      byte b(4)
      integer ii
      equivalence(ii,b)
 
      integer i, npu, nbu
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (.not.(_LINUX_)) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            b(3) = buff(nbu+3)
            b(4) = buff(nbu+4)
            endif
         if ((_LINUX_)) then
            b(4) = buff(nbu+1)
            b(3) = buff(nbu+2)
            b(2) = buff(nbu+3)
            b(1) = buff(nbu+4)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = ii
         enddo
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_r4.f"
c****                                         
c*********************************************
                                              
 
c--------------------------------------------------
c
c this just reads in an r4 fits image
c
 
      subroutine readfits_r4(FILE,pix,NDIMX,NDIMY)
      implicit none
 
      character*(*) FILE
      integer NDIMX,NDIMY
      real    pix(NDIMX,NDIMY)
 
      character*199 FILEU
      character*070 INFO(10)
 
      integer naxes
      integer laxis(3)
 
      character*8  field
      character*70 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
      integer j
 
      character*2880 buffc
      byte   buffb(2880)
      equivalence (buffc,buffb)
 
      real*4 buffr(0720)
      integer ii,nn,nx,ny
      integer nxx, nyy
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
      logical DIAG
      data DIAG /.false./
 
      character*70 HDR(25)
c     common/HDR/HDR
 
      logical extend_tf
 
      FILEU = FILE
      do i = 1, 195
         if (FILE(i:i+4).eq.'.fits') then
             FILEU = FILE(1:i+4)
             goto 1
             endif
         enddo
 
      print*,' '
      print*,'readfits_r4:    no .fits'
      print*,'      FILE:  ',FILE
      stop
    1 continue
      do i = 1, 25
         HDR(i) = ' '
         enddo
 
 
      if (DIAG) then
         print*,'enter readfits_r4...'
         print*,'FILE: ',FILE(1:60)
         endif
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened'
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
 
      extend_tf = .false.
 
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buffc
      if (DIAG) print*,'READREC: ',i
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         do j = 1, 80
            if (ichar(buffc(k*80+j:k*80+j)).eq.0)
     .                buffc(k*80+j:k*80+j) = ' '
            enddo
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+10:k*80+79)
         if (DIAG) write(*,'(''   FIELD : '',8a)') field
         if (DIAG) write(*,'(''   STREAM: '',20a)') stream
         if (DIAG) write(*,'(''   STREAM: '',70a)') stream
         if (field.eq.'EXTEND  ') read(stream,*) extend_tf
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'EXPTIME ') INFO(1) = stream
         if (field.eq.'FILTNAM1') INFO(2) = stream
         if (field.eq.'FILENAME') INFO(3) = stream
         if (field.eq.'DATE-OBS') INFO(4) = stream
         if (field.eq.'TIME-OBS') INFO(5) = stream
         if (field.eq.'DEC_TARG') INFO(6) = stream
         if (field.eq.'RA_TARG ') INFO(7) = stream
         if (field.eq.'PA_V3   ') INFO(8) = stream
         if (field.eq.'PROPOSID') INFO(9) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER1 ') HDR(22) = stream
         if (field.eq.'FILTER2 ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
 
         if (field.eq.'END     ') goto 101
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
 
      if (extend_tf.and.NREAD.eq.1.and.NAXES.eq.0) goto 100 ! read the first extension...
 
      if (DIAG) then
         print*,'----------------------------------------'
         print*,'  NREAD: ',nread
         print*,'NEXTEND: ',nextend
         print*,'  NAXIS: ',naxes
         print*,'  LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,' BITPIX: ',bitpix
         print*,' BSCALE: ',bscale
         print*,'  BZERO: ',bzero
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      nbper  = 4*laxis(1)*laxis(2)
      npt    = laxis(1)*laxis(2)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (BITPIX.ne.-32) then
         print*,'   FILEU: ',FILEU(1:40)
         print*,'   FILE : ',FILE(1:40)
         print*,'BITPIX.ne.-32... unreal!'
         stop
         endif
 
      do i = 01, NDIMX
      do j = 01, NDIMY
         pix(i,j) = 0.
         enddo
         enddo
 
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         call buff2pix_r4(buffb,buffr,0001,0720)
         do ii = 001, 720
            nn = np1 + (ii-1)
            ny = 1 + (nn-1)/laxis(1)
            nx = nn-(ny-1)*laxis(1)
            if (nx.ge.001.and.nx.le.NDIMX.and.
     .          ny.ge.001.and.ny.le.NDIMY) then
                pix(nx,ny) = buffr(ii)
                nxx = nx
                nyy = ny
                endif
            enddo
         if (ny.gt.NDIMY) goto 899
 
c        if (DIAG) write(*,1115) i,np1,np2,npt,nxx,nyy
c1115    format(1x,i8,1x,i10,1x,i10,1x,i10,1x,2i6)
         enddo
 
  899 close(10)
c     if (DIAG) write(*,1115) i,np1,np2,npt,nxx,nyy
 
 
 
      return
 
  900 continue
      print*,'                '
      print*,'READFITS ERROR: '
      print*,'                '
      write(*,'(''   could not read in file:   '',80a)') FILEU
      print*,'                '
      stop
 
      end
 
 
 
      subroutine buff2pix_r4(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      real pix(*)
      integer n1,nt
 
      byte b(4)
      real r
      equivalence(r,b)
 
      integer i, npu, nbu
      logical islinux
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (.not.islinux()) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            b(3) = buff(nbu+3)
            b(4) = buff(nbu+4)
            endif
         if (islinux()) then
            b(4) = buff(nbu+1)
            b(3) = buff(nbu+2)
            b(2) = buff(nbu+3)
            b(1) = buff(nbu+4)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = r
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_r4e.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------------------------
c
c reads an r4 fits image, with extensions (reads in one extension)
c
 
      subroutine readfits_r4e(FILE,pix,NDIMX,NDIMY,NEXTENU)
      implicit none
 
      character*(*) FILE
      integer NDIMX,NDIMY
      real    pix(NDIMX,NDIMY)
      integer NEXTENU
 
      character*200 FILEU
      character*70 INFO(10)
      common / fitsinfo / INFO
 
      integer naxes
      integer laxis(3)
      common/laxis3_/laxis
 
      integer NXF
      integer NYF
 
      character*8  field
      character*40 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
c     integer j
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
      character*70 HDR(25)
      common/HDR/HDR
 
      logical DIAG
      data DIAG /.false./
      integer NEND
      integer iend
 
      if (DIAG) then
         print*,'enter readfits_r4e...... '
         print*,'FILEi: ',FILE(1:60)
         endif
 
      FILEU = FILE
      iend = 0
      do i = 196,1,-1
         if (DIAG) print*,i,iend,FILE(i:i+4)
         if (FILE(i:i+4).eq.'.fits') iend = i+4
         enddo
      if (DIAG) then
         print*,'iend: ',iend
         endif
      if (iend.eq.0) then
          print*,'NO .fits in FILENAME'
          print*,'FILE: ',FILE
          stop
          endif
      FILEU = FILE(1:iend)
 
      if (DIAG) then
         print*,'purge...'
         print*,'FILEu: ',FILEU
         endif
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened ',FILEU
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
 
      BSCALE = 1.0
      BZERO  = 0.0
 
      NEND = 0
      i = 0
      nread = 0
 100  continue
      i = i + 1
      if (DIAG) print*,'READREC: ',i
      read(10,rec=i,iostat=ios) buffc
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+51)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'EXPTIME ') INFO(1) = stream
         if (field.eq.'FILTER  ') INFO(2) = stream
         if (field.eq.'FILTNAM1') INFO(2) = stream
         if (field.eq.'FILENAME') INFO(3) = stream
         if (field.eq.'DATE-OBS') INFO(4) = stream
         if (field.eq.'TIME-OBS') INFO(5) = stream
         if (field.eq.'DEC_TARG') INFO(6) = stream
         if (field.eq.'RA_TARG ') INFO(7) = stream
         if (field.eq.'PA_V3   ') INFO(8) = stream
         if (field.eq.'PROPOSID') INFO(9) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER ')  HDR(22) = stream
         if (field.eq.'FILTER1 ') HDR(22) = stream
         if (field.eq.'FILTER2 ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
 
         if (field.eq.'END     ') then
           !print*,' ---> NEND: ',NEND,NEXTENU
            if (NEND.eq.NEXTENU) goto 101
            NEND = NEND + 1
            endif
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,' '
         print*,'----------------------------------------'
         print*,'  NREAD: ',nread
         print*,'NEXTEND: ',nextend
         print*,'  NAXIS: ',naxes
         print*,'  LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,' BITPIX: ',bitpix
         print*,' BSCALE: ',bscale
         print*,'  BZERO: ',bzero
         print*,'  NDIMX: ',NDIMX
         print*,'  NDIMY: ',NDIMY
         print*,' '
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      NXF = laxis(1)
      NYF = laxis(2)
 
      nbper  = 4*laxis(1)*laxis(2)
      npt    = laxis(1)*laxis(2)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (BITPIX.eq.-64) then
         print*,'from readfits_r4e... '
         print*,'     BITPIX: ',BITPIX
         print*,'call readfits_r8e... '
         print*,'                   '
         call readfits_r8e_r4(FILE,pix,NDIMX,NDIMY,NEXTENU)
         return
         endif
 
      if (BITPIX.ne.-32) then
         print*,'readfits_r4e...'
         print*,'BITPIX: ',BITPIX
         print*,'prob'
         stop
         endif
 
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
c        call buff2pix_r4(buffb,pix,np1,npt)
         call buff2pix_r4_edge(buffb,pix,np1,npt,
     .                         NDIMX,NDIMY,laxis(1),laxis(2))
         if (DIAG) write(*,1115) i,np1,np2,npt
 1115    format(1x,i8,1x,i10,1x,i10,1x,i10)
         enddo
 
      close(10)
      if (DIAG) print*,'...closed ',FILEU
      return
 
 900  continue
      print*,' '
      print*,'readfits_r4e ERROR'
      write(*,'(''NEXTU: '',i4  )') NEXTENU
      write(*,'(''FILEI: '',a200)') FILE
      write(*,'('' IEND: '',i4  )') IEND
      write(*,'(''FILEU: '',a200)') FILEU
      print*,' '
      stop
 
      end
 
 
c------------------------------------------------------
c
c
      subroutine buff2pix_r4_edge(buff,pix,n1,nt,
     .                            NXP,NYP,NXF,NYF)
      implicit none
c     character buff(2880)
      byte buff(2880)
      integer NXP,NYP
      real pix(NXP,NYP)
      integer n1,nt
      integer NXF,NYF
 
      real pbuff(720)
      common /sneaky/pbuff
      integer i
      integer npu, nbu
      integer NX, NY
 
      byte b(4)
      real r
      equivalence(r,b)
      logical islinux
 
      if (NYF.eq.0) continue ! just to "use" the argument
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (npu.ge.1.and.npu.le.nt) then
            NX = npu - (npu-1)/NXF*NXF
            NY = 1 + (npu-1)/NXF
            if (NX.le.NXP.and.NY.le.NYP) then
               if (.not.islinux()) then
                  b(1) = buff(nbu+1)
                  b(2) = buff(nbu+2)
                  b(3) = buff(nbu+3)
                  b(4) = buff(nbu+4)
                  endif
               if (islinux()) then
                  b(4) = buff(nbu+1)
                  b(3) = buff(nbu+2)
                  b(2) = buff(nbu+3)
                  b(1) = buff(nbu+4)
                  endif
               if (npu.ge.1.and.npu.le.nt) pix(NX,NY) = r
               endif
            endif
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_r8e_r4.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------------------------
c
c reads an r4 fits image, with extensions (reads in one extension)
c
 
      subroutine readfits_r8e_r4(FILE,pix,NDIMX,NDIMY,NEXTENU)
      implicit none
 
      character*(*) FILE
      integer NDIMX,NDIMY
      real*4  pix(NDIMX,NDIMY)
      integer NEXTENU
 
      character*199 FILEU
      character*70 INFO(10)
      common / fitsinfo / INFO
 
      integer naxes
      integer laxis(3)
      common/laxis3_/laxis
 
      integer NXF
      integer NYF
 
      character*8  field
      character*40 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
      integer j
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
      character*70 HDR(25)
      common/HDR/HDR
 
      logical DIAG
      data DIAG /.false./
      integer NEND
      integer iend
 
      if (DIAG) then
         print*,'enter readfits_r4e...... '
         print*,'FILEi: ',FILE(1:60)
         endif
 
      FILEU = FILE
      iend = 0
      do i = 196,1,-1
         if (DIAG) print*,i,iend,FILE(i:i+4)
         if (FILE(i:i+4).eq.'.fits') iend = i+4
         enddo
      if (DIAG) then
         print*,'iend: ',iend
         endif
      if (iend.eq.0) stop 'NO .fits in FILENAME'
      FILEU = FILE(1:iend)
 
      if (DIAG) then
         print*,'purge...'
         print*,'FILEu: ',FILEU
         endif
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened ',FILEU
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
 
      BSCALE = 1.0
      BZERO  = 0.0
 
      NEND = 0
      i = 0
      nread = 0
 100  continue
      i = i + 1
      if (DIAG) print*,'READREC: ',i
      read(10,rec=i,iostat=ios) buffc
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+51)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'EXPTIME ') INFO(1) = stream
         if (field.eq.'FILTER  ') INFO(2) = stream
         if (field.eq.'FILTNAM1') INFO(2) = stream
         if (field.eq.'FILENAME') INFO(3) = stream
         if (field.eq.'DATE-OBS') INFO(4) = stream
         if (field.eq.'TIME-OBS') INFO(5) = stream
         if (field.eq.'DEC_TARG') INFO(6) = stream
         if (field.eq.'RA_TARG ') INFO(7) = stream
         if (field.eq.'PA_V3   ') INFO(8) = stream
         if (field.eq.'PROPOSID') INFO(9) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER ')  HDR(22) = stream
         if (field.eq.'FILTER1 ') HDR(22) = stream
         if (field.eq.'FILTER2 ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
 
         if (field.eq.'END     ') then
           !print*,' ---> NEND: ',NEND,NEXTENU
            if (NEND.eq.NEXTENU) goto 101
            NEND = NEND + 1
            endif
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,' '
         print*,'----------------------------------------'
         print*,'  NREAD: ',nread
         print*,'NEXTEND: ',nextend
         print*,'  NAXIS: ',naxes
         print*,'  LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,' BITPIX: ',bitpix
         print*,' BSCALE: ',bscale
         print*,'  BZERO: ',bzero
         print*,'  NDIMX: ',NDIMX
         print*,'  NDIMY: ',NDIMY
         print*,' '
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      NXF = laxis(1)
      NYF = laxis(2)
 
      nbper  = 8*laxis(1)*laxis(2)
      npt    = laxis(1)*laxis(2)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (BITPIX.ne.-64) then
         print*,'readfits_r8e...'
         print*,'BITPIX: ',BITPIX
         print*,'prob'
         stop
         endif
 
      if (DIAG) then
         print*,'          '
         print*,'do i ---  ',i1,i2
         print*,'   nbper: ',nbper
         print*,'     npt: ',npt
         print*,'          '
         endif
 
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/8 + 1
         np2 = (nbyteE-nbyte1)/8 + 1
         call buff2pix_r8_edge(buffb,pix,np1,npt,
     .                         NDIMX,NDIMY,laxis(1),laxis(2))
         if (DIAG) write(*,1115) i,np1,np2,npt
 1115    format(1x,i8,1x,i10,1x,i10,1x,i10)
         enddo
 
      if (DIAG) then
          print*,' '
          do j = 10, 01, -1
             write(*,'(10x,i2,1x,10f8.2)') j, (pix(i,j),i=1,10)
             enddo
          print*,' '
          endif
 
      close(10)
      if (DIAG) print*,'...closed ',FILEU
      return
 
 900  continue
      print*,'READFITS ERROR'
      stop
 
      end
 
 
c------------------------------------------------------
c
c
      subroutine buff2pix_r8_edge(buff,pix,n1,nt,
     .                            NXP,NYP,NXF,NYF)
      implicit none
      byte buff(2880)
      integer NXP,NYP
      real*4  pix(NXP,NYP)
      integer n1,nt
      integer NXF,NYF
 
c     real pbuff(360)
      integer i
      integer npu, nbu
      integer NX, NY
 
      byte b(8)
      real*8 r8
      equivalence(r8,b)
      logical islinux
 
      if (NYF.eq.0) continue
 
      do i = 1, 360
         npu = n1+i-1
         nbu = (i-1)*8
         if (npu.ge.1.and.npu.le.nt) then
            NX = npu - (npu-1)/NXF*NXF
            NY = 1 + (npu-1)/NXF
            if (NX.le.NXP.and.NY.le.NYP) then
               if (.not.islinux()) then
                  b(1) = buff(nbu+1)
                  b(2) = buff(nbu+2)
                  b(3) = buff(nbu+3)
                  b(4) = buff(nbu+4)
                  b(5) = buff(nbu+5)
                  b(6) = buff(nbu+6)
                  b(7) = buff(nbu+7)
                  b(8) = buff(nbu+8)
                  endif
               if (islinux()) then
                  b(8) = buff(nbu+1)
                  b(7) = buff(nbu+2)
                  b(6) = buff(nbu+3)
                  b(5) = buff(nbu+4)
                  b(4) = buff(nbu+5)
                  b(3) = buff(nbu+6)
                  b(2) = buff(nbu+7)
                  b(1) = buff(nbu+8)
                  endif
               if (npu.ge.1.and.npu.le.nt) pix(NX,NY) = SNGL(r8)
               endif
            endif
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/writfits_r4.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------------
c
c this just writes a real*4 fits image
c
 
      subroutine writfits_r4(FILE,pix,PXDIMX,PXDIMY)
      implicit none
 
      character*(*) FILE
      integer PXDIMX,PXDIMY
      real    pix(PXDIMX,PXDIMY)
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer k, j
 
      character*200 FILEU
      character*70 HDR(25)
      common/HDR/HDR
 
      integer nonspace
 
 
      HDR(05) = "' pixel    '"
      HDR(06) = "' pixel    '"
 
      FILEU = FILE
      do i = 1, 195
         if (FILE(i:i+4).eq.'.fits') then
             FILEU = FILE(1:i+4)
             goto 1
             endif
         enddo
 
 
      print*,' '
      print*,'writfits_r4:    no .fits'
      print*,'      FILE:  ',FILE
      stop
    1 continue
 
      i = 1
 
      open(10,file=FILEU,status='unknown',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      do k = 00, 34
         write(buffc(k*80+1:k*80+80),'(80x)')
         enddo
 
      write(10,rec=i,iostat=ios) buffc
 
 
      write(buffc( 0*80+1: 1*80),'(''SIMPLE  =                    T'')')
      write(buffc( 1*80+1: 2*80),'(''BITPIX  =                  -32'')')
      write(buffc( 2*80+1: 3*80),'(''NAXIS   = '',8x,i12)') 2
      write(buffc( 3*80+1: 4*80),'(''NAXIS1  = '',8x,i12)') PXDIMX
      write(buffc( 4*80+1: 5*80),'(''NAXIS2  = '',8x,i12)') PXDIMY
      write(buffc( 5*80+1: 6*80),'(''DATATYPE= '',9a)')
     .                          " 'REAL*4' "
      write(buffc(07*80+1:08*80),'(''COMMENT   '',a05)') '     '
      write(buffc(08*80+1:09*80),'(''COMMENT   '',a05)') '     '
      write(buffc(09*80+1:10*80),'(''CRPIX1  = '',a70)') HDR(01)
      write(buffc(10*80+1:11*80),'(''CRPIX2  = '',a70)') HDR(02)
      write(buffc(11*80+1:12*80),'(''CRVAL1  = '',a70)') HDR(03)
      write(buffc(12*80+1:13*80),'(''CRVAL2  = '',a70)') HDR(04)
      write(buffc(13*80+1:14*80),'(''CTYPE1  = '',a70)') HDR(05)
      write(buffc(14*80+1:15*80),'(''CTYPE2  = '',a70)') HDR(06)
      write(buffc(15*80+1:16*80),'(''CD1_1   = '',a70)') HDR(07)
      write(buffc(16*80+1:17*80),'(''CD1_2   = '',a70)') HDR(08)
      write(buffc(17*80+1:18*80),'(''CD2_1   = '',a70)') HDR(09)
      write(buffc(18*80+1:19*80),'(''CD2_2   = '',a70)') HDR(10)
      write(buffc(19*80+1:20*80),'(''ORIENTAT= '',a70)') HDR(11)
      write(buffc(20*80+1:21*80),'(''PA_APER = '',a70)') HDR(12)
      write(buffc(21*80+1:22*80),'(''PA_V3   = '',a70)') HDR(13)
      write(buffc(22*80+1:23*80),'(''DATE-OBS= '',a70)') HDR(14)
      write(buffc(23*80+1:24*80),'(''TIME-OBS= '',a70)') HDR(15)
      write(buffc(24*80+1:25*80),'(''EXPTIME = '',a70)') HDR(16)
      write(buffc(25*80+1:26*80),'(''ROOTNAME= '',a70)') HDR(17)
      write(buffc(26*80+1:27*80),'(''TARGNAME= '',a70)') HDR(18)
      write(buffc(27*80+1:28*80),'(''RA_TARG = '',a70)') HDR(19)
      write(buffc(28*80+1:29*80),'(''DEC_TARG= '',a70)') HDR(20)
      write(buffc(29*80+1:30*80),'(''PROPOSID= '',a70)') HDR(21)
      write(buffc(30*80+1:31*80),'(''FILTER1 = '',a70)') HDR(22)
      write(buffc(31*80+1:32*80),'(''FILTER2 = '',a70)') HDR(23)
      write(buffc(33*80+1:34*80),'(''VAFACTOR= '',a70)') HDR(24)
      write(buffc(32*80+1:33*80),'(''CCDGAIN = '',a70)') HDR(25)
      write(buffc(33*80+1:34*80),'(''COMMENT   '',a05)') '     '
      write(buffc(34*80+1:35*80),'(''COMMENT   '',a05)') '     '
      write(buffc(35*80+1:36*80),'(''END       '')')
 
      do k = 00, 34
         nonspace = 0
         do j = 10, 80
            if (buffc(k*80+j:k*80+j).ne.' '.and.
     .          iachar(buffc(k*80+j:k*80+j)).ne.0) nonspace = nonspace+1
            enddo
         if (nonspace.eq.0) then
             do j = 1, 80
                buffc(k*80+j:k*80+j) = ' '
                enddo
             endif
         enddo
 
      write(10,rec=i,iostat=ios) buffc
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      nbper  = 4*PXDIMX*PXDIMY
      npt    =   PXDIMX*PXDIMY
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         call pix2buff_r4(buffb,pix,np1,npt)
         write(10,rec=i,iostat=ios) buffc
         enddo
 
      close(10)
 
      return
 
 900  continue
      print*,'writfits_r4.f ERROR'
      print*,'   FILEU: ',FILEU
      stop
 
      end
 
 
 
c-------------------------------------------------------
c
c
      subroutine pix2buff_r4(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      real*4 pix(*)
      integer n1,nt
 
      byte b(4)
      real*4 r
      equivalence(r,b)
 
      integer i, npu, nbu
      logical islinux
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (npu.ge.1.and.npu.le.nt) r = pix(npu)
         if (.not.islinux()) then
            buff(nbu+1) = b(1)
            buff(nbu+2) = b(2)
            buff(nbu+3) = b(3)
            buff(nbu+4) = b(4)
            endif
         if (islinux()) then
            buff(nbu+1) = b(4)
            buff(nbu+2) = b(3)
            buff(nbu+3) = b(2)
            buff(nbu+4) = b(1)
            endif
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/writfits_b1.f"
c****                                         
c*********************************************
                                              
 
 
      subroutine writfits_b1(FILE,pix,PXDIMX,PXDIMY)
      implicit none
 
      character*(*) FILE
      integer PXDIMX,PXDIMY
      byte pix(PXDIMX,PXDIMY)
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
 
      character*70 HDR(25)
      common/HDR/HDR
 
      character*80 FILEU
 
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
 
 
c     write(*,'(''ENTER   writfits_b1: '',80a)') FILEU
 
      open(10,file=FILEU,
     .     status='unknown',
     .     err   =900,
     .     recl  =2880,
     .     form  ='UNFORMATTED',
     .     access='DIRECT')
 
 
      i = 1
      write(buffc( 0*80+1: 1*80),'(''SIMPLE  = T    '')')
      write(buffc( 1*80+1: 2*80),'(''BITPIX  =  8  '')')
      write(buffc( 2*80+1: 3*80),'(''NAXIS   = '',i12)') 2
      write(buffc( 3*80+1: 4*80),'(''NAXIS1  = '',i12)') PXDIMX
      write(buffc( 4*80+1: 5*80),'(''NAXIS2  = '',i12)') PXDIMY
      write(buffc( 5*80+1: 6*80),'(''DATATYPE= '',9a)')
     .                          ' ''BYTE    '''
      write(buffc( 6*80+1: 7*80),'(''DATE    = '',11a)')
     .                          ' ''28/01/00'''
      write(buffc( 7*80+1: 8*80),'(''BSCALE  = '',i12)') 00001
      write(buffc( 8*80+1: 9*80),'(''BZERO   = '',i12)') 00000
      write(buffc(09*80+1:10*80),'(''CRPIX1  = '',a20)') HDR(01)
      write(buffc(10*80+1:11*80),'(''CRPIX2  = '',a20)') HDR(02)
      write(buffc(11*80+1:12*80),'(''CRVAL1  = '',a20)') HDR(03)
      write(buffc(12*80+1:13*80),'(''CRVAL2  = '',a20)') HDR(04)
      write(buffc(13*80+1:14*80),'(''CTYPE1  = '',a20)') HDR(05)
      write(buffc(14*80+1:15*80),'(''CTYPE2  = '',a20)') HDR(06)
      write(buffc(15*80+1:16*80),'(''CD1_1   = '',a20)') HDR(07)
      write(buffc(16*80+1:17*80),'(''CD1_2   = '',a20)') HDR(08)
      write(buffc(17*80+1:18*80),'(''CD2_1   = '',a20)') HDR(09)
      write(buffc(18*80+1:19*80),'(''CD2_2   = '',a20)') HDR(10)
      write(buffc(19*80+1:20*80),'(''ORIENTAT= '',a20)') HDR(11)
      write(buffc(20*80+1:21*80),'(''PA_APER = '',a20)') HDR(12)
      write(buffc(21*80+1:22*80),'(''PA_V3   = '',a20)') HDR(13)
      write(buffc(22*80+1:23*80),'(''DATE-OBS= '',a20)') HDR(14)
      write(buffc(23*80+1:24*80),'(''TIME-OBS= '',a20)') HDR(15)
      write(buffc(24*80+1:25*80),'(''EXPTIME = '',a20)') HDR(16)
      write(buffc(25*80+1:26*80),'(''ROOTNAME= '',a20)') HDR(17)
      write(buffc(26*80+1:27*80),'(''TARGNAME= '',a20)') HDR(18)
      write(buffc(27*80+1:28*80),'(''RA_TARG = '',a20)') HDR(19)
      write(buffc(28*80+1:29*80),'(''DEC_TARG= '',a20)') HDR(20)
      write(buffc(29*80+1:30*80),'(''PROPOSID= '',a20)') HDR(21)
      write(buffc(30*80+1:31*80),'(''FILTER1 = '',a20)') HDR(22)
      write(buffc(31*80+1:32*80),'(''FILTER2 = '',a20)') HDR(23)
      write(buffc(32*80+1:33*80),'(''VAFACTOR= '',a20)') HDR(24)
      write(buffc(33*80+1:34*80),'(''COMMENT   '')')
      write(buffc(34*80+1:35*80),'(''COMMENT   '')')
      write(buffc(35*80+1:36*80),'(''END       '')')
 
c     print*,buffc
      write(10,rec=i,iostat=ios) buffc
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      nbper  =   PXDIMX*PXDIMY
      npt    =   PXDIMX*PXDIMY
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
 
c      print*,'nbyte1: ',nbyte1
c      print*,'nbyte2: ',nbyte1
c      print*,'    i1: ',i1
c      print*,'    i2: ',i2
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1) + 1
         np2 = (nbyteE-nbyte1)+ 1
        !if (i.lt.0010) print*,'i: ',i,i1,i2,np1,np2,nbyte0
        !if (i.gt.2900) print*,'i: ',i,i1,i2,np1,np2,nbyte0
         call pix2buff_b1(pix,buffb,np1,npt)
         write(10,rec=i,iostat=ios) buffc
         enddo
 
      close(10)
 
      return
 
 900  continue
      print*,'WRITFITS.f ERROR'
      stop
 
      end
 
      subroutine pix2buff_b1(pix,buffb,n1,nt)
      implicit none
      byte pix(1)
      byte buffb(2880)
 
      integer   n1,nt
 
      integer i
      integer npu
 
      byte ipval
 
      do i = 1, 2880
         npu = (1+(n1-1)*2)+i-1
         npu = (1+(n1-1)*1)+i-1
         if (npu.ge.1.and.npu.le.nt) then
            ipval = pix(npu)
            buffb(i) = ipval
            endif
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/writfits_i4.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------
c
c this routine will write an integer*4 array into
c a 2-dimensional fits image
c
      subroutine writfits_i4(FILE,pix,PXDIMX,PXDIMY)
      implicit none
 
      integer PXDIMX,PXDIMY
      character*(*) FILE
      integer*4 pix(PXDIMX,PXDIMY)
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios
 
      integer ii, jj
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
 
      logical DIAG
      data DIAG/.false./
 
      character*70 HDR(25)
      common/HDR/HDR
      character*80 FILEU
 
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
      open(10,file=FILEU,
     .     status='unknown',
     .     err   =900,
     .     recl  =2880,
     .     form  ='UNFORMATTED',
     .     access='DIRECT')
 
      write(buffc( 0*80+1: 1*80),'(''SIMPLE  = T    '')')
      write(buffc( 1*80+1: 2*80),'(''BITPIX  =  32  '')')
      write(buffc( 2*80+1: 3*80),'(''NAXIS   ='',i12)') 2
      write(buffc( 3*80+1: 4*80),'(''NAXIS1  ='',i12)') PXDIMX
      write(buffc( 4*80+1: 5*80),'(''NAXIS2  ='',i12)') PXDIMY
      write(buffc( 5*80+1: 6*80),'(''DATATYPE='',9a)')
     .                          ' ''INTEGER*4'''
      write(buffc( 6*80+1: 7*80),'(''DATE    ='',11a)')
     .                          ' ''00/00/00'''
      write(buffc( 7*80+1: 8*80),'(''BSCALE  ='',i12)') 00001
      write(buffc( 8*80+1: 9*80),'(''BZERO   ='',i12)') 00000
      write(buffc(09*80+1:10*80),'(''CRPIX1  ='',a20)') HDR(01)
      write(buffc(10*80+1:11*80),'(''CRPIX2  ='',a20)') HDR(02)
      write(buffc(11*80+1:12*80),'(''CRVAL1  ='',a20)') HDR(03)
      write(buffc(12*80+1:13*80),'(''CRVAL2  ='',a20)') HDR(04)
      write(buffc(13*80+1:14*80),'(''CTYPE1  ='',a20)') HDR(05)
      write(buffc(14*80+1:15*80),'(''CTYPE2  ='',a20)') HDR(06)
      write(buffc(15*80+1:16*80),'(''CD1_1   ='',a20)') HDR(07)
      write(buffc(16*80+1:17*80),'(''CD1_2   ='',a20)') HDR(08)
      write(buffc(17*80+1:18*80),'(''CD2_1   ='',a20)') HDR(09)
      write(buffc(18*80+1:19*80),'(''CD2_2   ='',a20)') HDR(10)
      write(buffc(19*80+1:20*80),'(''ORIENTAT='',a20)') HDR(11)
      write(buffc(20*80+1:21*80),'(''PA_APER ='',a20)') HDR(12)
      write(buffc(21*80+1:22*80),'(''PA_V3   ='',a20)') HDR(13)
      write(buffc(22*80+1:23*80),'(''DATE-OBS='',a20)') HDR(14)
      write(buffc(23*80+1:24*80),'(''TIME-OBS='',a20)') HDR(15)
      write(buffc(24*80+1:25*80),'(''EXPTIME ='',a20)') HDR(16)
      write(buffc(25*80+1:26*80),'(''ROOTNAME='',a20)') HDR(17)
      write(buffc(26*80+1:27*80),'(''TARGNAME='',a20)') HDR(18)
      write(buffc(27*80+1:28*80),'(''RA_TARG ='',a20)') HDR(19)
      write(buffc(28*80+1:29*80),'(''DEC_TARG='',a20)') HDR(20)
      write(buffc(29*80+1:30*80),'(''PROPOSID='',a20)') HDR(21)
      write(buffc(30*80+1:31*80),'(''FILTER1 ='',a20)') HDR(22)
      write(buffc(31*80+1:32*80),'(''FILTER2 ='',a20)') HDR(23)
      write(buffc(33*80+1:34*80),'(''VAFACTOR='',a20)') HDR(24)
      write(buffc(32*80+1:33*80),'(''CCDGAIN ='',a20)') HDR(25)
      write(buffc(34*80+1:35*80),'(''COMMENT  '')')
      write(buffc(35*80+1:36*80),'(''END      '')')
 
      i = 1
      write(10,rec=i,iostat=ios) buffc
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      nbper  = 4*PXDIMX*PXDIMY
      npt    =   PXDIMX*PXDIMY
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (DIAG) then
         print*,'----->      i1: ',i1
         print*,'----->      i2: ',i2
         print*,'----->  PXDIMX: ',PXDIMX
         print*,'----->  PXDIMY: ',PXDIMY
         print*,'----->   nbper: ',nbper
         print*,'----->     npt: ',npt
         print*,'----->  C'
         endif
 
      do ii = 1, PXDIMX
      do jj = 1, PXDIMY
         pix(ii,jj) = pix(ii,jj)
         enddo
         enddo
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         call pix2buff_i4(buffb,pix,np1,npt)
         write(10,rec=i,iostat=ios) buffc
         enddo
 
      close(10)
 
      return
 
 900  continue
      print*,' '
      print*,'WRITFITS_i4 ERROR: '
      print*,' COULD NOT OPEN FILE: '
      print*,' FILE: ',FILEU
      print*,' '
      stop
 
      end
 
 
c
c
c
      subroutine pix2buff_i4(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      integer*4 pix(*)
      integer n1,nt
 
      byte b(4)
      integer ii
      equivalence(ii,b)
 
      integer i, npu, nbu
      logical islinux
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (npu.ge.1.and.npu.le.nt) ii = pix(npu)
         if (.not.islinux()) then
            buff(nbu+1) = b(1)
            buff(nbu+2) = b(2)
            buff(nbu+3) = b(3)
            buff(nbu+4) = b(4)
            endif
         if (islinux()) then
            buff(nbu+1) = b(4)
            buff(nbu+2) = b(3)
            buff(nbu+3) = b(2)
            buff(nbu+4) = b(1)
            endif
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_r4_3D.f"
c****                                         
c*********************************************
                                              
 
 
c------------------------------------------------------
c
c
c
      subroutine readfits_r4_3D(FILE,pix,NX_,NY_,NZ_)
      implicit none
 
      character*(*) FILE
      integer NX_, NY_, NZ_
      real*4  pix(NX_,NY_,NZ_)
 
      integer*8 NX, NY, NZ
 
      integer*8 naxes
      integer*8 laxis(3)
 
      character*8  field
      character*20 stream
 
      real    pixu
      integer*8 nbyte0
      integer*8 nbyteE
      integer*8 nbyte1
      integer*8 nbyte2
      integer*8 nbper
      integer*8 i,ios, k
      integer*8 ii, jj, kk
      integer*8 n
      integer*8 NXU, NYU, NZU
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      real*4 rbuff(720)
 
      integer*8 ifirst, i1, i2
c     integer*8 j
 
      integer*8 np1, np2, npt
      integer*8 nextend
      integer*8 nread
      real bscale, bzero
      integer*8 bitpix
 
 
      logical DIAG
      data DIAG /.false./
 
 
      character*80 FILEU
 
      NX = NX_
      NY = NY_
      NZ = NZ_
 
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
 
c      write(*,'(''ENTER readfits_i2: '',80a)') FILEU
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened'
 
      bscale = 1
      bzero  = 0
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buffc
      if (DIAG) print*,'READREC: ',i
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+31)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
         if (field.eq.'END     ') goto 101
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,'----------------------------------------'
         print*,'  NREAD: ',nread
         print*,'NEXTEND: ',nextend
         print*,'  NAXIS: ',naxes
         print*,'  LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,' BITPIX: ',bitpix
         print*,' BSCALE: ',bscale
         print*,'  BZERO: ',bzero
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      if (BITPIX.ne.-32) then
         print*,'readfits_r4...: '
         print*,'                '
         print*,'   you called a routine to read in an'
         print*,'   real*4 mage, and the image you'
         print*,'   gave it has BITPIX = ',BITPIX
         print*,'   '
         print*,'   FILEU: ',FILEU
         print*,'   '
         stop
         endif
 
      nbper = 4*laxis(1)*laxis(2)*laxis(3)
      npt   =   laxis(1)*laxis(2)*laxis(3)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (laxis(1).ne.NX.or.
     .    laxis(2).ne.NY.or.
     .    laxis(3).ne.NZ) then
         write(*,'(''readfits_r4_3D: '',80a)') FILE
         write(*,'(''readfits_r4_3D: '',80a)') FILEU
         print*,' '
         print*,'  laxis1: ',laxis(1)
         print*,'      NX: ',NX
         print*,' '
         print*,'  laxis2: ',laxis(2)
         print*,'      NY: ',NY
         print*,' '
         print*,'  laxis3: ',laxis(3)
         print*,'      NZ: ',NZ
         print*,' '
         stop
         endif
 
      NXU = laxis(1)
      NYU = laxis(2)
      NZU = laxis(2)
 
      if (DIAG) then
         print*,'     NX: ',NX
         print*,'     NY: ',NY
         print*,'     NZ: ',NZ
         print*,'  NBPER: ',nbper
         print*,'  NBYT1: ',nbyte1
         print*,'  NBYT2: ',nbyte2
         print*,' IFIRST: ',ifirst
         print*,'     I1: ',i1
         print*,'     I2: ',i2
         print*,'    NPT: ',NPT
         endif
 
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         np2 = min(np2,npt)
         call buff2pix_r4_3D(buffb,rbuff,0001,0720)
         do n = np1, np2, 1
            kk = n/(NXU*NYU)
            jj = (n-kk*NXU*NYU)/NXU
            ii = n-kk*NXU*NYU-jj*NXU
            pixu = rbuff(n-np1+1)*bscale+bzero
            pix(ii,jj+1,kk+1) = pixu
            enddo
         enddo
 
      if (DIAG) then
         print*,'  NBPER: ',nbper
         print*,'  NBYT1: ',nbyte1
         print*,'  NBYT2: ',nbyte2
         print*,' IFIRST: ',ifirst
         print*,'     I1: ',i1
         print*,'     I2: ',i2
         print*,'    NPT: ',NPT
         endif
 
 
      return
 
 900  continue
      print*,'READFITS_I2_3D ERROR'
      stop
 
      end
 
 
 
      subroutine buff2pix_r4_3D(buff,pix,n1,nt)
      implicit none
      byte    buff(2880)
      real*4  pix(720)
      integer n1,nt
 
      byte   b(4)
      real*4 r
      equivalence(r,b)
 
      integer*8 i, npu, nbu
      logical   islinux
 
      do i = 0001, 0720
         npu = n1+i-1
         nbu = (i-1)*4
         if (.not.islinux()) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            b(3) = buff(nbu+3)
            b(4) = buff(nbu+4)
            endif
         if (islinux()) then
            b(4) = buff(nbu+1)
            b(3) = buff(nbu+2)
            b(2) = buff(nbu+3)
            b(1) = buff(nbu+4)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = r
         enddo
 
      return
      end
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/WFC.09x10/rpsf_phot.f"
c****                                         
c*********************************************
                                              
 
 
c--------------------------------------
c
c this will evaluate a PSF at a given (dx,dy)
c offset; for the regions within 4 pixels of
c the center, it uses bi-cubic interpolation
c
      real function rpsf_phot(x,y,psf)
      implicit none
      real x, y
      real psf(101,101)
 
 
      real    rx, ry
      integer ix, iy   !     3   4
      real    fx, fy   !    *1*  2
 
      real    dd
 
      real A1, B1, C1, D1, E1, F1, V1
      real A2, B2, C2, D2, E2, F2, V2
      real A3, B3, C3, D3, E3, F3, V3
      real A4, B4, C4, D4, E4, F4, V4
 
 
      rx = 51 + x*4
      ry = 51 + y*4
      ix = int(rx)
      iy = int(ry)
      fx = rx-ix
      fy = ry-iy
 
      dd = sqrt(x**2+y**2)
 
 
      rpsf_phot = 0.
      if (dd.gt.12.0) return
 
      if (dd.gt.4.0) then
         rpsf_phot = (1-fx)*(1-fy)*psf(ix  ,iy  )
     .             + ( fx )*(1-fy)*psf(ix+1,iy  )
     .             + (1-fx)*( fy )*psf(ix  ,iy+1)
     .             + ( fx )*( fy )*psf(ix+1,iy+1)
         return
         endif
 
 
      A1 =  psf(ix  ,iy  )
      B1 = (psf(ix+1,iy  )-psf(ix-1,iy  ))/2
      C1 = (psf(ix  ,iy+1)-psf(ix  ,iy-1))/2
      D1 = (psf(ix+1,iy  )+psf(ix-1,iy  )-2*A1)/2
      F1 = (psf(ix  ,iy+1)+psf(ix  ,iy-1)-2*A1)/2
      E1 = (psf(ix+1,iy+1)-A1)
 
      A2 =  psf(ix+1,iy  )
      B2 = (psf(ix+2,iy  )-psf(ix  ,iy  ))/2
      C2 = (psf(ix+1,iy+1)-psf(ix+1,iy-1))/2
      D2 = (psf(ix+2,iy  )+psf(ix  ,iy  )-2*A2)/2
      F2 = (psf(ix+1,iy+1)+psf(ix+1,iy-1)-2*A2)/2
      E2 =-(psf(ix  ,iy+1)-A2)
 
      A3 =  psf(ix  ,iy+1)
      B3 = (psf(ix+1,iy+1)-psf(ix-1,iy+1))/2
      C3 = (psf(ix  ,iy+2)-psf(ix  ,iy  ))/2
      D3 = (psf(ix+1,iy+1)+psf(ix-1,iy+1)-2*A3)/2
      F3 = (psf(ix  ,iy+2)+psf(ix  ,iy  )-2*A3)/2
      E3 =-(psf(ix+1,iy  )-A3)
 
      A4 =  psf(ix+1,iy+1)
      B4 = (psf(ix+2,iy+1)-psf(ix  ,iy+1))/2
      C4 = (psf(ix+1,iy+2)-psf(ix+1,iy  ))/2
      D4 = (psf(ix+2,iy+1)+psf(ix  ,iy+1)-2*A4)/2
      F4 = (psf(ix+1,iy+2)+psf(ix+1,iy  )-2*A4)/2
      E4 = (psf(ix  ,iy  )-A4)
 
 
      V1 = A1
     .   + B1*( fx )
     .   + C1*( fy )
     .   + D1*( fx )**2
     .   + E1*( fx )*( fy )
     .   + F1*( fy )**2
 
      V2 = A2
     .   + B2*(fx-1)
     .   + C2*( fy )
     .   + D2*(fx-1)**2
     .   + E2*(fx-1)*( fy )
     .   + F2*( fy )**2
 
      V3 = A3
     .   + B3*( fx )
     .   + C3*(fy-1)
     .   + D3*( fx )**2
     .   + E3*( fx )*(fy-1)
     .   + F3*(fy-1)**2
 
      V4 = A4
     .   + B4*(fx-1)
     .   + C4*(fy-1)
     .   + D4*(fx-1)**2
     .   + E4*(fx-1)*(fy-1)
     .   + F4*(fy-1)**2
 
      rpsf_phot = (1-fx)*(1-fy)*V1
     .          + ( fx )*(1-fy)*V2
     .          + (1-fx)*( fy )*V3
     .          + ( fx )*( fy )*V4
 
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/WFC.09x10/zero_fix.f"
c****                                         
c*********************************************
                                              
 
 
      subroutine zero_fix(pix)
      implicit none
      real    pix(4096,4096)
 
      integer hist1(25), hist2(25), hist3(25)
      integer i, j
      real    PM2, PM1, P00, PP1, PP2
      real    EM2, EM1, E00, EP1, EP2
      real    ERR
      real    f
      real    A, B, C
      real    fmin, emin
      real    rand
      integer iif
 
      print*,'          '
      print*,'          '
      print*,'ZERO_FIX: (for antiquated way of storing images)'
      print*,'          '
      print*,'          '
 
      call find_hist(pix,hist1)
 
      do i = 0001, 4096
      do j = 0001, 4096
        !write(*,'(2i5,1x,f10.3)') i,j,pix(i,j)
         if (pix(i,j).lt.-0.9) pix(i,j) = pix(i,j)-1
         enddo
         enddo
 
      call find_hist(pix,hist2)
 
c      print*,' '
c      do h = 01, 25
c         hz = h-13
c         write(*,'(i3,1x,i3,1x,2i10)') h,hz,hist1(h),hist2(h)
c         enddo
c      print*,' '
 
      fmin = 0
      emin = 9e9
c      print*,' '
      do iif = 000, 100, 001
         f = iif*0.01
         PM2 = hist2(11)
         PM1 = hist2(13)*( f )
         P00 = hist2(13)*(1-f)
         PP1 = hist2(14)
         PP2 = hist2(15)
         A = P00
         B = ((PP1-PM1)/2.0 + (PP2-PM2)/4.0)/2.0
         C = (PP2+PM2-2*A)/8.0
 
c-----------------------------------------------------
c         A = -0.08571*PM2
c     .       +0.34286*PM1
c     .       +0.48572*P00
c     .       +0.34286*PP1
c     .       -0.08571*PP2
c         B = -0.20000*PM2
c     .       -0.10000*PM1
c     .       +0.00000*P00
c     .       +0.10000*PP1
c     .       +0.20000*PP2
c         C = +0.71430*PM2
c     .       -0.35710*PM1
c     .       -0.71430*P00
c     .       -0.35710*PP1
c     .       +0.71430*PP2
c         print*,' '
c         write(*,'(30x,3f15.2)') A,B,C
c         A = P00
c         B = ((PP1-PM1)/2.0 + (PP2-PM2)/4.0)/2.0
c         C = (PP2+PM2-2*A)/8.0
c         write(*,'(30x,3f15.2)') A,B,C
c         print*,' '
c-----------------------------------------------------
 
         EM2 = A - 2*B + 4*C
         EM1 = A -   B +   C
         E00 = A
         EP1 = A +   B +   C
         EP2 = A + 2*B + 4*C
         ERR = abs(PM2-EM2)
     .       + abs(PM1-EM1)
     .       + abs(P00-E00)
     .       + abs(PP1-EP1)
     .       + abs(PP2-EP2)
c         write(*,'(f8.4,10x,5i8,10x,5i8,10x,i12)') f,
c     .             PM2,PM1,P00,PP1,PP2,
c     .             EM2,EM1,E00,EP1,EP2,
c     .             ERR
         if (ERR.lt.emin) then
            emin = ERR
            fmin = f
            endif
         enddo
c      print*,' '
c      print*,'fmin: ',fmin
c      print*,' '
 
      do i = 0001, 4096
      do j = 0001, 4096
         if (int(pix(i,j)).eq.0) then
            if (rand().lt.fmin) pix(i,j) = -1
            endif
         enddo
         enddo
 
      call find_hist(pix,hist3)
 
c     print*,' '
c      do h = 01, 25
c        hz = h-13
c        write(*,'(i3,1x,i3,1x,3i10)') h,hz,hist1(h),hist2(h),hist3(h)
c        enddo
c      print*,' '
 
      return
 
      end
 
 
c-----------------------------------
c
c
      subroutine find_hist(pix,hist)
      implicit none
 
      real pix(4096,4096)
      integer hist(25)
 
      integer h
      integer i, j
 
      do h = 01, 25
         hist(h) = 0
         enddo
 
      do i = 0001, 4096
      do j = 0001, 4096
         h = 13 + int(pix(i,j)+0.5)
         if (h.ge.01.and.h.le.25) hist(h) = hist(h)+1
         enddo
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/BARSIG/rbarsigs.f"
c****                                         
c*********************************************
                                              
 
 
      subroutine rbarsigs(xlist,NTOT,bar,sig,NUSE,SIGCLIP)
      implicit none
 
      integer NTOT
      real xlist(NTOT)
      real bar
      real sig
      integer NUSE
      real SIGCLIP
 
      integer n
      real*8    bsum, ssum
      integer nsum, nsumo
      integer NIT
 
 
      nsum = 0
      bar = 0.e0
      sig = 9e9
      do NIT = 1, 20
         nsumo = nsum
         bsum = 0.
         ssum = 0.
         nsum = 0.
         do n = 1, NTOT
            if (abs(xlist(n)-bar).le.SIGCLIP*sig) then
               bsum = bsum + xlist(n)
               ssum = ssum + abs(xlist(n)-bar)
               nsum = nsum + 1
               endif
            enddo
         if (nsum.gt.0) bar = SNGL(bsum / nsum)
         if (nsum.gt.1) sig = SNGL(ssum/(nsum-1))
         if (nsum.lt.0.35*NTOT.and.NIT.ge.4) goto 1
         if (nsum.eq.nsumo.and.NIT.ge.4) goto 1
         enddo
  1   continue
      NUSE = nsum
      if (nsum.le.1) sig = 0.999
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/PROC_SATN/max_contig_NAXIS.f"
c****                                         
c*********************************************
                                              
 
      subroutine max_contig_NAXIS(pixp,pixx,UPR_LIM,
     .                            NAXIS1,NAXIS2,VERBOSE)
      implicit none
 
      integer NAXIS1, NAXIS2
      real    pixp(NAXIS1,NAXIS2)
      real    pixx(NAXIS1,NAXIS2)
      integer i ,j
      integer UPR_LIM
      integer VERBOSE
 
c     integer jmin
c     integer jmax
 
c     integer L, Ls, Lo, LL
c     integer il(99999)
c     integer jl(99999)
c     real    pmax
      integer NIT, NCHG
 
      if (VERBOSE.ge.2) then
          print*,'ENTR max_contig_NAXIS...'
          endif
 
      do i = 0001, NAXIS1
      do j = 0001, NAXIS2
         pixx(i,j) = pixp(i,j)
         enddo
         enddo
 
      NIT  = 1
    1 NIT  = NIT + 1
      NCHG = 0
      do j = 0001 + 1, NAXIS2-1,  1
      do i = 0001 + 1, NAXIS1-1,  1
         if (pixx(i,j).gt.UPR_LIM) then
            if (pixx(i,j).lt.pixx(i+1,j  )) then
               pixx(i,j) = pixx(i+1,j  )
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i-1,j  )) then
               pixx(i,j) = pixx(i-1,j  )
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i  ,j+1)) then
               pixx(i,j) = pixx(i  ,j+1)
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i  ,j-1)) then
               pixx(i,j) = pixx(i  ,j-1)
               NCHG = NCHG + 1
               endif
            endif
         enddo
         enddo
      do j = NAXIS2-1,  0001 +1, -1
      do i = NAXIS1-1,  0001 +1, -1
         if (pixx(i,j).gt.UPR_LIM) then
            if (pixx(i,j).lt.pixx(i+1,j  )) then
               pixx(i,j) = pixx(i+1,j  )
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i-1,j  )) then
               pixx(i,j) = pixx(i-1,j  )
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i  ,j+1)) then
               pixx(i,j) = pixx(i  ,j+1)
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i  ,j-1)) then
               pixx(i,j) = pixx(i  ,j-1)
               NCHG = NCHG + 1
               endif
            endif
         enddo
         enddo
      if (VERBOSE.ge.2) then
          write(*,'(6x,''  NIT: '',i6,1x,i8)') NIT,NCHG
          endif
      if (NCHG.gt.0) goto 1
 
      if (VERBOSE.ge.2) then
          print*,'EXIT max_contig_NAXIS...'
          endif
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/PROC_SATN/peak_sat_NAXIS.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------
c
c this routine will go through the image pixr() and
c generate two supplemental images:  pixp() and pixx().
c pixp() gives a sense of how saturated each saturated
c pixel is, and pixx() tells you what the maximum value
c is for a touching saturated pixel ; if pixx.eq.pixp,
c then the pixel is the maximum of its distribution
c
      subroutine peak_sat_NAXIS(pixr,pixp,pixx,pixq,
     .                          UPR_LIM,
     .                          NAXIS1,NAXIS2,VERBOSE)
      implicit none
 
      integer  NAXIS1,NAXIS2
      real    pixr(NAXIS1,NAXIS2)
      real    pixp(NAXIS1,NAXIS2)
      real    pixx(NAXIS1,NAXIS2)
      byte    pixq(NAXIS1,NAXIS2)
      integer UPR_LIM
      integer VERBOSE
 
      integer i,j
      integer ii,jj
c     integer imin, imax
      integer jmin, jmax
      integer r
 
      integer nsat, ntot
      real    ptota
      real    ptotb
      real    ptot
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'ENTER PEAK_SAT...',UPR_LIM
          print*,' '
          endif
 
      do i = 0001+0005, NAXIS1-5
      if (i.eq.i/500*500.and.VERBOSE.ge.2)
     .    print*,'       i: ',i
      do j = 0001+0005, NAXIS2-5
         pixp(i,j) = 0
         jmin =  0001
         jmax = NAXIS2
         if (NAXIS2.eq.4096) then
            if (j.le.2048) then
               jmin = 0001
               jmax = 2048
               endif
            if (j.ge.2049) then
               jmin = 2049
               jmax = 4096
               endif
            endif
         if (pixq(i,j).ne.0) then
            r = 1
            ptota = 0
    3       ptota = ptota + pixr(i,j-r)
            if (pixr(i,j-r).gt.0.75*UPR_LIM.and.j-r-1.gt.jmin) then
                r = r + 1
                goto 3
                endif
            r = 1
            ptotb = 0
    2       ptotb = ptotb + pixr(i,j+r)
            if (pixr(i,j+r).gt.0.75*UPR_LIM.and.j+r+1.lt.jmax) then
                r = r + 1
                goto 2
                endif
            r = 2
    1       continue
            nsat = 0
            ntot = 0
            ptot = 0
            do ii = -r, +r
            do jj = -r, +r
               if (i-r.lt. 0001 .or.
     .             i+r.gt.NAXIS1.or.
     .             j-r.lt.jmin.or.
     .             j+r.gt.jmax) then
                   pixp(i,j) = -750
                   goto 666
                   endif
               if (ii**2+jj**2.le.(r+0.5)**2) then
                  ntot = ntot + 1
                  if (i+ii.lt.0001.or.
     .                i+ii.gt.NAXIS1.or.
     .                j+jj.lt.0001.or.
     .                j+jj.gt.NAXIS2) goto 666
                  ptot = ptot + max(pixr(i+ii,j+jj),0.0)
                  if (pixr(i+ii,j+jj).gt.UPR_LIM) nsat = nsat + 1
                  endif
               enddo
               enddo
            if (nsat.gt.0.85*ntot) then
               r = r + 1
               goto 1
               endif
            pixp(i,j) = ptot + ptota + ptotb
            endif
  666    continue
         enddo
         enddo
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'CALL FIND MAX_CONTG...'
          print*,' '
          endif
      call max_contig_NAXIS(pixp,pixx,UPR_LIM,NAXIS1,NAXIS2,VERBOSE)
      if (VERBOSE.ge.2) then
          print*,' '
          print*,' RET FIND MAX_CONTG...'
          print*,' '
          endif
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'EXIT PEAK_SAT...',UPR_LIM
          print*,' '
          endif
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/PROC_SATN/sat_phot_NAXIS.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------
c
c
c
      subroutine sat_phot_NAXIS(pixr,pixp,pixx,UPR_LIM,
     .                          NAXIS1,NAXIS2,PSFFILE,
     .                          il,jl,zl,Ls,VERBOSE)
      implicit none
 
      real          pixr(NAXIS1,NAXIS2)
      real          pixp(NAXIS1,NAXIS2)
      real          pixx(NAXIS1,NAXIS2)
      integer       UPR_LIM
      integer       NAXIS1, NAXIS2
      character*200 PSFFILE
      integer       il(_NSTMAX_)
      integer       jl(_NSTMAX_)
      real          zl(_NSTMAX_)
      integer       Ls
      integer       VERBOSE
 
      real      pixs(NAXIS1,NAXIS2)
 
      integer i
      integer j
 
c     logical trip
c     character*80 FILEI
c     character*80 FILEO
 
 
c     integer iu
c     real pixe
c     integer NSATs
      real sr, mbar_sky_NAXIS
      real zr, zrmax
      integer  Lx
c     real apphot_sat2, rtot
      real rtot
c     integer nr, nr0
c     integer ir
 
c     real    reff
c     integer ireff
c     integer ii, jj
      real    rpsf_phot
 
      integer ntot, nap
      real*8 ptot
      real*8 ftot
      real pixpu
      integer iii, jjj
 
      real psfloc(101,101)
 
      logical DIAG
      common /DIAG_/DIAG
 
      if (VERBOSE.ge.2) print*,'ENTER: sat_phot_NAXIS'
 
      if (NAXIS2.eq.4096.and.NAXIS1.eq.4096) then
         do i = 0001, NAXIS1
            pixr(i,2048) = -750
            pixr(i,2049) = -750
            enddo
         endif
 
      if (VERBOSE.ge.2) print*,'     : sat_phot_NAXIS-b'
      do i = 0001, NAXIS1
      do j = 0001, NAXIS2
         pixs(i,j) = pixr(i,j)
         enddo
         enddo
 
      if (VERBOSE.ge.2) print*,'     : sat_phot_NAXIS-c'
      if (DIAG) open(92,file='LOG.SAT_PHOT.ijpl',status='unknown')
      Ls = 0
      do i = 0001, NAXIS1
      do j = 0001, NAXIS2
         if (pixp(i,j).gt.UPR_LIM.and.
     .       pixp(i,j).eq.pixx(i,j)) then
             Ls = Ls + 1
             if (DIAG) write(92,*) i,j,pixp(i,j),Ls
             endif
         enddo
         enddo
      if (DIAG) close(92)
 
      if (VERBOSE.ge.2) print*,'     : sat_phot_NAXIS-d'
      if (DIAG) then
         open(55,file='LOG.peaksat_CEN.reg',status='unknown')
         write(55,'(''# Region file format: DS9 version 3.0'')')
         write(55,'(''global color=yellow'')')
         endif
 
      if (VERBOSE.ge.2) print*,'     : sat_phot_NAXIS-e'
      zrmax = 1.
      il(1) = 0
      jl(1) = 0
      zl(1) = 1.
 
      if (VERBOSE.ge.1) then
          write(*,*)
          write(*,889)
          write(*,887)
          write(*,889)
          endif
 
      Ls = 0
      Lx = 1
      il(1) = -1
      jl(1) = -1
      zl(1) =  1.00
      if (DIAG) open(93,file='LOG.SAT_PHOT.ijms',status='unknown')
      do j = 0001+10, NAXIS2-10
      do i = 0001+10, NAXIS1-10
         if (pixp(i,j).gt.UPR_LIM) then
             if (pixp(i,j).lt.pixx(i,j)) goto 47
             sr = mbar_sky_NAXIS(i,j,35,50,pixs,NAXIS1,NAXIS2)   ! a distant sky
             call locpsfij_stdpsf(i,j,psfloc,PSFFILE)            ! get the local psf
             pixpu = pixp(i,j)                                   ! this is an ID for the saturated star
             nap  = 0.
             ntot = 0.
             ptot = 0.
             ftot = 0.
             do iii = max(i-50,0001+2), min(i+50,NAXIS1-2)
             do jjj = 0001+2, NAXIS2-2
                if (pixx(iii  ,jjj  ).eq.pixpu.or.
     .              pixx(iii+1,jjj  ).eq.pixpu.or.
     .              pixx(iii-1,jjj  ).eq.pixpu.or.
     .              pixx(iii  ,jjj+1).eq.pixpu.or.
     .              pixx(iii  ,jjj-1).eq.pixpu.or.
     .              pixx(iii+1,jjj+1).eq.pixpu.or.
     .              pixx(iii+1,jjj-1).eq.pixpu.or.
     .              pixx(iii-1,jjj+1).eq.pixpu.or.
     .              pixx(iii-1,jjj-1).eq.pixpu.or.
     .              pixx(iii-2,jjj-2).eq.pixpu.or.
     .              pixx(iii-2,jjj-1).eq.pixpu.or.
     .              pixx(iii-2,jjj  ).eq.pixpu.or.
     .              pixx(iii-2,jjj+1).eq.pixpu.or.
     .              pixx(iii-2,jjj+2).eq.pixpu.or.
     .              pixx(iii-1,jjj+2).eq.pixpu.or.
     .              pixx(iii  ,jjj+2).eq.pixpu.or.
     .              pixx(iii+1,jjj+2).eq.pixpu.or.
     .              pixx(iii+2,jjj+2).eq.pixpu.or.
     .              pixx(iii+2,jjj+1).eq.pixpu.or.
     .              pixx(iii+2,jjj  ).eq.pixpu.or.
     .              pixx(iii+2,jjj-1).eq.pixpu.or.
     .              pixx(iii+2,jjj-2).eq.pixpu.or.
     .              pixx(iii+1,jjj-2).eq.pixpu.or.
     .              pixx(iii  ,jjj-2).eq.pixpu.or.
     .              pixx(iii-1,jjj-2).eq.pixpu) then
                    ptot = ptot + (pixr(iii,jjj)-sr)
                    ftot = ftot + rpsf_phot(1.*(iii-i),
     .                                      1.*(jjj-j),psfloc)
                    nap  = nap  + 1
                    if (pixr(iii,jjj).gt.UPR_LIM) ntot = ntot + 1
                    endif
                enddo
                enddo
             if (ftot.le.0) ftot = 1.0
             rtot = SNGL(ftot)
             zr = SNGL(ptot/ftot)
             Ls = Ls + 1
             if (VERBOSE.ge.1.and.
     .           ((Ls.le.0010).or.
     .            (zr.gt.zrmax).or.
     .            (Ls.eq.Ls/010*010.and.Ls.le.100).or.
     .            (Ls.eq.Ls/100*100)))
     .            write( *,888) Ls,i,j,
     .                          -2.5*log10(max(zr,1.)),sr,
     .                          zr,ntot,nap,ftot
             if (zr.gt.zrmax) then
                 zrmax = zr
                 Lx = Ls
                 endif
             if (DIAG) write(93,888) Ls,i,j,
     .                               -2.5*log10(max(zr,1.0)),sr,
     .                               zr,ntot,nap,ftot
  888        format(16x,i5.5,1x,i4.4,1x,i4.4,
     .                1x,f6.2,1x,f6.1,
     .                1x,f12.1,1x,i6,1x,i6,1x,f6.4)
  889        format(16x,'-----',1x,'----',1x,'----',
     .               1x,'------',1x,'------',
     .               1x,'------------',
     .               1x,'------',1x,'------',
     .               1x,'------')
  887        format(16x,' LIST',1x,'  I ',1x,'  J ',
     .               1x,'  MAG ',1x,'  SKY ',
     .               1x,'     FLUX   ',
     .               1x,' NSAT ',1x,'  NAP ',
     .               1x,'PSFTOT')
             pixr(i,j) = zr
             il(Ls) = i
             jl(Ls) = j
             zl(Ls) = zr
             if (DIAG) write(55,112) i,j,0.5,'blue'
  112        format('image;circle( ',i4,',',i4,',',f6.3,') # color=',a7)
             endif
   47    continue
         enddo
         enddo
      if (DIAG) close(93)
      if (DIAG) close(55)
      if (VERBOSE.ge.1) then
          write(*,889)
          write(*,887)
          write(*,889)
          write(*,*)
          write(*,116) Ls,'L',Lx, il(Lx), jl(Lx), -2.5*log10(zl(Lx))
  116     format(16x,'MEASURED SATd STARS: ',i4,
     .            3x,'BRIGHTEST: ',a1,i4.4,2i5.4,f8.2)
          endif
      if (VERBOSE.ge.2) then
          print*,'                     '
          print*,'EXIT : sat_phot_NAXIS'
          print*,'                     '
          endif
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/PROC_SATN/max_contig_drz.f"
c****                                         
c*********************************************
                                              
 
c--------------------------------------------------------
c
c
c
c
      subroutine max_contig_drz(pixp,pixx,pixu,NX,NY)
      implicit none
 
      integer NX, NY
      real    pixp(NX,NY)
      real    pixx(NX,NY)
      byte    pixu(NX,NY)
      integer i ,j
 
c     integer jmin
c     integer jmax
 
c     real    pmax
      integer NIT, NCHG
 
      do i = 0001, NX
      do j = 0001, NY
         pixx(i,j) = pixp(i,j)
         enddo
         enddo
 
      NIT  = 1
    1 NIT  = NIT + 1
      NCHG = 0
      do j = 0002, NY-1,  1
      do i = 0002, NX-1,  1
         if (pixu(i,j).eq.1) then
            if (pixx(i,j).lt.pixx(i+1,j  )) then
               pixx(i,j) = pixx(i+1,j  )
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i-1,j  )) then
               pixx(i,j) = pixx(i-1,j  )
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i  ,j+1)) then
               pixx(i,j) = pixx(i  ,j+1)
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i  ,j-1)) then
               pixx(i,j) = pixx(i  ,j-1)
               NCHG = NCHG + 1
               endif
            endif
         enddo
         enddo
      do j = NY-1, 0002, -1
      do i = 0002, NX-1,  1
         if (pixu(i,j).eq.1) then
            if (pixx(i,j).lt.pixx(i+1,j  )) then
               pixx(i,j) = pixx(i+1,j  )
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i-1,j  )) then
               pixx(i,j) = pixx(i-1,j  )
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i  ,j+1)) then
               pixx(i,j) = pixx(i  ,j+1)
               NCHG = NCHG + 1
               endif
            if (pixx(i,j).lt.pixx(i  ,j-1)) then
               pixx(i,j) = pixx(i  ,j-1)
               NCHG = NCHG + 1
               endif
            endif
         enddo
         enddo
      write(*,'(''  NIT: '',i6,1x,i8)') NIT,NCHG
      if (NCHG.gt.0) goto 1
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/PROC_SATN/peak_sat_drz.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------
c
c this routine will go through the image pixr() and
c generate two supplemental images:  pixp() and pixx().
c pixp() gives a sense of how saturated each saturated
c pixel is, and pixx() tells you what the maximum value
c is for a touching saturated pixel ; if pixx.eq.pixp,
c then the pixel is the maximum of its distribution
c
      subroutine peak_sat_drz(pixr,pixu,pixp,pixx,NX,NY)
      implicit none
 
      integer NX, NY
      real pixr(NX,NY)
      byte pixu(NX,NY)
      real pixp(NX,NY)
      real pixx(NX,NY)
 
      integer i,j
      integer ii,jj
      integer r
 
      integer nsat, ntot
      real    ptota
      real    ptotb
      real    ptot
 
      print*,'ENTER PEAK_SAT...'
 
      ptota = 0
      ptotb = 0
      ptot  = 0
 
      do i = 00001+0005, NX-0005
      if (i.eq.i/100*100) print*,'  i: ',i
      do j = 00001+0005, NY-0005
         pixp(i,j) = 0
         if (pixu(i,j).eq.1) then
            r = 2
    1       continue
            nsat = 0
            ntot = 0
            ptot = 0
            do ii = -r, +r
            do jj = -r, +r
               if (i+r.lt.0001.or.
     .             i+r.gt.4096.or.
     .             j+r.lt.0001.or.
     .             j+r.gt.4096) then
                   pixp(i,j) = -750
                   goto 666
                   endif
               if (ii**2+jj**2.le.(r+0.5)**2) then
                  ntot = ntot + 1
                  ptot = ptot + max(pixr(i+ii,j+jj),0.0)
                  if (pixu(i+ii,j+jj).eq.1) nsat = nsat + 1
                  endif
               enddo
               enddo
            if (nsat.gt.0.85*ntot) then
               r = r + 1
               goto 1
               endif
            pixp(i,j) = ptot + ptota + ptotb
            endif
  666    continue
         enddo
         enddo
 
      print*,'               '
      print*,'FIND MAX_CONTIG_DRZ...'
      print*,'---> go through the image pixel by pixel and determine'
      print*,'     the brightest pixp pixel that is saturatedly '
      print*,'     contiguous'
      print*,'               '
      call max_contig_drz(pixp,pixx,pixu,NX,NY)
 
      print*,'               '
      print*,'               '
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/rd2x.f"
c****                                         
c*********************************************
                                              
c-----------------------------------------------
c
c This routine will take an (ra,dec) and a
c tangent-point (ra0,dec0) and will compute
c the x coordinate in the tangent plane.  The
c tangent-plane x-axis is directed along -RA.
c The units for x will be degrees, just lilke
c those for RA and DEC.
c
      real*8 function rd2x(r,d,r0,d0)
      implicit none
 
      real*8 r, d
      real*8 r0,d0
 
      real*8 cosra, sinra
      real*8 cosde, sinde
      real*8 cosd0, sind0
      real*8 rrrr
      real*8 xrad
      real*8 x, y, z
      real*8 xx,yy,zz
 
      cosra = cos((r-r0)*(_PI_)/180.0d0)
      sinra = sin((r-r0)*(_PI_)/180.0d0)
 
      cosde = cos(d *(_PI_)/180.0d0)
      sinde = sin(d *(_PI_)/180.0d0)
      cosd0 = cos(d0*(_PI_)/180.0d0)
      sind0 = sin(d0*(_PI_)/180.0d0)
 
      rrrr = sind0*sinde + cosd0*cosde*cosra
 
 
      xrad = cosde*sinra/rrrr
      rd2x = xrad*180.0d0/_PI_
 
      x  = cosde*cos(r *(_PI_)/180.0d0)
      y  = cosde*sin(r *(_PI_)/180.0d0)
      z  = sinde
      xx = cosd0*cos(r0*(_PI_)/180.0d0)
      yy = cosd0*sin(r0*(_PI_)/180.0d0)
      zz = sind0
 
      if (x*xx + y*yy + z*zz.lt.0) rd2x = 90.0
 
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/rd2y.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------
c
c This routine will take an (ra,dec) and a
c tangent-point (ra0,dec0) and will compute
c the y coordinate in the tangent plane.  The
c tangent-plane y-axis is directed along +DEC.
c The units for y will be degrees, just lilke
c those for RA and DEC.
c
      real*8 function rd2y(r,d,r0,d0)
      implicit none
 
      real*8 r, d
      real*8 r0,d0
 
      real*8 cosra, sinra
      real*8 cosde, sinde
      real*8 cosd0, sind0
      real*8 rrrr
      real*8 yrad
      real*8 x, y, z
      real*8 xx,yy,zz
 
      cosra = cos((r-r0)*(_PI_)/180.0d0)
      sinra = sin((r-r0)*(_PI_)/180.0d0)
      cosde = cos(d *(_PI_)/180.0d0)
      sinde = sin(d *(_PI_)/180.0d0)
      cosd0 = cos(d0*(_PI_)/180.0d0)
      sind0 = sin(d0*(_PI_)/180.0d0)
 
      rrrr = sind0*sinde + cosd0*cosde*cosra
 
      yrad = (cosd0*sinde-sind0*cosde*cosra)/rrrr
      rd2y = yrad*180.0d0/_PI_
 
      x  = cosde*cos(r *(_PI_)/180.0d0)
      y  = cosde*sin(r *(_PI_)/180.0d0)
      z  = sinde
      xx = cosd0*cos(r0*(_PI_)/180.0d0)
      yy = cosd0*sin(r0*(_PI_)/180.0d0)
      zz = sind0
 
      if (x*xx + y*yy + z*zz.lt.0) rd2y = 90
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/xy2r.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------
c
c This routine will take a point (x,y) in the
c tangent plane, and the coordinate of the
c tangent-point (ra0,dec0), and will compute
c the ra coordinate that corresponds to (x,y).
c
      real*8 function xy2r(x,y,r0,d0)
      implicit none
 
      real*8 x, y
      real*8 r0,d0
 
c     real*8 cosde, sinde
      real*8 cosd0, sind0
      real*8 tandr, dr
      real*8 xrad, yrad
 
      xrad = x/180.0d0*(_PI_)
      yrad = y/180.0d0*(_PI_)
 
      cosd0 = cos(d0*(_PI_)/180.0d0)
      sind0 = sin(d0*(_PI_)/180.0d0)
 
      tandr = xrad/(cosd0-yrad*sind0)
      dr    = atan(tandr)
      xy2r  = r0 + dr*180.0d0/(_PI_)
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/xy2d.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------
c
c This routine will take a point (x,y) in the
c tangent plane, and the coordinate of the
c tangent-point (ra0,dec0), and will compute
c the ra coordinate that corresponds to (x,y).
c
      real*8 function xy2d(x,y,r0,d0)
      implicit none
 
      real*8 x, y
      real*8 r0,d0
 
      real*8 cosd0, sind0
      real*8 tandr, dr
      real*8 cosdr
      real*8 tande
      real*8 xrad, yrad
 
      if (r0.gt.0) continue
 
      xrad = x/180.0d0*(_PI_)
      yrad = y/180.0d0*(_PI_)
 
      cosd0 = cos(d0*(_PI_)/180.0d0)
      sind0 = sin(d0*(_PI_)/180.0d0)
 
      tandr = xrad/(cosd0-yrad*sind0)
      dr    = atan(tandr)
 
      cosdr = cos(dr)
 
      tande = cosdr*(sind0+yrad*cosd0)/
     .              (cosd0-yrad*sind0)
 
      !print*,'---> tande: ',tande
      xy2d = atan(tande)*180.0d0/(_PI_)
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/rd2lb_G.f"
c****                                         
c*********************************************
                                              
 
c--------------------------------------
c
c ra,dec to Galactic longitude, latitude
c
      subroutine rd2lb_G(ra,dec,l,b)
      implicit none
 
      real*8 ra, dec
      real*8 l, b
 
      b = 180/3.14159*asin(cos(3.14159/180*dec)
     .                    *cos(3.14159/180*27.4)
     .                    *cos(3.14159/180*(ra-192.25))
     .                    +sin(3.14159/180*dec)
     .                    *sin(3.14159/180*27.4))
 
      l = 180/3.14159*atan2(sin(3.14159/180*dec)
     .                     -sin(3.14159/180*b)
     .                     *sin(3.14159/180*27.4)
     .                     ,cos(3.14159/180*dec)
     .                     *sin(3.14159/180*(ra-192.25))
     .                     *cos(3.14159/180*27.4)) + 33.
 
      if (b.gt.180) b = b - 360
      if (l.lt.000) l = l + 360
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/lb2rd_G.f"
c****                                         
c*********************************************
                                              
 
c--------------------------------------
c
c Galactic longitude, latitude to ra, dec
c
      subroutine lb2rd_G(l,b,ra,dec)
      implicit none
 
      real*8 l, b
      real*8 ra, dec
 
      dec = 180/3.14159*asin(cos(3.14159/180*b)
     .                      *cos(3.14159/180*27.4)
     .                      *sin(3.14159/180*(l-33.0))
     .                      +sin(3.14159/180*b)
     .                      *sin(3.14159/180*27.4))
 
      ra = 180/3.14159*atan2(cos(3.14159/180*b)
     .                      *cos(3.14159/180*(l-33))
     .                      ,sin(3.14159/180*b)
     .                      *cos(3.14159/180*27.4)
     .                      -cos(3.14159/180*b)
     .                      *sin(3.14159/180*27.4)
     .                      *sin(3.14159/180*(l-33))) + 192.25
 
      if (l.lt.0) l = l + 360
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/rd2lb_E.f"
c****                                         
c*********************************************
                                              
 
c--------------------------------------
c
c ra,dec to ecliptic longitude, latitude
c
      subroutine rd2lb_E(ra,dec,l,b)
      implicit none
 
      real*8 ra, dec
      real*8 l, b
 
      real*8 pi8
      real*8 ls8
 
      pi8 = 3.1415926535897932
      ls8 = 23.44189
 
 
      b = 180d0/pi8*asin(sin(pi8/180d0*dec)
     .                     *cos(pi8/180d0*ls8)
     .                     -cos(pi8/180d0*dec)
     .                     *sin(pi8/180d0*ls8)
     .                     *sin(pi8/180d0*ra))
 
      l = 180d0/pi8*atan2(sin(pi8/180d0*ra)
     .                     *cos(pi8/180d0*ls8)
     .                     +tan(pi8/180d0*dec)
     .                     *sin(pi8/180d0*ls8)
     .                     ,cos(pi8/180d0*ra))
 
      if (b.gt.180) b = b - 360
      if (l.lt.000) l = l + 360
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/lb2rd_E.f"
c****                                         
c*********************************************
                                              
 
c--------------------------------------
c
c ra,dec to ecliptic longitude, latitude
c
      subroutine lb2rd_E(l,b,ra,dec)
      implicit none
 
      real*8 l, b
      real*8 ra, dec
 
      real*8 pi8
      real*8 ls8
 
      pi8 = 3.1415926535897932
      ls8 = 23.44189
 
      dec = 180d0/pi8*asin(sin(pi8/180d0*ls8)
     .                       *sin(pi8/180d0*l)
     .                       *cos(pi8/180d0*b)
     .                       +cos(pi8/180d0*ls8)
     .                       *sin(pi8/180d0*b))
 
      ra  = 180d0/pi8*atan2(cos(pi8/180d0*ls8)
     .                       *sin(pi8/180d0*l)
     .                       *cos(pi8/180d0*b)
     .                       -sin(pi8/180d0*ls8)
     .                       *sin(pi8/180d0*b)
     .                       ,cos(pi8/180d0*l)
     .                       *cos(pi8/180d0*b))
 
      if (ra.lt.0) ra = ra + 360.0d0
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/string2ra.f"
c****                                         
c*********************************************
                                              
 
c-------------------------------------------
c
c this routine will convert a string into RA,
c it can handle both decimal and sexigesimal
c
      real*8 function string2ra(string)
      implicit none
      character*15 string
 
      logical iscolon
      character*15 stringc
      real rah, ram, ras
      integer i
 
      iscolon = .false.
      do i = 01, 15
         stringc(i:i) = string(i:i)
         if (stringc(i:i).eq.':') then
            iscolon = .true.
            stringc(i:i) = ' '
            endif
         enddo
 
      if (.not.iscolon) then
         read(stringc,*) string2ra
         return
         endif
      if (iscolon) then
         read(stringc,*) RAH, RAM, RAS
         string2ra = (rah + ram/60. + ras/60./60.)*15.0
         return
         endif
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/string2de.f"
c****                                         
c*********************************************
                                              
 
c-------------------------------------------
c
c this routine will convert a string into RA,
c it can handle both decimal and sexigesimal
c
      real*8 function string2de(string)
      implicit none
      character*15 string
 
      logical iscolon
      logical isneg
      character*15 stringc
      real DED, DEM, DES
      integer i
 
 
      iscolon = .false.
      isneg   = .false.
      do i = 01, 15
         stringc(i:i) = string(i:i)
         if (stringc(i:i).eq.':') then
            iscolon = .true.
            stringc(i:i) = ' '
            endif
         if (stringc(i:i).eq.'-') isneg = .true.
         enddo
 
      if (.not.iscolon) then
         read(stringc,*) string2de
         return
         endif
 
      if (iscolon) then
         read(stringc,*) DED, DEM, DES
         string2de = (abs(DED) + DEM/60. + DES/60./60.)
         if (isneg) string2de = -string2de
         return
         endif
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/ra2sexig.f"
c****                                         
c*********************************************
                                              
 
c-------------------------------------------
c
c this routine will convert a string into RA,
c it can handle both decimal and sexigesimal
c
      character*11 function ra2sexig(ra)
      implicit none
      real*8 ra
 
      integer rah, ram, rasi, rasf_x100
      real*8  ras, rasf
 
      rah  = int(ra/15)
      ram  = int((ra/15-rah)*60)
      ras  = (ra/15-rah-ram/60.)*60*60
      rasi = int(ras)
      rasf = ras-rasi
      rasf_x100 = int(rasf*100)
 
      write(ra2sexig,'(i2.2,'':'',i2.2,'':'',i2.2,''.'',i2.2)')
     .    rah, ram, rasi, rasf_x100
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/de2sexig.f"
c****                                         
c*********************************************
                                              
 
c-------------------------------------------
c
c this routine will convert a string into RA,
c it can handle both decimal and sexigesimal
c
      character*12 function de2sexig(de)
      implicit none
      real*8 de
 
      real*8  deu
      integer ded, dem, desi, desf_x10
      real*8  des, desf
      character neg
 
      neg = '+'
      if (de.lt.0) neg = '-'
      deu = abs(de)
      ded = int(deu)
      dem = int((deu-ded)*60)
      des = (deu-ded-dem/60.)*60*60
      desi = int(des)
      desf = des-desi
      desf_x10 = int(desf*100)
 
      write(de2sexig,'(a1,i2.2,'':'',i2.2,'':'',i2.2,''.'',i2.2)')
     .    neg, ded, dem, desi, desf_x10
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/fill_wcs_info.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------------
c
c
c
c
      subroutine fill_wcs_info(WCSMODE,NAME,
     .                         CRPIX1_OUT,CRPIX2_OUT,
     .                         CRVAL1_OUT,CRVAL2_OUT,
     .                          CD1_1_OUT, CD1_2_OUT,
     .                          CD2_1_OUT, CD2_2_OUT,
     .                         RCD1_1_OUT,RCD1_2_OUT,
     .                         RCD2_1_OUT,RCD2_2_OUT)
      implicit none
 
      character*(*) WCSMODE
      character*(*) NAME
      real*8        CRPIX1_OUT, CRPIX2_OUT
      real*8        CRVAL1_OUT, CRVAL2_OUT
      real*8         CD1_1_OUT,  CD1_2_OUT
      real*8         CD2_1_OUT,  CD2_2_OUT
      real*8        RCD1_1_OUT, RCD1_2_OUT
      real*8        RCD2_1_OUT, RCD2_2_OUT
 
      character*80 STRING
 
      character*11 ra_string11, ra2sexig
      character*12 de_string12, de2sexig
 
      integer ira_hr
      integer ira_mn
      real    rra_sc
      integer ide_dg
      integer ide_mn
      real    rde_sc
 
      real*8 rRA, rDE
      real*8 rRA0,rDE0
      integer i, ii
 
      character*20 STREAM
      character*80 WCSFILE
 
      WCSFILE = 'NOT FILLED'
c
c------------------------------------------------------------
c
 
      rRA = CRVAL1_OUT
      rDE = CRVAL2_OUT
 
      CRPIX1_OUT = 14100
      CRPIX2_OUT = 14100
      CRVAL1_OUT =    84.537400D0
      CRVAL2_OUT =   -69.138889D0
      CD1_1_OUT  = -9.010672487D-06
      CD1_2_OUT  = -6.309340800D-06
      CD2_1_OUT  = -6.309340800D-06
      CD2_2_OUT  =  9.010672487D-06
 
      CRPIX1_OUT = -9999.00d0
      CRPIX2_OUT = -9999.00d0
      CRVAL1_OUT = -9999.00d0
      CRVAL2_OUT = -9999.00d0
      CD1_1_OUT  = -9999.00d0
      CD1_2_OUT  = -9999.00d0
      CD2_1_OUT  = -9999.00d0
      CD2_2_OUT  = -9999.00d0
 
      rRA0 = CRVAL1_OUT
      rDE0 = CRVAL2_OUT
 
      print*,'FIND_WCSINFO...'
      print*,'   MODE: ',WCSMODE
      print*,'   rRA : ',rRA , rDE
      print*,'   rRA0: ',rRA0, rDE0
 
      if (WCSMODE(1:4).eq.'FIND') then
         call find_obj(rRA,rDE,NAME,rRA0,rDE0)
         print*,'----> find_obj: '
         print*,'---->      rRA: ',rRA
         print*,'---->      rDE: ',rDE
         print*,'---->     NAME: ',NAME
         print*,'---->     rRA0: ',rRA0
         print*,'---->     rDE0: ',rDE0
         CRPIX1_OUT = 0.00
         CRPIX2_OUT = 0.00
         CRVAL1_OUT = rRA0
         CRVAL2_OUT = rDE0
         CD1_1_OUT  = -0.000013888888889d0
         CD1_2_OUT  =  0.000000000000000d0
         CD2_1_OUT  =  0.000000000000000d0
         CD2_2_OUT  =  0.000013888888889d0
         goto 999
         endif
 
      print*,'what is WCSMODE1? ', WCSMODE(1:4), WCSMODE
      if (WCSMODE(1:4).eq.'AUTO') then
         print*,'----> AUTO: '
         print*,'---->     rRA: ',rRA
         print*,'---->     rDE: ',rDE
         CRPIX1_OUT = 0.00
         CRPIX2_OUT = 0.00
         CRVAL1_OUT = rRA
         CRVAL2_OUT = rDE
         CD1_1_OUT  = -0.000013888888889d0
         CD1_2_OUT  =  0.000000000000000d0
         CD2_1_OUT  =  0.000000000000000d0
         CD2_2_OUT  =  0.000013888888889d0
         goto 999
         endif
 
      print*,'what is WCSMODE2? ', WCSMODE(1:4), WCSMODE
      if (WCSMODE(1:4).eq.'WCS=') then
          NAME = 'BY_WCS_TEXT'
          WCSFILE = WCSMODE(5:80)
          open(19,file=WCSFILE,status='old')
          write(*,'(''WCS2UV FILE: '',a80)') WCSFILE
          write(*,'('' '')')
   23     read(19,'(80a)',end=24) STRING
          write(*,'(''---> '',80a)') STRING
          ii = 0
          do i = 1, 80
             if (STRING(i:i).eq.'=') ii = i
             enddo
          if (ii.eq.0) then
             write(*,'(''WCSMODE: '',80a)') WCSMODE
             write(*,'(''PROBLEM WITH WCSFILE: '',80a)') WCSFILE
             write(*,'(''THERE IS NO = IN THIS STRING: '')')
             write(*,'(''STRING:  '',80a)') STRING
             stop
             endif
          if (STRING(1:10).eq.'CRPIX1_OUT')
     .        read(STRING(ii+1:80),*) CRPIX1_OUT
          if (STRING(1:10).eq.'CRPIX2_OUT')
     .        read(STRING(ii+1:80),*) CRPIX2_OUT
          if (STRING(1:10).eq.'CRVAL1_OUT')
     .        read(STRING(ii+1:80),*) CRVAL1_OUT
          if (STRING(1:10).eq.'CRVAL2_OUT')
     .        read(STRING(ii+1:80),*) CRVAL2_OUT
          if (STRING(1:09).eq.'CD1_1_OUT')
     .        read(STRING(ii+1:80),*) CD1_1_OUT
          if (STRING(1:09).eq.'CD1_2_OUT')
     .        read(STRING(ii+1:80),*) CD1_2_OUT
          if (STRING(1:09).eq.'CD2_1_OUT')
     .        read(STRING(ii+1:80),*) CD2_1_OUT
          if (STRING(1:09).eq.'CD2_2_OUT')
     .        read(STRING(ii+1:80),*) CD2_2_OUT
          goto 23
   24     close(19)
          write(*,'('' '')')
          goto 999
          endif
 
      if (WCSMODE(1:4).eq.'HDR=') then
          NAME = 'BYHDR'
          WCSFILE = WCSMODE(5:80)
          print*,'HDR_IS_FITS: ',WCSFILE(1:40)
          call query_hdre(WCSFILE,'CRPIX1  ',STREAM,-1)
          read(STREAM,*) CRPIX1_OUT
          call query_hdre(WCSFILE,'CRPIX2  ',STREAM,-1)
          read(STREAM,*) CRPIX2_OUT
          call query_hdre(WCSFILE,'CRVAL1  ',STREAM,-1)
          read(STREAM,*) CRVAL1_OUT
          call query_hdre(WCSFILE,'CRVAL2  ',STREAM,-1)
          read(STREAM,*) CRVAL2_OUT
          call query_hdre(WCSFILE,'CD1_1   ',STREAM,-1)
          read(STREAM,*) CD1_1_OUT
          call query_hdre(WCSFILE,'CD1_2   ',STREAM,-1)
          read(STREAM,*) CD1_2_OUT
          call query_hdre(WCSFILE,'CD2_1   ',STREAM,-1)
          read(STREAM,*) CD2_1_OUT
          call query_hdre(WCSFILE,'CD2_2   ',STREAM,-1)
          read(STREAM,*) CD2_2_OUT
          goto 999
          endif
 
      if (WCSMODE(1:4).eq.'RDC=') then
          NAME = 'BYRDC'
          print*,'RDC_OK: ',WCSMODE(1:40)
          if (WCSMODE(05:05).ne.'('.or.
     .        WCSMODE(08:08).ne.':'.or.
     .        WCSMODE(11:11).ne.':'.or.
     .        WCSMODE(16:16).ne.','.or.
     .        WCSMODE(20:20).ne.':'.or.
     .        WCSMODE(23:23).ne.':'.or.
     .        WCSMODE(29:29).ne.')') then
              print*,' '
              print*,'WCSMODE FORMAT PROBLEMS (MUST BE EXACT): '
              write(*,'('' TEMPLATE: '',80a)')
     .                'RDC=(00:23:13.5,+33:44:13.22)'
              write(*,'(''   ACTUAL: '',80a)') WCSMODE
              stop
              endif
          read(WCSMODE(06:07),*) ira_hr
          read(WCSMODE(09:10),*) ira_mn
          read(WCSMODE(12:15),*) rra_sc
          read(WCSMODE(18:19),*) ide_dg
          read(WCSMODE(21:22),*) ide_mn
          read(WCSMODE(24:28),*) rde_sc
          print*,'rde_sc: ',rde_sc
          CRPIX1_OUT = 0.000
          CRPIX2_OUT = 0.000
          CRVAL1_OUT = (ira_hr + ira_mn/60.0D0
     .                         + rra_sc/60.0D0/60.0D0)
     .                  *360.0D0/24.0D0
          CRVAL2_OUT = (ide_dg + ide_mn/60.0D0
     .                         + rde_sc/60.0D0/60.0D0)
          if (WCSMODE(17:17).eq.'-') CRVAL2_OUT = -CRVAL2_OUT
          CD1_1_OUT  = -0.000013888889
          CD1_2_OUT  =  0.000000000000
          CD2_1_OUT  =  0.000000000000
          CD2_2_OUT  =  0.000013888889
          goto 999
          endif
 
      if (WCSMODE(1:6).eq.'RDCD=(') then
          STRING = WCSMODE(7:80)
          do i = 01, 80
             if (STRING(i:i).eq.')') STRING(i:i) = ' '
             enddo
          read(STRING,*) CRVAL1_OUT, CRVAL2_OUT
          CRPIX1_OUT = 0.000
          CRPIX2_OUT = 0.000
          CD1_1_OUT  = -0.000013888889
          CD1_2_OUT  =  0.000000000000
          CD2_1_OUT  =  0.000000000000
          CD2_2_OUT  =  0.000013888889
          goto 999
          endif
 
      print*,' '
      write(*,'(''THE WCS DID NOT GET SPECIFIED ADEQUATELY...'')')
      write(*,'(''WCSMODE: '',80a)') WCSMODE
      write(*,'(''WCSFILE: '',80a)') WCSFILE
      print*,' '
      stop
 
  999 continue
      if (CRPIX1_OUT.lt.-9990.or.CRPIX2_OUT.lt.-9990.or.
     .    CRVAL1_OUT.lt.-9990.or.CRVAL2_OUT.lt.-9990.or.
     .    CD1_1_OUT .lt.-9990.or.CD1_2_OUT .lt.-9990.or.
     .    CD2_1_OUT .lt.-9990.or.CD2_2_OUT .lt.-9990) then
          print*,'INSUFFICIENT SPECIFIED WCS INFO.  NEED ALL 8: '
          print*,'  CRPIX1_OUT: ',CRPIX1_OUT
          print*,'  CRPIX2_OUT: ',CRPIX2_OUT
          print*,'  CRVAL1_OUT: ',CRVAL1_OUT
          print*,'  CRVAL2_OUT: ',CRVAL2_OUT
          print*,'   CD1_1_OUT: ', CD1_1_OUT
          print*,'   CD1_2_OUT: ', CD1_2_OUT
          print*,'   CD2_1_OUT: ', CD2_1_OUT
          print*,'   CD2_2_OUT: ', CD2_2_OUT
          stop
          endif
 
      RCD1_1_OUT= CD2_2_OUT/(CD1_1_OUT*CD2_2_OUT-CD2_1_OUT*CD1_2_OUT)
      RCD1_2_OUT=-CD1_2_OUT/(CD1_1_OUT*CD2_2_OUT-CD2_1_OUT*CD1_2_OUT)
      RCD2_1_OUT=-CD2_1_OUT/(CD1_1_OUT*CD2_2_OUT-CD2_1_OUT*CD1_2_OUT)
      RCD2_2_OUT= CD1_1_OUT/(CD1_1_OUT*CD2_2_OUT-CD2_1_OUT*CD1_2_OUT)
      ra_string11 = ra2sexig(CRVAL1_OUT)
      de_string12 = de2sexig(CRVAL2_OUT)
 
      if (.false.) then
         write(*,'('' '')')
         write(*,'(''INPUT WCS2PIX INFORMATION...'')')
         write(*,'('' CRPIX12:  '',2f20.10)') CRPIX1_OUT, CRPIX2_OUT
         write(*,'('' CRVAL12:  '',2f20.10,5x,a10,1x,a12)')
     .                           CRVAL1_OUT,CRVAL2_OUT,
     .                           ra_string11, de_string12
         write(*,'(''  CD1_12:  '',2f20.10)')  CD1_1_OUT,  CD1_2_OUT
         write(*,'(''  CD2_12:  '',2f20.10)')  CD2_1_OUT,  CD2_2_OUT
         write(*,'('' RCD1_12:  '',2f20.10)') RCD1_1_OUT, RCD1_2_OUT
         write(*,'('' RCD2_12:  '',2f20.10)') RCD2_1_OUT, RCD2_2_OUT
         write(*,'('' '')')
         write(*,'(''PIXEL SCALE --- '',f6.3,'' ARCSEC/PIX '')')
     .            sqrt(-CD1_1_OUT*CD2_2_OUT+CD2_1_OUT*CD1_2_OUT)*60*60
         write(*,'('' '')')
         endif
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/inside_poly.f"
c****                                         
c*********************************************
                                              
 
 
c-----------------------------------------------
c
c reports whether a point is inside a convex
c polygon
c
      logical function inside_poly(x,y,xl,yl,Ns)
      implicit none
 
      real*8 x,y
      integer Ns
      real*8 xl(Ns), yl(Ns)
 
      integer n
      real*8  cross1
      real*8  crossN
 
      inside_poly = .true.
      cross1 = (x-xl(Ns))*(yl(1)-yl(Ns))
     .       - (y-yl(Ns))*(xl(1)-xl(Ns))
      do n = 1, Ns-1
           crossN = (x-xl(N))*(yl(N+1)-yl(N))
     .            - (y-yl(N))*(xl(N+1)-xl(N))
           if (cross1*crossN.le.0) inside_poly = .false.
           enddo
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/find_obj.f"
c****                                         
c*********************************************
                                              
 
c----------------------------------------------------
c
c find the closest object of interest to this
c location; info from HARRIS' on-line catalog
c is contained within data statements.
c
      subroutine find_obj(rRA,rDC,NAME,rRA0,rDC0)
      implicit none
      real*8 rRA , rDC      ! input
      character*11 NAME     ! output (nearest obj)
      real*8 rRA0, rDC0     ! output (locn)
 
      real*8 rRAn, rDCn
      real*8 dRA,  dDC
      real*8 dDD, dmin
      integer N
      character*10 RSTRING
      character*09 DSTRING
 
      integer iRAH, iRAM
      real    rRAS
      integer iDEG, iMIN, iSEC
 
#define _NOBJ_ 191
      character*35 INFO(_NOBJ_)
      common /INFO/INFO ! need to do this in LINUX to preserve
      data INFO /
     .'NGC0104 47T 00 24 05.2 -72 04 51.00',
     .'NGC0288     00 52 47.5 -26 35 24.00',
     .'NGC0362     01 03 14.3 -70 50 54.00',
     .'NGC1261     03 12 15.3 -55 13 01.00',
     .'Pal1        03 33 23.0 +79 34 50.00',
     .'AM1     E01 03 55 02.7 -49 36 52.00',
     .'Eridanus    04 24 44.5 -21 11 13.00',
     .'Pal2        04 46 05.9 +31 22 51.00',
     .'NGC1851     05 14 06.3 -40 02 50.00',
     .'NGC1904 M79 05 24 10.6 -24 31 27.00',
     .'NGC2298     06 48 59.2 -36 00 19.00',
     .'NGC2419     07 38 08.5 +38 52 55.00',
     .'Pyxis       09 07 57.8 -37 13 17.00',
     .'NGC2808     09 12 02.6 -64 51 47.00',
     .'E3          09 20 59.3 -77 16 57.00',
     .'Pal3        10 05 31.4 +00 04 17.00',
     .'NGC3201     10 17 36.8 -46 24 40.00',
     .'Pal4        11 29 16.8 +28 58 25.00',
     .'NGC4147     12 10 06.2 +18 32 31.00',
     .'NGC4372     12 25 45.4 -72 39 33.00',
     .'Rup106      12 38 40.2 -51 09 01.00',
     .'NGC4590 M68 12 39 28.0 -26 44 34.00',
     .'NGC4833     12 59 35.0 -70 52 29.00',
     .'NGC5024 M53 13 12 55.3 +18 10 09.00',
     .'NGC5053     13 16 27.0 +17 41 53.00',
     .'NGC5139 OMC 13 26 45.9 -47 28 37.00',
     .'NGC5272 M03 13 42 11.2 +28 22 32.00',
     .'NGC5286     13 46 26.5 -51 22 24.00',
     .'AM4         13 55 50.1 -27 10 22.00',
     .'NGC5466     14 05 27.3 +28 32 04.00',
     .'NGC5634     14 29 37.3 -05 58 35.00',
     .'NGC5694     14 39 36.5 -26 32 18.00',
     .'IC4499      15 00 18.5 -82 12 49.00',
     .'NGC5824     15 03 58.5 -33 04 04.00',
     .'Pal5        15 16 05.3 -00 06 41.00',
     .'NGC5897     15 17 24.5 -21 00 37.00',
     .'NGC5904 M05 15 18 33.8 +02 04 58.00',
     .'NGC5927     15 28 00.5 -50 40 22.00',
     .'NGC5946     15 35 28.5 -50 39 34.00',
     .'BH176       15 39 07.3 -50 03 02.00',
     .'NGC5986     15 46 03.5 -37 47 10.00',
     .'Lynga7      16 11 03.0 -55 18 52.00',
     .'Pal14       16 11 04.9 +14 57 29.00',
     .'NGC6093 M80 16 17 02.5 -22 58 30.00',
     .'NGC6121 M04 16 23 35.5 -26 31 31.00',
     .'NGC6101     16 25 48.6 -72 12 06.00',
     .'NGC6144     16 27 14.1 -26 01 29.00',
     .'NGC6139     16 27 40.4 -38 50 56.00',
     .'Terzan 3    16 28 40.1 -35 21 13.00',
     .'NGC6171     16 32 31.9 -13 03 13.00',
     .'1636-283    16 39 25.5 -28 23 52.00',
     .'NGC6205 M13 16 41 41.5 +36 27 37.00',
     .'NGC6229     16 46 58.9 +47 31 40.00',
     .'NGC6218 M12 16 47 14.5 -01 56 52.00',
     .'NGC6235     16 53 25.4 -22 10 38.00',
     .'NGC6254 M10 16 57 08.9 -04 05 58.00',
     .'NGC6256     16 59 32.6 -37 07 17.00',
     .'Pal15       17 00 02.4 -00 32 31.00',
     .'NGC6266 M62 17 01 12.8 -30 06 49.00',
     .'NGC6273 M19 17 02 37.8 -26 16 05.00',
     .'NGC6284     17 04 28.8 -24 45 53.00',
     .'NGC6287     17 05 09.4 -22 42 29.00',
     .'NGC6293     17 10 10.2 -26 34 55.00',
     .'NGC6304     17 14 32.1 -29 27 44.00',
     .'NGC6316     17 16 37.3 -28 08 24.00',
     .'NGC6341 M92 17 17 07.3 +43 08 11.00',
     .'NGC6325     17 17 59.2 -23 45 57.00',
     .'NGC6333 M09 17 19 11.8 -18 30 59.00',
     .'NGC6342     17 21 10.2 -19 35 14.00',
     .'NGC6356     17 23 35.0 -17 48 47.00',
     .'NGC6355     17 23 58.6 -26 21 13.00',
     .'NGC6352     17 25 29.2 -48 25 22.00',
     .'IC1257      17 27 08.5 -07 05 35.00',
     .'Terzan2 HP3 17 27 33.1 -30 48 08.00',
     .'NGC6366     17 27 44.3 -05 04 36.00',
     .'Terzan4 HP4 17 30 39.0 -31 35 44.00',
     .'HP1         17 31 05.2 -29 58 54.00',
     .'NGC6362     17 31 54.8 -67 02 53.00',
     .'Liller1     17 33 24.5 -33 23 20.00',
     .'NGC6380 Ton 17 34 28.0 -39 04 09.00',
     .'Terzan1     17 35 47.2 -30 28 54.00',
     .'Ton2        17 36 10.5 -38 33 12.00',
     .'NGC6388     17 36 17.0 -44 44 06.00',
     .'NGC6402 M14 17 37 36.1 -03 14 45.00',
     .'NGC6401     17 38 36.6 -23 54 34.00',
     .'NGC6397     17 40 41.3 -53 40 25.00',
     .'Pal6        17 43 42.2 -26 13 21.00',
     .'NGC6426     17 44 54.7 +03 10 13.00',
     .'Djorg1      17 47 28.3 -33 03 56.00',
     .'Terzan5 Trz 17 48 04.9 -24 46 45.00',
     .'NGC6440     17 48 52.7 -20 21 37.00',
     .'NGC6441     17 50 12.9 -37 03 05.00',
     .'Terzan6 HP5 17 50 46.4 -31 16 31.00',
     .'NGC6453     17 50 51.7 -34 35 57.00',
     .'UKS1        17 54 27.2 -24 08 43.00',
     .'NGC6496     17 59 02.0 -44 15 54.00',
     .'Terzan9     18 01 38.8 -26 50 23.00',
     .'Djorg2      18 01 49.1 -27 49 33.00',
     .'NGC6517     18 01 50.6 -08 57 32.00',
     .'Terzan10    18 02 57.4 -26 04 00.00',
     .'NGC6522     18 03 34.1 -30 02 02.00',
     .'NGC6535     18 03 50.7 -00 17 49.00',
     .'NGC6528     18 04 49.6 -30 03 21.00',
     .'NGC6539     18 04 49.8 -07 35 09.00',
     .'NGC6540 Dj  18 06 08.6 -27 45 55.00',
     .'NGC6544     18 07 20.6 -24 59 51.00',
     .'NGC6541     18 08 02.2 -43 30 00.00',
     .'2MSGC01     18 08 21.8 -19 49 47.00',
     .'ESOSC06     18 09 06.0 -46 25 23.00',
     .'NGC6553     18 09 17.6 -25 54 31.00',
     .'2MSGC02     18 09 36.5 -20 46 44.00',
     .'NGC6558     18 10 17.6 -31 45 50.00',
     .'IC1276  Pal 18 10 44.2 -07 12 27.00',
     .'Terzan12    18 12 15.8 -22 44 31.00',
     .'NGC6569     18 13 38.8 -31 49 37.00',
     .'NGC6584     18 18 37.7 -52 12 54.00',
     .'NGC6624     18 23 40.5 -30 21 40.00',
     .'NGC6626 M28 18 24 32.9 -24 52 12.00',
     .'NGC6638     18 30 56.1 -25 29 51.00',
     .'NGC6637 M69 18 31 23.2 -32 20 53.00',
     .'NGC6642     18 31 54.1 -23 28 31.00',
     .'NGC6652     18 35 45.7 -32 59 25.00',
     .'NGC6656 M22 18 36 24.2 -23 54 12.00',
     .'Pal8        18 41 29.9 -19 49 33.00',
     .'NGC6681 M70 18 43 12.7 -32 17 31.00',
     .'NGC6712     18 53 04.3 -08 42 22.00',
     .'NGC6715 M54 18 55 03.3 -30 28 42.00',
     .'NGC6717 Pal 18 55 06.2 -22 42 03.00',
     .'NGC6723     18 59 33.2 -36 37 54.00',
     .'NGC6749     19 05 15.3 +01 54 03.00',
     .'NGC6752     19 10 52.0 -59 59 05.00',
     .'NGC6760     19 11 12.1 +01 01 50.00',
     .'NGC6779 M56 19 16 35.5 +30 11 05.00',
     .'Terzan7     19 17 43.7 -34 39 27.00',
     .'Pal10       19 18 02.1 +18 34 18.00',
     .'Arp2        19 28 44.1 -30 21 14.00',
     .'NGC6809 M55 19 39 59.4 -30 57 44.00',
     .'Terzan8     19 41 45.0 -34 00 01.00',
     .'Pal11       19 45 14.4 -08 00 26.00',
     .'NGC6838 M71 19 53 46.1 +18 46 42.00',
     .'NGC6864 M75 20 06 04.8 -21 55 17.00',
     .'NGC6934     20 34 11.6 +07 24 15.00',
     .'NGC6981 M72 20 53 27.9 -12 32 13.00',
     .'NGC7006     21 01 29.5 +16 11 15.00',
     .'NGC7078 M15 21 29 58.3 +12 10 01.00',
     .'NGC7089 M02 21 33 29.3 -00 49 23.00',
     .'NGC7099 M30 21 40 22.0 -23 10 45.00',
     .'Pal12       21 46 38.8 -21 15 03.00',
     .'Pal13       23 06 44.4 +12 46 19.00',
     .'NGC7492     23 08 26.7 -15 36 41.00',
     .'ANDROMEDM31 00 42 44.3 +41 16 09.00',
     .'LMC         05 23 34.6 -69 45 22.00', ! for now replace LMC with JWST-CAL
     .'JWST-CALIB  05 21 57.0 -69 29 54.00',
     .'SMC         00 52 42.0 -72 49 00.00',
     .'BPTAU       04 19 15.8 +29 06 27.00',
     .'DFTAU       04 27 02.8 +25 42 22.00',
     .'ORION-PAR   05 35 25.0 -05 30 59.00',
     .'UDF         03 32 39.0 -27 47 29.00',
     .'JWST-CALIB  05 21 57.0 -69 29 54.00',
     .'BULGE-SWEEP 17 58 59.1 -29 12 17.73',
     .'BULGE-STANK 17 54 41.7 -29 49 30.00',
     .'BULGE-OGL29 17 48 15.3 -37 09 01.40',
     .'BULGE-BAADE 18 03 10.2 -29 56 33.60',
     .'TBROWN-DISK 18 59 45.0 -04 26 08.40',
     .'NGC6791     19 20 53.0 +37 46 30.00', ! <---
     .'SDSSJ090744 09 07 44.0 +02 45 06.40',
     .'SDSSJ093320 09 33 20.9 +44 17 05.50',
     .'HE0437-5439 04 38 12.8 -53 33 11.80',
     .'SDSSJ091301 09 13 01.0 +30 51 20.20',
     .'SDSSJ091759 09 17 59.6 +67 22 38.80',
     .'SDSSJ110557 11 05 57.5 +09 34 39.47',
     .'SDSSJ113312 11 33 12.1 +01 08 24.87',
     .'SDSSJ094214 09 42 14.1 +20 03 22.07',
     .'SDSSJ102137 10 21 37.1 -00 52 34.77',
     .'SDSSJ120337 12 03 37.6 +18 02 50.35',
     .'SDSSJ105009 10 50 09.6 +03 15 50.67',
     .'SDSSJ105248 10 52 48.3 -00 01 33.94',
     .'SDSSJ144955 14 49 55.6 +31 03 51.37',
     .'SDSSJ101018 10 10 18.8 +30 20 28.22',
     .'SDSSJ110224 11 02 24.4 +02 50 02.77',
     .'MO9-BLG-195 18 03 01.2 -28 23 26.50',
     .'MO9-BLG-046 17 54 43.4 -35 03 07.50',
     .'MO9-BLG-260 17 58 28.6 -26 50 21.10',
     .'OGL9-BULG-D 17 30 0.00 -29 00 00.00',
     .'OGL9-BULG-E 17 30 0.00 -30 00 00.00',
     .'SDSSJ142001 14 20 01.9 +12 44 04.70',
     .'PLEIADES_01 03 47 17.0 +24 14 50.60',
     .'PLEIADES_02 03 48 12.2 +23 59 07.30',
     .'PLEIADES_03 03 48 37.6 +24 13 11.40',
     .'30__DORADUS 05 38 40.0 -69 06 00.00',
     .'GALACTICCEN 17 45 40.0 -29 00 28.10'/
 
 
      dmin = 30.0       ! 30 arcmin finding radius
      NAME = 'NO ID'
      rRA0 = rRA
      rDC0 = rDC
      do N = 1, _NOBJ_
         RSTRING = INFO(N)(13:22)
         DSTRING = INFO(N)(24:32)
         read(RSTRING,*) iRAH,iRAM,rRAS
         read(DSTRING,*) iDEG,iMIN,iSEC
         rRAn = (iRAH+iRAM/60.+rRAS/60./60.)*360/24  ! in degs
         rDCn = abs(iDEG)+iMIN/60.+iSEC/60./60.      ! in degs
c        if (iDEG.lt.0) rDCn = -rDCn
         if (DSTRING(01:01).eq.'-') rDCn = -rDCn
         dRA = (rRA-rRAn)*60.0*cos(rDC*3.14159/180)  ! in arcmin (W+)
         dDC = (rDC-rDCn)*60.0                       ! in arcmin
         dDD = sqrt(dRA**2+dDC**2)
         if (dDD.lt.dmin) then
            dmin = dDD
            rRA0 = rRAn
            rDC0 = rDCn
            NAME = INFO(N)(01:11)
            endif
         enddo
 
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/PERT/find_psfpert.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------------
c
c this routine will derive a perturbation for a library
c PSF so that it will better fit an image
c
 
      subroutine find_psfpert(pixc,HMB,HIFLAG,NAXIS1,NAXIS2,
     .                        psfpert,NPERTs,
     .                        PSFFILE_USE,VERBOSE)
      implicit none
 
      real         pixc(NAXIS1,NAXIS2)
      real         HMB
      integer      HIFLAG
      integer      NAXIS1, NAXIS2
      real         psfpert(101,101,_NPRTMX_,_NPRTMX_)
      integer      NPERTs
      character*80 PSFFILE_USE
      integer      VERBOSE
 
      integer i, ii, iii
      integer j, jj, jjj
 
      real*8 xr, yr, fr, sr
      real   qr, cr
 
      real*8 xro, yro
 
      real   dx, dy
 
      real    FEST
      integer L, Ls
      integer il(99999)
      integer jl(99999)
      real*8  xl(99999)
      real*8  yl(99999)
      real    ml(99999)
      real    zl(99999)
      real    sl(99999)
      real    ql(99999)
      real    pl(99999)
      integer ul(99999)
      real    rxl(99999)
      real    ryl(99999)
      real    pixl(11,11,99999)
      real    psfl(11,11,99999)
 
      real    rpsf_phot
      real    psfloc(101,101)
c     real    dpsf(99999)
 
      real    fx, fy
 
      real   FMIN
      integer NIT
      real    histpert_ij(11,11), histpert_min
      real    psfpertu(101,101,_NPRTMX_,_NPRTMX_)
      real    psfpertv(101,101,_NPRTMX_,_NPRTMX_)
      integer PX, PY
      integer ipsf,jpsf
 
      FMIN = HIFLAG
 
      if (VERBOSE.ge.2) then
          print*,'                                               '
          print*,'ENTER FIND_PSFPERT:                            '
          print*,'                                               '
          print*,'   FIND THE AVERAGE DIFFERENCE BETWEEN THE     '
          print*,'   INPUT LIBRARY PSF AND THE PSF IN THIS IMAGE '
          print*,'                                               '
          print*,'         HIFLAG: ',HIFLAG
          print*,'           FMIN: ',FMIN
          print*,'            HMB: ',HMB
          print*,'            NIT: ',NIT
          print*,'         NAXIS1: ',NAXIS1
          print*,'         NAXIS2: ',NAXIS2
          print*,'            PSF: ',PSFFILE_USE
          print*,'         NPERTs: ',NPERTs
          print*,'                '
          endif
 
      if (NPERTs.gt.11) stop 'NPERTs.gt.11 ; 11 is the max possible'
 
      do PX = 1, NPERTs
      do PY = 1, NPERTs
         do i = 001, 101
         do j = 001, 101
            psfpertu(i,j,PX,PY) = 0.
            enddo
            enddo
         enddo
         enddo
 
      do PX = 1, NPERTs
      do PY = 1, NPERTs
         ii = int(1 + (PX-0.5)*(NAXIS1-1)/NPERTs)
         jj = int(1 + (PY-0.5)*(NAXIS2-1)/NPERTs)
         call locpsfij_stdpsf(ii,jj,psfpertv(1,1,PX,PY),PSFFILE_USE)
         enddo
         enddo
 
      if (VERBOSE.ge.2) then
          print*,'             '
          print*,'GO THROUGH WAVES FO FIND ENOUGH STARS FOR PSFPERT'
          print*,'                '
          endif
 
      histpert_min = 0
      NIT = 0
  3   continue
      NIT = NIT + 1
      if (VERBOSE.ge.2) then
          print*,'          '
          print*,'     NIT: ',NIT, FMIN, histpert_min
          print*,'          '
          endif
      Ls = 0
      do jj = 10, NAXIS2-10
      do ii = 10, NAXIS1-10
         if (pixc(ii,jj).lt.FMIN/9) goto 222
         if (pixc(ii,jj).gt.HIFLAG) goto 222
         FEST = pixc(ii-1,jj+1) + pixc(ii,jj+1) + pixc(ii+1,jj+1)
     .        + pixc(ii-1,jj  ) + pixc(ii,jj  ) + pixc(ii+1,jj  )
     .        + pixc(ii-1,jj-1) + pixc(ii,jj-1) + pixc(ii+1,jj-1)
     .        - HMB*9
         if (FEST.lt. FMIN) goto 222
         do i = -9, 9
         do j = -9, 9
            if (i**2+j**2.le.9.5**2) then
               if (pixc(ii+i,jj+j).gt.pixc(ii,jj)) goto 222
               endif
            if (i**2+j**2.le.5.5**2) then
               if (pixc(ii+i,jj+j).lt.-50) goto 222
               endif
            enddo
            enddo
         fx = (pixc(ii+1,jj)-pixc(ii-1,jj))/2/
     .        (pixc(ii  ,jj)-min(pixc(ii+1,jj),pixc(ii-1,jj)))
         fy = (pixc(ii,jj+1)-pixc(ii,jj-1))/2/
     .        (pixc(ii,jj  )-min(pixc(ii,jj+1),pixc(ii,jj-1)))
         xr = ii + fx
         yr = jj + fy
         xro = xr
         yro = yr
         sr = HMB
         call locpsfij_stdpsf(ii,jj,psfloc,PSFFILE_USE)
         call find_xyzXX_NAXIS(xr,yr,fr,sr,qr,cr,pixc,psfloc,
     .                         NAXIS1,NAXIS2,0,'5x5') ! 0 means weight by flux (center focus)
         if (qr.gt.0.5) goto 222  ! this may help prevent CRs from
         Ls = Ls + 1              ! being included
         if (Ls.gt.99999) then
            print*,'  Ls    : ', Ls
            print*,'       ii: ', ii
            print*,'       jj: ', jj
            print*,'  99999: ',99999
            stop
            endif
         il(Ls) = ii
         jl(Ls) = jj
         xl(Ls) = xr
         yl(Ls) = yr
         ml(Ls) = SNGL(-2.5*log10(max(fr,1.)))
         zl(Ls) = SNGL(fr)
         sl(Ls) = SNGL(sr)
c        ql(Ls) = SNGL(qr)
         ql(Ls) = qr
         pl(Ls) = pixc(ii,jj)
         ul(Ls) = 1
         rxl(Ls) = 1 + (ii-1.0)/NAXIS1*(NPERTs-1)
         ryl(Ls) = 1 + (jj-1.0)/NAXIS2*(NPERTs-1)
         do i = 01, 11
         do j = 01, 11
            iii = ii+(i-6)
            jjj = jj+(j-6)
            dx  = SNGL(iii-xl(Ls))
            dy  = SNGL(jjj-yl(Ls))
            pixl(i,j,Ls) = pixc(iii,jjj) - sl(Ls)
            psfl(i,j,Ls) = rpsf_phot(dx,dy,psfloc)
            enddo
            enddo
         if (VERBOSE.ge.2.and.
     .       ((Ls.lt.00025).or.
     .        (Ls.lt.00100.and.Ls.eq.Ls/0010*0010).or.
     .        (Ls.eq.Ls/0100*0100)))
     .   write( *,182) xl(Ls),yl(Ls),ml(Ls),zl(Ls),sl(Ls),
     .                 Ls,il(Ls),jl(Ls),
     .                 psfl(6,6,Ls),ql(Ls),
     .                 pixc(ii,jj)
 182     format(20x,f9.3,1x,f9.3,1x,f8.4,1x,f10.1,1x,f7.2,
     .           3x,i6,3x,i4,1x,i4,1x,f8.6,1x,f8.6,4x,2f9.1)
 222     continue
         enddo
         enddo
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,' Ls: ',Ls
          print*,'FMIN: ',FMIN
          endif
 
      histpert_min = 9e9
      do i = 1, NPERTs
      do j = 1, NPERTs
         histpert_ij(i,j) = 0
         do L = 1, Ls
            histpert_ij(i,j) = histpert_ij(i,j)
     .                       + max(1.-abs(i-rxl(L)),0.)
     .                       * max(1.-abs(j-ryl(L)),0.)
            enddo
         if (histpert_ij(i,j).lt.histpert_min)
     .       histpert_min = histpert_ij(i,j)
         enddo
         enddo
 
      if (VERBOSE.ge.2) then
          print*,' '
          write(*,'(2x,1x,11(4x,i2,4x))') (i,i=1,NPERTs)
          print*,' '
          do j = NPERTs, 1, -1
             write(*,'(i2,1x,11f10.1)') j,(histpert_ij(i,j),i=1,NPERTs)
             enddo
          print*,' '
          write(*,'(2x,1x,11(4x,i2,4x))') (i,i=1,NPERTs)
          print*,' '
          print*,'histpert_min: ',histpert_min
          print*,' '
          endif
 
      if (histpert_min.lt.10) then
         if (VERBOSE.ge.2) then
             print*,' '
             print*,'NEED TO HAVE AT LEAST 10 PERT-DONOR STARS'
             print*,'IN EACH QUADRANT'
             print*,' '
             endif
         FMIN = FMIN/2.0
         if (FMIN.lt.2500) then ! can't go fainter than FMIN ~ 2500
             do PX = 1, NPERTs
             do PY = 1, NPERTs
                do ipsf = 001, 101
                do jpsf = 001, 101
                   psfpert(ipsf,jpsf,PX,PY) = 0
                   enddo
                   enddo
                enddo
                enddo
            write(*,'(1x,''                            '')')
            write(*,'(1x,''NOT ENOUGH BRIGHT STARS     '')')
            write(*,'(1x,''    AVAILABLE WITHIN EACH   '')')
            write(*,'(1x,''    BIN FOR PERT PSF.       '')')
            write(*,'(1x,''                            '')')
            write(*,'(1x,''                            '')')
            write(*,'(1x,''CONSIDER RUNNING AGAIN      '')')
            write(*,'(1x,''    WITH A VALUE FOR NPERTs '')')
            write(*,'(1x,''    SMALLER THAN '',i2)') NPERTs
            write(*,'(1x,''                            '')')
            stop 'ERROR EXIT.'
            endif
         goto 3 ! go find more stars
         endif
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'call ras2pertpsf...',Ls,NPERTs
          print*,' '
          endif
 
      call ras2pertpsf(pixl,psfl,il,jl,xl,yl,ul,Ls,
     .                 rxl,ryl,psfpertu,psfpertv,NPERTs,VERBOSE)
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,' ret ras2pertpsf...',psfpertu(51,51,1,1)
          print*,' '
          endif
 
      do PX = 1, NPERTs
      do PY = 1, NPERTs
         do ipsf = 001, 101
         do jpsf = 001, 101
            psfpert(ipsf,jpsf,PX,PY) = psfpertu(ipsf,jpsf,PX,PY)
            enddo
            enddo
         enddo
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/PERT/output_psfperts.f"
c****                                         
c*********************************************
                                              
 
      subroutine output_psfperts(psfperts,NPERTs,STEM_N,NIMs,VERBOSE)
      implicit none
 
      real        psfperts(101,101,_NPRTMX_,_NPRTMX_,_NIMMXP_)
      integer     NPERTs
      character*9 STEM_N(NIMs)
      integer     NIMs
      integer     VERBOSE
 
      real*4, dimension(:,:), allocatable :: show_psfperts
 
      integer  NDIMx, NDIMy
 
      integer NXs, NX
      integer NYs, NY
      integer PX, PY
      integer ipsf,jpsf
 
      integer i, j
      integer NIM
      character*09 NUMSTRING
 
      NXs = 10
      NYs = 1 + (NIMs-1)/10
 
      NDIMx = 57*NPERTs*NXs
      NDIMy = 57*NPERTs*NYs
 
      if (VERBOSE.ge.2) then
          print*,'ENTER output_psfperts...'
          print*,'      NPERTs: ',NPERTs
          print*,'         NXs: ',NXs,NYs
          print*,'        NIMs: ',NIMs
          print*,'       NDIMx: ',NDIMx,NDIMy
          do NIM = 1, NIMs
             write(*,'('' STEM_N('',i2.2,'') = '',a9)') NIM,STEM_N(NIM)
             enddo
          print*,' '
          endif
 
      if (VERBOSE.ge.2) then
          print*,'      allocate(show_psfperts) '
          endif
 
      allocate(show_psfperts(NDIMx,NDIMy))
 
      do i = 001, NDIMx
      do j = 001, NDIMy
         show_psfperts(i,j) = -0.1
         enddo
         enddo
 
      do NIM = 1, NIMs
         NX = NIM - (NIM-1)/10*10
         NY = NYs - (NIM-1)/10
         do PX = 1, NPERTs
         do PY = 1, NPERTs
            do ipsf = -26, 26
            do jpsf = -26, 26
               show_psfperts((NX-1)*57*NPERTs+55*(PX-1)+28+ipsf+NPERTs,
     .                       (NY-1)*57*NPERTs+55*(PY-1)+28+jpsf+NPERTs)
     .                       = psfperts(51+ipsf,51+jpsf,PX,PY,NIM)
               enddo
               enddo
            show_psfperts((NX-1)*57*NPERTs+55*(PX-1)+28+00+NPERTs,
     .                    (NY-1)*57*NPERTs+55*(PY-1)+28+26+NPERTs)= -0.1
            show_psfperts((NX-1)*57*NPERTs+55*(PX-1)+28+00+NPERTs,
     .                    (NY-1)*57*NPERTs+55*(PY-1)+28-26+NPERTs)= -0.1
            show_psfperts((NX-1)*57*NPERTs+55*(PX-1)+28+26+NPERTs,
     .                    (NY-1)*57*NPERTs+55*(PY-1)+28+00+NPERTs)= -0.1
            show_psfperts((NX-1)*57*NPERTs+55*(PX-1)+28-26+NPERTs,
     .                    (NY-1)*57*NPERTs+55*(PY-1)+28+00+NPERTs)= -0.1
            if (VERBOSE.ge.2) then
                print*,'---> NIM: ',NIM,NX,NY,PX,PY,
     .                              psfperts(51,51,PX,PY,NIM),
     .                              STEM_N(NIM)
                endif
            enddo
            enddo
 
         write(NUMSTRING,'(3x,i3.3,3x)') NIM
         if (NPERTs.eq.NPERTs/2*2) then ! even number
             call img2putstr_r4(NUMSTRING,09,0.1,
     .                (NX-1)*57*NPERTs+55*((NPERTs-1)/2)+04+NPERTs,
     .                (NY-1)*57*NPERTs+55*((NPERTs-1)/2)+51+NPERTs,
     .                show_psfperts,
     .                NDIMx,NDIMy)
             call img2putstr_r4(STEM_N(NIM),09,0.1,
     .                (NX-1)*57*NPERTs+55*((NPERTs-1)/2)+04+NPERTs,
     .                (NY-1)*57*NPERTs+55*((NPERTs-1)/2)+05+NPERTs,
     .                show_psfperts,
     .                NDIMx,NDIMy)
             if (VERBOSE.ge.3) then
                 print*,'-A->  ',
     .               (NX-1)*57*NPERTs+55*((NPERTs-1)/2)+04+NPERTs,
     .               (NY-1)*57*NPERTs+55*((NPERTs-1)/2)+51+NPERTs
                 print*,'-B->  ',
     .               (NX-1)*57*NPERTs+55*((NPERTs-1)/2)+04+NPERTs,
     .               (NY-1)*57*NPERTs+55*((NPERTs-1)/2)+05+NPERTs,
     .               STEM_N(NIM)
                 endif
            else
             call img2putstr_r4(NUMSTRING,09,0.1,
     .                (NX-1)*57*NPERTs+55*(NPERTs/2)+04+NPERTs,
     .                (NY-1)*57*NPERTs+55*(NPERTs/2)+51+NPERTs,
     .                show_psfperts,
     .                NDIMx,NDIMy)
             call img2putstr_r4(STEM_N(NIM),09,0.1,
     .                       (NX-1)*57*NPERTs+55*(NPERTs/2)+04+NPERTs,
     .                       (NY-1)*57*NPERTs+55*(NPERTs/2)+05+NPERTs,
     .                show_psfperts,
     .                NDIMx,NDIMy)
             if (VERBOSE.ge.3) then
                 print*,'-A->  ',
     .                   (NX-1)*57*NPERTs+55*(NPERTs/2)+04+NPERTs,
     .                   (NY-1)*57*NPERTs+55*(NPERTs/2)+51+NPERTs
                 print*,'-B->  ',
     .                   (NX-1)*57*NPERTs+55*(NPERTs/2)+04+NPERTs,
     .                   (NY-1)*57*NPERTs+55*(NPERTs/2)+05+NPERTs,
     .                   STEM_N(NIM)
                 endif
             endif
 
         enddo
 
      if (VERBOSE.ge.2) then
          print*,'            '
          print*,'---> OUTPUT:  LOG.psfperts.fits -- ',NDIMx,NDIMy
          print*,'            '
          endif
      call writfits_r4('LOG.psfperts.fits',show_psfperts,NDIMx,NDIMy)
 
      deallocate(show_psfperts)
 
 
      end
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/PERT/ras2pertpsf.f"
c****                                         
c*********************************************
                                              
c--------------------------------------------------------
c
c this routine will take a set of 11x11 rasters and will
c construct a perturbed PSF out of them
c
      subroutine ras2pertpsf(pixl,psfl,il,jl,xl,yl,ul,Ls,
     .                       rxl,ryl,psfpertu,psfpertv,NPERTs,
     .                       VERBOSE)
      implicit none
 
      integer Ls
      real pixl(11,11,Ls)
      real psfl(11,11,Ls)
      real psfpertu(101,101,_NPRTMX_,_NPRTMX_)
      real psfpertv(101,101,_NPRTMX_,_NPRTMX_)
      integer NPERTs
      integer il(Ls), jl(Ls)
      real*8  xl(Ls), yl(Ls)
      real   rxl(Ls),ryl(Ls)
      integer ul(Ls)
      integer VERBOSE
 
      integer ipsf,jpsf
 
      integer L
      integer PX, PY
c     integer ipx,ipy
 
      real ssl(99999), sslo
      real zzl(99999), zzlo
      real pixu(99999), pbar, psig
      real ptot, ftot
      integer U, Us, Uu
 
      real    el(9999)
      real    wu(99999), wt
      real    du(99999), dbar, dsig
      integer lu(9999)
 
      integer  i,  j
      integer ii, jj
      integer NIT
      integer NREJu, NREJt
 
      real    psfperto(101,101,_NPRTMX_,_NPRTMX_)
      real    psfperta(101,101,_NPRTMX_,_NPRTMX_)
      real    psfperte(101,101,_NPRTMX_,_NPRTMX_)
      integer psfpertn(101,101,_NPRTMX_,_NPRTMX_)
      integer psfpertg(101,101,_NPRTMX_,_NPRTMX_)
      real    psfpertt(101,101,_NPRTMX_,_NPRTMX_)
      real    psfperts(101,101,_NPRTMX_,_NPRTMX_)
      real    psfperth(101,101,_NPRTMX_,_NPRTMX_)
 
      real xpsf, ypsf, rpsf
      real dx, dy
c     real fx, fy
      real xx, yy
c     real rx, ry
c     real pp, rpsf_phot, rpsfpert_phot
      real pp, rpsfpert_phot
      real pertbar(101,101)
      real normu
      real normv
 
      integer Q, Qs
      real pq(999)
      real fq(999)
 
      real*4, dimension(:,:), allocatable ::  show_psfpertnit
 
 
 
      if (VERBOSE.ge.2) then
          print*,'          '
          print*,'ALLOCATE SHOW_PSFPERTNIT: ',
     .             (   5    )*NPERTs*51+1-NPERTs,
     .             ' x ',
     .             (_NITPRT_)*NPERTs*51+1-NPERTs
          print*,'          '
          endif
 
      allocate(show_psfpertnit((   5    )*NPERTs*51+1-NPERTs,
     .                         (_NITPRT_)*NPERTs*51+1-NPERTs))
 
      do i = 1,          5*NPERTs*51+1-NPERTs
      do j = 1, (_NITPRT_)*NPERTs*51+1-NPERTs
         show_psfpertnit(i,j) = -0.1
         enddo
         enddo
 
 
      if (Ls.gt.99999) stop 'ras2pertpsf: Ls.gt.99999'
 
 
c------------------------------------------------------------
c
c We start out with the central location of each
c raster in the detector and the position of the star itself,
c along with the estimate of the fraction of light in
c each pixel from the PSF; these things will not change.
c We will not assume the rasters to be sky-subtracted.
c
c------------------------------------------------------------
 
 
 
 
c------------------------------------------------------------
c
c We begin here by measuring self-consistent values
c for the flux and the sky.  The flux comes from the
c pixels within a radius of 4.5 and the sky comes
c from the PSF-model-subtracted pixels in the annulus
c between 4.5 and 6.5 pixels (restricted to being within
c the inner square of  11x11, naturally)
c
      do L = 1, Ls
         ul(L)  = 1
         zzl(L) = 0.
         ssl(L) = 0.
         do NIT = 1, 3 ! iterate to solve for flux and sky
            sslo = ssl(L)
            zzlo = zzl(L)
            Us = 0
            do i = -5, 5
            do j = -5, 5
               if (i**2+j**2.ge.4.5**2.and.i**2+j**2.le.6.5**2) then
                  Us = Us + 1
                  pixu(Us) = pixl(6+i,6+j,L)
     .                     - psfl(6+i,6+j,L)*zzl(L)
                  endif
               enddo
               enddo
            call rbarsigs(pixu,Us,pbar,psig,Uu,3.5)
            ssl(L) = pbar
            ptot = 0.
            ftot = 0.
            Qs = 0
            do i = -5, 5
            do j = -5, 5
               if (i**2+j**2.le.4.5**2) then
                  ptot = ptot + pixl(6+i,6+j,L) - ssl(L)
                  ftot = ftot + psfl(6+i,6+j,L)
                  Qs = Qs + 1
                  pq(Qs) = pixl(6+i,6+j,L) - ssl(L)
                  fq(Qs) = psfl(6+i,6+j,L)
                  endif
               enddo
               enddo
            zzl(L) = ptot/ftot
            el(L) = 0.
            do Q = 1, Qs
               el(L) = el(L) + abs(pq(Q)-zzl(L)*fq(Q))/zzl(L)
               enddo
            enddo!NIT
         do i = -5, 5
         do j = -5, 5
            ii = il(L) + i
            jj = jl(L) + j
c           write(91,191) L,ii,jj,ii-xl(L),jj-yl(L),
c    .                    pixl(6+i,6+j,L),zzl(L),ssl(L),
c    .                    psfl(6+i,6+j,L)
c 191       format(i5,1x,i4.4,1x,i4.4,1x,f8.3,1x,f8.3,1x,
c    .                3x,f8.1,1x,f12.4,1x,f8.2,1x,f8.6)
            enddo
            enddo
         enddo
      close(91)
 
      do L = 1, Ls
         if (el(L).gt.0.25) ul(L) = 0
         enddo
 
c------------------------------------------------------------
c
c initiate the pertpsf to 0.0
c
      do PX = 01, NPERTs
      do PY = 01, NPERTs
         do ipsf = 001, 101
         do jpsf = 001, 101
            psfpertu(ipsf,jpsf,PX,PY) = 0.00
            enddo
            enddo
         enddo
         enddo
 
 
c------------------------------------------------------------
c
c perform 5 iterations to optimize...
c
      NREJt = 0
      do NIT = 1, _NITPRT_
         NREJu = 0
         do PX = 1, NPERTs
         do PY = 1, NPERTs
            do jpsf = 001, 101
            do ipsf = 001, 101
               psfperto(ipsf,jpsf,PX,PY) = psfpertu(ipsf,jpsf,PX,PY)
               psfperta(ipsf,jpsf,PX,PY) = 0.
               psfpertn(ipsf,jpsf,PX,PY) = 0
               psfpertg(ipsf,jpsf,PX,PY) = 0
               xpsf = (ipsf-51.)/4.0
               ypsf = (jpsf-51.)/4.0
               rpsf = sqrt(xpsf**2+ypsf**2)
               if (rpsf.gt.5.0) then
                  psfpertu(ipsf,jpsf,PX,PY) = 0.
                  psfperta(ipsf,jpsf,PX,PY) = 0.
                  goto 9
                  endif
               Us = 0
               do L = 1, Ls
                  wt = max(0.,1-abs(PX-rxl(L)))*max(0.,1-abs(PY-ryl(L)))
                  if (wt.gt.0.and.ul(L).eq.1) then
                     xx = SNGL(xl(L) + xpsf)
                     yy = SNGL(yl(L) + ypsf)
                     ii = int(xx+0.5)
                     jj = int(yy+0.5)
                     i  = ii-il(L)
                     j  = jj-jl(L)
                     if (i.ge.-5.and.i.le.+5.and.
     .                   j.ge.-5.and.j.le.+5) then
                        dx = SNGL(ii-xl(L))
                        dy = SNGL(jj-yl(L))
                        pp = rpsfpert_phot(dx,dy,psfpertu,
     .                                     rxl(L),ryl(L),NPERTs)
                        Us = Us + 1
                        wu(Us) = wt
                        lu(Us) = L
                        du(Us) = (pixl(6+i,6+j,L)-ssl(L))/zzl(L)
     .                         -  psfl(6+i,6+j,L) - pp
                        endif
                     endif
                  enddo
               call rbarsigsw(du,wu,Us,dbar,dsig,Uu,4.0)
               do U = 1, Us
                  L = lu(u)
                  if ((.false.).and.
     .                ul(L).eq.1.and.
     .                wu(U).ge.0.5.and.
     .                abs(du(U)-dbar).gt.10*dsig) then
                      ul(L) = 0
                      NREJu = NREJu + 1
                      NREJt = NREJt + 1
                      endif
                  enddo
               psfperta(ipsf,jpsf,PX,PY) = dbar
               psfperte(ipsf,jpsf,PX,PY) = dsig
               psfpertn(ipsf,jpsf,PX,PY) = Us
               psfpertg(ipsf,jpsf,PX,PY) = Uu
    9          continue
               psfpertt(ipsf,jpsf,PX,PY) = psfperto(ipsf,jpsf,PX,PY)
     .                                   + psfperta(ipsf,jpsf,PX,PY)
               enddo
               enddo
            call smoo_psfpert(psfpertt(1,1,PX,PY),
     .                        psfperts(1,1,PX,PY))
            normu = 0.
            normv = 0.
            do ipsf = 001, 101
            do jpsf = 001, 101
               normu = normu + psfperts(ipsf,jpsf,PX,PY)/16.0
               normv = normv + psfpertv(ipsf,jpsf,PX,PY)/16.0
               enddo
               enddo
            do ipsf = 001, 101
            do jpsf = 001, 101
c
c don't do any normalization
c
c              psfperth(ipsf,jpsf,PX,PY) = psfperts(ipsf,jpsf,PX,PY)
c    .                                   - psfpertv(ipsf,jpsf,PX,PY)
c    .                                     *normu/normv
               psfperth(ipsf,jpsf,PX,PY) = psfperts(ipsf,jpsf,PX,PY)
               enddo
               enddo
            if (VERBOSE.ge.2) then
                if (PX.eq.1.and.PY.eq.1) write(*,129)
                write( *,119) NIT,PX,PY,51,51,Us,Uu,
     .                        psfperto(51,51,PX,PY),
     .                        psfperta(51,51,PX,PY),
     .                        psfperte(51,51,PX,PY),
     .                        psfperts(51,51,PX,PY)-
     .                        psfperto(51,51,PX,PY),
     .                        normu,
     .                        psfperth(51,51,PX,PY)-
     .                        psfperto(51,51,PX,PY),
     .                        psfperth(51,51,PX,PY),
     .                        psfpertv(51,51,PX,PY)
  129           format(1x,'N',1x,'PX',1x,'PY',1x,' I ',1x,' J ',
     .                 5x,'  NNN',1x,'  UUU',
     .                 5x,'  PERT_OLD','  PERT_ADJ','  PERT_SIG',
     .                    '  PERT_SMU','  PERT_CHG','  PERT_NRM',
     .                    '  PERT_NEW','   PSF_VAL')
  119           format(1x,i1.1,1x,i2.2,1x,i2.2,1x,i3.3,1x,i3.3,
     .                 5x,i5,1x,i5,5x,9f10.6)
                endif
            enddo!PY
            enddo!PX
         do PX = 01, NPERTs
         do PY = 01, NPERTs
            do ipsf = 001, 101
            do jpsf = 001, 101
               psfpertu(ipsf,jpsf,PX,PY) = psfperth(ipsf,jpsf,PX,PY)
               enddo
               enddo
            enddo
            enddo
         do ipsf = 001, 101
         do jpsf = 001, 101
            pertbar(ipsf,jpsf) = 0.
            do PX = 01, NPERTs
            do PY = 01, NPERTs
               pertbar(ipsf,jpsf) = pertbar(ipsf,jpsf)
     .                            + psfpertu(ipsf,jpsf,PX,PY)
     .                              /NPERTs/NPERTs
               enddo
               enddo
            enddo
            enddo
         do PX = 01, NPERTs
         do PY = 01, NPERTs
            do ipsf = 001, 101
            do jpsf = 001, 101
               if (ipsf.ge.27.and.ipsf.le.75.and.
     .             jpsf.ge.27.and.jpsf.le.75) then
                   show_psfpertnit(0*51*NPERTs+50*(PX-1)+26+(ipsf-51),
     .                       (NIT-1)*51*NPERTs+50*(PY-1)+26+(jpsf-51))
     .                               = psfperto(ipsf,jpsf,PX,PY)
                   show_psfpertnit(1*51*NPERTs+50*(PX-1)+26+(ipsf-51),
     .                       (NIT-1)*51*NPERTs+50*(PY-1)+26+(jpsf-51))
     .                               = psfperta(ipsf,jpsf,PX,PY)
                   show_psfpertnit(2*51*NPERTs+50*(PX-1)+26+(ipsf-51),
     .                       (NIT-1)*51*NPERTs+50*(PY-1)+26+(jpsf-51))
     .                               = psfpertu(ipsf,jpsf,PX,PY)
     .                               - psfperto(ipsf,jpsf,PX,PY)
                   show_psfpertnit(3*51*NPERTs+50*(PX-1)+26+(ipsf-51),
     .                       (NIT-1)*51*NPERTs+50*(PY-1)+26+(jpsf-51))
     .                               = psfpertu(ipsf,jpsf,PX,PY)
                   show_psfpertnit(4*51*NPERTs+50*(PX-1)+26+(ipsf-51),
     .                       (NIT-1)*51*NPERTs+50*(PY-1)+26+(jpsf-51))
     .                               = psfpertu(ipsf,jpsf,PX,PY)
     .                               - pertbar(ipsf,jpsf)
                   endif
               enddo
               enddo
            enddo
            enddo
         if (.false.)
     .   call writfits_r4('LOG.pertVnit.fits',show_psfpertnit,
     .                     (   5    )*NPERTs*51+1-NPERTs,
     .                     (_NITPRT_)*NPERTs*51+1-NPERTs)
 
         if (VERBOSE.ge.2) then
             write(*,'(''             '')')
             write(*,'(''END PERT NIT '',2i5)') NIT,(_NITPRT_)
             write(*,'(''        Ls = '', i5)') Ls
             write(*,'(''     NREJu = '', i5)') NREJu
             write(*,'(''     NREJt = '', i5)') NREJt
             write(*,'(''             '')')
             endif
 
         enddo
 
      deallocate(show_psfpertnit)
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/PERT/rbarsigsw.f"
c****                                         
c*********************************************
                                              
 
      subroutine rbarsigsw(xlist,wlist,NTOT,bar,sig,NUSE,SIGCLIP)
      implicit none
 
      integer NTOT
      real xlist(NTOT)
      real wlist(NTOT)
      real bar
      real sig
      integer NUSE
      real SIGCLIP
 
      integer n
      real*8  bsum, ssum, wsum
      integer nsum, nsumo
      integer NIT
 
 
      nsum = 0
      bar = 0.e0
      sig = 9e9
      do NIT = 1, 20
         nsumo = nsum
         bsum = 0.
         ssum = 0.
         wsum = 0.
         nsum = 0.
         do n = 1, NTOT
            if (abs(xlist(n)-bar).le.SIGCLIP*sig) then
               bsum = bsum + wlist(n)*xlist(n)
               ssum = ssum + wlist(n)*abs(xlist(n)-bar)
               wsum = wsum + wlist(n)
               nsum = nsum + 1
               endif
            enddo
         if (nsum.gt.0) bar = SNGL(bsum/wsum)
         if (nsum.gt.1) sig = SNGL(ssum/wsum)
         if (nsum.lt.0.35*NTOT.and.NIT.ge.3) return
         if (nsum.eq.nsumo.and.NIT.ge.3) goto 1
         enddo
  1   continue
      NUSE = nsum
      if (nsum.le.1) sig = 0.999
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/PERT/rpsfpert_phot.f"
c****                                         
c*********************************************
                                              
 
      real function rpsfpert_phot(dx,dy,psfpertu,rxi,ryi,NPERTs)
      implicit none
 
      real dx, dy
      real psfpertu(101,101,_NPRTMX_,_NPRTMX_)
 
      real rxi,ryi
      integer NPERTs
c     logical SHOW
 
      real    rx, ry
      integer ix, iy
      real    fx, fy
c     real    pp
      real    rpsf_phot
 
      rpsfpert_phot = 0.
      if (NPERTs.eq.0) return
 
      if (NPERTs.eq.1) then
         rpsfpert_phot = rpsf_phot(dx,dy,psfpertu)
         return
         endif
 
      rx = rxi
      ry = ryi
 
      if (rx.le.   1.0) rx =    1.0
      if (ry.le.   1.0) ry =    1.0
      if (rx.gt.NPERTs) rx = NPERTs
      if (ry.gt.NPERTs) ry = NPERTs
 
      ix = min(int(rx),NPERTs-1)
      iy = min(int(ry),NPERTs-1)
      if (ix.lt.1) ix = 1
      if (iy.lt.1) iy = 1
      if (ix.gt.NPERTs-1) ix = NPERTs-1
      if (iy.gt.NPERTs-1) iy = NPERTs-1
      fx = rx-ix
      fy = ry-iy
 
      rpsfpert_phot
     .       = (1-fx)*(1-fy)*rpsf_phot(dx,dy,psfpertu(1,1,ix  ,iy  ))
     .       + ( fx )*(1-fy)*rpsf_phot(dx,dy,psfpertu(1,1,ix+1,iy  ))
     .       + (1-fx)*( fy )*rpsf_phot(dx,dy,psfpertu(1,1,ix  ,iy+1))
     .       + ( fx )*( fy )*rpsf_phot(dx,dy,psfpertu(1,1,ix+1,iy+1))
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPSFs/ROUTINES/infofits_stdpsf.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------------------------
c
c
c
 
      subroutine infofits_stdpsf(FILEI,NXPSFs,NYPSFs,ilist,jlist)
      implicit none
 
      character*200 FILEI
      integer NXPSFs
      integer NYPSFs
      integer ilist(20)
      integer jlist(20)
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer i, j, k
      character*200 FILEU
 
c     integer NPSFs
 
c     integer q, npu
      character*08 FIELD
      character*20 STREAM
      character*70 STREEM
      integer ios
c
c-------------------------------------------------
c
      character*200 FILEI_stdpsf
      integer       NXPSFs_stdpsf
      integer       NYPSFs_stdpsf
      integer       ilist_stdpsf(20)
      integer       jlist_stdpsf(20)
 
      common /FILEI_stdpsf_  /FILEI_stdpsf
      common /NXPSFs_stdpsf_ /NXPSFs_stdpsf
      common /NYPSFs_stdpsf_ /NYPSFs_stdpsf
      common /ilist_stdpsf_  /ilist_stdpsf
      common /jlist_stdpsf_  /jlist_stdpsf
 
c
c-------------------------------------------------
c
 
      if (FILEI.eq.FILEI_stdpsf) then
          NXPSFs = NXPSFs_stdpsf
          NYPSFs = NYPSFs_stdpsf
          do i = 01, 20
             ilist(i) = ilist_stdpsf(i)
             jlist(i) = jlist_stdpsf(i)
             enddo
          return
          endif
 
      FILEU = 'NONE'
      do i = 195,2,-1
         if (FILEI(i:i+4).eq.'.fits') FILEU = FILEI(1:i+4)
         enddo
      if (FILEU(1:4).eq.'NONE') then
          print*,'       '
          print*,'subroutine infofits_stdpsf --- '
          print*,'       '
          print*,'FILEI: ',FILEI
          print*,'FILEU: ',FILEU
          print*,'       '
          stop 'infofits no fits'
          endif
 
!$omp critical(infofits_stdpsf)
      open(25,file=FILEU,
     .     status='old',
     .     err   =900,
     .     iostat=ios,
     .     recl  =2880,
     .     form  ='UNFORMATTED',
     .     access='DIRECT')
 
      NXPSFs = 0
      NYPSFs = 0
      do i = 01, 20
         ilist(i) = -999
         jlist(i) = -999
         enddo
 
      read(25,rec=1) buffc
 
      do k = 01, 35
         FIELD  = buffc(01+(k-1)*80:08+(k-1)*80)
         STREAM = buffc(11+(k-1)*80:30+(k-1)*80)
         STREEM = buffc(11+(k-1)*80:80+(k-1)*80)
         if (FIELD.eq.'NXPSFs  ') read(STREAM,*) NXPSFs
         if (FIELD.eq.'NYPSFs  ') read(STREAM,*) NYPSFs
         if (FIELD.eq.'IPSFX01 ') read(STREAM,*) ilist(01)
         if (FIELD.eq.'IPSFX02 ') read(STREAM,*) ilist(02)
         if (FIELD.eq.'IPSFX03 ') read(STREAM,*) ilist(03)
         if (FIELD.eq.'IPSFX04 ') read(STREAM,*) ilist(04)
         if (FIELD.eq.'IPSFX05 ') read(STREAM,*) ilist(05)
         if (FIELD.eq.'IPSFX06 ') read(STREAM,*) ilist(06)
         if (FIELD.eq.'IPSFX07 ') read(STREAM,*) ilist(07)
         if (FIELD.eq.'IPSFX08 ') read(STREAM,*) ilist(08)
         if (FIELD.eq.'IPSFX09 ') read(STREAM,*) ilist(09)
         if (FIELD.eq.'IPSFX10 ') read(STREAM,*) ilist(10)
         if (FIELD.eq.'JPSFY01 ') read(STREAM,*) jlist(01)
         if (FIELD.eq.'JPSFY02 ') read(STREAM,*) jlist(02)
         if (FIELD.eq.'JPSFY03 ') read(STREAM,*) jlist(03)
         if (FIELD.eq.'JPSFY04 ') read(STREAM,*) jlist(04)
         if (FIELD.eq.'JPSFY05 ') read(STREAM,*) jlist(05)
         if (FIELD.eq.'JPSFY06 ') read(STREAM,*) jlist(06)
         if (FIELD.eq.'JPSFY07 ') read(STREAM,*) jlist(07)
         if (FIELD.eq.'JPSFY08 ') read(STREAM,*) jlist(08)
         if (FIELD.eq.'JPSFY09 ') read(STREAM,*) jlist(09)
         if (FIELD.eq.'JPSFY10 ') read(STREAM,*) jlist(10)
         do i = 1, 70
            if (STREEM(i:i).eq."'") STREEM(i:i) = ' '
            enddo
         if (FIELD.eq.'IPSFXA5 ')
     .       read(STREEM,*) ilist(01), ilist(02), ilist(03),
     .                                 ilist(04), ilist(05)
         if (FIELD.eq.'IPSFXB5 ')
     .       read(STREEM,*) ilist(06), ilist(07), ilist(08),
     .                                 ilist(09), ilist(10)
         if (FIELD.eq.'IPSFXC5 ')
     .       read(STREEM,*) ilist(11), ilist(12), ilist(13),
     .                                 ilist(14), ilist(15)
         if (FIELD.eq.'IPSFXD5 ')
     .       read(STREEM,*) ilist(16), ilist(17), ilist(18),
     .                                 ilist(19), ilist(20)
         if (FIELD.eq.'JPSFYA5 ')
     .       read(STREEM,*) jlist(01), jlist(02), jlist(03),
     .                                 jlist(04), jlist(05)
         if (FIELD.eq.'JPSFYB5 ')
     .       read(STREEM,*) jlist(06), jlist(07), jlist(08),
     .                                 jlist(09), jlist(10)
         enddo
 
c     print*,' '
c     print*,'  NXPSFs: ',NXPSFs
c     print*,'          ',(ilist(i),i=1,NXPSFs)
c     print*,' '
c     print*,'  NYPSFs: ',NYPSFs
c     print*,'          ',(jlist(i),i=1,NYPSFs)
c     print*,' '
 
 
      do i = 01, NYPSFs-1
         if (jlist(i).eq.2048.and.
     .       jlist(i+1).eq.2048) jlist(i+1) = 2049
         enddo
 
      do i = 01, 20
         if (i.gt.NXPSFs) ilist(i) = 9999
         if (i.gt.NYPSFs) jlist(i) = 9999
         enddo
 
      do i = 01, 20
         if ((i.le.NXPSFs.and.ilist(i).lt.0).or.
     .       (i.le.NYPSFs.and.jlist(i).lt.0)) then
              print*,'infofits_stdpsf: '
              print*,'    HEADER NEEDs TO SPECIFY ALL IPSFs and JPSFs'
              print*,'       i: ',i,ilist(i),jlist(i)
              print*,'    FILE: ',FILEU
              stop
              endif
         if (NXPSFs.eq.0) stop 'infofits_stdpsf: HEADER NEEDs NXPSFs'
         if (NYPSFs.eq.0) stop 'infofits_stdpsf: HEADER NEEDs NXPSFs'
         enddo
 
 
 
      goto 901
  900 continue
      print*,' '
      print*,'ERROR ACCESSING FITS FILE IN infofits_stdpsf(): '
      write(*,'('' FILEI_stdpsf: '',a80)') FILEI_stdpsf
      write(*,'('' FILEI       : '',a80)') FILEI
      write(*,'('' FILEU       : '',a80)') FILEU
      write(*,'('' IOS         : '', i5)') IOS
      print*,' '
      stop
  901 close(25)
!$omp end critical(infofits_stdpsf)
      return
      end
 
 
c*********************************************
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPSFs/ROUTINES/loadfits_stdpsf_flexibl.f"
c****                                         
c*********************************************
                                              
 
 
c-----------------------------------------------------------------
c
c this routine will load into memory a STDPSF ; this flexible
c version will read in the median-filter PSF from a STDPBF file.
c
c
      subroutine loadfits_stdpsf(FILEI)
      implicit none
 
      character*200 FILEI
 
c
c----------------------------------------------
c
      character*200 FILEI_stdpsf
      real*4        psfij_stdpsf(101,101,20,20)
      integer       NNPSFs_stdpsf
      integer       NXPSFs_stdpsf
      integer       NYPSFs_stdpsf
      integer       ilist_stdpsf(20)
      integer       jlist_stdpsf(20)
      character*72  COMMENT1_stdpsf
      character*72  COMMENT2_stdpsf
      character*72  COMMENT3_stdpsf
      character*20  DATESTRING_stdpsf
      character*20  TIMESTRING_stdpsf
 
      common /FILEI_stdpsf_  /FILEI_stdpsf
      common /psfij_stdpsf_  /psfij_stdpsf
      common /NNPSFs_stdpsf_ /NNPSFs_stdpsf
      common /NXPSFs_stdpsf_ /NXPSFs_stdpsf
      common /NYPSFs_stdpsf_ /NYPSFs_stdpsf
      common /ilist_stdpsf_  /ilist_stdpsf
      common /jlist_stdpsf_  /jlist_stdpsf
      common /COMMENT_stdpsf_/COMMENT1_stdpsf,
     .                        COMMENT2_stdpsf,
     .                        COMMENT3_stdpsf
      common /DATESTR_stdpsf_/DATESTRING_stdpsf
      common /TIMESTR_stdpsf_/TIMESTRING_stdpsf
c
c----------------------------------------------
c
      data FILEI_stdpsf/'NONE'/
      character*200 FILEU
 
      integer NX, NY, NN
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios
 
c     integer c1, c2, c3
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer ii
      integer ifirst, i1, i2
      integer np1, np2, npt
 
      integer k
 
 
      byte b(4)
      real*4 r
      equivalence(r,b)
 
      integer q, npu, nbu
      real*4, dimension(:), allocatable :: psfn
 
      character*08 FIELD
      character*20 STREAM
      character*70 STREEM
 
      integer ipsf
      integer jpsf
      integer NCOMs
 
      integer NAXIS
      real    floc
      logical islinux
c
c--------------------------------------------------------
c
      if (FILEI_stdpsf.eq.FILEI) return
 
      if (FILEI(1:6).eq.'APPHOT') then
          NNPSFs_stdpsf = 1
          NXPSFs_stdpsf = 1
          NYPSFs_stdpsf = 1
          ilist_stdpsf(1) = 0000
          jlist_stdpsf(1) = 0000
          ilist_stdpsf(2) = 9999
          jlist_stdpsf(2) = 9999
          do ipsf = 001, 101
          do jpsf = 001, 101
             psfij_stdpsf(ipsf,jpsf,1,1) = 0.
             enddo
             enddo
          return
          endif
 
      FILEU = 'XXX'
      do i = 195,2,-1
         if (FILEI(i:i+4).eq.'.fits') FILEU = FILEI(1:i+4)
         enddo
      if (FILEU(1:3).eq.'XXX') then
         print*,'loadfits_stdpsf --- '
         print*,'   FILEI: ',FILEI
         print*,'   DOES NOT CONTAIN .fits'
         stop
         endif
 
      close(25)
      open(25,file=FILEU,
     .     status='old',
     .     err   =900,
     .     iostat=ios,
     .     recl  =2880,
     .     form  ='UNFORMATTED',
     .     access='DIRECT')
 
      do ii = 0001, 2880
         buffc(ii:ii) = ' '
         enddo
 
      NNPSFs_stdpsf = 0
      NXPSFs_stdpsf = 0
      NYPSFs_stdpsf = 0
 
      DATESTRING_stdpsf = 'NONE'
      TIMESTRING_stdpsf = 'NONE'
 
      do i = 01, 20
         ilist_stdpsf(i) = -999
         jlist_stdpsf(i) = -999
         enddo
 
      read(25,rec=1) buffc
      do k = 01, 35
         FIELD  = buffc(01+(k-1)*80:08+(k-1)*80)
         STREAM = buffc(11+(k-1)*80:30+(k-1)*80)
         if (FIELD.eq.'NAXIS   ') then
            read(STREAM,*) NAXIS
            if (NAXIS.eq.4) then
               close(25)
               floc = 0.
               call loadstdpsf_stdpbf(floc,FILEI,FILEI)
               return
               endif
            endif
         enddo
 
      NCOMs = 0
      COMMENT1_stdpsf = 'NO COMMENT'
      COMMENT2_stdpsf = 'NO COMMENT'
      COMMENT3_stdpsf = 'NO COMMENT'
 
      do k = 01, 35
         FIELD  = buffc(01+(k-1)*80:08+(k-1)*80)
         STREAM = buffc(11+(k-1)*80:30+(k-1)*80)
         STREEM = buffc(11+(k-1)*80:80+(k-1)*80)
         if (FIELD.eq.'DATE    ') DATESTRING_stdpsf = STREAM
         if (FIELD.eq.'TIME    ') TIMESTRING_stdpsf = STREAM
         if (FIELD.eq.'NXPSFs  ') read(STREAM,*) NXPSFs_stdpsf
         if (FIELD.eq.'NYPSFs  ') read(STREAM,*) NYPSFs_stdpsf
         if (FIELD.eq.'IPSFX01 ') read(STREAM,*) ilist_stdpsf(01)
         if (FIELD.eq.'IPSFX02 ') read(STREAM,*) ilist_stdpsf(02)
         if (FIELD.eq.'IPSFX03 ') read(STREAM,*) ilist_stdpsf(03)
         if (FIELD.eq.'IPSFX04 ') read(STREAM,*) ilist_stdpsf(04)
         if (FIELD.eq.'IPSFX05 ') read(STREAM,*) ilist_stdpsf(05)
         if (FIELD.eq.'IPSFX06 ') read(STREAM,*) ilist_stdpsf(06)
         if (FIELD.eq.'IPSFX07 ') read(STREAM,*) ilist_stdpsf(07)
         if (FIELD.eq.'IPSFX08 ') read(STREAM,*) ilist_stdpsf(08)
         if (FIELD.eq.'IPSFX09 ') read(STREAM,*) ilist_stdpsf(09)
         if (FIELD.eq.'IPSFX10 ') read(STREAM,*) ilist_stdpsf(10)
         if (FIELD.eq.'JPSFY01 ') read(STREAM,*) jlist_stdpsf(01)
         if (FIELD.eq.'JPSFY02 ') read(STREAM,*) jlist_stdpsf(02)
         if (FIELD.eq.'JPSFY03 ') read(STREAM,*) jlist_stdpsf(03)
         if (FIELD.eq.'JPSFY04 ') read(STREAM,*) jlist_stdpsf(04)
         if (FIELD.eq.'JPSFY05 ') read(STREAM,*) jlist_stdpsf(05)
         if (FIELD.eq.'JPSFY06 ') read(STREAM,*) jlist_stdpsf(06)
         if (FIELD.eq.'JPSFY07 ') read(STREAM,*) jlist_stdpsf(07)
         if (FIELD.eq.'JPSFY08 ') read(STREAM,*) jlist_stdpsf(08)
         if (FIELD.eq.'JPSFY09 ') read(STREAM,*) jlist_stdpsf(09)
         if (FIELD.eq.'JPSFY10 ') read(STREAM,*) jlist_stdpsf(10)
         do i = 1, 70
            if (STREEM(i:i).eq."'") STREEM(i:i) = ' '
            enddo
         if (FIELD.eq.'IPSFXA5 ')
     .       read(STREEM,*) ilist_stdpsf(01), ilist_stdpsf(02),
     .                      ilist_stdpsf(03), ilist_stdpsf(04),
     .                                        ilist_stdpsf(05)
         if (FIELD.eq.'IPSFXB5 ')
     .       read(STREEM,*) ilist_stdpsf(06), ilist_stdpsf(07),
     .                      ilist_stdpsf(08), ilist_stdpsf(09),
     .                                        ilist_stdpsf(10)
         if (FIELD.eq.'IPSFXC5 ')
     .       read(STREEM,*) ilist_stdpsf(11), ilist_stdpsf(12),
     .                      ilist_stdpsf(13), ilist_stdpsf(14),
     .                                        ilist_stdpsf(15)
         if (FIELD.eq.'IPSFXD5 ')
     .       read(STREEM,*) ilist_stdpsf(16), ilist_stdpsf(17),
     .                      ilist_stdpsf(18), ilist_stdpsf(19),
     .                                        ilist_stdpsf(20)
         if (FIELD.eq.'JPSFYA5 ')
     .       read(STREEM,*) jlist_stdpsf(01), jlist_stdpsf(02),
     .                      jlist_stdpsf(03), jlist_stdpsf(04),
     .                                        jlist_stdpsf(05)
         if (FIELD.eq.'JPSFYB5 ')
     .       read(STREEM,*) jlist_stdpsf(06), jlist_stdpsf(07),
     .                      jlist_stdpsf(08), jlist_stdpsf(09),
     .                                        jlist_stdpsf(10)
 
         if (FIELD.eq.'COMMENT ') then
            NCOMs = NCOMs + 1
c           if (NCOMs.gt.3) stop 'MORE THAN 3 COMMENTS'
            if (NCOMs.eq.1) COMMENT1_stdpsf = buffc(09+(k-1)*80:
     .                                              80+(k-1)*80)
            if (NCOMs.eq.2) COMMENT2_stdpsf = buffc(09+(k-1)*80:
     .                                              80+(k-1)*80)
            if (NCOMs.eq.3) COMMENT3_stdpsf = buffc(09+(k-1)*80:
     .                                              80+(k-1)*80)
            endif
         if (FIELD.eq.'END     ') goto 1
         enddo!k
    1 continue
 
      do i = 20, NYPSFs_stdpsf+1, -1
         jlist_stdpsf(i) = 9999
         enddo
      do i = 20, NXPSFs_stdpsf+1, -1
         ilist_stdpsf(i) = 9999
         enddo
 
 
      NNPSFs_stdpsf = NXPSFs_stdpsf*NYPSFs_stdpsf
 
      allocate(psfn(101*101*NNPSFs_stdpsf))
 
      ifirst = 2
      i = ifirst
 
      nbper  = 4*101*101*NNPSFs_stdpsf
      npt    =   101*101*NNPSFs_stdpsf
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i + nbyte1/2880
      i2 = i + nbyte2/2880
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         read(25,rec=i,iostat=ios) buffb
         do q = 001, 720
            npu = np1+q-1
            nbu = (q-1)*4
            if (.not.islinux()) stop 'not LINUX'
            b(4) = buffb(nbu+1)  ! assume LINUX ; do the byte flip
            b(3) = buffb(nbu+2)  ! this flips the bytes for r, too
            b(2) = buffb(nbu+3)
            b(1) = buffb(nbu+4)
            if (npu.le.npt) psfn(npu) = r
            enddo
         enddo
      close(25)
 
      FILEI_stdpsf  = FILEI
      do NX = 1, NXPSFs_stdpsf
      do NY = 1, NYPSFs_stdpsf
         NN = NX + (NY-1)*NXPSFs_stdpsf
         do jpsf = 001, 101
         do ipsf = 001, 101
            npu = ipsf + (jpsf-1)*101 + (NN-1)*101*101
            psfij_stdpsf(ipsf,jpsf,NX,NY) = psfn(npu)
            enddo
            enddo
         enddo
         enddo
 
      deallocate(psfn)
      return
 
  900 continue
      print*,' '
      print*,'ERROR ACCESSING FITS FILE IN loadfits_pixpsf(): '
      write(*,'('' FILEI_stdpsf: '',a80)') FILEI_stdpsf
      write(*,'('' FILEI       : '',a80)') FILEI
      write(*,'('' FILEU       : '',a80)') FILEU
      write(*,'('' IOS         : '', i5)') IOS
      print*,' '
      stop
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPSFs/ROUTINES/locpsfij_stdpsf_preload.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------------------
c
c
c
      subroutine locpsfij_stdpsf(iloc,jloc,psfloc,FILEI)
      implicit none
 
      integer iloc
      integer jloc
      real    psfloc(101,101)
      character*(*) FILEI
c
c----------------------------------------------
c
      character*200 FILEI_stdpsf
      real*4        psfij_stdpsf(101,101,20,20)
      integer       NNPSFs_stdpsf
      integer       NXPSFs_stdpsf
      integer       NYPSFs_stdpsf
      integer       ilist_stdpsf(20)
      integer       jlist_stdpsf(20)
      character*72  COMMENT1_stdpsf
      character*72  COMMENT2_stdpsf
      character*72  COMMENT3_stdpsf
      character*20  DATESTRING_stdpsf
      character*20  TIMESTRING_stdpsf
 
      common /FILEI_stdpsf_  /FILEI_stdpsf
      common /psfij_stdpsf_  /psfij_stdpsf
      common /NNPSFs_stdpsf_ /NNPSFs_stdpsf
      common /NXPSFs_stdpsf_ /NXPSFs_stdpsf
      common /NYPSFs_stdpsf_ /NYPSFs_stdpsf
      common /ilist_stdpsf_  /ilist_stdpsf
      common /jlist_stdpsf_  /jlist_stdpsf
      common /COMMENT_stdpsf_/COMMENT1_stdpsf,
     .                        COMMENT2_stdpsf,
     .                        COMMENT3_stdpsf
      common /DATESTR_stdpsf_/DATESTRING_stdpsf
      common /TIMESTR_stdpsf_/TIMESTRING_stdpsf
c
c----------------------------------------------
c
      integer nx, ny
      real    fx, fy
 
      integer ipsf,jpsf
 
      call loadfits_stdpsf(FILEI)
 
      if (NXPSFs_stdpsf.eq.1.and.NYPSFs_stdpsf.eq.1) then
          do ipsf = 001, 101
          do jpsf = 001, 101
             psfloc(ipsf,jpsf) = psfij_stdpsf(ipsf,jpsf,1,1)
             enddo
             enddo
          return
          endif
 
      nx = 1
    1 continue
      if (iloc.gt.ilist_stdpsf(nx+1).and.nx.le.NXPSFs_stdpsf-2) then
         nx = nx + 1
         goto 1
         endif
 
      ny = 1
    2 continue
      if (jloc.gt.jlist_stdpsf(ny+1).and.ny.le.NYPSFs_stdpsf-2) then
         ny = ny + 1
         goto 2
         endif
 
      fx = 1.00*(iloc              -ilist_stdpsf(NX))/
     .          (ilist_stdpsf(NX+1)-ilist_stdpsf(NX))
      fy = 1.00*(jloc              -jlist_stdpsf(NY))/
     .          (jlist_stdpsf(NY+1)-jlist_stdpsf(NY))
 
      if (fx.lt.0.0000) fx = 0.0000
      if (fy.lt.0.0000) fy = 0.0000
      if (fx.gt.0.9999) fx = 0.9999
      if (fy.gt.0.9999) fy = 0.9999
 
      do ipsf = 001, 101
      do jpsf = 001, 101
         psfloc(ipsf,jpsf)
     .              = (1-fx)*(1-fy)*psfij_stdpsf(ipsf,jpsf,nx  ,ny  )
     .              + (1-fx)*( fy )*psfij_stdpsf(ipsf,jpsf,nx  ,ny+1)
     .              + ( fx )*(1-fy)*psfij_stdpsf(ipsf,jpsf,nx+1,ny  )
     .              + ( fx )*( fy )*psfij_stdpsf(ipsf,jpsf,nx+1,ny+1)
         if (psfloc(ipsf,jpsf).lt.0.00) psfloc(ipsf,jpsf) = 0.00
         enddo
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPSFs/ROUTINES/stdpsf2psfbar.f"
c****                                         
c*********************************************
                                              
 
c----------------------------------------------------
c
c this routine will take a standard PSF and will find
c the average ; could do a better job area-averaging
c to deal with the outer edges and gap edges.
c
      subroutine stdpsf2psfbar(PSFFILE_USE,psfbar)
      implicit none
 
      character*200 PSFFILE_USE
      real*4  psfbar(101,101)
 
      integer NXPSFs, NYPSFs
      integer ilist(20)
      integer jlist(20)
      real*4  psfloc(101,101)
      integer ipsf, jpsf
      integer i, j
 
      call infofits_stdpsf(PSFFILE_USE,NXPSFs,NYPSFs,ilist,jlist)
 
      do i = 001, 101
      do j = 001, 101
         psfbar(i,j) = 0.
         enddo
         enddo
 
      do i = 1, NXPSFs
      do j = 1, NYPSFs
         call locpsfij_stdpsf(ilist(i),jlist(j),
     .                        psfloc,PSFFILE_USE)
         do ipsf = 001, 101
         do jpsf = 001, 101
            psfbar(ipsf,jpsf) = psfbar(ipsf,jpsf) + psfloc(ipsf,jpsf)
            enddo
            enddo
         enddo
         enddo
 
      do ipsf = 001, 101
      do jpsf = 001, 101
         psfbar(ipsf,jpsf) = psfbar(ipsf,jpsf)/NXPSFs/NYPSFs
         enddo
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPSFs/ROUTINES/writfits_stdpsf.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------------------------
c
c
c
 
      subroutine writfits_stdpsf(FILE,pix,NXPSFs,NYPSFs,ilist,jlist,
     .                           COMMENT1,COMMENT2,COMMENT3)
      implicit none
 
      character*80 FILE
      integer NXPSFs
      integer NYPSFs
      real*4  pix(*)
      integer ilist(10)
      integer jlist(10)
      character*(*) COMMENT1
      character*(*) COMMENT2
      character*(*) COMMENT3
 
      character*72 COMMENT1U
      character*72 COMMENT2U
      character*72 COMMENT3U
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios
 
c     integer c1, c2, c3
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer ii
      integer ifirst, i1, i2
      integer np1, np2, npt
 
      integer n, k
      character*80 FILEU
 
      character*20 DATESTRING
      character*20 TIMESTRING
      integer today(3)
      integer now(3)
 
      integer NPSFs
 
      byte b(4)
      real*4 r
      equivalence(r,b)
 
      integer q, npu, nbu
 
 
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
      open(10,file=FILEU,
     .     status='unknown',
     .     err   =900,
     .     recl  =2880,
     .     form  ='UNFORMATTED',
     .     access='DIRECT')
 
      do ii = 0001, 2880
         buffc(ii:ii) = ' '
         enddo
 
      COMMENT1U = COMMENT1
      COMMENT2U = COMMENT2
      COMMENT3U = COMMENT3
 
      do i = 72, 02, -1
         if (COMMENT1U(i:i).eq.'!') COMMENT1U = COMMENT1U(1:i-1)
         if (COMMENT2U(i:i).eq.'!') COMMENT2U = COMMENT2U(1:i-1)
         if (COMMENT3U(i:i).eq.'!') COMMENT3U = COMMENT3U(1:i-1)
         enddo
 
 
c
c we'll only use ONE header record, for simplicity ; it still
c conforms to the FITS standard, but I know to read only one
c
      call idate(today)
      call itime(now)
 
c 12 1 2013
c 10 24 17
 
      write(DATESTRING,'(a1,i4.4,''-'',i2.2,''-'',i2.2,a1)')
     .                   '''',today(3), today(2), today(1),''''
      write(TIMESTRING,'(a1,i2.2,'':'',i2.2,'':'',i2.2,a1)')
     .                   '''',now(1), now(2), now(3),''''
 
      NPSFs = NXPSFs*NYPSFs
 
      write(buffc( 0*80+1: 1*80),'(''SIMPLE  =                    T'')')
      write(buffc( 1*80+1: 2*80),'(''BITPIX  =                  -32'')')
      write(buffc( 2*80+1: 3*80),'(''NAXIS   = '',i20)') 3
      write(buffc( 3*80+1: 4*80),'(''NAXIS1  = '',i20)') 101
      write(buffc( 4*80+1: 5*80),'(''NAXIS2  = '',i20)') 101
      write(buffc( 5*80+1: 6*80),'(''NAXIS3  = '',i20)') NPSFs
      write(buffc( 6*80+1: 7*80),'(''DATE    = '',a20)') DATESTRING
      write(buffc( 7*80+1: 8*80),'(''TIME    = '',a20)') TIMESTRING
      write(buffc( 8*80+1:09*80),'(''BSCALE  = '',f20.4)') 00001.00
      write(buffc( 9*80+1:10*80),'(''BZERO   = '',f20.4)') 00000.00
      write(buffc(10*80+1:11*80),'(''NXPSFs  = '',i20)') NXPSFs
      write(buffc(11*80+1:12*80),'(''NYPSFs  = '',i20)') NYPSFs
      do n = 01, 10
         k = 11+n
         write(buffc(k*80+1:k*80+80),'(''IPSFX'',i2.2,'' = '',i20)')
     .                                          n,ilist(n)
         enddo
      do n = 01, 10
         k = 21+n
         write(buffc(k*80+1:k*80+80),'(''JPSFY'',i2.2,'' = '',i20)')
     .                                          n,jlist(n)
         enddo
      write(buffc(32*80+1:34*80),'(''COMMENT '',a72)') COMMENT1U
      write(buffc(33*80+1:34*80),'(''COMMENT '',a72)') COMMENT2U
      write(buffc(34*80+1:35*80),'(''COMMENT '',a72)') COMMENT3U
      write(buffc(35*80+1:36*80),'(''END                           '')')
      write(10,rec=1,iostat=ios) buffc
 
      ifirst = 2
      i = ifirst
 
      nbper  = 4*101*101*NPSFs
      npt    =   101*101*NPSFs
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i + nbyte1/2880
      i2 = i + nbyte2/2880
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         do q = 001, 720
            npu = np1+q-1
            nbu = (q-1)*4
            if (npu.ge.1.and.npu.le.npt) r = pix(npu)
            if (.not.(_LINUX_)) then
               buffb(nbu+1) = b(1)
               buffb(nbu+2) = b(2)
               buffb(nbu+3) = b(3)
               buffb(nbu+4) = b(4)
               endif
            if ((_LINUX_)) then
               buffb(nbu+1) = b(4)
               buffb(nbu+2) = b(3)
               buffb(nbu+3) = b(2)
               buffb(nbu+4) = b(1)
               endif
            enddo
         write(10,rec=i,iostat=ios) buffc
         enddo
 
      close(10)
 
      return
 
  900 continue
      print*,' '
      print*,'ERROR ACCESSING FITS FILE IN writfits_pixpsf(): '
      write(*,'('' FILE : '',a80)') FILE
      write(*,'('' FILEU: '',a80)') FILEU
      print*,' '
      stop
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPSFs/ROUTINES/savefits_stdpsf.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------------------------
c
c
c
      subroutine savefits_stdpsf(FILEO)
      implicit none
 
      character*(*) FILEO
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios
 
c     integer c1, c2, c3
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer ii
      integer ifirst, i1, i2
      integer np1, np2, npt
 
      integer n, k
      character*200 FILEU
 
      integer today(3)
      integer now(3)
 
      byte b(4)
      real*4 r
      equivalence(r,b)
 
      integer q, npu, nbu
      integer NX, NY, NN
      integer ipsf, jpsf
 
c
c----------------------------------------------
c
      character*200 FILEI_stdpsf
      integer      NNPSFs_stdpsf
      integer      NXPSFs_stdpsf
      integer      NYPSFs_stdpsf
      integer      ilist_stdpsf(20)
      integer      jlist_stdpsf(20)
      character*72 COMMENT1_stdpsf
      character*72 COMMENT2_stdpsf
      character*72 COMMENT3_stdpsf
      character*20 DATESTRING_stdpsf
      character*20 TIMESTRING_stdpsf
      real*4       psfij_stdpsf(101,101,20,20)
 
      common /FILEI_stdpsf_  /FILEI_stdpsf
      common /NNPSFs_stdpsf_ /NNPSFs_stdpsf
      common /NXPSFs_stdpsf_ /NXPSFs_stdpsf
      common /NYPSFs_stdpsf_ /NYPSFs_stdpsf
      common /ilist_stdpsf_  /ilist_stdpsf
      common /jlist_stdpsf_  /jlist_stdpsf
      common /COMMENT_stdpsf_/COMMENT1_stdpsf,
     .                        COMMENT2_stdpsf,
     .                        COMMENT3_stdpsf
      common /DATESTR_stdpsf_/DATESTRING_stdpsf
      common /TIMESTR_stdpsf_/TIMESTRING_stdpsf
      common /psfij_stdpsf_  /psfij_stdpsf
 
      logical islinux
c
c----------------------------------------------
c
 
      FILEI_stdpsf = FILEO
 
      FILEU = FILEO
      do i = 75,2,-1
         if (FILEO(i:i+4).eq.'.fits') FILEU = FILEO(1:i+4)
         enddo
 
      open(10,file=FILEU,
     .     status='unknown',
     .     err   =900,
     .     recl  =2880,
     .     form  ='UNFORMATTED',
     .     access='DIRECT')
 
      do ii = 0001, 2880
         buffc(ii:ii) = ' '
         enddo
 
c
c we'll only use ONE header record, for simplicity ; it still
c conforms to the FITS standard, but I know to read only one
c
      call idate(today)
      call itime(now)
 
      write(DATESTRING_stdpsf,'(a1,i4.4,''-'',i2.2,''-'',i2.2,a1)')
     .                       '''',today(3), today(2), today(1),''''
      write(TIMESTRING_stdpsf,'(a1,i2.2,'':'',i2.2,'':'',i2.2,a1)')
     .                       '''',now(1),   now(2),   now(3),  ''''
 
      if (NXPSFs_stdpsf.gt.10)
     .    stop 'savefits_stdpsf not ready for NXPSFs>10'
      if (NYPSFs_stdpsf.gt.10)
     .    stop 'savefits_stdpsf not ready for NYPSFs>10'
 
      NNPSFs_stdpsf = NXPSFs_stdpsf*NYPSFs_stdpsf
 
      write(buffc( 0*80+1: 1*80),'(''SIMPLE  =                    T'')')
      write(buffc( 1*80+1: 2*80),'(''BITPIX  =                  -32'')')
      write(buffc( 2*80+1: 3*80),'(''NAXIS   = '',i20)') 3
      write(buffc( 3*80+1: 4*80),'(''NAXIS1  = '',i20)') 101
      write(buffc( 4*80+1: 5*80),'(''NAXIS2  = '',i20)') 101
      write(buffc( 5*80+1: 6*80),'(''NAXIS3  = '',i20)') NNPSFs_stdpsf
      write(buffc( 6*80+1: 7*80),'(''DATE    = '',a20)')
     .                               DATESTRING_stdpsf
      write(buffc( 7*80+1: 8*80),'(''TIME    = '',a20)')
     .                               TIMESTRING_stdpsf
      write(buffc( 8*80+1:09*80),'(''BSCALE  = '',f20.4)') 00001.00
      write(buffc( 9*80+1:10*80),'(''BZERO   = '',f20.4)') 00000.00
      write(buffc(10*80+1:11*80),'(''NXPSFs  = '',i20)') NXPSFs_stdpsf
      write(buffc(11*80+1:12*80),'(''NYPSFs  = '',i20)') NYPSFs_stdpsf
      do n = 01, 10
         k = 11+n
         write(buffc(k*80+1:k*80+80),'(''IPSFX'',i2.2,'' = '',i20)')
     .                                          n,ilist_stdpsf(n)
         enddo
      do n = 01, 10
         k = 21+n
         write(buffc(k*80+1:k*80+80),'(''JPSFY'',i2.2,'' = '',i20)')
     .                                          n,jlist_stdpsf(n)
         enddo
      write(buffc(32*80+1:34*80),'(''COMMENT '',a72)') COMMENT1_stdpsf
      write(buffc(33*80+1:34*80),'(''COMMENT '',a72)') COMMENT2_stdpsf
      write(buffc(34*80+1:35*80),'(''COMMENT '',a72)') COMMENT3_stdpsf
      write(buffc(35*80+1:36*80),'(''END                           '')')
      write(10,rec=1,iostat=ios) buffc
 
      ifirst = 2
      i = ifirst
 
      nbper  = 4*101*101*NNPSFs_stdpsf
      npt    =   101*101*NNPSFs_stdpsf
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i + nbyte1/2880
      i2 = i + nbyte2/2880
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         do q = 001, 720
            npu = np1+q-1
            nbu = (q-1)*4
            NN   = 1 + (npu-1)/101/101
            NY   = 1 + (NN-1)/NXPSFs_stdpsf
            NX   = NN - (NY-1)*NXPSFs_stdpsf
            jpsf = 1 +  (npu-1-(NN-1)*101*101)/101
c           ipsf = npu -     jpsf*101 - (NN-1)*101*101    ! old
            ipsf = npu - (jpsf-1)*101 - (NN-1)*101*101    ! fixed
            if (npu.ge.1.and.npu.le.npt)
     .          r = psfij_stdpsf(ipsf,jpsf,NX,NY)
            if (.not.islinux()) stop 'must be LINUX now...'
            buffb(nbu+1) = b(4)
            buffb(nbu+2) = b(3)
            buffb(nbu+3) = b(2)
            buffb(nbu+4) = b(1)
            enddo
         write(10,rec=i,iostat=ios) buffc
         enddo
 
      close(10)
 
      return
 
  900 continue
      print*,' '
      print*,'ERROR ACCESSING FITS FILE IN savefits_stdpsf(): '
      write(*,'('' FILEO: '',a80)') FILEO
      write(*,'('' FILEU: '',a80)') FILEU
      print*,' '
      stop
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPSFs/ROUTINES/writfits_psfpert2std.f"
c****                                         
c*********************************************
                                              
 
      subroutine writfits_psfpert2std(psfpert,NPERTs,STEM,
     .                                NAXIS1,NAXIS2,
     .                                PSFFILE_LIB,
     .                                PSFFILE_USE,
     .                                VERBOSE)
      implicit none
 
      real          psfpert(101,101,_NPRTMX_,_NPRTMX_)
      integer       NPERTs
      character*(*) STEM
      integer       NAXIS1
      integer       NAXIS2
      character*200 PSFFILE_LIB
      character*200 PSFFILE_USE
      integer       VERBOSE
 
      real*4, dimension(:,:,:), allocatable :: psfijn
 
c     integer PX, PY
      integer ipsf,jpsf
 
      integer NPSFs,  NPSF
      integer NXPSFs, NXPSF
      integer NYPSFs, NYPSF
      integer ilist(20)
      integer jlist(20)
      real*4  psfloc(101,101)
      integer i, j, ii
      real    xpsf, ypsf
      real    rx, ry
      real    rpsfpert_phot
 
      character*72 COMMENT1
      character*72 COMMENT2
      character*72 COMMENT3
 
      real atot
      real ctot
 
 
      if (VERBOSE.ge.2) then
          print*,'                    '
          print*,'ENTER psfpert2std...'
          print*,'      NPERTs: ',NPERTs
          print*,' PSFFILE_LIB: ',PSFFILE_LIB
          print*,' PSFFILE_USE: ',PSFFILE_USE
          endif
 
      call infofits_stdpsf(PSFFILE_LIB,NXPSFs,NYPSFs,ilist,jlist)
 
      NPSFs = NXPSFs*NYPSFs
 
      if (VERBOSE.ge.2) then
          print*,'                    '
          print*,'      NXPSFs: ',NXPSFs
          print*,'      NYPSFs: ',NYPSFs
          print*,'       NPSFs: ',NPSFs
          endif
 
      allocate(psfijn(101,101,NPSFs))
 
      atot = 0.
      ctot = 0.
      do NXPSF = 1, NPERTs
      do NYPSF = 1, NPERTs
         ctot = ctot + psfpert(051,051,NXPSF,NYPSF)
         do ipsf = 001, 101
         do jpsf = 001, 101
            atot = atot + abs(psfpert(ipsf,jpsf,NXPSF,NYPSF)/
     .                                NPERTs/NPERTs/16)
            enddo
            enddo
         enddo
         enddo
 
      do NXPSF = 1, NXPSFs
      do NYPSF = 1, NYPSFs
         NPSF = 1 + (NXPSF-1) + (NYPSF-1)*NXPSFs
         do ipsf = 001, 101
         do jpsf = 001, 101
            psfijn(ipsf,jpsf,NPSF) = 0.0
            enddo
            enddo
         enddo
         enddo
 
      NPSF = 0
      do NYPSF = 1, NYPSFs
      do NXPSF = 1, NXPSFs
         NPSF = 1 + (NXPSF-1) + (NYPSF-1)*NXPSFs
         call locpsfij_stdpsf(ilist(NXPSF),jlist(NYPSF),
     .                        psfijn(1,1,NPSF),PSFFILE_LIB)
 
         rx = 1. + 1.*ilist(NXPSF)*(NPERTs-1)/NAXIS1
         ry = 1. + 1.*jlist(NYPSF)*(NPERTs-1)/NAXIS2
         do ipsf = 001, 101
         do jpsf = 001, 101
            xpsf = (ipsf-51)*0.25
            ypsf = (jpsf-51)*0.25
            psfloc(ipsf,jpsf) = rpsfpert_phot(xpsf,ypsf,psfpert,
     .                                        rx,ry,NPERTs)
            psfijn(ipsf,jpsf,NPSF) = psfijn(ipsf,jpsf,NPSF)
     .                             + psfloc(ipsf,jpsf)
            enddo
            enddo
c        write(87,199) NXPSF,NYPSF,NPSF,
c    .                    ilist(NXPSF),jlist(NYPSF),rx,ry,
c    .                    psfijn(51,51,NPSF),psfloc(51,51),
c    .                    psfijn(51,51,NPSF)-psfloc(51,51)
         if (VERBOSE.ge.2) then
             write(*,199) NXPSF,NYPSF,NPSF,
     .                    ilist(NXPSF),jlist(NYPSF),rx,ry,
     .                    psfijn(51,51,NPSF),psfloc(51,51),
     .                    psfijn(51,51,NPSF)-psfloc(51,51)
             endif
  199    format(1x,i2.2,1x,i2.2,1x,i3.3,1x,i4.4,1x,i4.4,1x,
     .          3x,f8.3,1x,f8.3,5x,f10.5,5x,f10.5,5x,f10.5)
         enddo
         enddo
 
 
      ii = 80
      do i = 80, 56, -1
         if (PSFFILE_LIB(i:i).ne.' ') ii = i
         enddo
 
      COMMENT1 = 'PSFFILE_LIB: ' // PSFFILE_LIB(ii-55:ii)
      write(COMMENT2,198) trim(STEM),NPERTs
      write(COMMENT3,197) atot, ctot
  198 format('FOR STEM=',a,' AND NPERTs = ',i1)
  197 format('AVG ABS PERT: ',f8.5,10x,'AVG CEN PERT: ',f8.5)
 
      call writfits_stdpsf(PSFFILE_USE,psfijn,
     .                     NXPSFs,NYPSFs,ilist,jlist,
     .                     COMMENT1,COMMENT2,COMMENT3)
 
      if (VERBOSE.ge.2) then
          print*,' '
          do j = NYPSFs, 1, -1
             write(*,137) j,(psfijn(51,51,(j-1)*NXPSFs+i),i=1,NXPSFs)
  137        format(10x,i3,1x,10f10.5)
             enddo
          endif
 
      deallocate(psfijn)
 
      end
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPBFs/ROUTINES/infofits_stdpbf.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------------------------
c
c
c
 
      subroutine infofits_stdpbf(FILE,NXPSFs,NYPSFs,Fs,ilist,jlist)
      implicit none
 
      character*80 FILE
      integer NXPSFs
      integer NYPSFs
      integer Fs
      integer ilist(10)
      integer jlist(10)
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer i, k
      character*80 FILEU
 
      character*08 FIELD
      character*20 STREAM
 
      if (FILE(1:1).eq.'0') then
         NXPSFs = 2
         NYPSfs = 2
         ilist(1) = 0000
         ilist(2) = 9999
         jlist(1) = 0000
         jlist(2) = 9999
         Fs = 1
         return
         endif
 
      FILEU = 'NONE'
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
!$omp critical(infofits_stdpsf)
      print*,'OPEN25 FILE  = ',FILE
      print*,'OPEN25 FILEU = ',FILEU
      close(25)
      open(25,file=FILEU,
     .     status='old',
     .     err   =900,
     .     recl  =2880,
     .     access='DIRECT')
 
      NXPSFs = 0
      NYPSFs = 0
      do i = 01, 10
         ilist(i) = -999
         jlist(i) = -999
         enddo
 
      read(25,rec=1) buffc
 
      Fs = 0
      NXPSFs = 0
      NYPSFs = 0
      do k = 01, 35
         FIELD  = buffc(01+(k-1)*80:08+(k-1)*80)
         STREAM = buffc(11+(k-1)*80:30+(k-1)*80)
         if (FIELD.eq.'NXPSFs  ') read(STREAM,*) NXPSFs
         if (FIELD.eq.'NYPSFs  ') read(STREAM,*) NYPSFs
         if (FIELD.eq.'NAXIS4')   read(STREAM,*) Fs
         if (FIELD.eq.'IPSFX01 ') read(STREAM,*) ilist(01)
         if (FIELD.eq.'IPSFX02 ') read(STREAM,*) ilist(02)
         if (FIELD.eq.'IPSFX03 ') read(STREAM,*) ilist(03)
         if (FIELD.eq.'IPSFX04 ') read(STREAM,*) ilist(04)
         if (FIELD.eq.'IPSFX05 ') read(STREAM,*) ilist(05)
         if (FIELD.eq.'IPSFX06 ') read(STREAM,*) ilist(06)
         if (FIELD.eq.'IPSFX07 ') read(STREAM,*) ilist(07)
         if (FIELD.eq.'IPSFX08 ') read(STREAM,*) ilist(08)
         if (FIELD.eq.'IPSFX09 ') read(STREAM,*) ilist(09)
         if (FIELD.eq.'IPSFX10 ') read(STREAM,*) ilist(10)
         if (FIELD.eq.'JPSFY01 ') read(STREAM,*) jlist(01)
         if (FIELD.eq.'JPSFY02 ') read(STREAM,*) jlist(02)
         if (FIELD.eq.'JPSFY03 ') read(STREAM,*) jlist(03)
         if (FIELD.eq.'JPSFY04 ') read(STREAM,*) jlist(04)
         if (FIELD.eq.'JPSFY05 ') read(STREAM,*) jlist(05)
         if (FIELD.eq.'JPSFY06 ') read(STREAM,*) jlist(06)
         if (FIELD.eq.'JPSFY07 ') read(STREAM,*) jlist(07)
         if (FIELD.eq.'JPSFY08 ') read(STREAM,*) jlist(08)
         if (FIELD.eq.'JPSFY09 ') read(STREAM,*) jlist(09)
         if (FIELD.eq.'JPSFY10 ') read(STREAM,*) jlist(10)
         enddo
 
 
      do i = 01, NYPSFs-1
         if (jlist(i  ).eq.2048.and.
     .       jlist(i+1).eq.2048) jlist(i+1) = 2049
         enddo
 
 
 
      do i = 01, 10
         if (ilist(i).lt.0.or.jlist(i).lt.0) then
            print*,'infofits_stdpsf: '
            print*,'    HEADER NEEDs TO SPECIFY ALL IPSFs and JPSFs'
            print*,'       i: ',i,ilist(i),jlist(i)
            print*,'    FILE: ',FILEU
            stop
            endif
         if (NXPSFs.eq.0) stop 'infofits_stdpsf: HEADER NEEDs NXPSFs'
         if (NYPSFs.eq.0) stop 'infofits_stdpsf: HEADER NEEDs NXPSFs'
         enddo
 
      goto 901
 
 
  900 continue
      print*,' '
      print*,'ERROR ACCESSING FITS FILE IN infofits_stdpsf(): '
      write(*,'('' FILE : '',a80)') FILE
      write(*,'('' FILEU: '',a80)') FILEU
      print*,' '
      stop
  901 close(25)
!$omp end critical(infofits_stdpsf)
      return
      end
 
 
c*********************************************
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPBFs/ROUTINES/locpsfijf_stdpbf.f"
c****                                         
c*********************************************
                                              
 
      subroutine locpsfijf_stdpbf(iloc,jloc,floc,psfloc,FILEI)
      implicit none
 
      integer iloc
      integer jloc
      real    floc ! this is the focus level
      real    psfloc(101,101)
 
      character*200 FILEI
 
c
c-----------------------------------------
c
 
      integer ipsf, jpsf
 
c     integer F
      real    rf
      real    ff, fx, fy
 
 
      character*200 FILEI_stdpbf
      integer       NX, NXPSFs_stdpbf
      integer       NY, NYPSFs_stdpbf
      integer           NNPSFs_stdpbf    ! total num of spatial PSFs
      integer       NF, NFPSFs_stdpbf    ! number of focus levels
      integer       ilist_stdpbf(10)
      integer       jlist_stdpbf(10)
 
      common /FILEI_stdpbf_ /FILEI_stdpbf
      common /NXPSFs_stdpbf_/NXPSFs_stdpbf
      common /NYPSFs_stdpbf_/NYPSFs_stdpbf
      common /NNPSFs_stdpbf_/NNPSFs_stdpbf
      common /NFPSFs_stdpbf_/NFPSFs_stdpbf
      common /ilist_stdpbf_ /ilist_stdpbf
      common /jlist_stdpbf_ /jlist_stdpbf
 
      real psfijxyf_stdpbf(101,101,10,10,21) ! maximum of 10x10 zones and 11 focus levels
      common /psfijxyf_stdpbf_/psfijxyf_stdpbf
 
c
c-----------------------------------------
c
 
      if (FILEI(1:1).eq.'0') then
          do ipsf = 001, 101
          do jpsf = 001, 101
             psfloc(ipsf,jpsf) = 0.
             enddo
             enddo
         return
         endif
 
      if (FILEI.ne.FILEI_stdpbf) call loadfits_stdpbf(FILEI)
 
      nx = 1
    1 continue
      if (iloc.gt.ilist_stdpbf(nx+1).and.nx.le.NXPSFs_stdpbf-2) then
         nx = nx + 1
         goto 1
         endif
      fx = 1.00*(iloc              -ilist_stdpbf(NX))/
     .          (ilist_stdpbf(NX+1)-ilist_stdpbf(NX))
 
      ny = 1
    2 continue
      if (jloc.gt.jlist_stdpbf(ny+1).and.ny.le.NYPSFs_stdpbf-2) then
         ny = ny + 1
         goto 2
         endif
      fy = 1.00*(jloc              -jlist_stdpbf(NY))/
     .          (jlist_stdpbf(NY+1)-jlist_stdpbf(NY))
 
      rf = floc
      if (rf.le.0.99) then
         rf = (1+NFPSFs_stdpbf)/2.0
         endif
      if (rf.lt.1) rf = 1.0
      if (rf.gt.NFPSFs_stdpbf-0.001) rf = NFPSFs_stdpbf-0.0001
      nf = int(rf)
      ff = rf-nf
 
      do ipsf = 001, 101
      do jpsf = 001, 101
        psfloc(ipsf,jpsf)
     .  = (1-fx)*(1-fy)*(1-ff)*psfijxyf_stdpbf(ipsf,jpsf,nx  ,ny  ,nf  )
     .  + (1-fx)*( fy )*(1-ff)*psfijxyf_stdpbf(ipsf,jpsf,nx  ,ny+1,nf  )
     .  + ( fx )*(1-fy)*(1-ff)*psfijxyf_stdpbf(ipsf,jpsf,nx+1,ny  ,nf  )
     .  + ( fx )*( fy )*(1-ff)*psfijxyf_stdpbf(ipsf,jpsf,nx+1,ny+1,nf  )
     .  + (1-fx)*(1-fy)*( ff )*psfijxyf_stdpbf(ipsf,jpsf,nx  ,ny  ,nf+1)
     .  + (1-fx)*( fy )*( ff )*psfijxyf_stdpbf(ipsf,jpsf,nx  ,ny+1,nf+1)
     .  + ( fx )*(1-fy)*( ff )*psfijxyf_stdpbf(ipsf,jpsf,nx+1,ny  ,nf+1)
     .  + ( fx )*( fy )*( ff )*psfijxyf_stdpbf(ipsf,jpsf,nx+1,ny+1,nf+1)
        if (psfloc(ipsf,jpsf).lt.0.00) psfloc(ipsf,jpsf) = 0.00
        enddo
        enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPBFs/ROUTINES/findfocus_stdpbf.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------------
c
c this routine will determine the optimal focus for this
c image
c
c
      subroutine findfocus_stdpbf(pixc,HMB,HIFLAG,NAXIS1,NAXIS2,
     .                            FOCUS_LEVEL,Ns,PSFFILE_USE,VERBOSE)
      implicit none
 
      integer       NAXIS1, NAXIS2
      real          pixc(NAXIS1,NAXIS2)
      real          HMB
      integer       HIFLAG
      real          FOCUS_LEVEL
      integer       Ns
      character*200 PSFFILE_USE
      logical       VERBOSE
 
      integer i, ii, iii
      integer j, jj, jjj
 
      real*8 xr, yr, fr, sr
      real   qr, cr
      real   qmin
 
      real*8 xro, yro
 
      real   dx, dy
 
      real    FEST
c     integer hobs, fnd_hloc
c     integer pobs, fnd_ploc
c     real    mbar_sky
      integer L, Ls, Lu
      integer il(99999)
      integer jl(99999)
 
      real*8 , dimension(:), allocatable :: xl
      real*8 , dimension(:), allocatable :: yl
      real*4 , dimension(:), allocatable :: ml
      real*4 , dimension(:), allocatable :: zl
      real*4 , dimension(:), allocatable :: sl
      real*4 , dimension(:), allocatable :: ql
      real*4 , dimension(:), allocatable :: pl
      integer, dimension(:), allocatable :: ul
      real*4 , dimension(:,:,:), allocatable :: pixl
      real*4 , dimension(:,:,:), allocatable :: psfl
c     real*4   qbar, qsig
c     real*4   psfq
 
      real    rpsf_phot
      real    psfloc(101,101)
c     integer NSs, NSu
 
      real    fx, fy
 
      real   FMIN
      integer NIT
 
      integer FF
      real    rF, qtot
      common /qmin_/qmin
 
c
c-----------------------------------------------------------
c
 
      FMIN = HIFLAG
 
      if (VERBOSE) then
          print*,'                                              '
          print*,'ENTER FINDFOCUS:                              '
          print*,'                                              '
          print*,'   FIND THE AVERAGE DIFFERENCE BETWEEN THE    '
          print*,'   INPUT LIBRARY PSF AND THE PSF IN THIS IMAGE'
          print*,'                                              '
          print*,'         HIFLAG: ',HIFLAG
          print*,'           FMIN: ',FMIN
          print*,'            HMB: ',HMB
          print*,'            NIT: ',NIT
          print*,'         NAXIS1: ',NAXIS1
          print*,'         NAXIS2: ',NAXIS2
          print*,'            PSF: ',PSFFILE_USE
          print*,'      FOCUS_LEV: ',FOCUS_LEVEL
          print*,'                '
          endif
 
      Ls  = 0
      NIT = 0
  3   continue
      NIT = NIT + 1
      if (VERBOSE)
     .print*,'FIND_PSFFOCUS FIND STARS TO USE --- NIT: ',NIT,FMIN,Ls
 
      Ls = 0
      do jj = 10, NAXIS2-10
      do ii = 10, NAXIS1-10
         if (pixc(ii,jj).lt.FMIN/9) goto 222
         if (pixc(ii,jj).gt.HIFLAG) goto 222
         FEST = pixc(ii-1,jj+1) + pixc(ii,jj+1) + pixc(ii+1,jj+1)
     .        + pixc(ii-1,jj  ) + pixc(ii,jj  ) + pixc(ii+1,jj  )
     .        + pixc(ii-1,jj-1) + pixc(ii,jj-1) + pixc(ii+1,jj-1)
     .        - HMB*9
         if (FEST.lt. FMIN) goto 222
         if (pixc(ii,jj)-HMB.gt.0.666*FEST) goto 222 ! likely CR
         do i = -9, 9
         do j = -9, 9
            if (i**2+j**2.le.9.5**2) then
               if (pixc(ii+i,jj+j).gt.pixc(ii,jj)) goto 222
               endif
            if (i**2+j**2.le.5.5**2) then
               if (pixc(ii+i,jj+j).lt.-50) goto 222
               endif
            enddo
            enddo
 
         Ls = Ls + 1              ! being included
         if (Ls.gt.99999) then
            print*,'  Ls    : ', Ls
            print*,'       ii: ', ii
            print*,'       jj: ', jj
            print*,'  99999: ',99999
            stop
            endif
         il(Ls) = ii
         jl(Ls) = jj
 222     continue
         enddo
         enddo
 
      if (Ls.lt.10) then
         print*,' '
         print*,'NEED TO HAVE AT LEAST 10 FOCUS-DONOR STARS'
         print*,'IN THE EXPOSURE'
         print*,' '
         FMIN = FMIN/2.0
         if (FMIN.lt.2500) then
            print*,'FMIN: ',FMIN
            print*,'  Ls: ',Ls
            Ns = Ls
            FOCUS_LEVEL = -1.00
            return
            endif
         goto 3
         endif
 
      if (VERBOSE) print*,'FIND_PSFPERT: allocate Ls: ',Ls
 
      allocate(xl(Ls))
      allocate(yl(Ls))
      allocate(ml(Ls))
      allocate(zl(Ls))
      allocate(sl(Ls))
      allocate(ql(Ls))
      allocate(pl(Ls))
      allocate(ul(Ls))
      allocate(pixl(11,11,Ls))
      allocate(psfl(11,11,Ls))
 
 
      Lu = 0
      do L = 1, Ls
         ii = il(L)
         jj = jl(L)
         fx = (pixc(ii+1,jj)-pixc(ii-1,jj))/2/
     .        (pixc(ii  ,jj)-min(pixc(ii+1,jj),pixc(ii-1,jj)))
         fy = (pixc(ii,jj+1)-pixc(ii,jj-1))/2/
     .        (pixc(ii,jj  )-min(pixc(ii,jj+1),pixc(ii,jj-1)))
         xr = ii + fx
         yr = jj + fy
         xro = xr
         yro = yr
         sr = HMB
         call locpsfijf_stdpbf(ii,jj,0.0,psfloc,PSFFILE_USE) ! use the average PSF for now...
         call find_xyzXX_NAXIS(xr,yr,fr,sr,qr,cr,pixc,psfloc,
     .                         NAXIS1,NAXIS2,0,'5x5') ! 0 means weight by flux (center focus)
         if (qr.gt.0.50) goto 333  ! this may help prevent CRs from
         Lu = Lu + 1
         il(Lu) = ii
         jl(Lu) = jj
         xl(Lu) = xr
         yl(Lu) = yr
         ml(Lu) = SNGL(-2.5*log10(max(fr,1.)))
         zl(Lu) = SNGL(fr)
         sl(Lu) = SNGL(sr)
c        ql(Lu) = SNGL(qr)
         ql(Lu) = qr
         pl(Lu) = pixc(ii,jj)
         ul(Lu) = 1
         do i = 01, 11
         do j = 01, 11
            iii = ii+(i-6)
            jjj = jj+(j-6)
            dx  = SNGL(iii-xl(Lu))
            dy  = SNGL(jjj-yl(Lu))
            pixl(i,j,Lu) = pixc(iii,jjj) - sl(Lu)
            psfl(i,j,Lu) = rpsf_phot(dx,dy,psfloc)
            enddo
            enddo
         if (((Lu.lt.00010).or.
     .        (Lu.lt.00100.and.L.eq.L/0010*0010).or.
     .        (Lu.lt.01000.and.L.eq.L/0025*0025).or.
     .        (L.eq.Ls)).and.VERBOSE)
     .   write( *,182) Lu,il(Lu),jl(Lu),
     .                 xl(Lu),yl(Lu),ml(Lu),zl(Lu),sl(Lu),
     .                 psfl(6,6,Lu),ql(Lu),
     .                 pixc(ii,jj),psfloc(51,51)
 182     format(i5.5,1x,i4.4,1x,i4.4,
     .          3x,f9.3,1x,f9.3,1x,f8.4,1x,f10.1,1x,f7.2,
     .          3x,f8.6,1x,f8.6,4x,f9.1,1x,f8.4)
 333     continue
         enddo
 
      qmin = 999999.9
      fmin = 0.
      do FF = 010, 110, 02
         rF = FF/10.0
         qtot = 0.
         do L = 1, Lu
            sr = HMB
            ii = il(L)
            jj = jl(L)
            xr = xl(L)
            yr = yl(L)
            call locpsfijf_stdpbf(ii,jj,rF,psfloc,PSFFILE_USE)
            call find_xyzXX_NAXIS(xr,yr,fr,sr,qr,cr,pixc,psfloc,
     .                            NAXIS1,NAXIS2,0,'5x5') ! 0 means weight by flux (center focus)
            qtot = qtot + qr/Lu
            enddo
         if (VERBOSE) write( *,133) rF, qtot
  133    format(1x,f8.3,1x,f9.4)
         if (qtot.lt.qmin) then
             qmin = qtot
             fmin = rF
             endif
         enddo
 
      Ns = Ls
      FOCUS_LEVEL = fmin
      if (VERBOSE) then
         print*,' '
         print*,' '
         print*,'-----> FOCUS_LEVEL = ',FOCUS_LEVEL,qmin
         print*,' '
         print*,' '
         endif
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPBFs/ROUTINES/loadstdpsf_stdpbf.f"
c****                                         
c*********************************************
                                              
 
c----------------------------------------------------
c
c This routine will take floc (a value for the
c focus-level) and a PBF file and will interpolate
c betwen the focus levels to generate a standard psf,
c which can be used by the program or saved somewhere.
c If the focus level is given to be less than 1,
c then the routine will use the median focus level.
c
      subroutine loadstdpsf_stdpbf(floc,FILEI,FILEF)
      implicit none
 
      real    floc       ! this is the focus level
      character*200 FILEI ! ths is the STDPBF file
      character*200 FILEF
 
      integer ipsf, jpsf
 
c     integer F
      real    rf
c     real    ff, fx, fy
      real    ff
 
      integer i
c     integer NX, NY, NN, NF
      integer NX, NY, NF
c
c-----------------------------------------------------------
c
      character*200 FILEI_stdpbf
      integer       NXPSFs_stdpbf
      integer       NYPSFs_stdpbf
      integer       NNPSFs_stdpbf    ! total num of spatial PSFs
      integer       NFPSFs_stdpbf    ! number of focus levels
      integer       ilist_stdpbf(10)
      integer       jlist_stdpbf(10)
      character*72  COMMENT1_stdpbf
      character*72  COMMENT2_stdpbf
      character*20  DATESTRING_stdpbf
      character*20  TIMESTRING_stdpbf
 
      common /FILEI_stdpbf_ /FILEI_stdpbf
      common /NXPSFs_stdpbf_/NXPSFs_stdpbf
      common /NYPSFs_stdpbf_/NYPSFs_stdpbf
      common /NNPSFs_stdpbf_/NNPSFs_stdpbf
      common /NFPSFs_stdpbf_/NFPSFs_stdpbf
      common /ilist_stdpbf_ /ilist_stdpbf
      common /jlist_stdpbf_ /jlist_stdpbf
      common /COMMENT_stdpbf_/COMMENT1_stdpbf,
     .                        COMMENT2_stdpbf
      common /DATESTR_stdpbf_/DATESTRING_stdpbf
      common /TIMESTR_stdpbf_/TIMESTRING_stdpbf
 
      real psfijxyf_stdpbf(101,101,10,10,21) ! maximum of 10x10 zones and 11 focus levels
      common /psfijxyf_stdpbf_/psfijxyf_stdpbf
c
c-----------------------------------------------------------
c
      character*200 FILEI_stdpsf
      integer       NNPSFs_stdpsf
      integer       NXPSFs_stdpsf
      integer       NYPSFs_stdpsf
      integer       ilist_stdpsf(20)
      integer       jlist_stdpsf(20)
      character*72  COMMENT1_stdpsf
      character*72  COMMENT2_stdpsf
      character*72  COMMENT3_stdpsf
      character*20  DATESTRING_stdpsf
      character*20  TIMESTRING_stdpsf
      real*4        psfij_stdpsf(101,101,20,20)
 
      common /FILEI_stdpsf_  /FILEI_stdpsf
      common /NNPSFs_stdpsf_ /NNPSFs_stdpsf
      common /NXPSFs_stdpsf_ /NXPSFs_stdpsf
      common /NYPSFs_stdpsf_ /NYPSFs_stdpsf
      common /ilist_stdpsf_  /ilist_stdpsf
      common /jlist_stdpsf_  /jlist_stdpsf
      common /COMMENT_stdpsf_/COMMENT1_stdpsf,
     .                        COMMENT2_stdpsf,
     .                        COMMENT3_stdpsf
      common /DATESTR_stdpsf_/DATESTRING_stdpsf
      common /TIMESTR_stdpsf_/TIMESTRING_stdpsf
      common /psfij_stdpsf_  /psfij_stdpsf
c
c----------------------------------------------
c
 
 
c
c make sure the FILEU PBF is currently loaded
c into the common block
c
      print*,'ENTER loadstdpsf_stdpbf...'
 
      print*,' CALL loadfits_stdpbf...'
      call loadfits_stdpbf(FILEI)
 
 
 
c
c determine which of the STDPBF focus-related PSFs to
c interpolate between in order to make the single-focus
c STDPSF
c
      print*,' DETERMINE floc = ',floc
      rf = floc
      if (rf.le.0.99) then
         rf = (1+NFPSFs_stdpbf)/2.0
         floc = rf
         endif
      if (rf.lt.1) rf = 1.0
      if (rf.gt.NFPSFs_stdpbf-0.001) rf = NFPSFs_stdpbf-0.0001
      nf = int(rf)
      ff = rf-nf
 
      print*,'       USE floc = ',floc
 
      do NX = 1, 10
      do NY = 1, 10
         do ipsf = 001, 101
         do jpsf = 001, 101
            psfij_stdpsf(ipsf,jpsf,NX,NY)
     .          = (1-ff)*psfijxyf_stdpbf(ipsf,jpsf,NX,NY,NF  )
     .          + ( ff )*psfijxyf_stdpbf(ipsf,jpsf,NX,NY,NF+1)
            enddo
            enddo
         enddo
         enddo
 
 
c
c copy over the fiducial spatial info from the
c 5-d stdpbf to the 4-d stdpsf
c
      do i = 01, 10
         ilist_stdpsf(i) = ilist_stdpbf(i)
         jlist_stdpsf(i) = jlist_stdpbf(i)
         enddo
 
      FILEI_stdpsf  = FILEF
 
      NXPSFs_stdpsf = NXPSFs_stdpbf
      NYPSFs_stdpsf = NYPSFs_stdpbf
      NNPSFs_stdpsf = NNPSFs_stdpbf
 
      DATESTRING_stdpsf = DATESTRING_stdpbf
      TIMESTRING_stdpsf = TIMESTRING_stdpbf
 
      COMMENT1_stdpsf = COMMENT1_stdpbf
      COMMENT2_stdpsf = COMMENT2_stdpbf
      write(COMMENT3_stdpsf,'(''FOCUS LEVEL = '',f8.3)') floc
 
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPBFs/ROUTINES/loadfits_stdpbf.f"
c****                                         
c*********************************************
                                              
 
 
c----------------------------------------------------------------------
c
c This routine will load in a STDPBF file into the common
c block that will allow it to be used by whatever program
c is calling.
c
c
      subroutine loadfits_stdpbf(FILEI)
      implicit none
 
      character*200 FILEI
 
      integer i
      integer ipsf, jpsf
      integer NX, NY, NN, NF
      character*200 FILEU
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer k
 
      character*08 FIELD
      character*20 STREAM
 
      real, dimension(:,:,:,:), allocatable :: psf_ijnf
 
      integer BITPIX
      integer NAXIS1, NAXIS2, NAXIS3, NAXIS4
      real    BZERO
      real    BSCALE
 
      integer NCOMs
c
c-----------------------------------------
c
      character*200 FILEI_stdpbf
      data FILEI_stdpbf/'NONE'/
 
      integer NXPSFs_stdpbf
      integer NYPSFs_stdpbf
      integer NNPSFs_stdpbf   ! total num of spatial PSFs
      integer NFPSFs_stdpbf   ! number of focus levels
 
      integer ilist_stdpbf(10)
      integer jlist_stdpbf(10)
 
      common /FILEI_stdpbf_ /FILEI_stdpbf
      common /NXPSFs_stdpbf_/NXPSFs_stdpbf
      common /NYPSFs_stdpbf_/NYPSFs_stdpbf
      common /NNPSFs_stdpbf_/NNPSFs_stdpbf
      common /NFPSFs_stdpbf_/NFPSFs_stdpbf
      common /ilist_stdpbf_ /ilist_stdpbf
      common /jlist_stdpbf_ /jlist_stdpbf
 
      character*72 COMMENT1_stdpbf
      character*72 COMMENT2_stdpbf
      common /COMMENT_stdpbf_/COMMENT1_stdpbf,
     .                        COMMENT2_stdpbf
      character*20 DATESTRING_stdpsf
      character*20 TIMESTRING_stdpsf
      common /DATESTRING_stdpbf_/DATESTRING_stdpsf
      common /TIMESTRING_stdpbf_/TIMESTRING_stdpsf
 
      real psfijxyf_stdpbf(101,101,10,10,21) ! maximum of 11 focus levels and 10 zones
      common /psfijxyf_stdpbf_/psfijxyf_stdpbf
 
      integer ios
c
c-----------------------------------------
c
 
      if (FILEI_stdpbf.eq.FILEI) return
 
 
      FILEU = 'NONE'
      do i = 195,2,-1
         if (FILEI(i:i+4).eq.'.fits') FILEU = FILEI(1:i+4)
         enddo
 
      close(25)
      open(25,file=FILEU,
     .     status='old',
     .     err   =900,
     .     recl  =2880,
     .     iostat=ios,
     .     access='DIRECT')
 
      FILEI_stdpbf = FILEI
 
      NXPSFs_stdpbf = 0
      NYPSFs_stdpbf = 0
      do i = 01, 10
         ilist_stdpbf(i) = -999
         jlist_stdpbf(i) = -999
         enddo
      COMMENT1_stdpbf = 'NO COMMENT'
      COMMENT2_stdpbf = 'NO COMMENT'
 
      read(25,rec=1) buffc
      close(25) ! this routine only needs to read the header
 
      BITPIX = 0
      NAXIS1 = 0
      NAXIS2 = 0
      NAXIS3 = 0
      NAXIS4 = 0
      BZERO  = -1
      BSCALE = 0
 
      NCOMs = 0
      do k = 01, 35
         FIELD  = buffc(01+(k-1)*80:08+(k-1)*80)
         STREAM = buffc(11+(k-1)*80:30+(k-1)*80)
         if (FIELD.eq.'BITPIX  ') read(STREAM,*) BITPIX
         if (FIELD.eq.'NAXIS1')   read(STREAM,*) NAXIS1
         if (FIELD.eq.'NAXIS2')   read(STREAM,*) NAXIS2
         if (FIELD.eq.'NAXIS3')   read(STREAM,*) NAXIS3
         if (FIELD.eq.'NAXIS4')   read(STREAM,*) NAXIS4
         if (FIELD.eq.'BZERO ')   read(STREAM,*) BZERO
         if (FIELD.eq.'BSCALE')   read(STREAM,*) BSCALE
         if (FIELD.eq.'NXPSFs  ') read(STREAM,*) NXPSFs_stdpbf
         if (FIELD.eq.'NYPSFs  ') read(STREAM,*) NYPSFs_stdpbf
         if (FIELD.eq.'NAXIS4')   read(STREAM,*) NFPSFs_stdpbf
         if (FIELD.eq.'IPSFX01 ') read(STREAM,*) ilist_stdpbf(01)
         if (FIELD.eq.'IPSFX02 ') read(STREAM,*) ilist_stdpbf(02)
         if (FIELD.eq.'IPSFX03 ') read(STREAM,*) ilist_stdpbf(03)
         if (FIELD.eq.'IPSFX04 ') read(STREAM,*) ilist_stdpbf(04)
         if (FIELD.eq.'IPSFX05 ') read(STREAM,*) ilist_stdpbf(05)
         if (FIELD.eq.'IPSFX06 ') read(STREAM,*) ilist_stdpbf(06)
         if (FIELD.eq.'IPSFX07 ') read(STREAM,*) ilist_stdpbf(07)
         if (FIELD.eq.'IPSFX08 ') read(STREAM,*) ilist_stdpbf(08)
         if (FIELD.eq.'IPSFX09 ') read(STREAM,*) ilist_stdpbf(09)
         if (FIELD.eq.'IPSFX10 ') read(STREAM,*) ilist_stdpbf(10)
         if (FIELD.eq.'JPSFY01 ') read(STREAM,*) jlist_stdpbf(01)
         if (FIELD.eq.'JPSFY02 ') read(STREAM,*) jlist_stdpbf(02)
         if (FIELD.eq.'JPSFY03 ') read(STREAM,*) jlist_stdpbf(03)
         if (FIELD.eq.'JPSFY04 ') read(STREAM,*) jlist_stdpbf(04)
         if (FIELD.eq.'JPSFY05 ') read(STREAM,*) jlist_stdpbf(05)
         if (FIELD.eq.'JPSFY06 ') read(STREAM,*) jlist_stdpbf(06)
         if (FIELD.eq.'JPSFY07 ') read(STREAM,*) jlist_stdpbf(07)
         if (FIELD.eq.'JPSFY08 ') read(STREAM,*) jlist_stdpbf(08)
         if (FIELD.eq.'JPSFY09 ') read(STREAM,*) jlist_stdpbf(09)
         if (FIELD.eq.'JPSFY10 ') read(STREAM,*) jlist_stdpbf(10)
         if (FIELD.eq.'COMMENT ') then
            NCOMs = NCOMs + 1
            if (NCOMs.gt.2) stop '.gt.2 COMMENTS IN AN STDPBF FILE'
            if (NCOMs.eq.1) COMMENT1_stdpbf = buffc(09+(k-1)*80:
     .                                              80+(k-1)*80)
            if (NCOMs.eq.2) COMMENT2_stdpbf = buffc(09+(k-1)*80:
     .                                              80+(k-1)*80)
            endif
         if (FIELD.eq.'END     ') goto 3
         enddo
    3 continue
 
      if (BZERO.ne.0.or.
     .    BSCALE.ne.1.or.
     .    NAXIS1.ne.101.or.
     .    NAXIS2.ne.101.or.
     .    NAXIS3.gt.100.or.
     .    NAXIS4.gt. 21) then
          print*,' '
          print*,'STDPBF FITS FILE NOT IN COMPLIANCE: '
          print*,'  FILEU: ',FILEU
          print*,'                  '
          print*,'FIGURE OUT WHERE: '
          print*,'  BSCALE must be ==  1:  BSCALE: ',BSCALE
          print*,'  BZERO  must be ==  0:  BZERO : ',BZERO
          print*,'  NAXIS1 must be ==101:  NAXIS1: ',NAXIS1
          print*,'  NAXIS2 must be ==101:  NAXIS2: ',NAXIS2
          print*,'  NAXIS3 must be <=100:  NAXIS3: ',NAXIS3
          print*,'  NAXIS4 must be <= 21:  NAXIS4: ',NAXIS4
          print*,'                  '
          print*,'                  '
          do k = 01, 35
             FIELD  = buffc(01+(k-1)*80:08+(k-1)*80)
             STREAM = buffc(11+(k-1)*80:30+(k-1)*80)
             write(*,'(i2.2,1x,a80)') k,buffc(01+(k-1)*80:80+(k-1)*80)
             enddo
          print*,'                  '
          stop   'in STDPBF'
          endif
 
      do i = 01, 10
         if (ilist_stdpbf(i).lt.0.or.jlist_stdpbf(i).lt.0) then
            print*,'                 '
            print*,'infofits_stdpsf: '
            print*,'                 '
            print*,'  HEADER NEEDs TO SPECIFY ALL IPSFs and JPSFs'
            print*,'                 i : ',i
            print*,'    ilist_stdpbf(i): ',ilist_stdpbf(i)
            print*,'    jlist_stdpbf(i): ',jlist_stdpbf(i)
            print*,'               FILE: ',FILEU
            print*,'                     '
            stop
            endif
         enddo
 
      do i = 01, NYPSFs_stdpbf-1
         if (jlist_stdpbf(i  ).eq.2048.and.
     .       jlist_stdpbf(i+1).eq.2048) jlist_stdpbf(i+1) = 2049
         enddo
 
      write(*,'(''#                          '')')
      write(*,'(''#  LOADFITS_STDPBF '')')
      write(*,'(''#                          '')')
      write(*,'(''#   FILEI_stdpbf: '',80a)') FILEI_stdpbf
      write(*,'(''#  NXPSFs_stdpbf: '',i4.2,1x,10i6)')
     .               NXPSFs_stdpbf,(ilist_stdpbf(NX),NX=1,NXPSFs_stdpbf)
      write(*,'(''#  NYPSFs_stdpbf: '',i4.2,1x,10i6)')
     .               NYPSFs_stdpbf,(jlist_stdpbf(NY),NY=1,NYPSFs_stdpbf)
      NNPSFs_stdpbf = NXPSFs_stdpbf*NYPSFs_stdpbf
      write(*,'(''#  NNPSFs: '',i4.2)') NNPSFs_stdpbf
      write(*,'(''#  NFPSFs: '',i4.2)') NFPSFs_stdpbf
      write(*,'(''#                          '')')
 
      allocate(psf_ijnf(101,101,NNPSFs_stdpbf,NFPSFs_stdpbf))
      call readfits_r4_4D(FILEU,psf_ijnf,101,101,NNPSFs_stdpbf,
     .                                           NFPSFs_stdpbf)
 
      do NX = 1, 10
      do NY = 1, 10
      do NF = 1, 21
         do ipsf = 001, 101
         do jpsf = 001, 101
            psfijxyf_stdpbf(ipsf,jpsf,NX,NY,NF) = 0.
            enddo
            enddo
         enddo
         enddo
         enddo
 
      do NF = 01, NFPSFs_stdpbf
         do NX = 1, NXPSFs_stdpbf
         do NY = 1, NYPSFs_stdpbf
            NN = NX + (NY-1)*NXPSFs_stdpbf
            do ipsf = 001, 101
            do jpsf = 001, 101
               psfijxyf_stdpbf(ipsf,jpsf,NX,NY,NF) = 0.
               enddo
               enddo
            do ipsf = 001, 101
            do jpsf = 001, 101
               i = int(psf_ijnf(ipsf,jpsf,NN,NF))
               enddo
               enddo
            do ipsf = 001, 101
            do jpsf = 001, 101
               psfijxyf_stdpbf(ipsf,jpsf,NX,NY,NF) =
     .                psf_ijnf(ipsf,jpsf,NN,NF)
               enddo
               enddo
            enddo
            enddo
         enddo
 
      deallocate(psf_ijnf)
 
      return
 
  900 continue
      print*,' '
      print*,'ERROR ACCESSING FITS FILE IN loadfits_stdpbf(): '
      print*,' '
      write(*,'('' FILEI_stdpbf: '',a80)') FILEI_stdpbf
      write(*,'('' FILEI       : '',a80)') FILEI
      write(*,'('' FILEU       : '',a80)') FILEU
      print*,' '
      write(*,'(''       iostat: '',i5)')  ios
      print*,' '
      stop
 
 
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/STDPSFs/ROUTINES/rpsf_phot_ij_stdpsf.f"
c****                                         
c*********************************************
                                              
 
 
c--------------------------------------------------------
c
c this routine evaluates the PSF at a pixel that is at a
c particular location relative to the center of a star (dx,dy)
c for a star that it at a particular location in an image (iloc,jloc).
c The PSF in PSFFILE is evaluated.  It uses the standard
c PSF format and only reads in a new PSF if the filename
c has changed.
c
      real function rpsf_phot_ij_STDPSF(dx,dy,iloc,jloc,PSFFILE)
      implicit none
 
      real          dx         ! input x offset of pixel from star center
      real          dy         ! input y offset of pixel from star center
      integer       iloc,jloc  ! input integer location of star central pixel
      character*(*) PSFFILE    ! STDPSF file name
 
c
c--------------------------------------------------------------
c
 
      integer nx, ny
      real    fx, fy
      real    rpsf_phot
c     integer i,j
 
c
c-------------------------------------------------
c
c These are the variables from the STDPSF common
c block that are needed to evaluate the PSF
c
      real*4       psfij_stdpsf(101,101,20,20)
      integer      NNPSFs_stdpsf
      integer      NXPSFs_stdpsf
      integer      NYPSFs_stdpsf
      integer      ilist_stdpsf(20)
      integer      jlist_stdpsf(20)
 
      common /psfij_stdpsf_  /psfij_stdpsf
      common /NNPSFs_stdpsf_ /NNPSFs_stdpsf
      common /NXPSFs_stdpsf_ /NXPSFs_stdpsf
      common /NYPSFs_stdpsf_ /NYPSFs_stdpsf
      common /ilist_stdpsf_  /ilist_stdpsf
      common /jlist_stdpsf_  /jlist_stdpsf
c
c-------------------------------------------------
c
 
c
c this routine will read in a new STDPSF into
c the current buffer; if PSFFILE is already read
c in, it will do nothing
c
      call loadfits_stdpsf(PSFFILE)
 
 
c-----------------------------------------------------------------
c
c determine which two x-columns we must interpolate between
c for this particular location in the image
c
      nx = 1
    1 continue
      if (iloc.gt.ilist_stdpsf(nx+1).and.nx.le.NXPSFs_stdpsf-2) then
         nx = nx + 1
         goto 1
         endif
 
c-----------------------------------------------------------------
c
c determine which two y-rows we must interpolate between
c for this particular location in the image
c
      ny = 1
    2 continue
      if (jloc.gt.jlist_stdpsf(ny+1).and.ny.le.NYPSFs_stdpsf-2) then
         ny = ny + 1
         goto 2
         endif
 
c-----------------------------------------------------------------
c
c determine where we are between the columns and rows
c
      fx = 1.00*(iloc              -ilist_stdpsf(NX))/
     .          (ilist_stdpsf(NX+1)-ilist_stdpsf(NX))
      fy = 1.00*(jloc              -jlist_stdpsf(NY))/
     .          (jlist_stdpsf(NY+1)-jlist_stdpsf(NY))
 
      if (NXPSFs_stdpsf.eq.1) then
         fx = 0.0
         NX = 1
         endif
      if (NYPSFs_stdpsf.eq.1) then
         fy = 0.0
         NY = 1
         endif
 
c-----------------------------------------------------------------
c
c now, evaluate the PSF at the four local fiducial locations, then
c do a simple bi-linear interpolation
c
      rpsf_phot_ij_STDPSF
     .    = (1-fx)*(1-fy)*rpsf_phot(dx,dy,psfij_stdpsf(1,1,NX  ,NY  ))
     .    + (1-fx)*( fy )*rpsf_phot(dx,dy,psfij_stdpsf(1,1,NX  ,NY+1))
     .    + ( fx )*(1-fy)*rpsf_phot(dx,dy,psfij_stdpsf(1,1,NX+1,NY  ))
     .    + ( fx )*( fy )*rpsf_phot(dx,dy,psfij_stdpsf(1,1,NX+1,NY+1))
 
      return
      end
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/IMAGE/pix2mask.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------------------
c
c there are three parameters for this model:
c
c    0) distance mapping --- dgen(NRAD)
c    1) radial   profile --- pgen(C,NRAD)
c    2) spike    profile --- sgen(C,NRAD)
c    3) spike    width   --- wgen(C,NRAD)
c
c
      subroutine pix2mask(pixm,KKK,
     .                    BBs,iref_bb,jref_bb,zref_bb,
     .                    NAXIS1,NAXIS2)
      implicit none
 
      integer NAXIS1
      integer NAXIS2
      real    pixm(NAXIS1,NAXIS2)
      integer KKK
 
      integer BBs
      integer iref_bb(BBs)
      integer jref_bb(BBs)
      real    zref_bb(BBs)
c
c----------------------------------------------------------
c
      integer BB
 
      integer dgen(23)
      common /dgen_/dgen
 
      real rgen(10,23) ! profile for radial part
      common /rgen_/rgen
 
      real sgen(10,23) ! profile for spike
      common /sgen_/sgen
 
      integer wgen(10,23) ! spike width
      common /wgen_/wgen
 
      real ANGLE_XC(4,10) ! x angle at the 4 corners   !  3  4
      common /angle_xc_/angle_xc                       !  1  2
      data angle_xc/
     .  000.00, 000.00, 000.00, 000.00, !  1
     .  000.00, 000.00, 000.00, 000.00, !  2
     .  000.00, 000.00, 000.00, 000.00, !  3
     .  000.00, 000.00, 000.00, 000.00, !  4
     .   -1.40,  -1.30,  -4.00,  -2.30, !  5
     .  000.00, 000.00, 000.00, 000.00, !  6
     .   -6.00,  -6.00,  -6.00,  -6.00, !  7
     .   43.02,  43.29,  43.03,  43.11, !  8
     .  048.10, 048.10, 048.10, 048.10, !  9
     .  000.00, 000.00, 000.00, 000.00/ ! 10
 
      real ANGLE_YC(4,10) ! y angle at the 4 corners
      common /angle_yc_/angle_yc
      data angle_yc/
     .  090.00, 090.00, 090.00, 090.00, !  1
     .  090.00, 090.00, 090.00, 090.00, !  2
     .  090.00, 090.00, 090.00, 090.00, !  3
     .  090.00, 090.00, 090.00, 090.00, !  4
     .  092.40, 091.50, 093.80, 091.60, !  5
     .  090.00, 090.00, 090.00, 090.00, !  6
     .  090.00, 090.00, 090.00, 090.00, !  7
     .  -46.21, -46.78, -46.84, -47.39, !  8
     .  -48.10, -48.10, -48.10, -48.10, !  9
     .  090.00, 090.00, 090.00, 090.00/ ! 10
 
      integer ANGLE_EC(10) ! extent ... where are the corners?
      common /angle_ec_/angle_ec
      data angle_ec/
     .   800,  800,  800,  800, 4096,
     .  4096, 1024, 4096, 4096, 1014/
 
      integer F
      real fx, fy
      real angle_x, angle_y
      real cosx, sinx
      real cosy, siny
      real zu
c     real zr
      integer i, iu, ii
      integer j, ju, jj
c     integer NR
      integer ir
c     real    rr, rru
c     real    fxl(4), fyl(4)
c     character*80 FILENAME
c     real    rprofi(1001)
c     real    sprofi(1001)
c     real    wprofi(1001)
      real    dya
      real    dyb
c     integer IRs
c     real*8  xcor, ycor
      real*8  xraw, yraw
      integer iraw, jraw
c     real*8  xcor0,ycor0
 
      real mask0(2001,2001)
      real mask1(2001,2001)
      real mask2(2001,2001)
      real mask3(2001,2001)
c     real xx, yy
c     real    z, zmax
c     integer FMAX
      integer ia1(2001), ib1(2001), ja1, jb1
      integer ia2(2001), ib2(2001), ja2, jb2
      integer ia3(2001), ib3(2001), ja3, jb3
 
      real    rprof_ik
      real    sprof_ik
      integer wprof_ik
      real    fxold, fyold
      integer ffold
c     logical same
c     real    xr_uv, yr_uv
 
      common /fxyf/ fxold, fyold, ffold
 
      data fxold / -1.0/
      data fyold / -1.0/
      data ffold / -1.0/
 
      real pixm_sum(4096,4096) ! the sum of them
      real pixm_max(4096,4096) ! the max of them
 
      fx = -1.0
      fy = -1.0
      F  = -1.0
 
      fxold = fx
      fyold = fy
      ffold = F
 
      if (.true.) then
         print*,'                 '
         print*,'ENTER MASK_TILE: '
         print*,'            KKK: ',KKK
         print*,'            BBs: ',BBs
         print*,'                 '
         endif
 
      if (NAXIS1.ne.4096.or.
     .    NAXIS2.ne.4096) stop 'mask NAXIS hardcode probs'
 
      do i = 001, 4096
      do j = 001, 4096
         pixm_max(i,j) = 0.
         pixm_sum(i,j) = 0.
         enddo
         enddo
 
      do BB = 1, BBs
         if (BB.eq.BB/10*10)
     .       print*,'--- masking sat star ---> BB: ',BB,' / ',BBs
 
         xraw = iref_bb(BB)
         yraw = jref_bb(BB)
         zu   = zref_bb(BB)
 
         fx = 0.5
         fy = 0.5
         if (KKK.eq.5) then ! ACS/WFC
            fx = SNGL(xraw/4096.0)
            fy = SNGL(yraw/4096.0)
            endif
         if (KKK.eq.7) then ! ACS/HRC
            fx = SNGL(xraw/1024.0)
            fy = SNGL(yraw/1024.0)
            endif
         if (KKK.eq.8) then ! WFC3/UVIS
            fx = SNGL(xraw/4096.0)
            fy = SNGL(yraw/4096.0)
            endif
         if (KKK.eq.8) then ! WFC3/UVIS
            fx = SNGL(xraw/4096.0)
            fy = SNGL(yraw/4096.0)
            endif
         if (fx.lt.0.00) fx = 0.0
         if (fy.lt.0.00) fy = 0.0
         if (fx.gt.1.00) fx = 1.0
         if (fy.gt.1.00) fy = 1.0
 
         ANGLE_X = (1-fx)*(1-fy)*ANGLE_XC(1,KKK)
     .           + ( fx )*(1-fy)*ANGLE_XC(2,KKK)
     .        + (1-fx)*( fy )*ANGLE_XC(3,KKK)
     .        + ( fx )*( fy )*ANGLE_XC(4,KKK)
         ANGLE_Y = (1-fx)*(1-fy)*ANGLE_YC(1,KKK)
     .           + ( fx )*(1-fy)*ANGLE_YC(2,KKK)
     .           + (1-fx)*( fy )*ANGLE_YC(3,KKK)
     .           + ( fx )*( fy )*ANGLE_YC(4,KKK)
         cosx = cos(ANGLE_X*3.14159/180)
         sinx = sin(ANGLE_X*3.14159/180)
         cosy = cos(ANGLE_Y*3.14159/180)
         siny = sin(ANGLE_Y*3.14159/180)
         ja1 = 2001
         ja2 = 2001
         ja3 = 2001
         jb1 = 0001
         jb2 = 0001
         jb3 = 0001
         do j = 0001, 2001
            ia1(j) = 2001
            ib1(j) = 0001
            ia2(j) = 2001
            ib2(j) = 0001
            ia3(j) = 2001
            ib3(j) = 0001
            do i = 0001, 2001
               mask0(i,j) = 0.00
               mask1(i,j) = 0.00
               mask2(i,j) = 0.00
               mask3(i,j) = 0.00
               ir = int(1 + sqrt((i-1001.)**2+(j-1001.)**2))
               if (ir.le.1001) then
                  mask1(i,j) = mask1(i,j) + rprof_ik(ir,KKK)
                  dya = (i-1001)*sinx - (j-1001)*cosx
                  if (abs(dya).lt.wprof_ik(ir,KKK)) then
                     mask2(i,j) = mask2(i,j) + sprof_ik(ir,KKK)
                     endif
                  dyb = (i-1001)*siny - (j-1001)*cosy
                  if (abs(dyb).lt.wprof_ik(ir,KKK)) then
                     mask3(i,j) = mask3(i,j) + sprof_ik(ir,KKK)
                     endif
                  endif
               mask0(i,j) = mask1(i,j) + mask2(i,j) + mask3(i,j)
               enddo
            ia1(j) = 2001
            ia2(j) = 2001
            ia3(j) = 2001
            ib1(j) = 0001
            ib2(j) = 0001
            ib3(j) = 0001
            do i = 0001, 2001
               if (mask1(i,j).gt.0) ib1(j) = i
               if (mask2(i,j).gt.0) ib2(j) = i
               if (mask3(i,j).gt.0) ib3(j) = i
               enddo
            do i = 2001, 0001, -1
               if (mask1(i,j).gt.0) ia1(j) = i
               if (mask2(i,j).gt.0) ia2(j) = i
               if (mask3(i,j).gt.0) ia3(j) = i
               enddo
            if (ia1(j).ne.2001) then
               ja1 = min(j,ja1)
               jb1 = max(j,jb1)
               endif
            if (ia2(j).ne.2001) then
               ja2 = min(j,ja2)
               jb2 = max(j,jb2)
               endif
            if (ia3(j).ne.2001) then
               ja3 = min(j,ja3)
               jb3 = max(j,jb3)
               endif
            enddo
 
         iraw = int(xraw+0.5)
         jraw = int(yraw+0.5)
         iu = iraw
         ju = jraw
 
         if (iu+1000.le. 0001 ) goto 333
         if (ju+1000.le. 0001 ) goto 333
         if (iu-1000.ge.4096) goto 333
         if (ju-1000.ge.4096) goto 333
 
         do j = ja2, jb2
            jj = ju + (j-1001)
            if (jj.ge.001.and.jj.le.4096) then
               do i = ia2(j), ib2(j)
                  ii = iu + (i-1001)
                  if (ii.ge.001.and.ii.le.4096) then
                     pixm_sum(ii,jj)= pixm_sum(ii,jj)+(zu*mask2(i,j))**2
                     pixm_max(ii,jj)= max(pixm_max(ii,jj),zu*mask2(i,j))
                     endif
                  enddo
               endif
            enddo
 
         do j = ja3, jb3
            jj = ju + (j-1001)
            if (jj.ge.001.and.jj.le.4096) then
               do i = ia3(j), ib3(j)
                  ii = iu + (i-1001)
                  if (ii.ge.001.and.ii.le.4096) then
                     pixm_sum(ii,jj)= pixm_sum(ii,jj)+(zu*mask3(i,j))**2
                     pixm_max(ii,jj)= max(pixm_max(ii,jj),zu*mask3(i,j))
                     endif
                  enddo
               endif
            enddo
 
c        if (iu+iref_bb(BB).lt. 0001 ) goto 333
c        if (iu-iref_bb(BB).gt.4096) goto 333
c        if (ju+jref_bb(BB).lt. 0001 ) goto 333
c        if (ju-jref_bb(BB).gt.4096) goto 333
 
         do j = ja1, jb1
            jj = ju + (j-1001)
            if (jj.ge.001.and.jj.le.4096) then
               do i = ia1(j), ib1(j)
                  ii = iu + (i-1001)
                  if (ii.ge.001.and.ii.le.4096) then
                     pixm_sum(ii,jj)= pixm_sum(ii,jj)+(zu*mask1(i,j))**2
                     pixm_max(ii,jj)= max(pixm_max(ii,jj),zu*mask1(i,j))
                     endif
                  enddo
               endif
            enddo
 
  333    continue
         enddo
 
      do i = 0001, 4096
      do j = 0001, 4096
         pixm(i,j) = sqrt(pixm_sum(i,j))
         enddo
         enddo
 
      return
      end
 
 
 
 
c------------------------------------------------------
c
c this will act like a simple array
c
      real function rprof_ik(ir,k)
      implicit none
 
      integer ir, k
      real rprof_arr(1001,10)
      common /rprof_arr_/rprof_arr
 
      integer dgen(23)
      common /dgen_/dgen
 
      real rgen(10,23)
      common /rgen_/rgen
 
      logical first_rprof
      common /first_rprof_/ first_rprof
      data first_rprof/.true./
 
      integer i, ii, iiu
      integer kk
      real    ff
 
      if (first_rprof) then
         do i = 0001, 1001
            iiu = 0
            do ii = 1, 22
               if (i.ge.dgen(ii)) iiu = ii
               enddo
            if (iiu.eq.00) stop 'screech iiu.eq.00'
            if (iiu.ge.23) stop 'screech iiu.ge.23'
            ff = (i-dgen(iiu))*1.0/(dgen(iiu+1)-dgen(iiu))
            do kk = 01, 10
               rprof_arr(i,kk) = rgen(kk,iiu)
     .                         + ff*(rgen(kk,iiu+1)-rgen(kk,iiu))
               enddo
            enddo
         first_rprof = .false.
         endif
 
      rprof_ik = 0.
      if (ir.lt.0001.or.ir.gt.1001) return
      rprof_ik = rprof_arr(ir,k)
 
      return
      end
 
 
 
c------------------------------------------------------
c
c this will act like a simple array ; the spike profile
c
      real function sprof_ik(ir,k)
      implicit none
 
      integer ir, k
      real sprof_arr(1001,10)
      common /sprof_arr_/sprof_arr
 
      integer dgen(23)
      common /dgen_/dgen
 
      real sgen(10,23)
      common /sgen_/sgen
 
      logical first_sprof
      common /first_sprof_/ first_sprof
      data first_sprof/.true./
 
      integer i, ii, iiu
      integer kk
      real    ff
 
      if (first_sprof) then
         do i = 0001, 1001
            iiu = 0
            do ii = 1, 22
               if (i.ge.dgen(ii)) iiu = ii
               enddo
            if (iiu.eq.00) stop 'screech iiu.eq.00'
            if (iiu.ge.23) stop 'screech iiu.ge.23'
            ff = (i-dgen(iiu))*1.0/(dgen(iiu+1)-dgen(iiu))
            do kk = 01, 10
               sprof_arr(i,kk) = sgen(kk,iiu)
     .                         + ff*(sgen(kk,iiu+1)-sgen(kk,iiu))
               enddo
            enddo
         first_sprof = .false.
         endif
 
      sprof_ik = 0.
      if (ir.lt.0001.or.ir.gt.1001) return
      sprof_ik = sprof_arr(ir,k)
 
      return
      end
 
 
 
c------------------------------------------------------
c
c this will act like a simple array ; the spike-width profile
c
      integer function wprof_ik(ir,k)
      implicit none
 
      integer ir, k
      integer wprof_arr(1001,10)
      common /wprof_arr_/wprof_arr
 
      integer dgen(23)
      common /dgen_/dgen
 
      integer wgen(10,23)
      common /wgen_/wgen
 
      logical first_wprof
      common /first_wprof_/ first_wprof
      data first_wprof/.true./
 
      integer i, ii, iiu
      integer kk
      real    ff
 
      if (first_wprof) then
         do i = 0001, 1001
            iiu = 0
            do ii = 1, 22
               if (i.ge.dgen(ii)) iiu = ii
               enddo
            if (iiu.eq.00) stop 'screech iiu.eq.00'
            if (iiu.ge.23) stop 'screech iiu.ge.23'
            ff = (i-dgen(iiu))*1.0/(dgen(iiu+1)-dgen(iiu))
            do kk = 01, 10
               wprof_arr(i,kk) =
     .                int(wgen(kk,iiu)
     .                   +ff*(wgen(kk,iiu+1)-wgen(kk,iiu)) + 0.5)
               enddo
            enddo
         first_wprof = .false.
         endif
 
      wprof_ik = 0.
      if (ir.lt.0001.or.ir.gt.1001) return
      wprof_ik = wprof_arr(ir,k)
 
      return
      end
 
 
 
c-------------------------------------------------
c this regulates the radial parametrization
c
      block data bd_dgen
      integer dgen(23)
      common /dgen_/dgen
      data dgen/
     . 0000, 0005, 0010, 0015, 0020, 0030, 0040, 0050, 0060, 0075,
     . 0100, 0125, 0150, 0200, 0250, 0300, 0400, 0500, 0600, 0700,
     . 0800, 0900, 1000/
      end
 
 
c-------------------------------------------------
c this regulates the radial profile
c
      block data bd_rgen
      real rgen(10,23) ! profile for radial part
      common /rgen_/rgen
      data rgen/
c       PC1  WF2   WF3   WF4   WFCb  WFCt  HRC   WFC3 WFC3IR
c       1     2     3     4     5     6     7     8     9   10
     . 0e-00,0e-00,0e-00,0e-00,8e-04,0e-00,6e-03,1e-03,7e-04,0e-00, ! 000 --- 01
     . 0e-00,0e-00,0e-00,0e-00,4e-04,0e-00,3e-03,1e-03,5e-04,0e-00, ! 005 --- 02
     . 0e-00,0e-00,0e-00,0e-00,2e-04,0e-00,2e-03,5e-04,7e-05,0e-00, ! 010 --- 03
     . 0e-00,0e-00,0e-00,0e-00,4e-05,0e-00,6e-04,2e-04,3e-05,0e-00, ! 015 --- 04
     . 0e-00,0e-00,0e-00,0e-00,1e-05,0e-00,3e-04,1e-05,1e-05,0e-00, ! 020 --- 05
     . 0e-00,0e-00,0e-00,0e-00,5e-06,0e-00,4e-05,6e-06,4e-06,0e-00, ! 030 --- 06
     . 0e-00,0e-00,0e-00,0e-00,2e-06,0e-00,8e-06,5e-06,2e-06,0e-00, ! 040 --- 07
     . 0e-00,0e-00,0e-00,0e-00,1e-06,0e-00,1e-06,4e-06,1e-06,0e-00, ! 050 --- 08
     . 0e-00,0e-00,0e-00,0e-00,8e-07,0e-00,0e-00,2e-06,6e-07,0e-00, ! 060 --- 09
     . 0e-00,0e-00,0e-00,0e-00,3e-07,0e-00,0e-00,8e-07,2e-08,0e-00, ! 075 --- 10
     . 0e-00,0e-00,0e-00,0e-00,1e-07,0e-00,0e-00,2e-07,1e-08,0e-00, ! 100 --- 11
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,1e-07,0e-00,0e-00, ! 125 --- 12
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,6e-08,0e-00,0e-00, ! 150 --- 13
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,3e-08,0e-00,0e-00, ! 200 --- 14
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,1e-08,0e-00,0e-00, ! 250 --- 15
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00, ! 300 --- 16
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00, ! 400 --- 17
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00, ! 500 --- 18
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00, ! 600 --- 19
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00, ! 700 --- 20
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00, ! 800 --- 21
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00, ! 900 --- 22
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00/ !1000 --- 23
      end
 
 
c-------------------------------------------------
c this regulates the spike profile
c
      block data bd_sgen
      real sgen(10,23) ! profile for spike
      common /sgen_/sgen
      data sgen/
c       1     2     3     4     5     6     7     8     9   10
     . 0e-00,0e-00,0e-00,0e-00,0e-05,0e-00,0e-03,0e-04,0e-04,0e-00, ! 000 --- 01
     . 0e-00,0e-00,0e-00,0e-00,4e-05,0e-00,2e-04,4e-05,2e-04,0e-00, ! 005 --- 02
     . 0e-00,0e-00,0e-00,0e-00,8e-05,0e-00,3e-04,7e-05,3e-04,0e-00, ! 010 --- 03
     . 0e-00,0e-00,0e-00,0e-00,5e-05,0e-00,1e-04,7e-05,2e-04,0e-00, ! 015 --- 04
     . 0e-00,0e-00,0e-00,0e-00,3e-05,0e-00,5e-05,5e-05,1e-04,0e-00, ! 020 --- 05
     . 0e-00,0e-00,0e-00,0e-00,2e-05,0e-00,4e-05,4e-05,6e-05,0e-00, ! 030 --- 06
     . 0e-00,0e-00,0e-00,0e-00,1e-05,0e-00,3e-05,3e-05,3e-05,0e-00, ! 040 --- 07
     . 0e-00,0e-00,0e-00,0e-00,1e-05,0e-00,2e-05,2e-05,1e-05,0e-00, ! 050 --- 08
     . 0e-00,0e-00,0e-00,0e-00,8e-06,0e-00,1e-05,1e-05,8e-06,0e-00, ! 060 --- 09
     . 0e-00,0e-00,0e-00,0e-00,4e-06,0e-00,5e-06,8e-06,6e-06,0e-00, ! 075 --- 10
     . 0e-00,0e-00,0e-00,0e-00,2e-06,0e-00,0e-00,6e-06,5e-06,0e-00, ! 100 --- 11
     . 0e-00,0e-00,0e-00,0e-00,1e-06,0e-00,0e-00,4e-06,3e-06,0e-00, ! 125 --- 12
     . 0e-00,0e-00,0e-00,0e-00,3e-07,0e-00,0e-00,2e-06,2e-06,0e-00, ! 150 --- 13
     . 0e-00,0e-00,0e-00,0e-00,2e-07,0e-00,0e-00,1e-06,1e-06,0e-00, ! 200 --- 14
     . 0e-00,0e-00,0e-00,0e-00,1e-07,0e-00,0e-00,6e-07,6e-07,0e-00, ! 250 --- 15
     . 0e-00,0e-00,0e-00,0e-00,4e-08,0e-00,0e-00,3e-07,4e-07,0e-00, ! 300 --- 16
     . 0e-00,0e-00,0e-00,0e-00,1e-08,0e-00,0e-00,1e-07,2e-07,0e-00, ! 400 --- 17
     . 0e-00,0e-00,0e-00,0e-00,4e-09,0e-00,0e-00,5e-08,1e-07,0e-00, ! 500 --- 18
     . 0e-00,0e-00,0e-00,0e-00,1e-09,0e-00,0e-00,3e-08,5e-08,0e-00, ! 600 --- 19
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,3e-08,4e-08,0e-00, ! 700 --- 20
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,3e-08,3e-08,0e-00, ! 800 --- 21
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,2e-08,2e-08,0e-00, ! 900 --- 22
     . 0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,0e-00,1e-08,1e-08,0e-00/ !1000 --- 23
 
 
 
 
      end
 
 
c-------------------------------------------------
c this regulates the spike width
c
      block data bd_wgen
      integer wgen(10,23) ! spike width
      common /wgen_/wgen
      data wgen/
c
c       1  2  3  4  5  6  7  8  9 10
c
     .  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, ! 000 --- 01
     .  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, ! 005 --- 02
     .  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, ! 010 --- 03
     .  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, ! 015 --- 04
     .  5, 5, 5, 5, 4, 5, 5, 4, 5, 5, ! 020 --- 05
     .  5, 5, 5, 5, 4, 5, 5, 4, 5, 5, ! 030 --- 06
     .  5, 5, 5, 5, 3, 5, 5, 3, 5, 5, ! 040 --- 07
     .  5, 5, 5, 5, 3, 5, 5, 3, 5, 5, ! 050 --- 08
     .  5, 5, 5, 5, 3, 5, 5, 3, 5, 5, ! 060 --- 09
     .  5, 5, 5, 5, 3, 5, 5, 3, 5, 5, ! 075 --- 10
     .  5, 5, 5, 5, 3, 5, 5, 3, 5, 5, ! 100 --- 11
     .  5, 5, 5, 5, 3, 5, 5, 3, 5, 5, ! 125 --- 12
     .  5, 5, 5, 5, 3, 5, 5, 3, 5, 5, ! 150 --- 13
     .  5, 5, 5, 5, 3, 5, 5, 3, 6, 5, ! 200 --- 14
     .  5, 5, 5, 5, 3, 5, 5, 3, 6, 5, ! 250 --- 15
     .  5, 5, 5, 5, 3, 5, 5, 3, 8, 5, ! 300 --- 16
     .  5, 5, 5, 5, 4, 5, 5, 2,10, 5, ! 400 --- 17
     .  5, 5, 5, 5, 4, 5, 5, 2,11, 5, ! 500 --- 18
     .  5, 5, 5, 5, 4, 5, 5, 2,12, 5, ! 600 --- 19
     .  5, 5, 5, 5, 5, 5, 5, 2,13, 5, ! 700 --- 20
     .  5, 5, 5, 5, 5, 5, 5, 2,14, 5, ! 800 --- 21
     .  5, 5, 5, 5, 5, 5, 5, 2,15, 5, ! 900 --- 22
     .  5, 5, 5, 5, 5, 5, 5, 2,15, 5/ !1000 --- 23
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/WFC.09x10/find_xyzXX_NAXIS.f"
c****                                         
c*********************************************
                                              
 
c----------------------------------------------
c
c uses a chisq minimization technique to find the optimal
c values for (x,y,z) using the inner 5x5 pixels; it
c takes the sky value (SKIN) as a given.  It does a very
c crude grid search to find the chisq minimim.
c
c HOWWT = 0  flat wgt
c HOWWT = 1  S/N wtg
c
c
      subroutine find_xyzXX_NAXIS(x,y,z,SKIN,qfit,chsq,
     .                            pix,psfloc,
     .                            NAXIS1,NAXIS2,HOWWT,PIXFIT)
      implicit none
 
      real*8 x,y,z
 
      real*8 SKIN
      real    qfit
      real    chsq
 
      integer     NAXIS1,NAXIS2
      real        pix(NAXIS1,NAXIS2)
      real        psfloc(101,101)
      integer     HOWWT
      character*3 PIXFIT
 
 
 
      real psfx(5,5)
      real pixx(5,5)
      real sig2(5,5)
      real psfx_(5,5)
 
      integer mmeth
      common / mmeth / mmeth
 
      integer NIT
      integer ii, jj, i, j
      integer NPIX
 
      real rpsf_phot
      real ftot
      real ptot
      real ftotw
      real ptotw
 
      real fxu, fx0, fxout
      real fyu, fy0, fyout
      real  zu,  zout
      real  dx, dy
 
      real  dd(11)
      data dd /0.300,0.200,0.100,0.050,0.030,
     .         0.020,0.010,0.005,0.003,0.002,
     .         0.001/
 
      real dxn(9)
      real dyn(9)
      data dxn/0.000,+1.000,-1.000,+0.000,+0.000,
     .               +0.707,+0.707,-0.707,-0.707/
      data dyn/0.000,+0.000,+0.000,+1.000,-1.000,
     .               +0.707,-0.707,-0.707,+0.707/
 
      integer nnn
 
      real err, chimin, chitot
      real abstot, absmin
      real pixtot
      real pixval
 
      integer i1, i2, iq, it
      integer j1, j2, jq, jt
      real    p
 
      integer NDONE
      data NDONE/0/
 
      mmeth = 5
 
      ii = int(x+0.5)
      jj = int(y+0.5)
 
      z = 0.
      zout = 0.
      qfit   = 0.99
      absmin = 0.99
 
      if (ii.lt. 0001 +2) return
      if (jj.lt. 0001 +2) return
      if (ii.gt.NAXIS1-2) return
      if (jj.gt.NAXIS2-2) return
 
      if (HOWWT.ne.0.and.HOWWT.ne.1) then
         print*,' '
         print*,'find_xymXX_chisq_NAXIS illegal param: '
         print*,'   HOWWT = ',HOWWT
         print*,' '
         stop
         endif
 
 
 
      pixtot = 0.
      do i = 1, 5
      do j = 1, 5
         pixval    = pix(ii+i-3,jj+j-3)
         pixx(i,j) = SNGL(pixval - SKIN)
         pixtot = pixtot + pixx(i,j)
         sig2(i,j) = max(pixval,0.00) + 25.00
         enddo
         enddo
 
 
c
c default is to use 5x5 box
c
      i1 = 1
      i2 = 5
      j1 = 1
      j2 = 5
 
      it = 2
      jt = 2
      pixval = 0.
      do iq = 2, 3
      do jq = 2, 3
         p = pixx(iq,jq  ) + pixx(iq+1,jq  )
     .     + pixx(iq,jq+1) + pixx(iq+1,jq+1)
         if (p.gt.pixval) then
             pixval = p
             it = iq
             jt = jq
             endif
         enddo
         enddo
 
      if (PIXFIT.eq.'4x4') then
          i1 = it-1
          i2 = it+2
          j1 = jt-1
          j2 = jt+2
          endif
 
      if (PIXFIT.eq.'3x3') then
          i1 = 2
          i2 = 4
          j1 = 2
          j2 = 4
          endif
 
      if (PIXFIT.eq.'2x2') then
          i1 = it
          i2 = it+1
          j1 = jt
          j2 = jt+1
          endif
 
      fxout = SNGL(x-ii)
      fyout = SNGL(y-jj)
 
      do NIT = 01, 11
         fx0 = fxout
         fy0 = fyout
         chimin = 9e30
         do nnn = 01, 09
            fxu = fx0 + dd(NIT)*dxn(nnn)
            fyu = fy0 + dd(NIT)*dyn(nnn)
            ftot  = 0.
            ptot  = 0.
            ftotw = 0.
            ptotw = 0.
            do i = i1, i2
            do j = j1, j2
               dx = (i-3) - fxu
               dy = (j-3) - fyu
               psfx(i,j) = rpsf_phot(dx,dy,psfloc)
               ftot  = ftot  + psfx(i,j)
               ptot  = ptot  + pixx(i,j)
               ftotw = ftotw + psfx(i,j)*psfx(i,j)/sig2(i,j)
               ptotw = ptotw + pixx(i,j)*psfx(i,j)/sig2(i,j)
               enddo
               enddo
            zu = ptot/ftot
            chitot = 0.
            abstot = 0.
            do i = i1, i2
            do j = j1, j2
               err  = abs(pixx(i,j)-zu*psfx(i,j))
               if (HOWWT.eq.0) chitot = chitot + err**2
               if (HOWWT.eq.1) chitot = chitot + err**2/sig2(i,j)
               abstot = abstot + err
               enddo
               enddo
            if (chitot.lt.chimin) then
               chimin = chitot
               fxout = fxu
               fyout = fyu
               zout  =  zu
               absmin = abstot/pixtot
               do i = 1, 5
               do j = 1, 5
                  psfx_(i,j) = psfx(i,j)
                  enddo
                  enddo
               endif
            enddo!nnn
         enddo!NIT
 
      x = ii + fxout
      y = jj + fyout
      z = zout
 
      npix = (i2-i1+1)*(j2-j1+1)
 
      chsq = sqrt(chitot/(npix-3))
      qfit = absmin
      if (qfit.gt.9.99) qfit = 9.99
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/WFC.09x10/z_xyoptXX_NAXIS.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------
c
 
      real function z_xyoptXX_NAXIS(xin,yin,skin,pix,psfloc,
     .                              NAXIS1,NAXIS2,DOSNWT,PIXFIT)
      implicit none
 
      real*8      xin
      real*8      yin
      real*8      skin
      integer     NAXIS1
      integer     NAXIS2
      real        pix(NAXIS1,NAXIS2)
      real        psfloc(101,101)
      integer     DOSNWT
      character*3 PIXFIT
 
      real   rpsf_phot
 
      real    dx, dy
      integer ix, iy
      integer i,  j
 
      integer NL, NLs
      real dl(500)
      real pl(500)
      real fl(500)
      real sl(500)
      real wl(500)
 
      real*8 sumpf
      real*8 sumff
      real*8 sumpfw
      real*8 sumffw
      real*8 zuse
 
      integer NARG
      common /NARG_/NARG
      integer mmeth
      common /mmeth/ mmeth
 
      integer i0, j0
      integer ii, jj
      integer i1, i2, it
      integer j1, j2, jt
      real    pixval
      real     p,  pmax
 
      z_xyoptXX_NAXIS = 0.
 
      i0 = int(xin+0.5)
      j0 = int(yin+0.5)
 
 
c
c find the brightest central pixel
c
      pmax = 0
      ix = int(xin+0.5)
      iy = int(yin+0.5)
      do ii = i0-1, i0+1
      do jj = j0-1, j0+1
         p = pix(ii,jj)
         if (p.gt.pmax) then
             pmax = p
             ix = ii
             iy = jj
             endif
         enddo
         enddo
 
c
c find the brightest 2x2 pixels
c
      pmax = 0
      it = ix-1
      jt = iy-1
      do ii = ix-1, ix
      do jj = iy-1, iy
         p = pix(ii,jj) + pix(ii+1,jj) + pix(ii,jj+1) + pix(ii+1,jj+1)
         if (p.gt.pmax) then
             pmax = p
             it = ii
             jt = jj
             endif
         enddo
         enddo
 
 
 
c
c default is to use 5x5 box
c
      i1 = ix-2
      i2 = ix+2
      j1 = iy-2
      j2 = iy+2
 
      if (PIXFIT.eq.'4x4') then
          i1 = it-1
          i2 = it+2
          j1 = jt-1
          j2 = jt+2
          endif
 
      if (PIXFIT.eq.'3x3') then
          i1 = ix-1
          i2 = ix+1
          j1 = iy-1
          j2 = iy+1
          endif
 
      if (PIXFIT.eq.'2x2') then
          i1 = it
          i2 = it+1
          j1 = jt
          j2 = jt+1
          endif
 
 
      NLs = 0
      do i = i1, i2
      do j = j1, j2
         dx = SNGL(i-xin)
         dy = SNGL(j-yin)
         NLs = NLs + 1
         if (NLs.gt.500) then
            print*,'z_opt: NLs.gt.500'
            stop
            endif
         pl(NLs) = SNGL(pix(i,j)-skin)
         fl(NLs) = rpsf_phot(dx,dy,psfloc)
         dl(NLs) = sqrt(dx**2+dy**2)
         enddo
         enddo
 
      sumpf = 0.
      sumff = 0.
      do NL = 01, NLs
         sumpf = sumpf + fl(NL)*pl(NL)
         sumff = sumff + fl(NL)*fl(NL)
         enddo
      zuse = sumpf/sumff
      if (zuse.lt.0) zuse = 0.
 
      do NL = 1, NLs
         sl(NL) = SNGL(sqrt(zuse*fl(NL)+skin+15))
         wl(NL) = 1.00/sl(NL)**2
         if (DOSNWT.eq.0) wl(NL) = 1.0
         enddo
 
      sumpfw = 0.
      sumffw = 0.
      do NL = 01, NLs
         sumpfw = sumpfw + fl(NL)*pl(NL)*wl(NL)
         sumffw = sumffw + fl(NL)*fl(NL)*wl(NL)
         enddo
      zuse = sumpfw/sumffw
      if (zuse.lt.0) zuse = 0.
 
      z_xyoptXX_NAXIS = SNGL(zuse)
 
      return
      end
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/PUTCHAR/img2putchar_r4.f"
c****                                         
c*********************************************
                                              
 
      subroutine img2putstr_r4(string,NELEM,val,ic,jc,pix,NX,NY)
      implicit none
      integer   NELEM
      character STRING(NELEM)
      integer ic,jc
      real*4  val
      integer NX,NY
      real*4  pix(NX,NY)
      integer N
 
      do N = 1, NELEM
         call img2putchar_r4(string(N),val,ic+(N-1)*6,jc,pix,NX,NY)
         enddo
 
      return
      end
 
 
 
      subroutine img2putchar_r4(putchar,val,ic,jc,pix,NX,NY)
      implicit  none
      character putchar
      integer   ic,jc
      real*4    val
      integer   NX,NY
      real*4    pix(NX,NY)
 
      integer i,j,n,nchar
 
      character*27 INFO(38)
      data INFO/
     .     'aA.***.*...*******...**...*',
     .     'bB****.*..******.*..******.',
     .     'cC.*****....*....*.....****',
     .     'dD****.*...**...**...*****.',
     .     'eE******....***..*....*****',
     .     'fF******....***..*....*....',
     .     'gG******....*..***...******',
     .     'hH*...**...*******...**...*',
     .     'iI.***...*....*....*...***.',
     .     'jJ....*....*....**...*.***.',
     .     'kK*...**..*.***..*..*.*...*',
     .     'lL*....*....*....*....*****',
     .     'mM*...***.***.*.**...**...*',
     .     'nN*...***..**.*.**..***...*',
     .     'oO.***.*...**...**...*.***.',
     .     'pP******...*******....*....',
     .     'qQ******...**...**..*.***.*',
     .     'rR******...****..*..*.*...*',
     .     'sS******....*****....******',
     .     'tT*****..*....*....*....*..',
     .     'uU*...**...**...**...******',
     .     'vV*...**...**...*.*.*...*..',
     .     'wW*...**...**.*.***.***...*',
     .     'xX*...*.*.*...*...*.*.*...*',
     .     'yY*...*.*.*...*....*....*..',
     .     'zZ*****...*...*...*...*****',
     .     '00.***.*...**.*.**...*.***.',
     .     '11.**....*....*....*...***.',
     .     '22*****....*******....*****',
     .     '33*****....******....******',
     .     '44...*.*..*.*****...*....*.',
     .     '55******....*****....******',
     .     '66******....******...******',
     .     '77*****....*...*....*....*.',
     .     '88******...*******   ******',
     .     '99******...******.   ******',
     .     '  .........................',
     .     '........................*..'/
 
      do N = 1, 38
         if (putchar.eq.INFO(N)(1:1).or.
     .       putchar.eq.INFO(N)(2:2)) then
            do i = -2,2
            do j = -2,2
               nchar = 3 + i+2 + (2-j)*5
               if (INFO(N)(nchar:nchar).eq.'*')
     .            pix(ic+i,jc+j) = val
               enddo
               enddo
            endif
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/SORT/quiksort.f"
c****                                         
c*********************************************
                                              
 
 
C From HDK@psuvm.psu.edu Thu Dec  8 15:27:16 MST 1994
C
C The following was converted from Algol recursive to Fortran iterative
C by a colleague at Penn State (a long time ago - Fortran 66, please
C excuse the GoTo's). The following code also corrects a bug in the
C Quicksort algorithm published in the ACM (see Algorithm 402, CACM,
C Sept. 1970, pp 563-567; also you younger folks who weren't born at
C that time might find interesting the history of the Quicksort
C algorithm beginning with the original published in CACM, July 1961,
C pp 321-322, Algorithm 64). Note that the following algorithm sorts
C integer data; actual data is not moved but sort is affected by sorting
C a companion index array (see leading comments). The data type being
C sorted can be changed by changing one line; see comments after
C declarations and subsequent one regarding comparisons(Fortran
C 77 takes care of character comparisons of course, so that comment
C is merely historical from the days when we had to write character
C compare subprograms, usually in assembler language for a specific
C mainframe platform at that time). But the following algorithm is
C good, still one of the best available.
 
 
      SUBROUTINE QSORTI (ORD,N,A)
C
C==============SORTS THE ARRAY A(I),I=1,2,...,N BY PUTTING THE
C   ASCENDING ORDER VECTOR IN ORD.  THAT IS ASCENDING ORDERED A
C   IS A(ORD(I)),I=1,2,...,N; DESCENDING ORDER A IS A(ORD(N-I+1)),
C   I=1,2,...,N .  THIS SORT RUNS IN TIME PROPORTIONAL TO N LOG N .
C
C
C     ACM QUICKSORT - ALGORITHM #402 - IMPLEMENTED IN FORTRAN 66 BY
C                                 WILLIAM H. VERITY, WHV@PSUVM.PSU.EDU
C                                 CENTER FOR ACADEMIC COMPUTING
C                                 THE PENNSYLVANIA STATE UNIVERSITY
C                                 UNIVERSITY PARK, PA.  16802
C
      IMPLICIT INTEGER (A-Z)
C
      DIMENSION ORD(N),POPLST(2,20)
C
C     TO SORT DIFFERENT INPUT TYPES, CHANGE THE FOLLOWING
C     SPECIFICATION STATEMENTS; FOR EXAMPLE, FOR FORTRAN CHARACTER
C     USE THE FOLLOWING:  CHARACTER *(*) A(N)
C
      REAL A(N)
      REAL X,XX,Z,ZZ,Y
C
      NDEEP=0
      U1=N
      L1=1
      DO I=1,N
         ORD(I)=I
         enddo
    2 IF (U1.LE.L1) RETURN
C
    3 L=L1
      U=U1
C
C PART
C
    4 P=L
      Q=U
C     FOR CHARACTER SORTS, THE FOLLOWING 3 STATEMENTS WOULD BECOME
C     X = ORD(P)
C     Z = ORD(Q)
C     IF (A(X) .LE. A(Z)) GO TO 2
C
C     WHERE "CLE" IS A LOGICAL FUNCTION WHICH RETURNS "TRUE" IF THE
C     FIRST ARGUMENT IS LESS THAN OR EQUAL TO THE SECOND, BASED ON "LEN"
C     CHARACTERS.
C
      X=A(ORD(P))
      Z=A(ORD(Q))
      IF (X.LE.Z) GO TO 5
      Y=X
      X=Z
      Z=Y
      YP=ORD(P)
      ORD(P)=ORD(Q)
      ORD(Q)=YP
    5 IF (U-L.LE.1) GO TO 15
      XX=X
      IX=P
      ZZ=Z
      IZ=Q
C
C LEFT
C
    6 P=P+1
      IF (P.GE.Q) GO TO 7
      X=A(ORD(P))
      IF (X.GE.XX) GO TO 8
      GO TO 6
    7 P=Q-1
      GO TO 13
C
C RIGHT
C
    8 Q=Q-1
      IF (Q.LE.P) GO TO 9
      Z=A(ORD(Q))
      IF (Z.LE.ZZ) GO TO 10
      GO TO 8
    9 Q=P
      P=P-1
      Z=X
      X=A(ORD(P))
C
C DIST
C
   10 IF (X.LE.Z) GO TO 11
      Y=X
      X=Z
      Z=Y
      IP=ORD(P)
      ORD(P)=ORD(Q)
      ORD(Q)=IP
   11 IF (X.LE.XX) GO TO 12
      XX=X
      IX=P
   12 IF (Z.GE.ZZ) GO TO 6
      ZZ=Z
      IZ=Q
      GO TO 6
C
C OUT
C
   13 CONTINUE
      IF (.NOT.(P.NE.IX.AND.X.NE.XX)) GO TO 14
      IP=ORD(P)
      ORD(P)=ORD(IX)
      ORD(IX)=IP
   14 CONTINUE
      IF (.NOT.(Q.NE.IZ.AND.Z.NE.ZZ)) GO TO 15
      IQ=ORD(Q)
      ORD(Q)=ORD(IZ)
      ORD(IZ)=IQ
   15 CONTINUE
      IF (U-Q.LE.P-L) GO TO 16
      L1=L
      U1=P-1
      L=Q+1
      GO TO 17
   16 U1=U
      L1=Q+1
      U=P-1
   17 CONTINUE
      IF (U1.LE.L1) GO TO 18
C
C START RECURSIVE CALL
C
      NDEEP=NDEEP+1
      POPLST(1,NDEEP)=U
      POPLST(2,NDEEP)=L
      GO TO 3
   18 IF (U.GT.L) GO TO 4
C
C POP BACK UP IN THE RECURSION LIST
C
      IF (NDEEP.EQ.0) GO TO 2
      U=POPLST(1,NDEEP)
      L=POPLST(2,NDEEP)
      NDEEP=NDEEP-1
      GO TO 18
C
C END SORT
C END QSORT
C
      END
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/query_hdre.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------
c
c This routine checks to see if the header of an image
c contains a particular keyword. If it does, it returns
c its value-string in STREAMX.
c
 
      subroutine query_hdre(filename,FIELDX,streamx,NEXTu)
      implicit none
 
      character*(*) filename
      character*8   fieldx
      character*20  streamx
 
      character*8  field
      character*20 stream
 
      integer NEXTu
 
      character*200 FILENAMEu
 
      integer  i
      integer ios, k
 
      character*2880 buff
 
      integer NREAD
      logical EXTEND
 
      integer BITPIX
      integer NAXIS1, NAXIS2, NAXIS3
 
c-----------------------------------------------
 
      streamx = ' '
 
      do i = 1, 195
         if (FILENAME(i:i+4).eq.'.fits') goto 3
         enddo
      print*,'query_hdre...',FILENAME
      stop 'no ".fits" '
 
    3 continue
      FILENAMEu = FILENAME(1:i+4)
 
      close(10)
      open(10,file=FILENAMEu,status='old',iostat=ios,
     .  err=900,recl=2880,form='UNFORMATTED',
     .  access='DIRECT')
 
      streamx = 'NULL'
      i = 0
      NREAD  = 0
      BITPIX = 8
      EXTEND = .false.
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buff
      if (ios.eq.5002) then ! bad option (?); maybe end of file?
          return
          endif
      if (ios.lt.   0) goto 901
      NAXIS1 = 0
      NAXIS2 = 1
      NAXIS3 = 1
      do k = 0, 35, 1
         field  = buff(k*80+01:k*80+08)
         stream = buff(k*80+11:k*80+31)
         if (field.eq.fieldx) then
            streamx = stream(1:20)
            if (NEXTu.eq.-1) then
                close(10)
                return
                endif
            endif
         if (field.eq.'EXTEND  ') read(stream,*) EXTEND
         if (field.eq.'END     ') goto 101
         if (field.eq.'BITPIX  ') read(stream,*) BITPIX
         if (field.eq.'NAXIS1  ') read(stream,*) NAXIS1
         if (field.eq.'NAXIS2  ') read(stream,*) NAXIS2
         if (field.eq.'NAXIS3  ') read(stream,*) NAXIS3
         continue
         enddo
      goto 100
 101  continue
      if (NREAD.ne.NEXTu.or.NEXTu.eq.-1) then
          NREAD = NREAD + 1
          i = i + (abs(BITPIX)/8*NAXIS1*NAXIS2*NAXIS3+2879)/2880
          goto 100
          endif
      close(10)
      return
 
  900 continue
      print*,' '
      print*,'query_hdre ERROR EXIT. '
      print*,' '
      print*,'FILE OPEN ERROR: '
      print*,' '
      write(*,'(''       FIELDX: '',a8)') FIELDX
      print*,' '
      write(*,'(''PROBLEM FILE : '',a)') FILENAME
      write(*,'(''PROBLEM FILEu: '',a)') FILENAMEu
      print*,' '
      write(*,'(''          IOS: '',i5)') ios
      print*,' '
      print*,' '
      print*,' '
      stop
 
  901 continue
      print*,' '
      print*,'query_hdre ERROR EXIT. '
      print*,'i/o error...'
      print*,' '
      write(*,'(''       FIELDX: '',a8)') FIELDX
      print*,' '
      write(*,'(''PROBLEM FILE : '',a)') FILENAME
      write(*,'(''PROBLEM FILEu: '',a)') FILENAMEu
      print*,' '
      write(*,'(''         IOS: '',i5)') ios
      print*,' '
      stop
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/query_hdre_i4.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------
c
 
      integer function i4_query_hdre(filename,FIELDX,NEXTu)
      implicit none
 
      character*(*) FILENAME
      character*8   FIELDX
      integer       NEXTu
 
      integer i4
 
      call query_hdre_i4(FILENAME,FIELDX,i4,NEXTu)
 
      i4_query_hdre = i4
 
      return
      end
 
 
 
 
c---------------------------------------------------
c
 
 
 
      subroutine query_hdre_i4(filename,FIELDX,i4,NEXTu)
      implicit none
 
      character*(*) filename
 
c     character*8  field
      integer*4    i4
      integer      NEXTu
 
c     character*20 stream
 
      character*8  fieldx
      character*20 streamx
 
c     integer  i
c     integer ios, k
 
c     character*2880 buff
 
c     integer nread
c     logical EXTEND
 
c     integer ii
c     integer nn
 
c-----------------------------------------------
 
      streamx = ' '
 
      call query_hdre(filename,FIELDX,streamx,NEXTu)
 
      read(STREAMX,*,err=3) i4
 
      return
 
   3  continue
      i4 = -1
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/query_hdre_r4.f"
c****                                         
c*********************************************
                                              
 
 
      real*4 function r4_query_hdre(filename,FIELDX,NEXTu)
      implicit none
 
      character*(*) FILENAME
      character*8   FIELDX
      integer       NEXTu
 
      real          r4
 
      call query_hdre_r4(filename,FIELDX,r4,NEXTu)
 
      r4_query_hdre = r4
 
      return
      end
 
 
 
 
c---------------------------------------------------
c
c This routine checks to see if the header of an image
c contains a particular keyword. If it does, it returns
c its value-string in STREAMX.
c
 
      subroutine query_hdre_r4(filename,FIELDX,r4,NEXTu)
      implicit none
 
      character*(*) filename
      character*8   FIELDX
      real          r4
      integer       NEXTu
 
      character*20  streamx
c     real*4        safe_read_r4
 
      streamx = ' '
 
      call query_hdre(filename,FIELDX,streamx,NEXTu)
 
 
      read(STREAMX,*,err=3) r4
 
      return
 
   3  continue
      r4 = -1
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/query_hdre_r8.f"
c****                                         
c*********************************************
                                              
 
 
      real*8 function r8_query_hdre(FILENAME,FIELDX,NEXTu)
      implicit none
 
      character*80 FILENAME
      character*8  FIELDX
      integer      NEXTu
 
      real*8 r8
 
 
      call query_hdre_r8(filename,FIELDX,r8,NEXTu)
 
      r8_query_hdre = r8
 
      return
      end
 
 
c---------------------------------------------------
c
c This routine checks to see if the header of an image
c contains a particular keyword. If it does, it returns
c its value-string in STREAMX.
c
 
      subroutine query_hdre_r8(filename,FIELDX,r8,NEXTu)
      implicit none
 
      character*(*) filename
      character*8   FIELDX
      real*8        r8
      integer       NEXTu
 
      character*20  streamx
      real*8 safe_read_r8
 
      streamx = ' '
 
      call query_hdre(filename,FIELDX,streamx,NEXTu)
      r8 = safe_read_r8(STREAMX)
      return
 
      end
 
 
 
 
      real*8 function safe_read_r8(STREAMX)
      implicit none
      character*20 STREAMX
 
      integer i
      integer n
 
      safe_read_r8 = -1
 
      n = 0
      do i = 1, 20
         if (STREAMX(i:i).ne.' ') then
             if (.not.STREAMX(i:i).ge.'0'.and.
     .           .not.STREAMX(i:i).le.'9'.and.
     .           .not.STREAMX(i:i).eq.'.'.and.
     .           .not.STREAMX(i:i).eq.'e'.and.
     .           .not.STREAMX(i:i).eq.'-'.and.
     .           .not.STREAMX(i:i).eq.'+'.and.
     .           .not.STREAMX(i:i).eq.' ') goto 1
             n = n + 1
             endif
         enddo
 
      if (n.ge.1) then
          read(STREAMX,*,err=5) safe_read_r8
          return
          endif
 
    1 return
 
    5 continue
      print*,'              '
      print*,'ERROR IN:     '
      print*,'              '
      print*,'safe_read_r8: '
      print*,'     STREAMX: ',STREAMX
      print*,' '
      print*,' '
      safe_read_r8 = 0.
      return
      end
 
 
 
 
c#include "/user/jayander/FORTRAN/2MASS/sub_query_2mass.f"
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/sub_find_ifilt_acswfc.f"
c****                                         
c*********************************************
                                              
 
 
      subroutine sub_find_ifilt_acswfc(FILENAME,IFILT,FILTNAME)
      implicit none
 
      character*80 FILENAME
      integer IFILT
      character*05 FILTNAME
 
      character*20 STREAM
 
      IFILT = 0
      FILTNAME = 'NONE'
 
      call query_hdre(FILENAME, 'FILTER1  ',STREAM,-1)
      if (STREAM(2:2).eq.'C')
     .call query_hdre(FILENAME, 'FILTER2  ',STREAM,-1)
      if (STREAM(2:6).eq.'F435W') IFILT = 01
      if (STREAM(2:6).eq.'F475W') IFILT = 02
      if (STREAM(2:6).eq.'F555W') IFILT = 03
      if (STREAM(2:6).eq.'F606W') IFILT = 04
      if (STREAM(2:6).eq.'F814W') IFILT = 05
      if (STREAM(2:6).eq.'F850W') IFILT = 06
      if (STREAM(2:6).eq.'F625W') IFILT = 07
      if (STREAM(2:6).eq.'F658W') IFILT = 08
      if (STREAM(2:6).eq.'F775W') IFILT = 09
      if (STREAM(2:6).eq.'F660N') IFILT = 10
      if (STREAM(2:6).eq.'F502N') IFILT = 11
      if (STREAM(2:6).eq.'F550N') IFILT = 12
      if (STREAM(2:2).eq.'F') FILTNAME = STREAM(2:6)
 
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/sub_find_ifilt_wfc3uv.f"
c****                                         
c*********************************************
                                              
 
 
 
      subroutine sub_find_ifilt_wfc3uv(FILENAME,IFILT,FILTNAME)
      implicit none
 
      character*80 FILENAME
      integer IFILT
      character*05 FILTNAME
 
      character*20 STREAM
 
      IFILT = -1
      FILTNAME = 'NONE'
 
      call query_hdre(FILENAME, 'FILTER   ',STREAM,-1)
      if (STREAM(2:6).eq.'F225W') IFILT = 00
      if (STREAM(2:6).eq.'F275W') IFILT = 01
      if (STREAM(2:6).eq.'F336W') IFILT = 02
      if (STREAM(2:6).eq.'F390W') IFILT = 03
      if (STREAM(2:6).eq.'F300X') IFILT = 03
      if (STREAM(2:6).eq.'F438W') IFILT = 04
      if (STREAM(2:6).eq.'F555W') IFILT = 05
      if (STREAM(2:6).eq.'F606W') IFILT = 06
      if (STREAM(2:6).eq.'F775W') IFILT = 07
      if (STREAM(2:6).eq.'F814W') IFILT = 08
      if (STREAM(2:6).eq.'F850W') IFILT = 09
      if (STREAM(2:2).eq.'F') FILTNAME = STREAM(2:6)
 
      return
      end
 
 
c#include "/user/jayander/FORTRAN/2MASS/find_offset_2MASS.f"
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/find_ifilt_ACSWFC.f"
c****                                         
c*********************************************
                                              
 
 
 
      integer function find_ifilt_ACSWFC(FILENAME)
      implicit none
 
      character*(*) FILENAME
 
      character*20 STREAM_FILTNAM1
      character*20 STREAM_FILTNAM2
 
      character*5 FILTNAME(12)
      data FILTNAME/'F435W','F475W','F555W','F606W','F814W',
     .              'F850L','F625W','F658N','F775W','F660N',
     .              'F502N','F550M'/
 
      integer i
 
      find_ifilt_ACSWFC = 0
 
      call query_hdre(FILENAME,'FILTNAM1',STREAM_FILTNAM1,-1)
      call query_hdre(FILENAME,'FILTNAM2',STREAM_FILTNAM2,-1)
 
      find_ifilt_ACSWFC = 4
      do i = 01, 12
         if (FILTNAME(i)(1:5).eq.
     .       STREAM_FILTNAM1(2:6)) find_ifilt_ACSWFC = i
         if (FILTNAME(i)(1:5).eq.
     .       STREAM_FILTNAM2(2:6)) find_ifilt_ACSWFC = i
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/WCS/find_ifilt_WFC3UV.f"
c****                                         
c*********************************************
                                              
 
 
 
      integer function find_ifilt_WFC3UV(FILENAME)
      implicit none
 
      character*(*) FILENAME
 
      character*20 STREAM_FILTNAME
 
      character*5 FILTNAME(10)
      data FILTNAME/'F275W','F336W','F390W','F438W','F555W',
     .              'F606L','F775W','F814W','F850L','F225W'/
 
      integer i
 
      find_ifilt_WFC3UV = 0
 
      call query_hdre(FILENAME,'FILTNAME',STREAM_FILTNAME,-1)
 
      find_ifilt_WFC3UV = 6
      do i = 01, 10
         if (FILTNAME(i)(1:5).eq.
     .       STREAM_FILTNAME(2:6)) find_ifilt_WFC3UV = i
         enddo
      if (find_ifilt_WFC3UV.eq.10) find_ifilt_WFC3UV = 0
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/GDC/STDGDCs/extract_stdgc.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------
c
c
c
      subroutine extract_stdgc(xr,yr,xc,yc,mc,FILE_STDGC,SENSE)
      implicit none
 
      real*8 xr, yr
      real*8 xc, yc, mc
      character*200 FILE_STDGC
      integer SENSE
 
      save
 
      logical FIRST
      data    FIRST/.true./
 
      character*200 FILE_STDGCu
      character*200 FILE_STDGCc
 
      integer   NDIM_XGC, NDIM_YGC
      integer*4 XGC_0, NDIM_XCG
      integer*4 YGC_0, NDIM_YCG
 
      integer i, ios
      integer k
      character*08   FIELD
      character*20   STREAM
      character*2880 buffc
 
      real*8  fx,   fy
      real*8  xcu,  ycu
      integer ipix, jpix
 
      integer*4, dimension(:,:), allocatable :: xgc
      integer*4, dimension(:,:), allocatable :: ygc
      integer*2, dimension(:,:), allocatable :: mgc
      integer*4, dimension(:,:), allocatable :: xcg
      integer*4, dimension(:,:), allocatable :: ycg
 
      if (FILE_STDGC(1:4).eq.'NONE'.or.
     .    FILE_STDGC(1:4).eq.'NULL') then
         if (SENSE.eq.0) then
            mc = 0.
            return
            endif
         if (SENSE.eq.1) then ! forward...
            xc = xr
            yc = yr
            return
            endif
         if (SENSE.eq.-1) then ! forward...
            xr = xc
            yr = yc
            return
            endif
         endif
 
      if (FIRST) FILE_STDGCc = ' '
 
      FILE_STDGCu = FILE_STDGC
      do k = 196,2,-1
         if (FILE_STDGCu(k:k+4).eq.'.fits')
     .       FILE_STDGCu = FILE_STDGCu(1:k+4)
         enddo
 
      if (FILE_STDGCc.ne.FILE_STDGCu) then
          FILE_STDGCc = FILE_STDGCu
c         print*,'EXTRACT_STDGC --- OPEN(10): ',FILE_STDGCc
          open(10,file=FILE_STDGCc,
     .         status='old',
     .         err   =900,
     .         recl  =2880,
     .         form  ='UNFORMATTED',
     .         access='DIRECT')
          i = 1
          read(10,rec=i,iostat=ios) buffc
          do k = 0, 35
             FIELD  = buffc(k*80+01:k*80+08)
             STREAM = buffc(k*80+11:k*80+30)
             if (FIELD.eq.'NDIM_XGC') read(STREAM,*) NDIM_XGC
             if (FIELD.eq.'NDIM_YGC') read(STREAM,*) NDIM_YGC
             if (FIELD.eq.'NDIM_XCG') read(STREAM,*) NDIM_XCG
             if (FIELD.eq.'NDIM_YCG') read(STREAM,*) NDIM_YCG
             if (FIELD.eq.'XGC_0   ') read(STREAM,*) XGC_0
             if (FIELD.eq.'YGC_0   ') read(STREAM,*) YGC_0
             enddo
          if (.not.FIRST) deallocate(xgc,ygc,mgc,xcg,ycg)
          allocate(xgc(NDIM_XGC,NDIM_YGC))
          allocate(ygc(NDIM_XGC,NDIM_YGC))
          allocate(mgc(NDIM_XGC,NDIM_YGC))
          allocate(xcg(NDIM_XCG,NDIM_YCG))
          allocate(ycg(NDIM_XCG,NDIM_YCG))
          i = 2
          call getext_i4(xgc,NDIM_XGC,NDIM_YGC,i)
          call getext_i4(ygc,NDIM_XGC,NDIM_YGC,i)
          call getext_i2(mgc,NDIM_XGC,NDIM_YGC,i)
          call getext_i4(xcg,NDIM_XCG,NDIM_YCG,i)
          call getext_i4(ycg,NDIM_XCG,NDIM_YCG,i)
          close(10)
          FIRST = .false.
          endif
 
      if (SENSE.eq.1) then ! forward...
          ipix = int(xr)
          jpix = int(yr)
          xc = -9999
          yc = -9999
 
          if (ipix.lt.       1-1) return
          if (ipix.gt.NDIM_XGC+1) return
          if (jpix.lt.       1-1) return
          if (jpix.gt.NDIM_YGC+1) return
 
          if (ipix.lt.1) ipix = 1
          if (jpix.lt.1) jpix = 1
          if (ipix.gt.NDIM_XGC-1) ipix = NDIM_XGC-1
          if (jpix.gt.NDIM_YGC-1) jpix = NDIM_YGC-1
 
          fx = xr-ipix
          fy = yr-jpix
          xc = (1-fx)*(1-fy)*xgc(ipix  ,jpix  )/1d5
     .       + (1-fx)*( fy )*xgc(ipix  ,jpix+1)/1d5
     .       + ( fx )*(1-fy)*xgc(ipix+1,jpix  )/1d5
     .       + ( fx )*( fy )*xgc(ipix+1,jpix+1)/1d5
          yc = (1-fx)*(1-fy)*ygc(ipix  ,jpix  )/1d5
     .       + (1-fx)*( fy )*ygc(ipix  ,jpix+1)/1d5
     .       + ( fx )*(1-fy)*ygc(ipix+1,jpix  )/1d5
     .       + ( fx )*( fy )*ygc(ipix+1,jpix+1)/1d5
          return
          endif
 
      if (SENSE.eq.0) then ! find the zeropoint...
          ipix = int(xr)
          jpix = int(yr)
          mc = 0.000
          if (ipix.lt.         1) return
          if (ipix.gt.NDIM_XGC-1) return
          if (jpix.lt.         1) return
          if (jpix.gt.NDIM_YGC-1) return
          fx = xr-ipix
          fy = yr-jpix
          mc = (1-fx)*(1-fy)*mgc(ipix  ,jpix  )/1d4
     .       + (1-fx)*( fy )*mgc(ipix  ,jpix+1)/1d4
     .       + ( fx )*(1-fy)*mgc(ipix+1,jpix  )/1d4
     .       + ( fx )*( fy )*mgc(ipix+1,jpix+1)/1d4
          return
          endif
 
      if (SENSE.eq.-1) then ! reverse
          xcu =  1 + (xc-XGC_0)
          ycu =  1 + (yc-YGC_0)
          ipix = int(xcu)
          jpix = int(ycu)
          xr = -1
          yr = -1
          if (ipix.lt.         1) return
          if (ipix.gt.NDIM_XCG-1) return
          if (jpix.lt.         1) return
          if (jpix.gt.NDIM_YCG-1) return
          if (xcg(ipix  ,jpix  ).le.-2000000000) return
          if (xcg(ipix+1,jpix  ).le.-2000000000) return
          if (xcg(ipix  ,jpix+1).le.-2000000000) return
          if (xcg(ipix+1,jpix+1).le.-2000000000) return
           fx = xcu-ipix
           fy = ycu-jpix
           xr = (1-fx)*(1-fy)*xcg(ipix  ,jpix  )/1d5
     .        + (1-fx)*( fy )*xcg(ipix  ,jpix+1)/1d5
     .        + ( fx )*(1-fy)*xcg(ipix+1,jpix  )/1d5
     .        + ( fx )*( fy )*xcg(ipix+1,jpix+1)/1d5
           yr = (1-fx)*(1-fy)*ycg(ipix  ,jpix  )/1d5
     .        + (1-fx)*( fy )*ycg(ipix  ,jpix+1)/1d5
     .        + ( fx )*(1-fy)*ycg(ipix+1,jpix  )/1d5
     .        + ( fx )*( fy )*ycg(ipix+1,jpix+1)/1d5
           return
           endif
 
      print*,'ILLEGAL SENSE',SENSE
      stop
 
  900 continue
      print*,'file open error'
      print*,'  FILE_STDGCc: ',FILE_STDGCc
      print*,'  FILE_SGDGC : ',FILE_STDGC
      stop
      end
 
 
c--------------------------------------------------------------------
c
c
      subroutine getext_i4(pix,NDIMX,NDIMY,i)
      implicit none
 
      integer NDIMX, NDIMY
      integer*4 PIX(NDIMX,NDIMY)
      integer i
 
      integer o
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer ifirst, i1, i2, ios
      integer np1, np2, npt
      integer nbu, npu
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      byte      b(4)
      integer*4 ii
      equivalence(ii,b)
 
      integer ipix, jpix
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      nbper  = 4*NDIMX*NDIMY
      npt    =   NDIMX*NDIMY
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         read(10,rec=i,iostat=ios) buffc
         do o = 1, 720
            npu = np1+o-1
            nbu = (o-1)*4
            ii  = 0
            ipix = npu - (npu-1)/NDIMX*NDIMX
            jpix =   1 + (npu-1)/NDIMX
            if (ipix.ge.1.and.ipix.le.NDIMX.and.
     .          jpix.ge.1.and.jpix.le.NDIMY) then
                if (.not.(_LINUX_)) then
                   b(1) = buffb(nbu+1)
                   b(2) = buffb(nbu+2)
                   b(3) = buffb(nbu+3)
                   b(4) = buffb(nbu+4)
                   endif
                if ((_LINUX_)) then
                   b(4) = buffb(nbu+1)
                   b(3) = buffb(nbu+2)
                   b(2) = buffb(nbu+3)
                   b(1) = buffb(nbu+4)
                   endif
                pix(ipix,jpix) = ii
                endif
            enddo!o
         enddo!i
 
      i = i2 + 1
 
      return
      end
 
 
 
c--------------------------------------------------------------------
c
c
      subroutine getext_i2(pix,NDIMX,NDIMY,i)
      implicit none
 
      integer NDIMX, NDIMY
      integer*2 PIX(NDIMX,NDIMY)
      integer i
 
      integer o
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer ifirst, i1, i2, ios
      integer np1, np2, npt
      integer nbu, npu
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      byte      b(2)
      integer*2 ii
      equivalence(ii,b)
 
      integer ipix, jpix
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      nbper  = 2*NDIMX*NDIMY
      npt    =   NDIMX*NDIMY
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/2 + 1
         np2 = (nbyteE-nbyte1)/2 + 1
         read(10,rec=i,iostat=ios) buffc
         do o = 1, 1440
            npu = np1+o-1
            nbu = (o-1)*2
            ii  = 0
            ipix = npu - (npu-1)/NDIMX*NDIMX
            jpix =   1 + (npu-1)/NDIMX
            if (ipix.ge.1.and.ipix.le.NDIMX.and.
     .          jpix.ge.1.and.jpix.le.NDIMY) then
                if (.not.(_LINUX_)) then
                   b(1) = buffb(nbu+1)
                   b(2) = buffb(nbu+2)
                   endif
                if ((_LINUX_)) then
                   b(2) = buffb(nbu+1)
                   b(1) = buffb(nbu+2)
                   endif
                pix(ipix,jpix) = ii
                endif
            enddo!o
         enddo!i
 
      i = i2 + 1
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/GDC/STDGDCs/xryr2mc_stdgc.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------
c
c mc should be the pixel area correction
c
c
      subroutine xryr2mc_stdgc(xr,yr,mc,FILE_STDGC)
      implicit none
 
      real*8 xr, yr
      real*8 mc
      character*(*) FILE_STDGC
      real*8 xc, yc
 
      call extract_stdgc(xr,yr,xc,yc,mc,FILE_STDGC,0)  ! 0 = pix area correction
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/GDC/STDGDCs/xryr2xcyc_stdgc.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------
c
      subroutine xryr2xcyc_stdgc(xr,yr,xc,yc,FILE_STDGC)
      implicit none
 
      real*8 xr, yr
      real*8 xc, yc
      character*(*) FILE_STDGC
      real*8 mc
 
      call extract_stdgc(xr,yr,xc,yc,mc,FILE_STDGC,1)  ! 1 = forward
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/GDC/STDGDCs/xcyc2xryr_stdgc.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------
c
      subroutine xcyc2xryr_stdgc(xc,yc,xr,yr,FILE_STDGC)
      implicit none
 
      real*8 xc, yc
      real*8 xr, yr
      character*(*) FILE_STDGC
      real*8 mc
 
      call extract_stdgc(xr,yr,xc,yc,mc,FILE_STDGC,-1)  ! -1 = reverse
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/writfits_i2.f"
c****                                         
c*********************************************
                                              
 
      subroutine writfits_i2(FILE,pix,PXDIMX,PXDIMY)
      implicit none
 
      integer PXDIMX,PXDIMY
      character*(*) FILE
      integer*2 pix(PXDIMX,PXDIMY)
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
 
      character*70 HDR(25)
      common/HDR/HDR
 
      character*80 FILEU
 
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
      !write(*,'(''ENTER   writfits_i2: '',80a)') FILEU
 
      open(10,file=FILEU,
     .     status='unknown',
     .     err   =900,
     .     recl  =2880,
     .     form  ='UNFORMATTED',
     .     access='DIRECT')
 
 
      i = 1
      write(buffc( 0*80+1: 1*80),'(''SIMPLE  = T    '')')
      write(buffc( 1*80+1: 2*80),'(''BITPIX  =  16  '')')
      write(buffc( 2*80+1: 3*80),'(''NAXIS   = '',i12)') 2
      write(buffc( 3*80+1: 4*80),'(''NAXIS1  = '',i12)') PXDIMX
      write(buffc( 4*80+1: 5*80),'(''NAXIS2  = '',i12)') PXDIMY
      write(buffc( 5*80+1: 6*80),'(''DATATYPE= '',9a)')
     .                          ' ''INTEGER*4 '''
      write(buffc( 6*80+1: 7*80),'(''DATE    = '',11a)')
     .                          ' ''28/01/00'''
      write(buffc( 7*80+1: 8*80),'(''BSCALE  = '',i12)') 00001
      write(buffc( 8*80+1: 9*80),'(''BZERO   = '',i12)') 00000
      write(buffc(09*80+1:10*80),'(''CRPIX1  = '',a20)') HDR(01)
      write(buffc(10*80+1:11*80),'(''CRPIX2  = '',a20)') HDR(02)
      write(buffc(11*80+1:12*80),'(''CRVAL1  = '',a20)') HDR(03)
      write(buffc(12*80+1:13*80),'(''CRVAL2  = '',a20)') HDR(04)
      write(buffc(13*80+1:14*80),'(''CTYPE1  = '',a20)') HDR(05)
      write(buffc(14*80+1:15*80),'(''CTYPE2  = '',a20)') HDR(06)
      write(buffc(15*80+1:16*80),'(''CD1_1   = '',a20)') HDR(07)
      write(buffc(16*80+1:17*80),'(''CD1_2   = '',a20)') HDR(08)
      write(buffc(17*80+1:18*80),'(''CD2_1   = '',a20)') HDR(09)
      write(buffc(18*80+1:19*80),'(''CD2_2   = '',a20)') HDR(10)
      write(buffc(19*80+1:20*80),'(''ORIENTAT= '',a20)') HDR(11)
      write(buffc(20*80+1:21*80),'(''PA_APER = '',a20)') HDR(12)
      write(buffc(21*80+1:22*80),'(''PA_V3   = '',a20)') HDR(13)
      write(buffc(22*80+1:23*80),'(''DATE-OBS= '',a20)') HDR(14)
      write(buffc(23*80+1:24*80),'(''TIME-OBS= '',a20)') HDR(15)
      write(buffc(24*80+1:25*80),'(''EXPTIME = '',a20)') HDR(16)
      write(buffc(25*80+1:26*80),'(''ROOTNAME= '',a20)') HDR(17)
      write(buffc(26*80+1:27*80),'(''TARGNAME= '',a20)') HDR(18)
      write(buffc(27*80+1:28*80),'(''RA_TARG = '',a20)') HDR(19)
      write(buffc(28*80+1:29*80),'(''DEC_TARG= '',a20)') HDR(20)
      write(buffc(29*80+1:30*80),'(''PROPOSID= '',a20)') HDR(21)
      write(buffc(30*80+1:31*80),'(''FILTER1 = '',a20)') HDR(22)
      write(buffc(31*80+1:32*80),'(''FILTER2 = '',a20)') HDR(23)
      write(buffc(32*80+1:33*80),'(''VAFACTOR= '',a20)') HDR(24)
      write(buffc(33*80+1:34*80),'(''COMMENT   '')')
      write(buffc(34*80+1:35*80),'(''COMMENT   '')')
      write(buffc(35*80+1:36*80),'(''END       '')')
 
      write(10,rec=i,iostat=ios) buffc
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      nbper  = 2*PXDIMX*PXDIMY
      npt    =   PXDIMX*PXDIMY
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         np1 = (nbyte0-nbyte1)/2 + 1
         np2 = (nbyteE-nbyte1)/2 + 1
        !if (i.lt.0010) print*,'i: ',i,i1,i2,np1,np2,nbyte0
        !if (i.gt.2900) print*,'i: ',i,i1,i2,np1,np2,nbyte0
         call pix2buff_i2(buffb,pix,np1,npt)
         write(10,rec=i,iostat=ios) buffc
         enddo
 
      close(10)
 
      return
 
 900  continue
      print*,'WRITFITS.f ERROR'
      stop
 
      end
 
 
      subroutine pix2buff_i2(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      integer*2 pix(*)
      integer n1,nt
 
      byte b(2)
      integer*2 ii
      equivalence(ii,b)
 
      integer i, npu, nbu
      logical islinux
 
      do i = 1, 1440
         npu = n1+i-1
         nbu = (i-1)*2
         if (npu.ge.1.and.npu.le.nt) ii = pix(npu)
         if (.not.(islinux())) then
            buff(nbu+1) = b(1)
            buff(nbu+2) = b(2)
           else
            buff(nbu+1) = b(2)
            buff(nbu+2) = b(1)
            endif
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/writfits_r4_WCSLTV.f"
c****                                         
c*********************************************
                                              
 
 
c-----------------------------------------------------
c
c this just writes a real*4 fits image
c
 
      subroutine writfits_r4_WCSLTV(FILE,pix,PXDIMX,PXDIMY,
     .                              CRPIX1,CRPIX2,CRVAL1,CRVAL2,
     .                              CD1_1, CD1_2, CD2_1, CD2_2,
     .                              LTV1, LTV2,
     .                              LTM1_1,LTM1_2,LTM2_1,LTM2_2)
      implicit none
 
      character*(*) FILE
      integer PXDIMX,PXDIMY
      real    pix(PXDIMX,PXDIMY)
      real*8  CRPIX1,CRPIX2,CRVAL1,CRVAL2
      real*8  CD1_1, CD1_2, CD2_1, CD2_2
      real*8  LTV1,  LTV2
      real*8  LTM1_1,LTM1_2,LTM2_1,LTM2_2
 
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffb,buffc)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer k
 
      character*80 FILEU
      character*70 HDR(25)
      common/HDR/HDR
 
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
      open(10,file=FILEU,status='unknown',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      do k = 00, 34
         write(buffc(k*80+1:k*80+80),'(80x)')
         enddo
 
      write(10,rec=i,iostat=ios) buffc
 
      write(buffc(00*80+1:01*80),'(''SIMPLE  =                    T'')')
      write(buffc(01*80+1:02*80),'(''BITPIX  =                  -32'')')
      write(buffc(02*80+1:03*80),'(''NAXIS   = '',8x,i12)') 2
      write(buffc(03*80+1:04*80),'(''NAXIS1  = '',8x,i12)') PXDIMX
      write(buffc(04*80+1:05*80),'(''NAXIS2  = '',8x,i12)') PXDIMY
      write(buffc(05*80+1:06*80),'(''DATATYPE= '',9a)')  " 'REAL*4' "
      write(buffc(06*80+1:07*80),'(''COMMENT   '',a05)') '     '
      write(buffc(07*80+1:08*80),'(''CTYPE1  = '',a10)') "'RA---TAN'"
      write(buffc(08*80+1:09*80),'(''CTYPE2  = '',a10)') "'DEC--TAN'"
      write(buffc(09*80+1:10*80),'(''CRPIX1  = '',f20.10)') CRPIX1
      write(buffc(10*80+1:11*80),'(''CRPIX2  = '',f20.10)') CRPIX2
      write(buffc(11*80+1:12*80),'(''CRVAL1  = '',f20.10)') CRVAL1
      write(buffc(12*80+1:13*80),'(''CRVAL2  = '',f20.10)') CRVAL2
      write(buffc(13*80+1:14*80),'(''CD1_1   = '',f20.10)') CD1_1
      write(buffc(14*80+1:15*80),'(''CD1_2   = '',f20.10)') CD1_2
      write(buffc(15*80+1:16*80),'(''CD2_1   = '',f20.10)') CD2_1
      write(buffc(16*80+1:17*80),'(''CD2_2   = '',f20.10)') CD2_2
      write(buffc(17*80+1:18*80),'(''COMMENT   '',a05)') '     '
      write(buffc(18*80+1:19*80),'(''LTV1    = '',f20.10)') LTV1
      write(buffc(19*80+1:20*80),'(''LTV2    = '',f20.10)') LTV2
      write(buffc(20*80+1:21*80),'(''LTM1_1  = '',f20.10)') LTM1_1
      write(buffc(21*80+1:22*80),'(''LTM1_2  = '',f20.10)') LTM1_2
      write(buffc(22*80+1:23*80),'(''LTM2_1  = '',f20.10)') LTM2_1
      write(buffc(23*80+1:24*80),'(''LTM2_2  = '',f20.10)') LTM2_2
      write(buffc(24*80+1:25*80),'(''COMMENT   '',a05)') '     '
      write(buffc(25*80+1:26*80),'(''END       '')')
 
      write(10,rec=i,iostat=ios) buffc
 
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      nbper  = 4*PXDIMX*PXDIMY
      npt    =   PXDIMX*PXDIMY
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         call pix2buff_r4_WCS(buffb,pix,np1,npt)
         write(10,rec=i,iostat=ios) buffc
         enddo
 
      close(10)
 
      return
 
 900  continue
      print*,'writfits_r4.f ERROR'
      print*,'   FILEU: ',FILEU
      stop
 
      end
 
c-------------------------------------------------------
c
c
      subroutine pix2buff_r4_WCS(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      real*4 pix(*)
      integer n1,nt
 
      byte b(4)
      real*4 r
      equivalence(r,b)
 
      integer i, npu, nbu
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (npu.ge.1.and.npu.le.nt) r = pix(npu)
         if (.not.(_LINUX_)) then
            buff(nbu+1) = b(1)
            buff(nbu+2) = b(2)
            buff(nbu+3) = b(3)
            buff(nbu+4) = b(4)
            endif
         if ((_LINUX_)) then
            buff(nbu+1) = b(4)
            buff(nbu+2) = b(3)
            buff(nbu+3) = b(2)
            buff(nbu+4) = b(1)
            endif
         enddo
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/sub_hst2xym_info.f"
c****                                         
c*********************************************
                                              
c
c This is the workhorse routine that finds stars and measures them
c in generic HST images.
c
c
      subroutine sub_hst2xym(HH,HHo,HHs,
     .                       HMIN,FMIN,PMAX,
     .                       HIFLAG,WCSMODE,DOSATD,
     .                       SHOW_USE,SHOW_FND,SHOW_ART,
     .                       SHOW_REF,SHOW_SUB,SHOW_MSK,
     .                       NPERTs,
     .                       KSEL,
     .                       QMAX,CMIN,CMAX,
     .                       IMIN,IMAX,JMIN,JMAX,
     .                       FILENAME,NIMu,NIMs,
     .                          PSFFILE_INP,
     .                          GDCFILE_INP,
     .                       Ns,  u_n, v_n,mm_n,
     .                            x_n, y_n, m_n, k_n,
     .                           xx_n,yy_n,
     .                           uu_n,vv_n,
     .                            h_n, w_n, ww_n,
     .                            r_n, d_n,
     .                            i_n, j_n,
     .                            p_n, pp_n,                 ! J: added pp_n for flux used for finding
     .                            f_n, ff_n,                 ! J: added  f_n and ff_n for central PSF val 2023.06.29
     .                            q_n, c_n, s_n, ss_n, t_n,
     .                            z_n, cc_n, o_n, oo_n,
     .                            sap_n, map_n,
     .                            n_n, e_n, ee_n,
     .                       BDRY_XR, BDRY_YR,
     .                       BDRY_XC, BDRY_YC,
     .                       BDRY_UG, BDRY_VG,
     .                       BDRY_RA, BDRY_DE,
     .                       BDRY_UU, BDRY_VV,
     .                       FILTu,EXPTu,RDATu,PROPu,INSTu,
     .                       CRPIX1_DEST,CRPIX2_DEST,
     .                       CRVAL1_DEST,CRVAL2_DEST,
     .                       CD1_1_DEST, CD1_2_DEST,
     .                       CD2_1_DEST, CD2_2_DEST,
     .                       VERBOSE,
     .                       As,xinp_a,yinp_a,minp_a,ASTYPE,
     .                       Bs,xinp_b,yinp_b,       BSTYPE,
     .                       FOCUS_LEVELi, PIXFIT,
     .                       SKI, SKO)
      implicit none
 
      character*249 HH(999)
      integer       HHo
      integer       HHs
      integer       HMIN
      real          FMIN
      real          PMAX
      character*200 PSFFILE_INP
      character*200 GDCFILE_INP
      integer       HIFLAG
      character*200 WCSMODE
      logical       DOSATD
      character     SHOW_USE
      character     SHOW_FND
      character     SHOW_REF
      character     SHOW_SUB
      character     SHOW_MSK
      character     SHOW_ART
      integer       NPERTs
      integer       KSEL
      real          QMAX
      real          CMIN, CMAX
      logical       QCAND
      integer       IMIN, IMAX
      integer       JMIN, JMAX
      character*200 FILENAME
      integer       NIMu
      integer       NIMs
      real*8         u_n(_NSTMAX_),  v_n(_NSTMAX_), mm_n(_NSTMAX_)
      real*8         x_n(_NSTMAX_),  y_n(_NSTMAX_),  m_n(_NSTMAX_)
      real*8        xx_n(_NSTMAX_), yy_n(_NSTMAX_)
      real*8        uu_n(_NSTMAX_), vv_n(_NSTMAX_)
      integer        k_n(_NSTMAX_)
      integer        h_n(_NSTMAX_)
      real*8         w_n(_NSTMAX_), ww_n(_NSTMAX_)
      real*8         r_n(_NSTMAX_),  d_n(_NSTMAX_)
      integer        i_n(_NSTMAX_),  j_n(_NSTMAX_)
      real           p_n(_NSTMAX_), pp_n(_NSTMAX_)
      real           f_n(_NSTMAX_), ff_n(_NSTMAX_)
      real           q_n(_NSTMAX_),  c_n(_NSTMAX_)
      real           s_n(_NSTMAX_), ss_n(_NSTMAX_)
      real*8         t_n(_NSTMAX_)
      integer      sat_n(_NSTMAX_)
c     integer      nt_n(_NSTMAX_)
c     real         wt_n(_NSTMAX_)
      real          z_n(_NSTMAX_)
      real         cc_n(_NSTMAX_)
      real          o_n(_NSTMAX_)
      real         oo_n(_NSTMAX_)
      real        sap_n(_NSTMAX_)
      real        map_n(9,_NSTMAX_)
      integer       n_n(_NSTMAX_)
      real          e_n(_NSTMAX_), ee_n(_NSTMAX_)
 
      real*8       BDRY_XR(4,4), BDRY_YR(4,4)
      real*8       BDRY_XC(4,4), BDRY_YC(4,4)
      real*8       BDRY_UG(4,4), BDRY_VG(4,4)
      real*8       BDRY_RA(4,4), BDRY_DE(4,4)
      real*8       BDRY_UU(4,4), BDRY_VV(4,4)
      character*05 FILTu
      real         EXPTu
      real         RDATu
      integer      PROPu
      integer      INSTu
      real*8  CRPIX1_DEST, CRPIX2_DEST
      real*8  CRVAL1_DEST, CRVAL2_DEST
      real*8   CD1_1_DEST,  CD1_2_DEST
      real*8   CD2_1_DEST,  CD2_2_DEST
      integer VERBOSE
      integer     As
      real*8      xinp_a(_ARTMAX_)
      real*8      yinp_a(_ARTMAX_)
      real*8      minp_a(_ARTMAX_)
      character*3 ASTYPE
      integer     Bs
      real*8      xinp_b(_ARTMAX_)
      real*8      yinp_b(_ARTMAX_)
      character*3 BSTYPE
 
      real        FOCUS_LEVELi
      character*3 PIXFIT
      integer SKI,SKO
c
c----------------------------------------------------------------------
c
      real          FOCUS_LEVELu
c     character*200 STRING
c     character*200 PROGNAME
c     character*200 TEMPSTRING
      character*30  STR30
 
      character*200 GDCFILE_USE
      character*200 PSFFILE_USE
      character*200 PSFFILE_PFF
      character*200 PSFFILE_PRT
c     character*200 FILEFITS
      character*200 DIRECT
      character*200 PREFIX
      character*9   STEM, STEMu
      character*7   SUFFIX
c     character*200 FILEOUT
      character*200 FILENAMu
      character*200 FILENAMx
 
      character*9   STEMs_N(_NIMMAX_)
      common/STEMs_N/STEMs_N
 
      character*80 MATFILE
      character*80 ARTFILE
 
      integer*4 NAXIS1
      integer*4 NAXIS2
 
      logical   ISFLT
 
      character*200 SHOW_USEu
      character*200 SHOW_FNDu
 
      integer PREFIX_LEN
c     integer i0, j0
      integer ii, jj
      integer  i,  j
c     integer ic, jc
c     integer iu
      integer NSAT
      logical SATD
c     integer ir
 
      real qr, ch
      real cr
      real dx,dy
      integer hobs, fnd_hloc_NAXIS
c     integer pobs, fnd_ploc_NAXIS
 
      real crat
      common /crat/ crat
      integer mmeth
      common /mmeth/ mmeth
 
c     integer NARGX, NARGY, NARGu
c     integer NARG, NARGs
      integer N, Ns
      integer Nx
 
c     integer       ISIMG_NARG(999)
c     character*200 STRNG_NARG(999)
 
      integer BITPIX
      common /BITPIX_/BITPIX
 
      real    xr4,yr4, sr4, fr4, ysigfit
c     real    xg4,yg4
      integer kr, kru
 
      real*8  xr, yr, fr, sr, mr, dmc
      real*8  xxr,yyr,mmr
      real*8   ur, vr, wr
      real*8  uur,vvr,wwr
      real*8  ssr
c     real*8  dr
      real*8  xro,yro,fro,sro
c     real*8  dclip
      real    z_xyoptXX_NAXIS
c     real    apl(10)
      real    fadd, fsig, fnoi, noise_sig
      real*8  faddt, faddn
 
      integer ixr0, iyr0
c     real*8 xgcu, ygcu
      real*8  xgc,  ygc
c     real*8 xxgc, yygc
      real*8 xgc0, ygc0
      real*8 mgc, m1k, mzp, mmgc
c     real   wfc_zpa
c     real   wfc3uv_zpa
 
      real*8 RA, DE
      real*8 ug, vg
      real*8 uu, vv
 
      real xtot, ytot, ptot, ftot
 
      real ss
      real rpsf_phot
      real HMB, histmode_NAXIS
      real mbar_sky_NAXIS
      real mbar_skyopt_NAXIS
      real minsky
      real skreff
 
      character*11 ra2sexig
      character*12 de2sexig
c
c the inner and outer radii used to find
c sky
c
      integer irmin, irmax
      common /SKYINFO_/irmin,irmax
 
      integer rsk1, rsk2
      real    rske
 
      integer*1 hu
      integer   hhist(16)
c     integer*1 bu
      character*20 hhwhy(16)
      data hhwhy/
     .     '..1..not on chip....',
     .     '..2..not loc max....',
     .     '..3..h < hmax.......',
     .     '..4..flux too low...',
     .     '..5..below mask thr.',
     .     '..6..out of bounds..',
     .     '..7..loflag issues..',
     .     '..8..saturated......',
     .     '..9..not contig sat.',
     .     '.10..not loc sat max',
     .     '.11..sat weirdness..',
     .     '.12..pk but not qsel',
     .     '.13..pk too peaky...',
     .     '.14..satd CR........',
     .     '.15..good unsat.....',
     .     '.16..good satd......'/
 
      real apphot_NAXIS
 
      real*4,    dimension(:,:),   allocatable :: pixo
      real*4,    dimension(:,:),   allocatable :: pixp
      real*4,    dimension(:,:),   allocatable :: pixx
      real*4,    dimension(:,:),   allocatable :: pixc
      real*4,    dimension(:,:),   allocatable :: pixw
      byte  ,    dimension(:,:),   allocatable :: pixq
      integer*4, dimension(:,:),   allocatable :: pixn
 
      real*4, dimension(:,:),   allocatable :: pixm
      real*4, dimension(:,:),   allocatable :: pixs
      real*4, dimension(:,:),   allocatable :: pixr
      byte  , dimension(:,:),   allocatable :: pixy
      real*4, dimension(:,:),   allocatable :: pixd ! difference:  just the added stars
      real*4, dimension(:,:),   allocatable :: pixa ! orig + arts
 
 
      integer iminu, imaxu
      integer jminu, jmaxu
 
      real pixc0
 
      real*8 fout, fxout, fyout
      real*8 fest, festr
 
      real zzz
      common /zzz/zzz
      real reff
      common /reff/reff
 
      logical DIAG
      common /DIAG_/DIAG
      data    DIAG/.false./
 
      logical DOAPPHOT
      real    RAP
 
      logical DOPRINT
      integer jnext
      real    mbrite
 
      character*200 IMSUBu
      character*200 IMREFu
      character*200 IMMSKu
 
c---------------------------------
c
c maybe unimportant?
c
      integer NITGLOM
      integer NSATGLOM
      integer NSATGLOMt
 
c-----------------------------------------
c
c contains info from the fits image header
c
      character*70 HDR(25)
      common/HDR/HDR
      character*70 INFO(10)
      common / fitsinfo / INFO
      integer GAIN
      data GAIN/ 0 /
c     real   rGAIN
 
 
c----------------------------------
c
c here are the 9x9 fiducial PSFs
c
 
      real psfarr1(10,10)
      real psfarr2(10,10)
      real psfloc(101,101)
 
 
      real psfpert(101,101,_NPRTMX_,_NPRTMX_,_NIMMXP_)
 
 
c     character*8  FIELD
      character*20 STREAM
 
      real*4  EXPT_EFF
 
c     integer NFILT ! the mapping for Mario's program
 
      integer ii0, jj0
      integer iit, jjt
      integer ninput
      data ninput/0/
 
      character*20 DATESTR
      character*20 TIMESTR
 
      character*20 STRING_TARGNAME
      character*20 STRING_RA_TARG
      character*20 STRING_DEC_TARG
      character*20 STRING_PLATESCL
 
      real   rDAT
      real*8 rDATuu
 
 
      integer NXPSFs, NYPSFs
      integer ilist(20)
      integer jlist(20)
 
      integer LNC ! LAST NON CHARACTER
      integer H
 
      integer PX, PY
      integer ipsf, jpsf
 
      integer NSATs
      integer isat(_NSTMAX_)
      integer jsat(_NSTMAX_)
      real    zsat(_NSTMAX_)
 
 
c-------------------------------------------------------------------
c
c for find_obj
c
      real*8 rRA , rDE      ! input
      character*11 OBJ_NAME ! output (nearest obj)
      real*8  RA0
c     real*8  DE0     ! output (locn)
c     real*8 dRA0
c     real*8 dDE0
      real*8  dRA,  dDE
      real*8  rd2x, rd2y
      real*8  xy2r, xy2d
 
 
      character*5 FILTNAME
      character*20 FILT0, FILT1, FILT2, FILT3, FILT4
      integer PID
 
c
c----------------------------------------------------------------
c
 
c     real dd
      real dm
 
c
c----------------------------------------------------------------
c
 
      integer K, P, Ks, Ku
      integer UMIN, UMAX
      integer VMIN, VMAX
      integer NAXISU, NAXISV
 
      integer IMINx, IMAXx
      integer JMINx, JMAXx
      integer UMINx, UMAXx
      integer VMINx, VMAXx
 
c     real*8      RA_MIN, RA_MAX
c     real*8      DE_MIN, DE_MAX
 
c     integer     O, Os
c     real*8      ra_o(_OMAX_)
c     real*8      de_o(_OMAX_)
c     real*8      mj_o(_OMAX_)
c     real*8      mh_o(_OMAX_)
c     real*8      mk_o(_OMAX_)
c     character*3 aa_o(_OMAX_)
c     integer     kk_o(_OMAX_)
c     real*8      ug_o(_OMAX_)
c     real*8      vg_o(_OMAX_)
c
c     integer     U, Us
c     integer     oo_u(_OMAX_)
c     real*8      ug_u(_OMAX_)
c     real*8      vg_u(_OMAX_)
c     real*8      mj_u(_OMAX_)
 
      logical     inside_poly
 
c     integer MSORT, MSORTs
c     real*8  u_msort(_NSTMAX_)
c     real*8  v_msort(_NSTMAX_)
c     real*8  m_msort(_NSTMAX_)
c     integer n_msort(_NSTMAX_)
 
      real*8  AG,BG,CG,DG
      real*8  GA,GB,GC,GD
      real*8  u1o,v1o,u2o,v2o
c     integer Lu, Ls, L
c     real    p_l(15)
      real    pbar
c     real    dmax
c     real    dbar
c
c     real*8  u1mat(_OMAX_), v1mat(_OMAX_), m1mat(_OMAX_)
c     real*8  u2mat(_OMAX_), v2mat(_OMAX_), m2mat(_OMAX_)
c     integer n1mat(_OMAX_)
c     integer n2mat(_OMAX_)
c     integer NMAT, NMATs
c     integer n_NMAT(_OMAX_)
c     integer o_NMAT(_OMAX_)
 
      integer A
 
      character*20 STRING20_INSTRUME
      character*20 STRING20_DETECTOR
 
      integer NAXIS_PSF
      integer i4_query_hdre
c     real*4  r4_query_hdre
 
      character*20 STRING20_APERTURE
      character*20 STRING20_FLSHCORR
      character*20 STRING20_FLASHDUR
      character*20 STRING20_FLASHCUR
      character*20 STRING20_FLASHLVL
      character*20 STRING20_FLASHSTA
      character*20 STRING20_SHUTRPOS
      character*20 STRING20_DARKTIME
 
      real r4_darktime
      real r4_darkest
      real r4_flashdur
      real r4_flashlvl
      character*01 c1_flashcur
      character*01 c1_shutrpos
 
      real find_postflash_wfc3uv
      real find_postflash_acswfc
 
 
c
c P000005 L35 FLASHDUR=                  3.3 / Exposure time in seconds: 0.1 to 409.5          00001 iegm01y4q_raw.fits
c P000006 L00 FLASHCUR= 'LOW    '            / Post flash current (zero  low  medium  high)    00001 iegm01y4q_raw.fits
c P000006 L01 FLASHLVL=                   8. / Post flash requested flash level                00001 iegm01y4q_raw.fits
c P000006 L02 FLASHSTA= 'SUCCESSFUL      '   / Status: SUCCESSFUL  ABORTED  NOT PERFORMED      00001 iegm01y4q_raw.fits
c
 
c------------------------------------------
c INSTRUMENT-BASED INFORMATION
c
 
      real*8  CRPIX1_INST,  CRPIX2_INST
      real*8  CRVAL1_INST,  CRVAL2_INST
      real*8   CD1_1_INST,   CD1_2_INST
      real*8   CD2_1_INST,   CD2_2_INST
 
      real*8  RCD1_1_INST,  RCD1_2_INST
      real*8  RCD2_1_INST,  RCD2_2_INST
      real*8  RCD1_1_DEST,  RCD1_2_DEST
      real*8  RCD2_1_DEST,  RCD2_2_DEST
 
      real*8  PC1_1,  PC1_2
      real*8  PC2_1,  PC2_2
      real*8  CDELT1, CDELT2
 
      character*200 WCSMODEu
      character*200 WCSFILE
      real    PLT_SCL
 
      integer LOFLAG_INST
      integer HIFLAG_INST
      character*05 FILT_INST
      real*4  EXPT_INST
      real*4  RDAT_INST
      integer PROP_INST
      real    GAIN_INST
 
      integer PMAX_PERT
      real    EXPTi
 
      logical ISDRZ
c     integer neq
      integer NFOCu
c     integer*4 qqqq
 
      integer NSATx
 
c     real cexp
c     real atot, aexp
c     real btot, bexp
c     real xru,  yru
 
      real FMINu
      real fff
      real sss
 
c     real g1, g2
      integer iii, jjj
c     real pabs
 
c
c------------------------------------------
c
 
      character*200 FILENAME_IMA
      character*200 FILENAME_FLT
      logical       str_contains
 
      logical       DOIMA
c     integer       SAMPNUMs, S
c     real          SAMPTIME_s(25)
c     integer       NOBS_s(25),  NFIT_s(25)
c     real          DXBAR_s(25), DXSIG_s(25)
c     real          DYBAR_s(25), DYSIG_s(25)
c     real          DMBAR_s(25), DMSIG_s(25)
 
c     integer NSATRD0
c     integer NSATRD1
c     integer NSATRD2
c     integer NSATRDF
c     integer NUNSAT1
 
      character*20 STR_SAMP_SEQ
      character*20 STR_NSAMP
      character*20 STR_SAMPZERO
      character*20 STR_SAMPNUM
      character*20 STR_SAMPTIME
      character*20 STR_ASN_ID
 
      integer b
      integer hist1(30), im1, cum1
      integer hist2(30), im2, cum2
      logical hshow
      integer HHi, HHt
 
c
c------------------------------------------
c
 
      integer HIFLAG_COMMON
      common / HIFLAG_ / HIFLAG_COMMON
 
      integer LOFLAG_COMMON
      common / LOFLAG_ / LOFLAG_COMMON
c
c------------------------------------------
c
      real*8 dm_cte
      real*8 dy_cte
c
c------------------------------------------
c
      real sap0,mapN(9)
 
 
      integer nsat_contig
      real    o, oo
 
      real*8  AG_mat,BG_mat
      real*8  CG_mat,DG_mat
      real*8  x1o_mat, y1o_mat
      real*8  x2o_mat, y2o_mat
      real*8  ZP_mat
      integer Ls_mat
      real*8  GA_mat,GB_mat
      real*8  GC_mat,GD_mat
c
c------------------------------------------
c
      real     mru
      real    fmru
      integer imru
 
      real e_m_ACS(20)
      data e_m_ACS / 0.750, 0.400, 0.250,  0.150,  0.100,
c                    -1     -2      -3      -4      -5
c                    -6     -7      -8      -9     -10
     .               0.060, 0.050, 0.035, 0.025,  0.020,
     .               0.018, 0.017, 0.016, 0.015,  0.050,
c                   -11    -12     -13     -14     -15
c                   -16    -17     -18     -19     -20
     .               0.070, 0.080, 0.090, 0.100,  0.500/
 
      real e_m_W3U(20)
      data e_m_W3U / 0.750, 0.400, 0.250,  0.150,  0.100,
c                    -1     -2      -3      -4      -5
c                    -6     -7      -8      -9     -10
     .               0.060, 0.050, 0.035, 0.025,  0.020,
     .               0.018, 0.017, 0.016, 0.015,  0.050,
c                   -11    -12     -13     -14     -15
c                   -16    -17     -18     -19     -20
     .               0.070, 0.080, 0.090, 0.100,  0.500/
 
      real e_m_W3I(20)
      data e_m_W3U / 0.750, 0.400, 0.250,  0.150,  0.100,
c                    -1     -2      -3      -4      -5
c                    -6     -7      -8      -9     -10
     .               0.060, 0.050, 0.035, 0.025,  0.020,
     .               0.018, 0.017, 0.016, 0.015,  0.050,
c                   -11    -12     -13     -14     -15
c                   -16    -17     -18     -19     -20
     .               0.070, 0.080, 0.090, 0.100,  0.500/
 
 
      integer B_
 
      real dm_uvis2(25)                                    ! bottom chip
      data dm_uvis2 / 0.000, 0.000, 0.000, 0.000, 0.000,
c                     -1     -2      -3      -4      -5
c                     -6     -7      -8      -9     -10
     .                0.000, 0.000, 0.000, 0.000, 0.000,
     .                0.000, 0.000, 0.000, 0.000, 0.000,
c                    -11    -12     -13     -14     -15
c                    -16    -17     -18     -19     -20
     .                0.000, 0.000,-0.005,-0.018,-0.050,
     .               -0.075,-0.100,-0.125,-0.150,-0.175/
c                    -21    -22     -23     -24      -25
 
      real dm_uvis1(25)                                    ! top chip
      data dm_uvis1 / 0.000, 0.000, 0.000, 0.000, 0.000,
c                     -1     -2      -3      -4      -5
c                     -6     -7      -8      -9     -10
     .                0.000, 0.000, 0.000, 0.000, 0.000,
     .                0.000, 0.000, 0.000, 0.000, 0.000,
c                    -11    -12     -13     -14     -15
c                    -16    -17     -18     -19     -20
     .                0.000,-0.030,-0.060,-0.120,-0.130,
     .               -0.175,-0.225,-0.275,-0.325,-0.375/
c                    -21    -22     -23     -24      -25
 
 
c
c------------------------------------------
c
      integer ir
      real    rr
      real*8  tp, pu
      integer tn, ts
 
c
c------------------------------------------
c
      ISFLT = .false.
 
      IMINx =  IMIN
      IMAXx =  IMAX
      JMINx =  JMIN
      JMAXx =  JMAX
 
      UMINx =  UMIN
      UMAXx =  UMAX
      VMINx =  VMIN
      VMAXx =  VMAX
 
      AG_mat = 0.
      BG_mat = 0.
      CG_mat = 0.
      DG_mat = 0.
      GA_mat = 0.
      GB_mat = 0.
      GC_mat = 0.
      GD_mat = 0.
 
      DOIMA = .false.
 
      GAIN_INST = 0.0
 
      if (PSFFILE_INP(1:4).eq.'AUTO') stop 'PSFFILE=AUTO depricated'
      if (GDCFILE_INP(1:4).eq.'AUTO') stop 'GDCFILE=AUTO depricated'
 
      PSFFILE_USE = PSFFILE_INP
      GDCFILE_USE = GDCFILE_INP
 
 
      AG = 1.00
      BG = 0.00
      CG = 0.00
      DG = 1.00
 
      GA = 1.00
      GB = 0.00
      GC = 0.00
      GD = 1.00
 
      u1o = 0.00
      v1o = 0.00
      u2o = 0.00
      v2o = 0.00
 
 
      FMINu    = FMIN
      DOAPPHOT = .false.
      ISDRZ    = .false.
 
      PSFFILE_PFF = PSFFILE_USE
      PMAX_PERT = 0
 
      K  = 1
 
 
c-------------------------------------------------------------------
c
c see if we have restricted the pixels to search
c     via FILE[005:50,007:75]...
c
      FILENAMu = FILENAME
      do i = 2, 200
         if (FILENAME(i:i).eq.'[') then
             FILENAMu = FILENAME(1:i-1)
             FILENAMx = FILENAME
              do ii = 2, 200
                 if (FILENAMx(ii:ii).eq.'[') FILENAMx(ii:ii) = ' '
                 if (FILENAMx(ii:ii).eq.']') FILENAMx(ii:ii) = ' '
                 if (FILENAMx(ii:ii).eq.',') iii = ii
                 enddo
              STR30 = FILENAMx(i+1:iii-1)
              print*,'STR30: ',STR30
              jjj = 0
              do ii = 1, 22
                 if (STR30(ii:ii).eq.':') then
                     jjj = ii
                     STR30(ii:ii) = ' '
                     endif
                 enddo
              if (jjj.eq.0) then
                  read(STR30,*) IMINx
                  read(STR30,*) IMAXx
                  endif
              if (jjj.ne.0) read(STR30,*) IMINx, IMAXx
              STR30 = FILENAMx(iii+1:200)
              print*,'STR30: ',STR30
              jjj = 0
              do ii = 1, 22
                 if (STR30(ii:ii).eq.':') then
                     jjj = ii
                     STR30(ii:ii) = ' '
                     endif
                 enddo
              if (jjj.eq.0) then
                  read(STR30,*) JMINx
                  read(STR30,*) JMAXx
                  endif
              if (jjj.ne.0) read(STR30,*) JMINx, JMAXx
             endif
         enddo
 
 
      write(*,'( 7x,''            '')')
      write(*,'( 7x,''ENTER sub_hst2xym -- '')')
      if (VERBOSE.ge.1) then
          write(*,'( 7x,''            '')')
          write(*,'(13x,''FILENAME: '',200a)')
     .                    FILENAME(1:LNC(FILENAME,200))
          write(*,'(13x,''FILENAMu: '',200a)')
     .                    FILENAMu(1:LNC(FILENAME,200))
          write(*,'(13x,''VERBOSE : '',i5 )') VERBOSE
          write(*,'(13x,''HMIN    : '',i5 )') HMIN
          write(*,'(13x,''FMIN    : '',i5 )') int(FMIN)
          write(*,'(13x,''IMIN/MAX: '',2i5)') IMINx, IMAXx
          write(*,'(13x,''JMIN/MAX: '',2i5)') JMINx, JMAXx
          write(*,'(13x,''DOSATD  : '',l5 )') DOSATD
          write(*,'(13x,''ARTSTARs: '',i5 )') As
          write(*,'(13x,''LSTSTARs: '',i5 )') Bs
          write(*,'(13x,''GDC_INP : '',200a)')
     .                    GDCFILE_INP(1:LNC(GDCFILE_INP,200))
          write(*,'(13x,''PSF_INP : '',200a)')
     .                    PSFFILE_INP(1:LNC(PSFFILE_INP,200))
          write(*,'(13x,''WCSMODE : '',200a)')
     .                    WCSMODE(1:LNC(WCSMODE,200))
          write(*,'(13x,''SHOW_USE: '',a1)') SHOW_USE
          write(*,'(13x,''SHOW_FND: '',a1)') SHOW_FND
          write(*,'(13x,''SHOW_REF: '',a1)') SHOW_REF
          write(*,'(13x,''SHOW_SUB: '',a1)') SHOW_SUB
          write(*,'(13x,''SHOW_ART: '',a1)') SHOW_ART
          write(*,'(13x,''SHOW_MSK: '',a1)') SHOW_MSK
          endif
 
 
      if (PSFFILE_USE(1:6).eq.'APPHOT') then
          read(PSFFILE_USE(7:80),*) RAP,SKI,SKO
          DOAPPHOT = .true.
          if (VERBOSE.ge.1) then
              write(*,'(13x,''RAPER    : '',f8.4)') RAP
              write(*,'(13x,''SK-INR   : '',i3)') SKI
              write(*,'(13x,''SK-OTR   : '',i3)') SKO
              endif
          endif
 
      if (VERBOSE.ge.1) write(*,'(13x,''DOAPPHOT: '',l5)') DOAPPHOT
 
 
      if (VERBOSE.ge.2) then
          write(*,'('' '')')
          write(*,'(12x,''       HHo: '',i4.4)') HHo
          write(*,'('' '')')
          do H = 1, HHo
             write(*,'(24x,''HH'',i4.4,1x,a80)') H, HH(H)(1:80)
             enddo
          write(*,'('' '')')
          write(*,'(12x,''      PMIN: '',i7 )') int(PMAX)
          write(*,'(12x,''    HIFLAG: '',i7 )') HIFLAG
          write(*,'(12x,''  SHOW_USE: '',a1)') SHOW_USE
          write(*,'(12x,''  SHOW_FND: '',a1)') SHOW_FND
          write(*,'(12x,''  SHOW_REF: '',a1)') SHOW_REF
          write(*,'(12x,''  SHOW_SUB: '',a1)') SHOW_SUB
          write(*,'(12x,''  SHOW_ART: '',a1)') SHOW_ART
          write(*,'(12x,''  SHOW_MSK: '',a1)') SHOW_MSK
          write(*,'(12x,''    NPERTs: '',i7)')  NPERTs
          write(*,'(12x,''FOCUS_LEVi: '',f9.1)')  FOCUS_LEVELi
          write(*,'(12x,''      KSEL: '',i7)')  KSEL
          write(*,'(12x,''      QMAX: '',f11.3)')  QMAX
          write(*,'(12x,''      CMIN: '',f11.3)')  CMIN
          write(*,'(12x,''      CMIN: '',2f11.3)')  CMIN,CMAX
          write(*,'(12x,''     QCAND: '',l9)')  QCAND
          write(*,'(12x,''  IMIN/MAX: '',2i7)')  IMIN, IMAX
          write(*,'(12x,''  JMIN/MAX: '',2i7)')  JMIN, JMAX
          write(*,'(12x,''    NIMu/s: '',2i7)')  NIMu, NIMs
          endif
 
 
      do H = HHo+1, 999  ! clear the rest of the header
         write(HH(H),'(''#'',248('' ''))')
         enddo
      HHs = HHo
 
      OBJ_NAME = ' '
      rRA = 0.
      RA0 = 0.
      dRA = 0.
      dRA = 0.
      rDE = 0.
      RDE = 0.
      dDE = 0.
      dDE = 0.
 
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'---> dirstrip filename...'
          endif
      call dirstrip(FILENAMu,DIRECT,PREFIX,SUFFIX)
      STEM  = PREFIX(1:9)
      STEMu = STEM
      STEMs_N(NIMu) = STEMu
 
      if (VERBOSE.ge.2) print*,'     --->  STEMu...  ',STEMu
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'---> query filter...'
          endif
 
      FILTNAME = 'NONE'
 
      call  query_hdre_i4(FILENAMu,'PROPOSID',PID,-1)
      call  query_hdre_r4(FILENAMu,'EXPTIME ',EXPTi,-1)
      call  query_hdre(FILENAMu,'FILTER  ',FILT0,-1)
      call  query_hdre(FILENAMu,'FILTER1 ',FILT1,-1)
      call  query_hdre(FILENAMu,'FILTER2 ',FILT2,-1)
      call  query_hdre(FILENAMu,'FILTNAM1',FILT3,-1)
      call  query_hdre(FILENAMu,'FILTNAM2',FILT4,-1)
 
      call query_hdre(FILENAMu,'APERTURE',STRING20_APERTURE,-1)
 
 
      FILTNAME = FILT0(1:5)
      if (FILT0(1:1).eq.'F')  FILTNAME = FILT0(1:5)
      if (FILT1(1:1).eq.'F')  FILTNAME = FILT1(1:5)
      if (FILT2(1:1).eq.'F')  FILTNAME = FILT2(1:5)
      if (FILT3(1:1).eq.'F')  FILTNAME = FILT3(1:5)
      if (FILT4(1:1).eq.'F')  FILTNAME = FILT4(1:5)
      if (FILT0(2:2).eq.'F')  FILTNAME = FILT0(2:6)
      if (FILT1(2:2).eq.'F')  FILTNAME = FILT1(2:6)
      if (FILT2(2:2).eq.'F')  FILTNAME = FILT2(2:6)
      if (FILT3(2:2).eq.'F')  FILTNAME = FILT3(2:6)
      if (FILT4(2:2).eq.'F')  FILTNAME = FILT4(2:6)
 
      if (VERBOSE.ge.2) print*,'     ---> FILTNAME...  ',FILTNAME
 
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'---> find_rdate...'
          endif
      call find_rdate(FILENAMu,rDAT,TIMESTR,DATESTR)
      rDATuu = rDAT
      if (rDAT.ge.050.and.rDAT.lt.200) rDATuu = rDAT + 1990.0d0
      if (rDAT.le.050)                 rDATuu = rDAT + 2000.0d0
 
      if (VERBOSE.ge.2) then
          print*,'     ---> DATESTR..  ',DATESTR
          print*,'     ---> TIMESTR..  ',TIMESTR
          print*,'     ---> rDATuu...',rDATuu
          endif
 
 
      EXPTu = EXPTi
      FILTu = FILTNAME(1:5)
      PROPu = PID
      RDATu = SNGL(rDATuu)
 
      if (VERBOSE.ge.1) then
          write(*,'( 7x,''           '')')
          write(*,'(13x,''STEMu   : '',a9)') STEMu(1:9)
          write(*,'(13x,''FILTu   : '',a5 )') FILTu
          write(*,'(13x,''PROPu   : '',i5 )') PROPu
          write(*,'(13x,''RDATu   : '',f11.5)') RDATuu
          endif
 
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'---> _NPRTMX_: ',_NPRTMX_
          endif
      do PX = 1, _NPRTMX_
      do PY = 1, _NPRTMX_
         do ipsf = 001, 101
         do jpsf = 001, 101
            if (NIMu.le._NIMMXP_)
     .          psfpert(ipsf,jpsf,PX,PY,NIMu) = 0.00
            enddo
            enddo
         enddo
         enddo
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'---> query_hdre: INSTRUM...'
          print*,' '
          endif
      call query_hdre(FILENAMu,'INSTRUME',STRING20_INSTRUME,-1)
      call query_hdre(FILENAMu,'DETECTOR',STRING20_DETECTOR,-1)
 
      if (VERBOSE.ge.1) then
          write(*,'( 7x,''            '')')
          write(*,'(12x,'' INSTRUME: '',a20)') STRING20_INSTRUME
          write(*,'(12x,'' DETECTOR: '',a20)') STRING20_DETECTOR
          endif
 
 
      INSTu  = -1
      NAXIS1 =  0
      NAXIS2 =  0
 
      if (index(FILENAMu,'_drz.fits').ne.0.or.
     .    index(FILENAMu,'_drc.fits').ne.0) then
          Ks = 1
          INSTu = 0
          NAXIS1 = i4_query_hdre(FILENAMu,'NAXIS1  ',-1)
          NAXIS2 = i4_query_hdre(FILENAMu,'NAXIS2  ',-1)
          allocate(pixn(NAXIS1,NAXIS2))
          allocate(pixo(NAXIS1,NAXIS2))
          allocate(pixc(NAXIS1,NAXIS2))
          allocate(pixp(NAXIS1,NAXIS2))
          allocate(pixx(NAXIS1,NAXIS2))
          allocate(pixq(NAXIS1,NAXIS2))
          allocate(pixw(NAXIS1,NAXIS2))
          if (VERBOSE.ge.2) then
              print*,' '
              print*,'CALL read_hstdrz_full...'
              print*,'     INSTu: ',INStu
              print*,'        Ks: ',Ks
              print*,'    NAXIS1: ',NAXIS1
              print*,'    NAXIS2: ',NAXIS2
              print*,' '
              endif
          if (WCSMODE.eq.'AUTO') WCSMODE = 'SELF'
          call read_hstdrz_full(FILENAMu,pixc, NAXIS1, NAXIS2,
     .                                   CRPIX1_INST, CRPIX2_INST,
     .                                   CRVAL1_INST, CRVAL2_INST,
     .                                   CD1_1_INST,  CD1_2_INST,
     .                                   CD2_1_INST,  CD2_2_INST,
     .                                   LOFLAG_INST, HIFLAG_INST,
     .                                   BDRY_XR,  BDRY_YR,
     .                                   FILT_INST,EXPT_INST,
     .                                   RDAT_INST,PROP_INST)
          if (VERBOSE.ge.2) then
              print*,' RET read_hstdrz_full...'
              endif
          EXPT_EFF = 1.0
          if (PSFFILE_USE(1:6).ne.'APPHOT') then ! NO PSFs possible for this type of image!
              RAP = 9.99
              SKI = 12
              SKO = 16
              DOAPPHOT = .true.
              endif
          xgc0 = CRPIX1_INST
          ygc0 = CRPIX2_INST
          do i = 0001, NAXIS1
          do j = 0001, NAXIS2
             pixo(i,j) = pixc(i,j)
             pixq(i,j) = 0
             if (pixc(i,j).gt.HIFLAG_INST) pixq(i,j) = 1
             enddo
             enddo
          BDRY_XR(1,1) = 0001
          BDRY_YR(1,1) = 0001
          BDRY_XR(2,1) = NAXIS1
          BDRY_YR(2,1) = 0001
          BDRY_XR(3,1) = NAXIS1
          BDRY_YR(3,1) = NAXIS2
          BDRY_XR(4,1) = 0001
          BDRY_YR(4,1) = NAXIS2
          if (VERBOSE.ge.2) then
              print*,' '
              print*,'DRZ/DRC image!!  BDRY INFO...'
              print*,'-----1--> ',BDRY_XR(1,K),BDRY_YR(1,K)
              print*,'-----2--> ',BDRY_XR(2,K),BDRY_YR(2,K)
              print*,'-----3--> ',BDRY_XR(3,K),BDRY_YR(3,K)
              print*,'-----4--> ',BDRY_XR(4,K),BDRY_YR(4,K)
              print*,' '
              endif
          goto 3  ! don't need to think about reading in anything else
          endif
 
 
      if (STRING20_INSTRUME(2:6).eq.'WFPC2') then
          if (VERBOSE.ge.2) then
              print*,' '
              print*,'CALL read_wfpc2_flt_full...'
              endif
          Ks = 4
          INSTu = 1
          NAXIS1 = 1600
          NAXIS2 = 1600
          allocate(pixn(NAXIS1,NAXIS2))
          allocate(pixo(NAXIS1,NAXIS2))
          allocate(pixc(NAXIS1,NAXIS2))
          allocate(pixp(NAXIS1,NAXIS2))
          allocate(pixx(NAXIS1,NAXIS2))
          allocate(pixq(NAXIS1,NAXIS2))
          call read_wfpc2_flt_full(FILENAMu,pixc,
     .                             CRPIX1_INST, CRPIX2_INST,
     .                             CRVAL1_INST, CRVAL2_INST,
     .                             CD1_1_INST,  CD1_2_INST,
     .                             CD2_1_INST,  CD2_2_INST,
     .                             LOFLAG_INST, HIFLAG_INST,
     .                             BDRY_XR,  BDRY_YR,
     .                             FILT_INST,EXPT_INST,
     .                             RDAT_INST,PROP_INST)
          xgc0 = CRPIX1_INST
          ygc0 = CRPIX2_INST
          do i = 0001, NAXIS1
          do j = 0001, NAXIS2
             pixo(i,j) = pixc(i,j)
             pixq(i,j) = 0
             if (pixc(i,j).gt.HIFLAG_INST) pixq(i,j) = 1
             enddo
             enddo
          call xryr2xcyc_stdgc(CRPIX1_INST,CRPIX2_INST,
     .                         xgc0,ygc0,GDCFILE_USE)
          CRPIX1_INST = xgc0
          CRPIX2_INST = ygc0
          goto 3  ! don't need to think about reading in anything else
          endif
 
 
      if (STRING20_INSTRUME(2:4).eq.'ACS'.and.
     .    STRING20_DETECTOR(2:4).eq.'HRC') then
          if (VERBOSE.ge.2) then
              print*,' '
              print*,'CALL read_acshrc_flt_full '
              print*,'     ---> PSFFILE_USE: ',PSFFILE_USE(1:40)
              print*,'     ---> GDCFILE_INP: ',GDCFILE_INP(1:40)
              endif
 
          Ks = 1
          INSTu = 7
          NAXIS1 = 1024
          NAXIS2 = 1024
          PMAX_PERT = 65000
          allocate(pixn(NAXIS1,NAXIS2))
          allocate(pixo(NAXIS1,NAXIS2))
          allocate(pixc(NAXIS1,NAXIS2))
          allocate(pixp(NAXIS1,NAXIS2))
          allocate(pixx(NAXIS1,NAXIS2))
          allocate(pixq(NAXIS1,NAXIS2))
          call read_acshrc_flt_full(FILENAMu,pixc,
     .                              CRPIX1_INST, CRPIX2_INST,
     .                              CRVAL1_INST, CRVAL2_INST,
     .                              CD1_1_INST,  CD1_2_INST,
     .                              CD2_1_INST,  CD2_2_INST,
     .                              LOFLAG_INST, HIFLAG_INST,
     .                              BDRY_XR,  BDRY_YR,
     .                              FILT_INST,EXPT_INST,
     .                              RDAT_INST,PROP_INST)
          if (VERBOSE.ge.2) then
              print*,' RET read_acshrc_flt_full '
              endif
          call xryr2xcyc_stdgc(CRPIX1_INST,CRPIX2_INST,
     .                         xgc0,ygc0,GDCFILE_USE)
          do i = 0001, NAXIS1
          do j = 0001, NAXIS2
             pixo(i,j) = pixc(i,j)
             pixq(i,j) = 0
             if (pixc(i,j).gt.HIFLAG_INST) pixq(i,j) = 1
             enddo
             enddo
          CRPIX1_INST = xgc0
          CRPIX2_INST = ygc0
          goto 3  ! don't need to think about reading in anything else
          endif
 
 
      if (STRING20_INSTRUME(2:4).eq.'ACS'.and.      ! ACSWFC
     .    STRING20_DETECTOR(2:4).eq.'WFC') then
          ISFLT = .false.
          do i = 1, 190
             if (FILENAMu(i:i+8).eq.'_flt.fits') ISFLT = .true.
             enddo
          if (VERBOSE.ge.2) then
              print*,' '
              print*,'CALL read_acswfc_flt_full '
              endif
          Ks = 2
          INSTu = 5
          NAXIS1 = 4096
          NAXIS2 = 4096
          PMAX_PERT = 55000
          allocate(pixn(NAXIS1,NAXIS2))
          allocate(pixo(NAXIS1,NAXIS2))
          allocate(pixc(NAXIS1,NAXIS2))
          allocate(pixp(NAXIS1,NAXIS2))
          allocate(pixx(NAXIS1,NAXIS2))
          allocate(pixq(NAXIS1,NAXIS2))
          call read_acswfc_flt_full(FILENAMu,pixc, pixq,
     .                              CRPIX1_INST, CRPIX2_INST,
     .                              CRVAL1_INST, CRVAL2_INST,
     .                              CD1_1_INST,  CD1_2_INST,
     .                              CD2_1_INST,  CD2_2_INST,
     .                              LOFLAG_INST, HIFLAG_INST,
     .                              BDRY_XR,  BDRY_YR,
     .                              FILT_INST,EXPT_INST,
     .                              RDAT_INST,PROP_INST,GAIN_INST)
          if (VERBOSE.ge.2) then
              print*,' RET read_acswfc_flt_full '
              endif
          if (VERBOSE.ge.2) then
              print*,'     ---> PSFFILE_USE: ',PSFFILE_USE(1:40)
              print*,'     ---> GDCFILE_INP: ',GDCFILE_INP(1:40)
              print*,'     --->      HIFLAG: ',HIFLAG
              endif
          call xryr2xcyc_stdgc(CRPIX1_INST,CRPIX2_INST,
     .                         xgc0,ygc0,GDCFILE_INP)
          if (VERBOSE.ge.2) print*,'    xgc0: ',xgc0
          if (VERBOSE.ge.2) print*,'    ygc0: ',ygc0
          if (VERBOSE.ge.2) print*,'  HIFLAG: ',HIFLAG
          if (VERBOSE.ge.2) print*,'  pixc(): ',pixc(100,100)
c         if (HIFLAG.gt.0) then                             ! set saturation flag image
c             if (VERBOSE.ge.2) print*,'  FLAG SATD WITH pixq() ',HIFLAG,pixc(100,100)
c             do i = 0001, NAXIS1
c             do j = 0001, NAXIS2
c                pixq(i,j) = 0
c                if (pixc(i,j).gt.HIFLAG) pixq(i,j) = 1
c                enddo
c                enddo
c             endif
          ii = 0
          do i = 0001, NAXIS1
          do j = 0001, NAXIS2
             pixo(i,j) = pixc(i,j)
             if (pixq(i,j).ne.0) ii = ii + 1
             enddo
             enddo
c         print*,'  NSATPIX: ',ii
c         print*,'   HIFLAG: ',HIFLAG,HIFLAG_INST
c         call writfits_r4('pixc.fits',pixc,NAXIS1,NAXIS2)
c         call writfits_b1('pixq.fits',pixq,NAXIS1,NAXIS2)
 
          STRING20_FLASHLVL = ' '
          call query_hdre(FILENAMu,'FLSHCORR',STRING20_FLSHCORR,-1)
          call query_hdre(FILENAMu,'FLASHDUR',STRING20_FLASHDUR,-1)
          call query_hdre(FILENAMu,'FLASHCUR',STRING20_FLASHCUR,-1)
c         call query_hdre(FILENAMu,'FLASHLVL',STRING20_FLASHLVL,-1)
          call query_hdre(FILENAMu,'FLASHSTA',STRING20_FLASHSTA,-1)
          call query_hdre(FILENAMu,'SHUTRPOS',STRING20_SHUTRPOS,-1)
          call query_hdre(FILENAMu,'DARKTIME',STRING20_DARKTIME,-1)
 
 
          read(STRING20_FLASHDUR,*) r4_flashdur
c         read(STRING20_FLASHLVL,*) r4_flashlvl
          read(STRING20_FLASHCUR,*) c1_flashcur
          read(STRING20_SHUTRPOS,*) c1_shutrpos
 
          read(STRING20_DARKTIME,*,err=7) r4_darktime
    7     continue
 
          r4_flashlvl = 13.2*r4_flashdur     ! 13.2 is the average at the gap
 
          r4_darkest =
     .       SNGL(r4_darktime/1000*max(2.0,11.0*(rDATuu-2002.40)/
     .                                          (2020.4-2002.40)) )
 
          write(HH(HHs+001),'(''#                                 '')')
          write(HH(HHs+002),'(''#================================='')')
          write(HH(HHs+003),'(''# ACS/WFC POSTFLASH INFO          '')')
          write(HH(HHs+004),'(''#                                 '')')
          write(HH(HHs+005),'(''# FLASHSTA: '',a20)') STRING20_FLASHSTA
          write(HH(HHs+005),'(''# FLSHCORR: '',a20)') STRING20_FLSHCORR
          write(HH(HHs+006),'(''# FLASHDUR: '',a20,11x,f8.2)')
     .                     STRING20_FLASHDUR, r4_flashdur
          write(HH(HHs+007),'(''# FLASHLVL: '',a20,11x,f8.2)')
     .                     STRING20_FLASHLVL, r4_flashlvl
          if (STRING20_FLSHCORR(2:5).eq.'OMIT') r4_flashdur = 0.
          write(HH(HHs+008),'(''# FLASHDUR: '',a20,11x,f8.2)')
     .                     STRING20_FLASHDUR, r4_flashdur
          write(HH(HHs+009),'(''# FLASHCUR: '',a20,16x,a1)')
     .                     STRING20_FLASHCUR, c1_flashcur
          write(HH(HHs+010),'(''# SHUTRPOS: '',a20,16x,a1)')
     .                     STRING20_SHUTRPOS, c1_shutrpos
          write(HH(HHs+011),'(''# DARKTIME: '',a20,11x,f8.2)')
     .                     STRING20_DARKTIME, r4_darktime
          write(HH(HHs+012),'(''# DARKEST : '',20x,11x,2f8.2)')
     .                                        r4_darkest,rDATuu
          write(HH(HHs+013),'(''#                                 '')')
          HHs = HHs + 13
 
          if (VERBOSE.ge.1) then
              write(*,*)
              write(*,'(13x,''FLASHSTA: '',a20)') STRING20_FLASHSTA
              write(*,'(13x,''FLSHCORR: '',a20)') STRING20_FLSHCORR
              write(*,'(13x,''SHUTRPOS: '',3x,a1)') c1_shutrpos
              write(*,'(13x,''FLASHCUR: '',3x,a1)') c1_flashcur
              write(*,'(13x,''FLASHDUR: '',f6.1)') r4_flashdur
              write(*,'(13x,''FLASHLVL: '',f6.1)') r4_flashlvl
              write(*,'(13x,''DARKTIME: '',f6.1)') r4_darktime
              write(*,'(13x,''DARKEST : '',f6.1)') r4_darkest
              endif
 
          goto 3
          endif
 
 
      if (STRING20_INSTRUME(2:5).eq.'WFC3'.and.
     .    STRING20_DETECTOR(2:5).eq.'UVIS') then
          ISFLT = .false.
          do i = 1, 190
             if (FILENAMu(i:i+8).eq.'_flt.fits') ISFLT = .true.
             enddo
          if (VERBOSE.ge.2) then
              print*,' '
              print*,'CALL read_wfc3uv_flt_full'
              endif
          Ks = 2
          INSTu = 8
          NAXIS1 = 4096
          NAXIS2 = 4096
          PMAX_PERT = 65000
          allocate(pixn(NAXIS1,NAXIS2))
          allocate(pixo(NAXIS1,NAXIS2))
          allocate(pixc(NAXIS1,NAXIS2))
          allocate(pixp(NAXIS1,NAXIS2))
          allocate(pixx(NAXIS1,NAXIS2))
          allocate(pixq(NAXIS1,NAXIS2))
          call read_wfc3uv_flt_full(FILENAMu,pixc,pixq,
     .                              CRPIX1_INST, CRPIX2_INST,
     .                              CRVAL1_INST, CRVAL2_INST,
     .                              CD1_1_INST,  CD1_2_INST,
     .                              CD2_1_INST,  CD2_2_INST,
     .                              LOFLAG_INST, HIFLAG_INST,
     .                              BDRY_XR,  BDRY_YR,
     .                              FILT_INST,EXPT_INST,
     .                              RDAT_INST,PROP_INST)
          if (VERBOSE.ge.2) then
              print*,' RET read_wfc3uv_flt_full'
              endif
          if (VERBOSE.ge.2) then
              print*,'     ---> PSFFILE_USE: ',PSFFILE_USE(1:40)
              print*,'     ---> GDCFILE_USE: ',GDCFILE_USE(1:40)
              print*,'     --->      HIFLAG: ',HIFLAG,HIFLAG_INST
              endif
          call xryr2xcyc_stdgc(CRPIX1_INST,CRPIX2_INST,
     .                         xgc0,ygc0,GDCFILE_USE)
          do i = 0001, NAXIS1
          do j = 0001, NAXIS2
             pixo(i,j) = pixc(i,j)
             enddo
             enddo
          if (HIFLAG.gt.0) then
              do i = 0001, NAXIS1
              do j = 0001, NAXIS2
                 pixq(i,j) = 0
                 if (pixc(i,j).gt.HIFLAG) pixq(i,j) = 1
                 enddo
                 enddo
              endif
          call query_hdre(FILENAMu,'FLSHCORR',STRING20_FLSHCORR,-1)
          call query_hdre(FILENAMu,'FLASHDUR',STRING20_FLASHDUR,-1)
          call query_hdre(FILENAMu,'FLASHCUR',STRING20_FLASHCUR,-1)
          call query_hdre(FILENAMu,'FLASHLVL',STRING20_FLASHLVL,-1)
          call query_hdre(FILENAMu,'FLASHSTA',STRING20_FLASHSTA,-1)
          call query_hdre(FILENAMu,'SHUTRPOS',STRING20_SHUTRPOS,-1)
          call query_hdre(FILENAMu,'DARKTIME',STRING20_DARKTIME,-1)
 
          read(STRING20_FLASHDUR,*) r4_flashdur
          read(STRING20_FLASHLVL,*) r4_flashlvl
          read(STRING20_FLASHCUR,*) c1_flashcur
          read(STRING20_SHUTRPOS,*) c1_shutrpos
 
          r4_darktime = 0.
          read(STRING20_DARKTIME,*,err=8) r4_darktime
    8     continue
 
          r4_darkest= SNGL(r4_darktime/900*(2.0 + 5.0*(rDATuu-2009.40)/
     .                                                (2016.5-2009.40)))
 
          write(HH(HHs+001),'(''#                                 '')')
          write(HH(HHs+002),'(''#================================='')')
          write(HH(HHs+003),'(''# WFC3/UVIS POSTFLASH INFO        '')')
          write(HH(HHs+004),'(''#                                 '')')
          write(HH(HHs+005),'(''# FLASHSTA: '',a20)') STRING20_FLASHSTA
          write(HH(HHs+005),'(''# FLSHCORR: '',a20)') STRING20_FLSHCORR
          write(HH(HHs+006),'(''# FLASHDUR: '',a20,11x,f8.2)')
     .                     STRING20_FLASHDUR, r4_flashdur
          write(HH(HHs+007),'(''# FLASHLVL: '',a20,11x,f8.2)')
     .                     STRING20_FLASHLVL, r4_flashlvl
          if (STRING20_FLSHCORR(2:5).eq.'OMIT') r4_flashlvl = 0.
          write(HH(HHs+008),'(''# FLASHLVL: '',a20,11x,f8.2)')
     .                     STRING20_FLASHLVL, r4_flashlvl
          write(HH(HHs+009),'(''# FLASHCUR: '',a20,16x,a1)')
     .                     STRING20_FLASHCUR, c1_flashcur
          write(HH(HHs+010),'(''# SHUTRPOS: '',a20,16x,a1)')
     .                     STRING20_SHUTRPOS, c1_shutrpos
          write(HH(HHs+011),'(''# DARKTIME: '',a20,11x,f8.2)')
     .                     STRING20_DARKTIME, r4_darktime
          write(HH(HHs+012),'(''# DARKEST : '',20x,11x,2f8.2)')
     .                                        r4_darkest,rDATuu
          HHs = HHs + 13
 
          if (VERBOSE.ge.1) then
              write(*,*)
              write(*,'(13x,''FLASHSTA: '',a20)') STRING20_FLASHSTA
              write(*,'(13x,''FLSHCORR: '',a20)') STRING20_FLSHCORR
              write(*,'(13x,''SHUTRPOS: '',3x,a1)') c1_shutrpos
              write(*,'(13x,''FLASHCUR: '',3x,a1)') c1_flashcur
              write(*,'(13x,''FLASHDUR: '',f6.1)') r4_flashdur
              write(*,'(13x,''FLASHLVL: '',f6.1)') r4_flashlvl
              write(*,'(13x,''DARKTIME: '',f6.1)') r4_darktime
              write(*,'(13x,''DARKEST : '',f6.1)') r4_darkest
              endif
          goto 3
          endif
 
      if (STRING20_INSTRUME(2:5).eq.'WFC3'.and.
     .    STRING20_DETECTOR(2:3).eq.'IR') then
          FILENAME_IMA = 'NONE'
          FILENAME_FLT = 'NONE'
 
          if (str_contains(FILENAMu,200,'_flt.fits',009)) then
              FILENAME_FLT = FILENAMu
              endif
 
          if (str_contains(FILENAMu,200,'_ima.fits',009)) then
              DOIMA = .true.
              FILENAME_IMA = FILENAMu
              do i = 190, 2, -1
                 if (FILENAME_IMA(i:i+8).eq.'_ima.fits') then
                     FILENAME_FLT = FILENAME_IMA(1:i-1) // '_flt.fits'
                     endif
                 enddo
              endif
 
          call query_hdre(FILENAMu,'SAMP_SEQ',STR_SAMP_SEQ,-1)
          call query_hdre(FILENAMu,'NSAMP   ',STR_NSAMP,   -1)
          call query_hdre(FILENAMu,'SAMPZERO',STR_SAMPZERO,-1)
          call query_hdre(FILENAMu,'SAMPNUM ',STR_SAMPNUM ,-1)
          call query_hdre(FILENAMu,'SAMPTIME',STR_SAMPTIME,-1)
          call query_hdre(FILENAMu,'ASN_ID  ',STR_ASN_ID  ,-1)
 
          write(HH(HHs+001),'(''#                                '')')
          write(HH(HHs+002),'(''#--------------------------------'')')
          write(HH(HHs+003),'(''# WFC3/IR IMAGE ... '')')
          write(HH(HHs+004),'(''#--------------------------------'')')
          write(HH(HHs+005),'(''# FILENAME: '',100a)')
     .                            FILENAME(1:100)
          write(HH(HHs+006),'(''# FILE_FLT: '',100a)')
     .                            FILENAME_FLT(1:100)
          write(HH(HHs+007),'(''# FILE_IMA: '',100a)')
     .                            FILENAME_IMA(1:100)
          write(HH(HHs+008),'(''# SAMP_SEQ: '',a20)') STR_SAMP_SEQ
          write(HH(HHs+009),'(''# NSAMP   : '',a20)') STR_NSAMP
          write(HH(HHs+010),'(''# SAMPZERO: '',a20)') STR_SAMPZERO
          write(HH(HHs+011),'(''# SAMPNUM : '',a20)') STR_SAMPNUM
          write(HH(HHs+012),'(''# SAMPTIME: '',a20)') STR_SAMPTIME
          write(HH(HHs+013),'(''# ASN_ID  : '',a20)') STR_ASN_ID
          HHs = HHs + 13
 
          if (VERBOSE.ge.2) then
              print*,' '
              print*,'CALL read_wfc3ir_flt_full'
              endif
          Ks = 1
          INSTu  = 9
          NAXIS1 = 1014
          NAXIS2 = 1014
          allocate(pixn(NAXIS1,NAXIS2))
          allocate(pixo(NAXIS1,NAXIS2))
          allocate(pixc(NAXIS1,NAXIS2))
          allocate(pixp(NAXIS1,NAXIS2))
          allocate(pixx(NAXIS1,NAXIS2))
          allocate(pixq(NAXIS1,NAXIS2))
          call read_wfc3ir_flt_full(FILENAME_FLT,pixc,pixo,
     .                              CRPIX1_INST, CRPIX2_INST,
     .                              CRVAL1_INST, CRVAL2_INST,
     .                              CD1_1_INST,  CD1_2_INST,
     .                              CD2_1_INST,  CD2_2_INST,
     .                              LOFLAG_INST, HIFLAG_INST,
     .                              BDRY_XR,  BDRY_YR,
     .                              FILT_INST,EXPT_INST,
     .                              RDAT_INST,PROP_INST)
 
          if (VERBOSE.ge.2) then
              print*,' '
              print*,' RET read_wfc3ir_flt_full'
              endif
          FMINu = FMIN/EXPT_INST
          PMAX_PERT = int(65000./EXPT_INST)
          call xryr2xcyc_stdgc(CRPIX1_INST,CRPIX2_INST,
     .                         xgc0,ygc0,GDCFILE_USE)
c         if (.true.) then
c             HIFLAG_INST = 80000*EXPT_INST
c             do i = 0001, NAXIS1
c             do j = 0001, NAXIS2
c                pixc(i,j) = pixc(i,j)*EXPT_INST
c                enddo
c                enddo
c             endif
          do i = 0001, NAXIS1
          do j = 0001, NAXIS2
             pixq(i,j) = 0
             if (pixc(i,j).gt.HIFLAG_INST) pixq(i,j) = 1
             enddo
             enddo
          goto 3
          endif
 
c#include "../ROUTINES/sub_hst2xym_info_plug_JWST.f"
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'Unrecognized instrument...'
          endif
 
      NAXIS1 = 0
      NAXIS2 = 0
      NAXIS1 = i4_query_hdre(FILENAMu,'NAXIS1  ',-1)
      NAXIS2 = i4_query_hdre(FILENAMu,'NAXIS2  ',-1)
      if (NAXIS1.le.0.or.NAXIS2.le.0) then
          print*,' FILENAME: ',FILENAME(1:60)
          print*,'   PREFIX: ',PREFIX(1:60)
          print*,'   NAXIS1: ',NAXIS1
          print*,'   NAXIS2: ',NAXIS2
          stop '---> no way found to read in image...'
          endif
      INSTu = 0
      Ks = 1
      allocate(pixn(NAXIS1,NAXIS2))
      allocate(pixo(NAXIS1,NAXIS2))
      allocate(pixc(NAXIS1,NAXIS2))
      allocate(pixp(NAXIS1,NAXIS2))
      allocate(pixx(NAXIS1,NAXIS2))
      allocate(pixq(NAXIS1,NAXIS2))
      allocate(pixw(NAXIS1,NAXIS2))
      CRPIX1_INST = 0.0
      CRPIX2_INST = 0.0
      CRVAL1_INST = 0.0
      CRVAL2_INST = 0.0
      CD1_1_INST  = 0.0
      CD1_2_INST  = 0.0
      CD2_1_INST  = 0.0
      CD2_2_INST  = 0.0
      LOFLAG_INST = -100.
      HIFLAG_INST = HIFLAG
      FILT_INST   = 'NONE'
      EXPT_INST   = 1.00
      RDAT_INST   = 0.00
      PROP_INST   = 00000
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'CALL readfits_r4e(generi) ',NAXIS1,NAXIS2
          endif
      call readfits_r4(FILENAMu,pixc, NAXIS1, NAXIS2)
      if (VERBOSE.ge.2) then
          print*,' '
          print*,' RET readfits_r4e(generi) '
          endif
      BDRY_XR(1,1) = 1
      BDRY_YR(1,1) = 1
      BDRY_XR(2,1) = NAXIS1
      BDRY_YR(2,1) = 1
      BDRY_XR(3,1) = NAXIS1
      BDRY_YR(3,1) = NAXIS2
      BDRY_XR(4,1) = 1
      BDRY_YR(4,1) = NAXIS2
      do i = 0001, NAXIS1
      do j = 0001, NAXIS2
         pixo(i,j) = pixc(i,j)
         pixq(i,j) = 0
         if (pixc(i,j).gt.HIFLAG_INST) pixq(i,j) = 1
         enddo
         enddo
 
 
    3 continue
 
      HIFLAG_COMMON = HIFLAG_INST
      LOFLAG_COMMON = LOFLAG_INST
 
      EXPT_EFF = EXPT_INST
      EXPTu    = EXPT_INST
      if (INSTu.eq.0) EXPT_EFF = 1.00
      if (INSTu.eq.9) EXPT_EFF = 1.00
 
      if (VERBOSE.ge.1) then
          write(*,'(12x,''           '')')
          write(*,'(12x,'' PSFFILE : '',a99)') PSFFILE_USE(1:99)
          write(*,'(12x,'' GDCFILE : '',a99)') GDCFILE_USE(1:99)
          endif
 
 
 
 
      do i = 0001, NAXIS1
      do j = 0001, NAXIS2
         pixn(i,j) = 0
         enddo
         enddo
 
      if (VERBOSE.ge.1) then
          write(*,'(13x,''           '')')
          write(*,'(13x,''DOSATD  : '',l6)') DOSATD
          write(*,'(13x,''HIFLAG  : '',i6)') HIFLAG
          endif
 
c------------------------------------------------------
c
c identify every pixel next to a saturated pixel
c    as saturation-affected ; this will give us
c    a penumbra around saturated stars when we
c    add up the related flux
c
      if (DOSATD.and.INSTu.ge.1) then
          if (HIFLAG.eq.0) then
              if (VERBOSE.ge.2) then
                  print*,'START SATGLOM ITERATIONS: '
                  endif
              NITGLOM = 0
              NSATGLOM  = 0
              NSATGLOMt = 0
  433         continue
              NSATGLOM = 0
              do i = 0002, 4095
              do j = 0002, 4095
                 if (pixq(i,j).ne.0) then
                     do ii = i-1, i+1
                     do jj = j-1, j+1
                        if (pixq(ii,jj).eq.0.and.
     .                      pixc(ii,jj).gt.HIFLAG_INST) then
                            NSATGLOM = NSATGLOM + 1
                            pixq(ii,jj) = 2
                            endif
                        enddo
                        enddo
                     endif
                 enddo
                 enddo
              NITGLOM = NITGLOM + 1
              NSATGLOMt = NSATGLOMt + NSATGLOM
              if (VERBOSE.ge.2) then
                  write(*,'(''   '',i3,1x,i6,1x,i6)')
     .                     NITGLOM, NSATGLOMt, NSATGLOM
                  endif
              if (NSATGLOM.gt.0) goto 433
              endif
 
         if (VERBOSE.ge.1) then
             write(*,'(13x,'''')')
             write(*,'(13x,''IDENTIFY SATURATED STARS '')')
             endif
 
         if (VERBOSE.ge.2) then
             print*,' '
             print*,'CALL peak_sat_NAXIS'
             endif
         print*,'CALL peak_sat_NAXIS',HIFLAG_INST
         call peak_sat_NAXIS(pixc,pixp,pixx,pixq,HIFLAG_INST,
     .                       NAXIS1,NAXIS2,VERBOSE)
         print*,'LLAC peak_sat_NAXIS',HIFLAG_INST
c
c TEMP
c
c        if (.false.) then
c            call writfits_r4('pixo.fits',pixc,NAXIS1,NAXIS2)
c            call writfits_r4('pixc.fits',pixc,NAXIS1,NAXIS2)
c            call writfits_r4('pixp.fits',pixp,NAXIS1,NAXIS2)
c            call writfits_r4('pixx.fits',pixx,NAXIS1,NAXIS2)
c            call writfits_b1('pixq.fits',pixq,NAXIS1,NAXIS2)
c            endif
c
c TEMP
c
 
         if (VERBOSE.ge.2) then
             print*,' '
             print*,' RET peak_sat_NAXIS'
             endif
 
         if (VERBOSE.ge.1) then
             write(*,'(13x,'' '')')
             write(*,'(13x,''GET FLUXES FOR SATURATED STARS '')')
             write(*,'(13x,'' '')')
             write(*,'(13x,''    PSFFILE_USE: '',a99)')
     .                           PSFFILE_USE(1:99)
             write(*,'(13x,'' '')')
             endif
         call sat_phot_NAXIS(pixc,pixp,pixx,HIFLAG_INST,
     .                       NAXIS1,NAXIS2,PSFFILE_USE,
     .                       isat,jsat,zsat,NSATs,VERBOSE)
         if (VERBOSE.ge.2) then
             print*,' '
             print*,' RET sat_phot_NAXIS'
             endif
 
         if (VERBOSE.ge.3) then
             call writfits_r4('pixo.fits',pixo,NAXIS1,NAXIS2)
             call writfits_r4('pixc.fits',pixc,NAXIS1,NAXIS2)
             call writfits_r4('pixp.fits',pixp,NAXIS1,NAXIS2)
             call writfits_r4('pixx.fits',pixx,NAXIS1,NAXIS2)
             call writfits_b1('pixq.fits',pixq,NAXIS1,NAXIS2)
             do i = 0001, 4096
             do j = 0001, 4096
                if (pixo(i,j).gt.HIFLAG*0.9) then
                   write(44,144) i, j, pixo(i,j), pixq(i,j), pixc(i,j)
  144               format(1x,i4,1x,i4,1x,f8.0,1x,i1,1x,f12.0)
                    endif
                 enddo
                 enddo
             endif
 
         endif ! DOSATD
 
 
 
 
c-------------------------------------------
c
c should we generate and apply a mask?
c
      if (SHOW_MSK.ne.'-') then
         allocate(pixm(NAXIS1,NAXIS2))
         do i = 001, NAXIS1
         do j = 001, NAXIS2
            pixm(i,j) = 0.
            enddo
            enddo
         call pix2mask(pixm,INSTu,                           ! this routine will generate a mask in the
     .                 NSATs,isat,jsat,zsat,                 !    image frame related to where the bright
     .                 NAXIS1,NAXIS2)                        !    saturated star PSFs affect other stars
         if (SHOW_MSK.eq.'+') then
            IMMSKu = PREFIX(1:9) // '_msk.fits'
            call writfits_r4(IMMSKu,pixm,NAXIS1,NAXIS2)      ! output mask image, if desired
            endif
         if (SHOW_MSK.eq.'~') then
            iii = 1
            do i = 1, 200
               if (FILENAMu(i:i).eq.'/') iii = i + 1
               enddo
            IMSUBu = FILENAMu(iii:200)
            print*,'FILENAMu: ',FILENAMu
            print*,'  IMSUBu: ',  IMSUBu
            print*,'     iii: ',iii
            if (IMSUBu(10:10).ne.'_') stop 'problem with filename'
            IMSUBu(9:9) = 'm'
            if (INSTu.ne.5.and.INSTu.ne.8.and.INSTu.ne.9) then
                print*,'                                          '
                 print*,' IF YOU WANT TO OUTPUT A MASKED IMAGE   '
                 print*,' IN A SHELL, THEN FOR NOW, THE IMAGE MUST '
                 print*,' BE ONE OF:  ACSWFC, WFC3UV, or WFC3IR.   '
                 print*,'                                          '
                 print*,' YOU CAN OUTPUT IT NORMALLY w/ SHOW_MSK+  '
                 print*,'                                          '
                 stop
                 endif
            if (INSTu.eq.5)
     .          call cpyNrepl_acswfc(FILENAMu,IMSUBu,pixm,'MSK')
            if (INSTu.eq.8)
     .          call cpyNrepl_wfc3uv(FILENAMu,IMSUBu,pixm,'MSK')
            if (INSTu.eq.9)
     .          call cpyNrepl_wfc3ir(FILENAMu,IMSUBu,pixm,'MSK')
            endif
         endif
 
 
c-------------------------------------------
c
c output some diagnostic information if VERBOSE.ge.2
c
      if (VERBOSE.ge.2) then
          write(*,'(''             '')')
          write(*,'(''   INSTRUME: '',a20)')    STRING20_INSTRUME
          write(*,'(''   DETECTOR: '',a20)')    STRING20_DETECTOR
          write(*,'(''             '')')
          write(*,'('' CRPIX1_INST: '',2f20.12)')CRPIX1_INST,CRPIX2_INST
          write(*,'('' CRPIX1_xgc0: '',2f20.12)')xgc0,ygc0
          write(*,'('' CRVAL1_INST: '',2f20.12)')CRVAL1_INST,CRVAL2_INST
          write(*,'(''  CD1_1_INST: '',2f20.12)')CD1_1_INST,CD1_2_INST
          write(*,'(''  CD2_1_INST: '',2f20.12)')CD2_1_INST,CD2_2_INST
          write(*,'('' LOFLAG_INST: '',i8)') LOFLAG_INST
          write(*,'('' HIFLAG_INST: '',i8)') HIFLAG_INST
          write(*,'(''BDRY_XR(1,1): '',2f20.12)') BDRY_XR(1,1),
     .                                           BDRY_YR(1,1)
          write(*,'(''BDRY_XR(2,1): '',2f20.12)') BDRY_XR(2,1),
     .                                           BDRY_YR(2,1)
          write(*,'(''BDRY_XR(3,1): '',2f20.12)') BDRY_XR(3,1),
     .                                           BDRY_YR(3,1)
          write(*,'(''BDRY_XR(4,1): '',2f20.12)') BDRY_XR(4,1),
     .                                           BDRY_YR(4,1)
          write(*,'(''   FILT_INST: '',a5  )') FILT_INST(1:5)
          write(*,'(''   EXPT_INST: '',f9.2)') EXPT_INST
          write(*,'(''   RDAT_INST: '',f9.2)') RDAT_INST
          write(*,'(''   PROP_INST: '',i5)')   PROP_INST
          write(*,'(''    RA2SEXIG: '',f12.7,a10)') CRVAL1_INST,
     .                                     ra2sexig(CRVAL1_INST)
          write(*,'(''    DE2SEXIG: '',f12.7,a10)') CRVAL2_INST,
     .                                     de2sexig(CRVAL2_INST)
          write(*,'(''              '')')
          write(*,'(''        NIMu: '',2i4)')  NIMu
          write(*,'(''        NIMs: '',2i4)')  NIMs
          write(*,'(''      NAXIS1: '',i4)')   NAXIS1
          write(*,'(''      NAXIS2: '',i4)')   NAXIS2
          write(*,'(''      NPERTs: '',i4)')   NPERTs
          write(*,'(''  FOCUS_LEVi: '',f9.4)') FOCUS_LEVELi
          write(*,'(''    FILENAME: '',80a)')  FILENAME
          write(*,'(''    FILTNAME: '',80a)')  FILTNAME
          write(*,'(''         PRE: '',80a)')  PREFIX
          write(*,'(''        STEM: '',80a)')  STEM
          write(*,'(''        SUFF: '',80a)')  SUFFIX
          write(*,'(''   FILT_INST: '',80a)')  FILT_INST
          write(*,'(''   EXPT_INST: '',f9.4)') EXPT_INST
          write(*,'(''   EXPT_EFF : '',f9.4)') EXPT_EFF
          write(*,'(''   RDAT_INST: '',f9.4)') RDAT_INST
          write(*,'(''   PROP_INST: '',i5.5)') PROP_INST
          write(*,'(''            '')')
          endif
 
 
 
      PREFIX_LEN = -1
      do i = 1,76
         if (prefix(i:i).ne.' ') PREFIX_LEN = i
         enddo
      if (VERBOSE.ge.2) print*,' PREFIX_LEN: ',PREFIX_LEN,
     .                                prefix(1:PREFIX_LEN)
 
      if (VERBOSE.ge.2) print*,' FIND_HISTMODE... '
      HMB = histmode_NAXIS(pixc,NAXIS1,NAXIS2)
      minsky = HMB
      if (VERBOSE.ge.1) then
          write(*,'(13x,''          '')')
          write(*,'(13x,''HISTMODE: '',f8.2)') HMB
          endif
 
      PSFFILE_PRT = 'NONE'
 
      if (VERBOSE.ge.2) print*,'DOAPPHOT: ',DOAPPHOT
 
      if (DOAPPHOT) goto 333
 
      NAXIS_PSF = i4_query_hdre(PSFFILE_USE,'NAXIS   ',-1)
 
      if (VERBOSE.ge.2) then
          print*,' '
          print*,'NAXIS_PSF: ',NAXIS_PSF
          print*,' FOC_LEVi: ',FOCUS_LEVELi
          print*,' '
          endif
 
c----------------------------------------------------------
c
c if we are given a focus-diverse PSF and just want to use
c the median PSF, then extract the median PSF and write it
c out as a file that can be used
c
      if (NAXIS_PSF.eq.4.and.FOCUS_LEVELi.eq.0) then
         if (VERBOSE.ge.2) then
             print*,'          '
             print*,'MAKE ONE-FOCUS PSF FROM MEDIAN OF MULTI...'
             print*,'---> FOCUS_LEVELi: ',FOCUS_LEVELi
             print*,'--->    NAXIS_PSF: ',NAXIS_PSF
             print*,'          '
             endif
         PSFFILE_PFF = PREFIX(1:9) // '_plv.fits'
         FOCUS_LEVELu = 0.
         call loadstdpsf_stdpbf(FOCUS_LEVELu,PSFFILE_USE,PSFFILE_PFF)
         PSFFILE_USE = PSFFILE_PFF
         endif
 
 
c----------------------------------------------------------
c
c if focus level is -1, then find the focus and extract the
c optimal-focus PSF to use it to measure these images
c
      if (FOCUS_LEVELi.lt.0) then
         if (VERBOSE.ge.1) then
             write(*,'(13x,''           '')')
             write(*,'(13x,''CALL FIND_FOCUS '')')
             endif
         FOCUS_LEVELu = FOCUS_LEVELi
         NFOCu = 0
         call findfocus_stdpbf(pixc,HMB,HIFLAG_INST,NAXIS1,NAXIS2,       ! identify some high S/N stars and fit the
     .                         FOCUS_LEVELu,NFOCu,PSFFILE_USE,.false.)   !    various-focus PSFs to them to see which
         call loadstdpsf_stdpbf(FOCUS_LEVELu,PSFFILE_USE,PSFFILE_PFF)    !    works best
         PSFFILE_PFF = PREFIX(1:9) // '_pff.fits'
         call savefits_stdpsf(PSFFILE_PFF)
         if (VERBOSE.ge.1) then
             write(*,'(13x,''          '')')
             write(*,'(13x,'' PSF_INP: '',a200)') PSFFILE_INP
             write(*,'(13x,'' PSF_PBF: '',a200)') PSFFILE_USE
             write(*,'(13x,'' PSF_PFF: '',a200)') PSFFILE_PFF
             write(*,'(13x,''   NFOCu: '',i5  )') NFOCu
             write(*,'(13x,''   FOCUS: '',f8.2)') FOCUS_LEVELu
             write(*,'(13x,'' PSF_PFF: '',a200)') PSFFILE_PFF
             endif
         PSFFILE_USE = PSFFILE_PFF
         endif
 
 
c----------------------------------------------------------
c
c if the user wants to perturb the PSF...
c
c
      if (NPERTs.ne.0.and.NIMu.le._NIMMXP_) then
         PSFFILE_PRT = PREFIX(1:9) // '_psf.fits'
         if (VERBOSE.ge.1) then
             write(*,'(13x,''           '')')
             write(*,'(13x,''PSFFILE_INP: '',a80)') PSFFILE_INP(1:80)
             write(*,'(13x,''PSFFILE_PRT: '',a80)') PSFFILE_PRT(1:80)
             write(*,'(13x,''           '')')
             write(*,'(13x,''CALL FIND_PSFPERT -- '',i1,''x'',i1)')
     .                       NPERTs,NPERTs
             endif
         if (VERBOSE.ge.2) then
             print*,'                   '
             print*,'---> NPERTs: ',NPERTs
             print*,'                   '
             print*,'     call find_psfpert...'
             print*,'     PSFFILE_INP = ',PSFFILE_INP
             print*,'     PSFFILE_PRT = ',PSFFILE_PRT
             print*,'            NIMu = ',NIMu
             print*,'            PMAX = ',PMAX
             print*,'                   '
             endif
         if (VERBOSE.ge.2) print*,'call find_psfpert...'
         call find_psfpert(pixc,HMB,PMAX_PERT,                        ! this routine takes an image and a PSF and
     .                     NAXIS1,NAXIS2,                             !    finds the perturbation that matches the
     .                     psfpert(1,1,1,1,NIMu),NPERTs,              !    PSF to the stars in the image
     .                     PSFFILE_USE,
     .                     VERBOSE)
         if (VERBOSE.ge.2) print*,'call output_psfperts...'
         call output_psfperts(psfpert,NPERTs,STEMs_N,NIMs,VERBOSE)    ! output an image showing all the perts
         if (VERBOSE.ge.2) then
             print*,'                   '
             print*,'     PSFFILE_USE = ',PSFFILE_USE(1:40)
             print*,'     PSFFILE_PRT = ',PSFFILE_PRT(1:40)
             print*,'                   '
             print*,'     (51,51,1,1) = ',psfpert(51,51,1,1,NIMu)
             print*,'                   '
             endif
         if (VERBOSE.ge.2) print*,'call writfits_psfpert2std...'
         call writfits_psfpert2std(psfpert(1,1,1,1,NIMu),            ! output the pert-psf as a
     .                             NPERTs,STEM,                      !    standard PSF
     .                             NAXIS1,NAXIS2,
     .                             PSFFILE_USE,
     .                             PSFFILE_PRT,
     .                             VERBOSE)
         if (VERBOSE.ge.1) then
             write(*,'(13x,''          '')')
             write(*,'(13x,''CENPERT : '',5x,9(i3,5x))') (i,i=1,NPERTs)
             do j = NPERTs, 01, -1
                write(*,'(23x,2x,i1,1x,9f8.4)')
     .                   j, (psfpert(51,51,i,j,NIMu),i=1,NPERTs)
                enddo
             endif
         PSFFILE_USE = PSFFILE_PRT
         endif
 
 
  333 continue ! jump to here if there is no PSF (i.e., aperture photometry)
 
      HIFLAG_COMMON = HIFLAG_INST
      LOFLAG_COMMON = LOFLAG_INST
 
      call query_hdre(FILENAMu,'TIME-OBS ',TIMESTR,-1)
      call query_hdre(FILENAMu,'DATE-OBS ',DATESTR,-1)
 
 
      write(HH(HHs+001),'(''# '')')
      write(HH(HHs+002),'(''#================================'')')
      write(HH(HHs+003),'(''# BASIC STAR-FINDING PARAMETERS  '')')
      write(HH(HHs+004),'(''# '')')
      write(HH(HHs+005),'(''# FILENAME: '',a80)')  FILENAME
      write(HH(HHs+006),'(''#   NAXIS1: '',i5)')  NAXIS1
      write(HH(HHs+007),'(''#   NAXIS2: '',i5)')  NAXIS2
      write(HH(HHs+008),'(''#           '')')
      write(HH(HHs+009),'(''#   CRPIX1: '',f30.22)') CRPIX1_INST
      write(HH(HHs+010),'(''#   CRPIX2: '',f30.22)') CRPIX2_INST
      write(HH(HHs+011),'(''#   CRVAL1: '',f30.22)') CRVAL1_INST
      write(HH(HHs+012),'(''#   CRVAL2: '',f30.22)') CRVAL2_INST
      write(HH(HHs+013),'(''#    CD1_1: '',f30.22)') CD1_1_INST
      write(HH(HHs+014),'(''#    CD1_2: '',f30.22)') CD1_2_INST
      write(HH(HHs+015),'(''#    CD2_1: '',f30.22)') CD2_1_INST
      write(HH(HHs+016),'(''#    CD2_2: '',f30.22)') CD2_2_INST
      write(HH(HHs+017),'(''#           '')')
      write(HH(HHs+018),'(''#     HMIN: '',i10  )')  HMIN
      write(HH(HHs+019),'(''#     PMAX: '',f12.1)')  PMAX
      write(HH(HHs+020),'(''#     FMIN: '',2f12.1)') FMINu,FMIN
      write(HH(HHs+021),'(''#   PIXFIT: '',a3)')     PIXFIT
      write(HH(HHs+022),'(''# HISTMODE: '',f12.1)')  HMB
      if (INSTu.eq.9)
     .write(HH(HHs+022),'(''# HISTMODE: '',2f12.1)') HMB,HMB*EXPT_INST
      write(HH(HHs+023),'(''# HIFLAG  : '',i10)') HIFLAG
      write(HH(HHs+024),'(''# HIFLAG_I: '',i10)') HIFLAG_INST
      write(HH(HHs+025),'(''# LOFLAG_I: '',i10)') LOFLAG_INST
      write(HH(HHs+026),'(''# DOAPPHOT: '',9x,l1)') DOAPPHOT
      write(HH(HHs+027),'(''#      PID: '',i10)') PID
      write(HH(HHs+028),'(''#     FILT: '',5x,a5)') FILTNAME
      write(HH(HHs+029),'(''#    EXPTI: '',f15.4)') EXPT_INST
      write(HH(HHs+030),'(''#    EXPTE: '',f15.4)') EXPT_EFF
      write(HH(HHs+031),'(''#     rDAT: '',f19.8)') rDATuu
      write(HH(HHs+032),'(''#  TIMESTR: '',5x,20a)') TIMESTR
      write(HH(HHs+033),'(''#  DATESTR: '',5x,20a)') DATESTR
      write(HH(HHs+034),'(''# APERTURE: '',5x,20a)') STRING20_APERTURE
      write(HH(HHs+035),'(''#     GAIN: '',5x,f8.2)') GAIN_INST
      write(HH(HHs+036),'(''#           '')')
      write(HH(HHs+037),'(''#  PSF_INP: '',a200)') PSFFILE_INP
      write(HH(HHs+038),'(''#  PSF_USE: '',a200)') PSFFILE_USE
      write(HH(HHs+039),'(''#   NPERTs: '',i4 )')  NPERTs
      write(HH(HHs+040),'(''#           '')')
      write(HH(HHs+041),'(''#  GDC_INP: '',a200)') GDCFILE_INP
      write(HH(HHs+042),'(''#           '')')
      HHs = HHs + 42
 
      if (FOCUS_LEVELi.ne.0.00) then
          write(HH(HHs+001),'(''# FOC_LEVi: '',f17.3)') FOCUS_LEVELi
          write(HH(HHs+002),'(''# FOC_LEVu: '',f17.3)') FOCUS_LEVELu
          write(HH(HHs+003),'(''# '')')
          HHs = HHs + 3
          endif
 
      if (.not.DOAPPHOT) then
         write(HH(HHs+001),'(''# '')')
         write(HH(HHs+002),'(''#================================'')')
         write(HH(HHs+003),'(''# PSF INFO '')')
         write(HH(HHs+004),'(''# '')')
         HHs = HHs + 004
         if (VERBOSE.ge.2) then
             print*,'  '
             print*,'HERE IS THE INFO ON THE PSF TO BE USED...'
             print*,'  '
             endif
 
         call infofits_stdpsf(PSFFILE_USE,NXPSFs,NYPSFs,ilist,jlist)
         do i = 1, NXPSFs
         do j = 1, NYPSFs
           call locpsfij_stdpsf(ilist(i),jlist(j),
     .                           psfloc,PSFFILE_USE)
           psfarr1(i,j) = psfloc(51,51)
           enddo
           enddo
         write(HH(HHs+1),'(''# PSFFILE_USE: '',a80)') PSFFILE_USE
         write(HH(HHs+2),'(''# '')')
         write(HH(HHs+3),'(''#      CENTRAL PIXEL ARRAY'')')
         write(HH(HHs+4),'(''#   '',20x,10i8.4)')
     .                      (ilist(i),i=1,NXPSFs)
         write(HH(HHs+5),'(''#   '',20x,10i8.2)')
     .                      (      i ,i=1,NXPSFs)
         HHs = HHs + 5
         do j = NYPSFs,01,-1
            HHs = HHs + 1
            write(HH(HHs),'(''# '',14x,i4.4,1x,i2.2,1x,10f8.4)')
     .             jlist(j),j,(psfarr1(i,j),i=1,NXPSFs)
            enddo
         HHs = HHs + 1
         write(HH(HHs),'(''# '')')
 
         if (NPERTs.ne.0) then
             call infofits_stdpsf(PSFFILE_INP,NXPSFs,NYPSFs,ilist,jlist)
             do i = 1, NXPSFs
             do j = 1, NYPSFs
                call locpsfij_stdpsf(ilist(i),jlist(j),
     .                               psfloc,PSFFILE_INP)
                psfarr2(i,j) = psfloc(51,51)
                enddo
                enddo
             if (NPERTs.ne.0.and.NIMu.le._NIMMXP_) then
                write(HH(HHs+1),'(''# CENTRAL PERT PSF: '')')
                HHs = HHs + 1
                do j = NPERTs, 1, -1
                   HHs = HHs + 1
                   write(HH(HHs),'(''# '',4x,1x,i2.2,1x,10f8.4)')
     .                   j,(psfpert(51,51,i,j,NIMu),i=1,NPERTs)
                   enddo
                HHs = HHs + 1
                write(HH(HHs),'(''# '')')
                endif
             ptot = 0.
             do i = 1, NYPSFs
             do j = 1, NXPSFs
                ptot = ptot + abs(psfarr1(i,j)-psfarr2(i,j))
                enddo
                enddo
             if (ptot.gt.1e-5) then
                write(HH(HHs+1),'(''# CENTRAL PSFFILE_INP: '',a80)')
     .                                        PSFFILE_INP
                write(HH(HHs+2),'(''#   '',10x,10i8.4)')
     .                             (ilist(i),i=1,NXPSFs)
                write(HH(HHs+3),'(''#   '',10x,10i8.2)')
     .                             (      i ,i=1,NXPSFs)
                HHs = HHs + 3
                do j = NYPSFs,01,-1
                   HHs = HHs + 1
                   write(HH(HHs),'(''# '',4x,i4.4,1x,i2.2,1x,10f8.4)')
     .                    jlist(j),j,(psfarr2(i,j),i=1,NXPSFs)
                   enddo
                HHs = HHs + 1
                write(HH(HHs),'(''# '')')
                write(HH(HHs+1),'(''# CENTRAL  DIFFERENCE'')')
                write(HH(HHs+2),'(''#   '',10x,10i8.4)')
     .                             (ilist(i),i=1,NXPSFs)
                write(HH(HHs+3),'(''#   '',10x,10i8.2)')
     .                             (      i ,i=1,NXPSFs)
                HHs = HHs + 3
                do j = NYPSFs,01,-1
                   HHs = HHs + 1
                   write(HH(HHs),'(''# '',4x,i4.4,1x,i2.2,1x,10f8.4)')
     .               jlist(j),j,(psfarr2(i,j)-psfarr1(i,j),i=1,NXPSFs)
                   enddo
                HHs = HHs + 1
                endif
             write(HH(HHs),'(''# '')')
             endif
         endif ! not APPHOT
 
 
 
 
 
      write(HH(HHs+01),'(''#  '')')
      write(HH(HHs+02),'(''#================================='')')
      write(HH(HHs+03),'(''# FRAME INFO                      '')')
      write(HH(HHs+04),'(''#  '')')
      write(HH(HHs+05),'(''#      WCSMODE: '',a200)') WCSMODE
      HHs = HHs + 05
 
      if (WCSMODE(1:3).eq.'HDR') then
          if (WCSMODE(4:4).ne.'{')
     .        stop 'No opening brace in WCS=HDR{iabcdefgq_drz.fits}'
          WCSFILE = WCSMODE(5:200)
          do i = 1, 195
             if (WCSFILE(i:i).eq.'}') then
                 WCSFILE = WCSFILE(1:i-1)
                 goto 339
                 endif
             enddo
          stop 'No closing brace in WCS=HDR{}'
  339     continue
          call query_hdre(WCSFILE,'CRPIX1  ',STREAM,-1)
          read(STREAM,*) CRPIX1_DEST
          call query_hdre(WCSFILE,'CRPIX2  ',STREAM,-1)
          read(STREAM,*) CRPIX2_DEST
          call query_hdre(WCSFILE,'CRVAL1  ',STREAM,-1)
          read(STREAM,*) CRVAL1_DEST
          call query_hdre(WCSFILE,'CRVAL2  ',STREAM,-1)
          read(STREAM,*) CRVAL2_DEST
          call query_hdre(WCSFILE,'CD1_1   ',STREAM,-1)
          read(STREAM,*) CD1_1_DEST
          call query_hdre(WCSFILE,'CD1_2   ',STREAM,-1)
          read(STREAM,*) CD1_2_DEST
          call query_hdre(WCSFILE,'CD2_1   ',STREAM,-1)
          read(STREAM,*) CD2_1_DEST
          call query_hdre(WCSFILE,'CD2_2   ',STREAM,-1)
          read(STREAM,*) CD2_2_DEST
          endif
 
      if (WCSMODE.eq.'SELF') then
          CRPIX1_DEST = CRPIX1_INST
          CRPIX2_DEST = CRPIX2_INST
          CRVAL1_DEST = CRVAL1_INST
          CRVAL2_DEST = CRVAL2_INST
          CD1_1_DEST  = CD1_1_INST
          CD1_2_DEST  = CD1_2_INST
          CD2_1_DEST  = CD2_1_INST
          CD2_2_DEST  = CD2_2_INST
          endif
 
      if (WCSMODE.eq.'AUTO') then
          call query_hdre(FILENAMu,'TARGNAME',STRING_TARGNAME,-1)
          if (STRING_TARGNAME(1:1).eq.'''')
     .        STRING_TARGNAME = STRING_TARGNAME(2:20)
          do i = 1, 20
             if (STRING_TARGNAME(i:i).eq.'''') STRING_TARGNAME(i:i)= ' '
             enddo
          call query_hdre(FILENAMu,'RA_TARG ',STRING_RA_TARG ,-1)
          call query_hdre(FILENAMu,'DEC_TARG',STRING_DEC_TARG,-1)
          if (STRING_RA_TARG(1:4).eq.'NULL') then
              call query_hdre(FILENAMu,'TARG_RA ',STRING_RA_TARG ,-1)
              call query_hdre(FILENAMu,'TARG_DEC',STRING_DEC_TARG,-1)
              endif
          PLT_SCL = 50 ! mas/pixel
          if (INSTu.eq.1) PLT_SCL = 100 ! WFPC2
          if (INSTu.eq.5) PLT_SCL =  50 ! ACS/WFC
          if (INSTu.eq.7) PLT_SCL =  25 ! ACS/HRC
          if (INSTu.eq.8) PLT_SCL =  40 ! WFC3/UVIS
          if (INSTu.eq.9) PLT_SCL = 100 ! WFC3/IR
          write(STRING_PLATESCL,'(f8.3,'' mas/pix'')') PLT_SCL
          write(HH(HHs+01),'(''#     TARGNAME: '',a20)') STRING_TARGNAME
          write(HH(HHs+02),'(''#     RA_TARG : '',a20)') STRING_RA_TARG
          write(HH(HHs+03),'(''#     DEC_TARG: '',a20)') STRING_DEC_TARG
          write(HH(HHs+04),'(''#        INSTu: '',i5 )') INSTu
          write(HH(HHs+05),'(''#     PLATESCL: '',a20)') STRING_PLATESCL
          HHs = HHs + 05
          CRPIX1_DEST = 0.00
          CRPIX2_DEST = 0.00
          read(STRING_RA_TARG ,*,err=77) CRVAL1_DEST
          read(STRING_DEC_TARG,*,err=77) CRVAL2_DEST
   77     continue
          CD1_1_DEST = -1.0d0/(3600.0d0*1000.0d0/PLT_SCL)
          CD1_2_DEST =  0.0d0
          CD2_1_DEST =  0.0d0
          CD2_2_DEST =  1.0d0/(3600.0d0*1000.0d0/PLT_SCL)
          endif
 
      if (WCSMODE(1:1).eq.'(') then              ! simple WCS by-hand specification:  (x,y,r,d,scl)
          print*,'WCSMODE : ',WCSMODE
          WCSMODEu = WCSMODE
          ii = 0
          do i = 1, 200
             if (WCSMODEu(i:i).eq.'(') WCSMODEu(i:i) = ' '
             if (WCSMODEu(i:i).eq.',') WCSMODEu(i:i) = ' '
             if (WCSMODEu(i:i).eq.')') then
                 WCSMODEu(i:i) = ' '
                 ii = i
                 endif
             enddo
          print*,'WCSMODEu: ',WCSMODEu
          if (ii.eq.0) stop 'WCS=(x,y,r,d,pltscl) needs closing paren'
          read(WCSMODEu,*) CRPIX1_DEST, CRPIX2_DEST,
     .                     CRVAL1_DEST, CRVAL2_DEST,
     .                     PLT_SCL
          CD1_1_DEST = -1.0d0/(3600.0d0*1000.0d0/PLT_SCL)
          CD1_2_DEST =  0.0d0
          CD2_1_DEST =  0.0d0
          CD2_2_DEST =  1.0d0/(3600.0d0*1000.0d0/PLT_SCL)
          write(HH(HHs+01),'(''# '')')
          write(HH(HHs+02),'(''#       CRPIX1: '',f20.8)') CRPIX1_DEST
          write(HH(HHs+03),'(''#       CRPIX2: '',f20.8)') CRPIX2_DEST
          write(HH(HHs+04),'(''#       CRVAL1: '',f20.8)') CRVAL1_DEST
          write(HH(HHs+05),'(''#       CRVAL2: '',f20.8)') CRVAL2_DEST
          write(HH(HHs+06),'(''#       PLTSCL: '',f10.3)') PLT_SCL
          write(HH(HHs+07),'(''#       CD2_12: '',2f11.8)') CD1_1_DEST,
     .                                                      CD1_2_DEST
          write(HH(HHs+08),'(''#       CD2_12: '',2f11.8)') CD2_1_DEST,
     .                                                      CD2_2_DEST
          write(HH(HHs+09),'(''# '')')
          HHs = HHs + 09
          endif
 
       if (WCSMODE(1:3).eq.'MAT') then
           MATFILE = STEM // '_mat.UVuvWw'
           write(*,'(12x,'' MATFILE : '',a20)') MATFILE
           call readmat2trans(MATFILE,Ls_mat,
     .                        AG_mat,BG_mat,
     .                        CG_mat,DG_mat,
     .                        x1o_mat,y1o_mat,
     .                        x2o_mat,y2o_mat,ZP_mat)
           GA_mat =  DG_mat/(AG_mat*DG_mat-BG_mat*CG_mat)
           GB_mat = -BG_mat/(AG_mat*DG_mat-BG_mat*CG_mat)
           GC_mat = -CG_mat/(AG_mat*DG_mat-BG_mat*CG_mat)
           GD_mat =  AG_mat/(AG_mat*DG_mat-BG_mat*CG_mat)
           write(HH(HHs+001),'(''# '')')
           write(HH(HHs+002),'(''#  WCSMODE: '',a3)')     WCSMODE
           write(HH(HHs+003),'(''#    MFILE: '',a20)')    MATFILE
           write(HH(HHs+004),'(''#    NMATs: '',i5)')     Ls_mat
           write(HH(HHs+005),'(''#       AB: '',2f12.6)') AG_mat, BG_mat
           write(HH(HHs+006),'(''#       CD: '',2f12.6)') CG_mat, DG_mat
           write(HH(HHs+007),'(''#        1: '',2f8.2)') x1o_mat,y1o_mat
           write(HH(HHs+008),'(''#        2: '',2f8.2)') x2o_mat,y2o_mat
           write(HH(HHs+009),'(''#       ZP: '',2f8.2)') ZP_mat
           write(HH(HHs+010),'(''# '')')
           HHs = HHs + 10
           endif
 
      write(HH(HHs+01),'(''#  '')')
      write(HH(HHs+02),2299) ' INST1: ',CRPIX1_INST,
     .                                  CD1_1_INST,
     .                                  CD1_2_INST,
     .                                  CRVAL1_INST,
     .                                  ra2sexig(CRVAL1_INST)
      write(HH(HHs+03),2299) '     2: ',CRPIX2_INST,
     .                                  CD2_1_INST,
     .                                  CD2_2_INST,
     .                                  CRVAL2_INST,
     .                                  de2sexig(CRVAL2_INST),
     .                            sqrt((-CD1_1_INST*CD2_2_INST
     .                                +CD1_2_INST*CD2_1_INST))
     .                                     *3600.0d0*1000.0d0
     .
      write(HH(HHs+04),2298)
      write(HH(HHs+05),2297)
      write(HH(HHs+06),2298)
      write(HH(HHs+07),2299) ' DEST1: ',CRPIX1_DEST,
     .                                  CD1_1_DEST,
     .                                  CD1_2_DEST,
     .                                  CRVAL1_DEST,
     .                                  ra2sexig(CRVAL1_DEST),
     .                           sqrt((-CD1_1_DEST*CD2_2_DEST
     .                                 +CD1_2_DEST*CD2_1_DEST))
     .                                    *3600.0d0*1000.0d0
      write(HH(HHs+08),2299) '     2: ',CRPIX2_DEST,
     .                                  CD2_1_DEST,
     .                                  CD2_2_DEST,
     .                                  CRVAL2_DEST,
     .                                  de2sexig(CRVAL2_DEST)
      write(HH(HHs+09),'(''#  '')')
      HHs = HHs + 09
 2299 format('#',7x,a8,
     .           3x,f10.2,
     .           5x,f11.8,1x,f11.8,5x,f13.7,1x,a12,
     .           5x,f8.3)
 2298 format('#',7x,' -----  ',
     .           3x,'----------',
     .           5x,'-----------',1x,'-----------',
     .           5x,' ------------',
     .           1x,'------------',
     .           5x,'---------')
 2297 format('#',7x,' FRAME  ',
     .           3x,'    CRPIX ',
     .           5x,'   CD_1    ',1x,'   CD_2    ',
     .           5x,'  RADEC(DEG) ',
     .           1x,'RADEC(SEXIG)',
     .           5x,'(mas/pix)')
 
 
 
 
c-------------------------------------------
c
c define the inverse WCS transformations
c
      RCD1_1_INST =  CD2_2_INST/(CD1_1_INST*CD2_2_INST
     .                          -CD1_2_INST*CD2_1_INST)
      RCD1_2_INST = -CD1_2_INST/(CD1_1_INST*CD2_2_INST
     .                          -CD1_2_INST*CD2_1_INST)
      RCD2_1_INST = -CD2_1_INST/(CD1_1_INST*CD2_2_INST
     .                          -CD1_2_INST*CD2_1_INST)
      RCD2_2_INST =  CD1_1_INST/(CD1_1_INST*CD2_2_INST
     .                          -CD1_2_INST*CD2_1_INST)
 
      RCD1_1_DEST =  CD2_2_DEST/(CD1_1_DEST*CD2_2_DEST
     .                          -CD1_2_DEST*CD2_1_DEST)
      RCD1_2_DEST = -CD1_2_DEST/(CD1_1_DEST*CD2_2_DEST
     .                          -CD1_2_DEST*CD2_1_DEST)
      RCD2_1_DEST = -CD2_1_DEST/(CD1_1_DEST*CD2_2_DEST
     .                          -CD1_2_DEST*CD2_1_DEST)
      RCD2_2_DEST =  CD1_1_DEST/(CD1_1_DEST*CD2_2_DEST
     .                          -CD1_2_DEST*CD2_1_DEST)
 
      if (As.ne.0) then
          ARTFILE = STEM // '_art.xymnfo'
          allocate(pixa(NAXIS1,NAXIS2))
          allocate(pixd(NAXIS1,NAXIS2))
          do i = 0001, NAXIS1
          do j = 0001, NAXIS2
             pixa(i,j) = pixo(i,j)
             pixd(i,j) = 0.
             enddo
             enddo
          open(71,file=ARTFILE,status='unknown')
          write(71,'(''#'')')
          write(71,271)
          write(71,371)
          write(71,271)
          write(71,'(''#'')')
          write(HH(HHs+001),'(''# '')')
          write(HH(HHs+002),'(''# ARTSTARS: '',i5)')  As
          write(HH(HHs+003),'(''#   ASTYPE: '',2x,3a)')  ASTYPE
          write(HH(HHs+004),'(''#  ARTFILE: '',20a)')    ARTFILE
          write(HH(HHs+005),'(''# '')')
          HHs = HHs + 5
          if (VERBOSE.ge.2) then
              print*,' '
              print*,'---> INSERT ARTIFICIAL STARS:  As = ',As
              print*,'--->                    EXPT_INST = ',EXPT_INST
              print*,'--->                    EXPT_EFF  = ',EXPT_EFF
              print*,'--->                    EXPTu     = ',EXPTu
              print*,' '
              endif
          if (ASTYPE.eq.'UVW') then ! throw ASs into the ref frame, so must convert to local frame
              MATFILE = STEM // '_mat.UVuvWw'
              write(*,'(12x,'' MATFILE : '',a20)') MATFILE
              call readmat2trans(MATFILE,Ls_mat,
     .                           AG_mat,BG_mat,CG_mat,DG_mat,
     .                           x1o_mat,y1o_mat,
     .                           x2o_mat,y2o_mat,ZP_mat)
              write(HH(HHs+001),'(''#  MATFILE: '',a20)')    MATFILE
              write(HH(HHs+002),'(''#    NMATs: '',i5)')     Ls_mat
              write(HH(HHs+003),'(''#       AB: '',2f12.6)') AG_mat,
     .                                                       BG_mat
              write(HH(HHs+004),'(''#       CD: '',2f12.6)') CG_mat,
     .                                                       DG_mat
              write(HH(HHs+005),'(''#        1: '',2f8.2)')  x1o_mat,
     .                                                       y1o_mat
              write(HH(HHs+006),'(''#        2: '',2f8.2)')  x2o_mat,
     .                                                       y2o_mat
              write(HH(HHs+007),'(''#       ZP: '',2f8.2)')  ZP_mat
              HHs = HHs + 7
              endif
          do A = 1, As
             uur = 0.00
             vvr = 0.00
             wwr = 0.00
              ur = 0.00
              vr = 0.00
              wr = 0.00
             xxr = 0.00
             yyr = 0.00
             mmr = 0.00
              xr = 0.00
              yr = 0.00
              mr = 0.00
             dy_cte = 0.00
             dm_cte = 0.00
             dmc    = 0.00
             if (ASTYPE.eq.'UVW') then
                 uur = xinp_a(A)
                 vvr = yinp_a(A)
                 wwr = minp_a(A)
                  ur = x2o_mat + AG_mat*(uur-x1o_mat)
     .                         + BG_mat*(vvr-y1o_mat)
                  vr = y2o_mat + CG_mat*(uur-x1o_mat)
     .                         + DG_mat*(vvr-y1o_mat)
                  wr = wwr + ZP_mat
                 call xcyc2xryr_stdgc(ur,vr,xxr,yyr,GDCFILE_USE)
                 call xryr2mc_stdgc(xxr,yyr,dmc,    GDCFILE_USE)
                 mmr = wr - dmc
                 endif
             if (ASTYPE.eq.'XYM') then
                 xxr = xinp_a(A)
                 yyr = yinp_a(A)
                 mmr = minp_a(A)
                 endif
             if (ASTYPE.eq.'UVW'.or.
     .           ASTYPE.eq.'XYM') then
                 if (ISFLT.and.
     .               xxr.ge.1.and.xxr.le.NAXIS1.and.
     .               yyr.ge.1.and.yyr.le.NAXIS2) then
                     ixr0 = int(xxr+0.5)
                     iyr0 = int(yyr+0.5)
                     if (INSTu.eq.8) then                                   ! WFC3/UVIS
                         sr = pixc(int(xxr+0.5),int(yyr+0.5))               ! just get bkgd from pixel itself... 3x3?
                         sr = mbar_sky_NAXIS(ixr0,iyr0,5,8,pixc,
     .                                       NAXIS1,NAXIS2)
                         pbar = r4_darkest
     .                        + r4_flashlvl
     .                          *find_postflash_wfc3uv(xxr,yyr,
     .                                                 c1_flashcur,         ! put back postflash
     .                                                 c1_shutrpos)
                         ssr = sr + pbar
                         call find_tabctecorr_wfc3uv(mmr,yyr,ssr,rDATuu,
     .                                               -1,                    ! no-iterate correction
     .                                               dm_cte,dy_cte)
                         endif
                     if (INSTu.eq.5) then                                   ! ACS/WFC
                         sr = pixc(int(xxr+0.5),int(yyr+0.5))               ! just get bkgd from pixel itself... 3x3?
                         sr = mbar_sky_NAXIS(ixr0,iyr0,5,8,pixc,
     .                                       NAXIS1,NAXIS2)
                         pbar = r4_darkest                                  ! put back in dark current
     .                        + r4_flashdur
     .                          *find_postflash_acswfc(xxr,yyr)             ! put back postflash
                         ssr = sr + pbar
                         call find_tabctecorr_acswfc(mmr,yyr,ssr,rDATuu,
     .                                               +1,                    ! no-iterate correction
     .                                               dm_cte,dy_cte)
                         endif
                     endif
                 xr = xxr
                 yr = yyr + dy_cte
                 mr = mmr + dm_cte
                 endif
             if (ASTYPE.eq.'xym') then  ! no correction of any kind...
                 xr = xinp_a(A)
                 yr = yinp_a(A)
                 mr = minp_a(A)
                 endif
             fr = 10**(-mr/2.5)                                             ! finally!  now we can add the star!
             call locpsfij_stdpsf(int(xr+0.5),int(yr+0.5),
     .                            psfloc,PSFFILE_USE)
             ixr0 = min(max(int(xr+0.5),1),NAXIS1)
             iyr0 = min(max(int(yr+0.5),1),NAXIS2)
             pixc0 = pixc(ixr0,iyr0)
             faddt = 0.
             faddn = 0.
             do i = max(0001,ixr0-12),min(NAXIS1,ixr0+12)
             do j = max(0001,iyr0-12),min(NAXIS2,iyr0+12)
                dx = SNGL(i-xr)
                dy = SNGL(j-yr)
                fadd = SNGL(fr*rpsf_phot(dx,dy,psfloc))
                fsig = sqrt(fadd)/sqrt(EXPT_EFF/EXPT_INST)
                fnoi = fsig*noise_sig()
                pixc(i,j) = pixc(i,j) + fadd + fnoi
                faddt = faddt + fadd
                faddn = faddn + fadd + fnoi
                pixa(i,j) = pixa(i,j) + fadd + fnoi
                pixd(i,j) = fadd
                enddo
                enddo
             if (A.le.10.or.A.eq.A/1000*1000) then
                 write( *,171) xr, yr, mr, fr,
     .                         xxr, yyr, mmr,
     .                          ur,  vr,  wr,
     .                         uur, vvr, wwr,
     .                         sr, ssr,
     .                         pixc0, pixc(ixr0,iyr0),
     .                         A, faddt, faddn
  371            format('#','  x-xraw', 1x,'  y-yraw',
     .                                  1x, ' m-mraw', 1x,'     fraw',
     .                   3x,'  X-xcte', 1x,'  Y-ycte',1x,' M-mcte',
     .                   3x,'   u-xgc', 1x,'   v-ygc',1x,'  w-mgc',
     .                   3x,'  U-xwcs', 1x,'  V-ywcs',1x,'  W-wcs',
     .                                  1x, ' s-sky',1x, ' S-sky',
     .                   2x,'  pixc0',  1x,'   pixc',
     .                   2x,'anumber',  2x,'     fadd',1x,' fadd/noi')
  271            format('#','........', 1x,'........',
     .                                  1x,'.......' ,1x,'.........',
     .                   3x,'........', 1x,'........',1x,'.......',
     .                   3x,'........', 1x,'........',1x,'.......',
     .                   3x,'........', 1x,'........',1x,'.......',
     .                                  1x, '......', 1x, '......'
     .                   2x,'.......',  1x, '.......',
     .                   2x,'.......',  2x,'.........',1x,'.........')
  171            format(1x,f8.3,1x,f8.3,
     .                          1x,f7.3,1x,f9.1,
     .                  3x,f8.3,1x,f8.3,1x,f7.3,
     .                  3x,f8.3,1x,f8.3,1x,f7.3,
     .                  3x,f8.3,1x,f8.3,1x,f7.3,
     .                          1x,f6.1,1x,f6.1,
     .                  2x,f7.1,1x,f7.1,
     .                  2x,'A',i6.6,2x,f9.1,1x,f9.1)
                 endif
             write(71,171) xr, yr, mr, fr,
     .                     xxr, yyr, mmr,
     .                      ur,  vr,  wr,
     .                     uur, vvr, wwr,
     .                     sr, ssr,
     .                     pixc0, pixc(ixr0,iyr0),
     .                     A, faddt, faddn
             enddo!A
         write(71,'(''#'')')
         write(71,271)
         write(71,371)
         write(71,271)
         close(71)
         endif
 
 
 
      if (VERBOSE.ge.2) then
         print*,'  '
         print*,'  '
         print*,'*************************************'
         print*,'*************************************'
         print*,'**   '
         print*,'**  GO THRU IMAGE AND FIND PEAKS... '
         print*,'**   '
         print*,'**     HMIN: ',HMIN
         print*,'**     FMIN: ',FMIN
         print*,'**    FMINu: ',FMINu
         print*,'**     PMAX: ',PMAX
         print*,'**     NIMu: ',NIMu
         print*,'**     NIMs: ',NIMs
         print*,'**   '
         print*,'** LOFLAG_I: ',LOFLAG_INST
         print*,'** HIFLAG_I: ',HIFLAG_INST
         print*,'** HIFLAG  : ',HIFLAG
         print*,'**   '
         print*,'**   NAXIS1: ',NAXIS1
         print*,'**   NAXIS2: ',NAXIS2
         print*,'**   '
         print*,'*************************************'
         print*,'*************************************'
         print*,'  '
         print*,'  '
         endif
 
 
      do hu = 1, 16
         hhist(hu) = 0
         enddo
 
      if (VERBOSE.ge.2) then
          print*,'                                         '
          print*,'SHOW_ALL: '
          print*,'                                         '
          print*,'---> output lots of diagnostic stuff...  '
          print*,'     such as pixo: original image        '
          print*,'             pixc: image to search       '
          print*,'             pixp: sat-peaked-up image   '
          print*,'             pixx: pixc except where     '
          print*,'                   max of saturated distn'
          print*,'                                         '
          call writfits_r4('pixo.fits',pixo,NAXIS1,NAXIS2)
          call writfits_r4('pixc.fits',pixc,NAXIS1,NAXIS2)
          call writfits_r4('pixp.fits',pixp,NAXIS1,NAXIS2)
          call writfits_r4('pixx.fits',pixx,NAXIS1,NAXIS2)
          if (INSTu.eq.0) then
             call writfits_r4('pixw.fits',pixw,NAXIS1,NAXIS2)
             call writfits_b1('pixq.fits',pixq,NAXIS1,NAXIS2)
             endif
          endif
 
      if (VERBOSE.ge.2) print*,'SHOW_USE: ',SHOW_USE
      if (SHOW_USE.eq.'+') then
          SHOW_USEu = PREFIX(1:9) // '_use.fits'
          call writfits_r4(SHOW_USEu,pixc,NAXIS1,NAXIS2)
          SHOW_USEu = PREFIX(1:9) // '_qqq.fits'
          call writfits_b1(SHOW_USEu,pixq,NAXIS1,NAXIS2)
          endif
 
      if (VERBOSE.ge.2) print*,'SHOW_FND: ',SHOW_FND
      if (SHOW_FND.eq.'+') then
         allocate(pixy(NAXIS1,NAXIS2))
         do i = 0001, NAXIS1
         do j = 0001, NAXIS2
            pixy(i,j) = 0
            enddo
            enddo
         endif
 
      if (VERBOSE.ge.2) print*,'SHOW_SUB: ',SHOW_SUB
      if (SHOW_SUB.ne.'-') then
        !print*,'ALLOCATE _SUB IMAGE...',NAXIS1,NAXIS2
         allocate(pixs(NAXIS1,NAXIS2))
         do i = 001, NAXIS1
         do j = 001, NAXIS2
            pixs(i,j) = pixo(i,j)
            enddo
            enddo
         endif
 
      if (VERBOSE.ge.1) then
         write( *,  *)
         write(*,'(13x,''NOW, GO THROUGH IMAGE AND FIND STARS'')')
         write( *,  *)
         write( *,378)
         write( *,278)
         write( *,378)
         endif
 
c--------------------------------------
c go through the image pixel by pixel to
c see if each one qualifies as a source worth
c "finding" and measuring
c
      Ns = 0
      Nx = 0 ! this will keep track of the total found
 
      mbrite = 0.
      jnext  = NAXIS2/50
 
      do K = 1, Ks
         iminu = int(min(BDRY_XR(1,K),BDRY_XR(2,K),
     .                   BDRY_XR(3,K),BDRY_XR(4,K)))
         imaxu = int(max(BDRY_XR(1,K),BDRY_XR(2,K),
     .                   BDRY_XR(3,K),BDRY_XR(4,K)))
         jminu = int(min(BDRY_YR(1,K),BDRY_YR(2,K),
     .                   BDRY_YR(3,K),BDRY_YR(4,K)))
         jmaxu = int(max(BDRY_YR(1,K),BDRY_YR(2,K),
     .                   BDRY_YR(3,K),BDRY_YR(4,K)))
         do i = iminu, imaxu
            do j = jminu, jmaxu
               if (pixc(i,j).gt.-700) then
                   iminu = i
                   goto 161
                   endif
               enddo
            enddo
         iminu = imaxu
  161    continue
         do i = imaxu, iminu, -1
            do j = jminu, jmaxu
               if (pixc(i,j).gt.-700) then
                   imaxu = i
                   goto 162
                   endif
               enddo
            enddo
         imaxu = iminu
  162    continue
         do j = jminu, jmaxu
            do i = iminu, imaxu
               if (pixc(i,j).gt.-700) then
                   jminu = j
                   goto 163
                   endif
               enddo
            enddo
         jminu = jmaxu
  163    continue
         do j = jmaxu, jminu, -1
            do i = iminu, imaxu
               if (pixc(i,j).gt.-700) then
                   jmaxu = j
                   goto 164
                   endif
               enddo
            enddo
         jmaxu = jminu
  164    continue
         do P = 1, 4
            if (BDRY_XR(P,K).lt.iminu) BDRY_XR(P,K) = iminu
            if (BDRY_XR(P,K).gt.imaxu) BDRY_XR(P,K) = imaxu
            if (BDRY_YR(P,K).lt.jminu) BDRY_YR(P,K) = jminu
            if (BDRY_YR(P,K).gt.jmaxu) BDRY_YR(P,K) = jmaxu
            enddo
         enddo
 
 
      do N = 1, _NSTMAX_
          x_n(N) = 0.00
          y_n(N) = 0.00
          m_n(N) = 0.00
         xx_n(N) = 0.00
         yy_n(N) = 0.00
         mm_n(N) = 0.00
          u_n(N) = 0.00
          v_n(N) = 0.00
          w_n(N) = 0.00
         uu_n(N) = 0.00
         vv_n(N) = 0.00
         ww_n(N) = 0.00
          k_n(N) = 0
          h_n(N) = 0
          r_n(N) = 0.00
          d_n(N) = 0.00
          i_n(N) = 0
          j_n(N) = 0
          p_n(N) = 0.00
         pp_n(N) = 0.00
          f_n(N) = 0.00
         ff_n(N) = 0.00
          q_n(N) = 0.00
          c_n(N) = 0.00
         cc_n(N) = 0.00
          s_n(N) = 0.00
         ss_n(N) = 0.00
          t_n(N) = 0.00
          z_n(N) = 0.00
          o_n(N) = 0.00
         oo_n(N) = 0.00
        sap_n(N) = 0.00
        do i = 1, 9
           map_n(i,N) = 0.00
           enddo
          n_n(N) = n
          o_n(N) = 0.00
        enddo!N
 
      B_ = 0
 
      do jjt = 0001+5, NAXIS2-5
      do iit = 0001+5, NAXIS1-5
 
         xr = 0.
         yr = 0.
         mr = 0.
         fr = 0.
         sr = 0.
         qr = 0.00
         ch = 0.00
         cr = 0.00
         mmeth = 0
         irmin = 0
         irmax = 0
         rsk1  = 0.00
         rsk2  = 0.00
         rske  = 0.00
 
         sap0 = 0.0
         do i = 1, 9
            mapN(i) = 0.00
            enddo
 
         if (Ns.ge._NSTMAX_) goto 444
 
         SATD = .false.
 
         ii = iit
         jj = jjt
 
         if (Bs.gt.0) then
             if (BSTYPE.eq.'   ') continue
             if (B_.ge.Bs) goto 444
             B_ = B_ + 1
             uur = xinp_b(B_)
             vvr = yinp_b(B_)
              ur = x2o_mat + AG_mat*(uur-x1o_mat) + BG_mat*(vvr-y1o_mat)
              vr = y2o_mat + CG_mat*(uur-x1o_mat) + DG_mat*(vvr-y1o_mat)
             call xcyc2xryr_stdgc(ur,vr,xxr,yyr,GDCFILE_USE)
             ii0 = int(xxr+0.5)
             jj0 = int(yyr+0.5)
             uur = x1o_mat + GA_mat*(ur-x2o_mat)
     .                     + GB_mat*(vr-y2o_mat)
             vvr = y1o_mat + GC_mat*(ur-x2o_mat)
     .                     + GD_mat*(vr-y2o_mat)
             ii = ii0
             jj = jj0
             do i = ii0-1, ii0+1
             do j = jj0-1, jj0+1
                if (pixc(i,j).gt.pixc(ii,jj)) then
                    ii = i
                    jj = j
                    endif
                enddo
                enddo
             Ns = B_
             Nx = B_
             endif
 
         hu  = 1
         kru = 0
         do K = 1, Ks
            if (inside_poly(ii*1.0d0,jj*1.0d0,
     .                      BDRY_XR(1,K),BDRY_YR(1,K),4))
     .                      kru = K
            enddo
         if (kru.eq.0) goto 444
         if (KSEL.ne.0.and.kru.ne.KSEL) goto 444
         if (ii.lt.IMINx) goto 444
         if (ii.gt.IMAXx) goto 444
         if (jj.lt.JMINx) goto 444
         if (jj.gt.JMAXx) goto 444
 
 
c------------------------
c 01) not a local max
c
         hu = 2
         do i = ii-1,ii+1
         do j = jj-1,jj+1
            if (pixc(i,j).gt.pixc(ii,jj)) goto 444
            enddo
            enddo
 
         if (pixc(i,j).eq.pixc(i-1,j  )) goto 444
         if (pixc(i,j).eq.pixc(i-1,j-1)) goto 444
         if (pixc(i,j).eq.pixc(i  ,j-1)) goto 444
 
 
 
c---------------------------------------
c 02) skip if too close to brighter pixel
c
         hu = 3
         hobs = fnd_hloc_NAXIS(ii,jj,pixc,NAXIS1,NAXIS2)
         if (HMIN.le.9.and.hobs.lt.abs(HMIN)) goto 444
         if (HMIN.gt.9) then
             do i = -HMIN, HMIN
             do j = -HMIN, HMIN
                if (i**2+j**2.le.(HMIN+0.5)**2) then
                    if (ii+i.lt.  0001) goto 444
                    if (jj+j.lt.  0001) goto 444
                    if (ii+i.gt.NAXIS1) goto 444
                    if (jj+j.gt.NAXIS2) goto 444
                    if (pixc(i+ii,j+jj).gt.pixc(i,j)) goto 444
                    endif
                 enddo
                 enddo
             endif
 
 
c-------------------------------------
c 03) skip if not enough flux in this peak
c
         hu = 4
 
         if (.true.) then
             FEST = 0
             do iii = ii, ii+1
             do jjj = jj, jj+1
                fff = pixc(iii-1,jjj-1)
     .              + pixc(iii  ,jjj-1)
     .              + pixc(iii-1,jjj  )
     .              + pixc(iii  ,jjj  )
                sss = (pixc(iii-2,jjj-1)
     .                +pixc(iii-2,jjj  )
     .                +pixc(iii-1,jjj-2)
     .                +pixc(iii-1,jjj+1)
     .                +pixc(iii  ,jjj-2)
     .                +pixc(iii  ,jjj+1)
     .                +pixc(iii+1,jjj-1)
     .                +pixc(iii+1,jjj  ))/8.0
                if (pixc(ii,jj).gt.HIFLAG.or.
     .              pixc(ii,jj).gt.HIFLAG_INST) sss = HMB
                fff = fff-sss*4
                if (fff.ge.FEST) FEST = fff
                enddo
                enddo
            FESTR = FEST
            endif
 
         if (.false.) then
            FEST = pixc(ii,jj) +
     .             max(pixc(ii+1,jj)+pixc(ii+1,jj+1)+pixc(ii,jj+1),
     .                 pixc(ii+1,jj)+pixc(ii+1,jj-1)+pixc(ii,jj-1),
     .                 pixc(ii-1,jj)+pixc(ii-1,jj+1)+pixc(ii,jj+1),
     .                 pixc(ii-1,jj)+pixc(ii-1,jj-1)+pixc(ii,jj-1))
            minsky = min(
     .          (pixc(ii+1,jj+1)+pixc(ii  ,jj+1)+pixc(ii-1,jj+1))/03,
     .          (pixc(ii+1,jj-1)+pixc(ii  ,jj-1)+pixc(ii-1,jj-1))/03,
     .          (pixc(ii+1,jj+1)+pixc(ii+1,jj  )+pixc(ii+1,jj-1))/03,
     .          (pixc(ii-1,jj+1)+pixc(ii-1,jj  )+pixc(ii-1,jj-1))/03,
     .          (pixc(ii-2,jj-1)+pixc(ii-2,jj  )+pixc(ii-2,jj+1)+
     .           pixc(ii+2,jj-1)+pixc(ii+2,jj  )+pixc(ii+2,jj+1)+
     .           pixc(ii-1,jj-2)+pixc(ii  ,jj-2)+pixc(ii+1,jj-2)+
     .           pixc(ii-1,jj+2)+pixc(ii  ,jj+2)+pixc(ii+1,jj+2))/12)
            minsky =  mbar_sky_NAXIS(ii,jj,5,8,pixc,NAXIS1,NAXIS2)
            FESTR = FEST
            if (pixc(ii,jj).gt.HIFLAG.or.
     .          pixc(ii,jj).gt.HIFLAG_INST) minsky = HMB
            FEST  = FEST - 4*minsky
            endif
 
         if (FEST.lt.FMINu) goto 444
 
 
c-----------------------------------------------
c 04) skip if this is below them mask prediction
c
         hu = 5
         if (SHOW_MSK.eq.'+') then
             if (pixc(ii,jj).lt.HIFLAG.and.
     .           FEST.lt.10*pixm(ii,jj)) goto 444
             endif
 
 
c----------------------------------------------------------
c 05) outside of the good bounds of the image
c
         hu = 6
         if (INSTu.eq.5.and.jj.ge.2046.and.jj.le.2050) goto 444
         if (INSTu.eq.8.and.jj.ge.2046.and.jj.le.2050) goto 444
 
c----------------------------------------------------------
c 06) loflag too close; within aperture
c
         hu = 7
         do i = ii-2,ii+2
         do j = jj-2,jj+2
            if (pixc(i,j).le.LOFLAG_INST) goto 444
            enddo
            enddo
 
 
c---------------------------------------
c 07) skip above the saturation threshold, but we don't
c     want to do saturated stars
c
         hu = 8
         if (pixq(ii,jj).eq.1.and.(.not.DOSATD)) goto 444
         if (pixc(ii,jj).gt.PMAX.and.PMAX.lt.HIFLAG)  goto 444
 
 
 
c----------------------------------------------------------
c 08) skip saturated pixels that are not the max of a contiguious saturated
c     distribution
c
         hu = 9
         if (pixp(ii,jj).gt.0) then
             do i = -5, 5
             do j = -5, 5
                if (i**2+j**2.le.5.5**2) then
                   if (ii+i.ge.0001.and.ii+i.le.NAXIS1.and.
     .                 jj+j.ge.0001.and.jj+j.le.NAXIS2) then
                       if (pixp(ii,jj).lt.pixx(ii,jj)) goto 444
                       endif
                   endif
                enddo
                enddo
             endif
 
 
c--------------------------------------------------------------
c 09) skip if saturated and too close to bigger saturated pixels
c
         hu = 10
         if (pixq(ii,jj).eq.1) then
             do i = ii-2,ii+2
             do j = jj-3,jj+3
                if ((i.ne.ii.or.j.ne.jj).and.
     .              pixc(i,j).ge.pixc(ii,jj)) goto 444
                enddo
                enddo
             endif
 
 
c---------------------------------------------------
c 10) throw out if not saturated, but near weirdness
c
         hu = 11
         NSAT = 0
         do i = -3,+3
         do j = -3,+3
            if (i**2+j**2.le.3.5**2.and.
     .          pixq(ii+i,jj+j).eq.1) NSAT = NSAT + 1
            enddo
            enddo
         if (pixq(ii,jj).eq.0.and.NSAT.gt.0) goto 444
 
 
c-------------------------------------------------------------
c 11) found a peak worth measuring!
c     get centroid positions, 3x3 aperture flux (quick-n-easy)
c
         hu = 12
         sr = min(HMB,minsky)
         if (pixc(ii,jj).gt.HIFLAG) sr = HMB
         fxout = (pixc(ii+1,jj)-pixc(ii-1,jj))/2/
     .           (pixc(ii  ,jj)-min(pixc(ii+1,jj),pixc(ii-1,jj)))
         fyout = (pixc(ii,jj+1)-pixc(ii,jj-1))/2/
     .           (pixc(ii,jj  )-min(pixc(ii,jj+1),pixc(ii,jj-1)))
         fout  = pixc(ii+1,jj+1)+pixc(ii  ,jj+1)+pixc(ii-1,jj+1)+
     .           pixc(ii+1,jj  )+pixc(ii  ,jj  )+pixc(ii-1,jj  )+
     .           pixc(ii+1,jj-1)+pixc(ii  ,jj-1)+pixc(ii-1,jj-1)-
     .           9*sr
 
         if (fout.lt.1) fout = FEST
         if (.not.(fxout.lt. 1.0)) fxout = 0.
         if (.not.(fxout.gt.-1.0)) fxout = 0.
         if (.not.(fyout.lt. 1.0)) fyout = 0.
         if (.not.(fyout.gt.-1.0)) fyout = 0.
         if (.not.( fout.gt.-1.0))  fout = 1.
 
 
         if (pixq(ii,jj).eq.1) then  ! saturated pixel!!!
             hu = 14
             SATD = .true.
             xr = ii
             yr = jj
             fr = pixo(ii,jj)/psfloc(51,51)
             do i = -3, 3
             do j = -3, 3
                if (i**2+j**2.le.3.5**2) then
                    if (fr*psfloc(51+i*4,51+j*4)*0.1.gt.
     .                  pixo(ii+i,jj+j)-sr) then          ! saturated CR!
                        goto 444
                        endif
                    endif
                enddo
                enddo
             fr = pixc(ii,jj)
             hu = 16
             sr = mbar_sky_NAXIS(ii,jj,12,16,pixc,NAXIS1,NAXIS2)
             cr = 0.
             if (INSTu.eq.9) then ! WFC3/IR
                 call fitsat_ir(xr,yr,sr,fr,qr,psfloc,pixc,
     .                           NAXIS1,NAXIS2,HIFLAG_INST)
                 qr = 0.0
                 endif
             if (INSTu.eq.5.or.INSTu.eq.8) then ! ACS/WFC or WFC3/UV
                 xr4 = SNGL(xr)
                 yr4 = SNGL(yr)
                 sr4 = SNGL(sr)
                 fr4 = SNGL(fr)
                 call fitsat_ccdXthenY(psfloc,pixo,NAXIS1,NAXIS2,sr4,
     .                                 xr4,yr4,fr4,ysigfit)
                 xr = xr4
                 yr = yr4
                 if (INSTu.eq.8) then
                     mr = -2.5*log10(fr4)
                     if (mr.lt.-24.5) mr = -24.5
                     if (mr.lt.-15.0) then
                         dm = 0.00
                         i    = int(-mr)
                         fff  = SNGL((-mr)-i)
                         if (yr4.gt.0000.and.yr4.lt.2048) then
                             dm = dm_uvis2(i) + fff*(dm_uvis2(i+1)
     .                                              -dm_uvis2(  i))
                             endif
                         if (yr4.gt.2048.and.yr4.lt.4096) then
                             dm = dm_uvis1(i) + fff*(dm_uvis1(i+1)
     .                                              -dm_uvis1(i ))
                             endif
                         fr  = fr *10**(-dm/2.5)
                         fr4 = fr4*10**(-dm/2.5)
c                        write(77,177) ii, jj, mr, -2.5*log10(fr4),
c    .                                             fr4, dm
c 177                    format(1x,i4,1x,i4,1x,f8.3,1x,f8.3,
c    .                                1x,f12.1,1x,f8.3)
                         endif
                     endif
                 endif
             mmeth = 9
             goto 137
             endif
 
         if (DOAPPHOT) then
             hu = 12
             if (RAP.eq.0) then  ! backdoor... easiest possible thing to do,
                fr = fout        ! measure the brightest 4/9 pixels...
                xr = ii + fxout
                yr = jj + fyout
                goto 137
                endif
             xr = ii + fxout
             yr = jj + fyout
             fr = apphot_NAXIS(ii,jj,RAP,SKI,SKO,pixc,ss,
     .                         NAXIS1,NAXIS2)
             sr = ss
             hu = 15
             goto 137
             endif
 
         xro = ii + fxout
         yro = jj + fyout
         fro = fout
         sro = HMB
 
         call locpsfij_stdpsf(ii,jj,psfloc,PSFFILE_USE)              ! get local PSF
 
         sr = mbar_skyopt_NAXIS(xro,yro,pixc,psfloc,
     .                          SKI, SKO,
     .                          NAXIS1,NAXIS2,
     .                          rsk1, rsk2, rske)   ! find PSF-corr sky
 
 
c-----------------------------------------------------
c find my best postion, then flux
c
         xr = xro
         yr = yro
         call find_xyzXX_NAXIS(xr,yr,fr,sr,qr,ch,pixc,psfloc,
     .                         NAXIS1,NAXIS2,1,PIXFIT) ! 1 means weight by S/N
 
         fr = z_xyoptXX_NAXIS(xr,yr,sr,pixc,psfloc,
     .                        NAXIS1,NAXIS2,1,PIXFIT)  ! 1 means to weight by S/N
 
 
         if (.not.SATD)  call cog_apphot_123456789(xr,yr,pixc,psfloc,
     .                                             NAXIS1,NAXIS2,
     .                                             sap0,mapN)
 
         if (.not.SATD.and.qr.gt.QMAX) goto 444
 
         hu = 13
 
         dx = SNGL(ii-xr)
         dy = SNGL(jj-yr)
         cr = SNGL((pixc(ii,jj)
     .            -sr
     .            -fr*rpsf_phot(dx,dy,psfloc))/fr)
         if (.not.(cr.lt. 0.999)) cr =  0.999
         if (.not.(cr.gt.-0.999)) cr = -0.999
         if (.not.SATD) then
            if (cr.gt.CMAX) goto 444
            if (cr.lt.CMIN) goto 444
            endif
 
         hu = 15
 
         if (fr.lt.1) then  ! if the "best" flux is found
            xr = xro        ! to be negative, then go with something
            yr = yro        ! cruder; we know it's a peak, so it *should*
            fr = fro        ! have a positve flux
            sr = sro
            mmeth = 0
            endif
 
 
c-----------------------------------------------
c
c this code is necessary because sometimes the
c saturation flags are not set for pixels that
c are actually saturated...
c
 
         if (pixc(ii,jj).gt.HIFLAG_INST) then
             NSATx = 0
             do i = ii-2, ii+2
             do j = jj-2, jj+2
                if (pixc(i,j).gt.HIFLAG_INST) NSATx = NSATx + 1
                enddo
                enddo
 
             if (NSATx.gt.2.or.
     .           pixc(ii,jj+1).gt.HIFLAG_INST.or.
     .           pixc(ii,jj-1).gt.HIFLAG_INST) then ! emergency protocol
                 if (.not.DOSATD) then
                     hu = 8
                     goto 444
                     endif
                 xtot = 0.
                 ytot = 0.
                 ptot = 0.
                 ftot = 0.
                 do i = ii-2, ii+2
                 do j = jj-2, jj+2
                    xtot = SNGL(xtot + (pixc(i,j)-sr)*i)
                    ytot = SNGL(ytot + (pixc(i,j)-sr)*j)
                    ptot = ptot + SNGL(pixc(i,j)-sr)
                    ftot = ftot + rpsf_phot((i-ii)*1.0,
     .                                      (j-jj)*1.0,psfloc)
                    enddo
                    enddo
                 fr = ptot/ftot
                 xr = xtot/ptot
                 yr = ytot/ptot
                 qr = 0 ! international sign of saturation
                 endif
             endif
 
  137    continue
         if (.not.(fr.gt.1.00)) fr = 1.0
         if (.not.(fr.lt.1e19)) fr = 1.0
         mr = -2.5*log10(fr)
         call xryr2mc_stdgc(xr,yr,dmc,GDCFILE_USE)
         Ns = Ns + 1
         Nx = Nx + 1
         if (B_.ne.0) then
             Ns = B_
             Nx = B_
             endif
         if (Ns.gt._NSTMAX_) goto 444
         if (Ns.gt._NSTMAX_) Ns = _NSTMAX_
         DOPRINT = .false.
         if (mr.lt.mbrite) then
             DOPRINT = .true.
             mbrite = SNGL(mr)
             endif
         if (jj.ge.jnext) then
             DOPRINT = .true.
             jnext = jnext + NAXIS2/50
             endif
         if (Ns.eq.Ns/1000*1000) DOPRINT = .true.
         if ((VERBOSE.ge.2.and.SATD).or.
     .       (VERBOSE.ge.1.and.DOPRINT)) then
              write( *,178) Ns,xr,yr,mr,sr,mmeth,irmin,irmax,
     .                      int(pixc(ii  ,jj  )),
     .                      int(pixc(ii+1,jj  )),
     .                      int(pixc(ii-1,jj  )),
     .                      int(pixc(ii  ,jj+1)),
     .                      int(pixc(ii  ,jj-1)),
     .                      int(pixc(ii+1,jj+1)),
     .                      int(pixc(ii-1,jj+1)),
     .                      int(pixc(ii+1,jj-1)),
     .                      int(pixc(ii-1,jj-1)),
     .                      int(sr),int(FESTR),int(FEST)
              endif
 
  178    format(18x,i7,1x,f9.3,1x,f9.3,1x,f7.3,1x,f6.1,'|',i1,i3,i3,
     .                   '|',i7,'|',4i6,'|',4i6,
     .                   '|',i7,1x,i7,1x,i7,1x,1l1)
  278    format(18x,' NSTARS',1x,      ! i7
     .          '    XCEN  ',1x,   ! f9.3
     .          '    YCEN  ',1x,   ! f9.3
     .          '  MAG ',1x,       ! f7.3
     .          ' SKY ' ,'|',     ! f6.1
     .          'M iS oS'  ,'|',   ! i1,1x,i2,1x,i2
     .          '   PCEN','|',     ! i7
     .          '   P02',          ! i6
     .          '   P03',
     .          '   P04',
     .          '   P05','|',
     .          '   P06',
     .          '   P07',
     .          '   P08',
     .          '   P09','|',
     .          '    mSKY',
     .          '    F2x2',
     .          ' F2x2-SK')
  378    format(18x,'-------',1x,'---------',1x,'---------',1x,
     .          '-------',1x,'------','|','- -- --','|',
     .          '-------','|',
     .          ' ----- ----- ----- -----','|',
     .          ' ----- ----- ----- -----','|',
     .          ' ------- ------- -------')
 
 
         dm_cte = 0.00
         dy_cte = 0.00
 
         ssr = sr ! start out with no CTE correction
         xxr = xr ! will be the CTE corrected values (if possible)
         yyr = yr
         mmr = mr
 
         if (INSTu.eq.5.and.GAIN_INST.eq.1.and.mr.lt.-13.75) then ! saturated ACS/WFC image taken with GAIN=1
             dm = SNGL(0.25*(mr+13.75)/(-15.75+13.75))
             if (mr.lt.-15.75) dm = 0.25
             mr  = mr  - dm
             mmr = mmr - dm
             endif
 
         if (INSTu.eq.8) then                                 ! wfc3uv CTE correction
            pbar = r4_darkest
     .           + r4_flashlvl
     .             *find_postflash_wfc3uv(xr,yr,c1_flashcur,   ! put back postflash
     .                                          c1_shutrpos)
            ssr = sr + pbar
            call find_tabctecorr_wfc3uv(mr,yr,ssr,rDATuu,+1,
     .                                  dm_cte,dy_cte)
            if (ISFLT) then
               xxr = xr             ! CTE correction
               yyr = yr - dy_cte    ! CTE correction
               mmr = mr - dm_cte    ! CTE correction
               endif
            endif
 
         if (INSTu.eq.5) then                                           ! acswfc CTE correction
            pbar = r4_darkest                                           ! put back in dark current
     .           + r4_flashdur
     .             *find_postflash_acswfc(xr,yr)                        ! put back postflash
            ssr = sr + pbar
            call find_tabctecorr_acswfc(mr,yr,ssr,rDATuu,+1,
     .                                  dm_cte,dy_cte)
            if (ISFLT) then
                xxr = xr             ! CTE correction
                yyr = yr - dy_cte    ! CTE correction
                mmr = mr - dm_cte    ! CTE correction
                endif
            endif
 
 
 
          mgc = mmr + dmc
         mmgc = mgc
 
c
c find the distortion-corrected positions in the STDGDC frame
c
         call xryr2xcyc_stdgc(xxr,yyr,xgc,ygc,GDCFILE_USE)
         dRA = (xgc-xgc0)*CD1_1_INST + (ygc-ygc0)*CD1_2_INST
         dDE = (xgc-xgc0)*CD2_1_INST + (ygc-ygc0)*CD2_2_INST
         RA = xy2r(dRA,dDE,CRVAL1_INST,CRVAL2_INST)
         DE = xy2d(dRA,dDE,CRVAL1_INST,CRVAL2_INST)
         kr = kru
 
         mzp = m1k
 
         ug = xgc
         vg = ygc
 
         if (WCSMODE(1:4).ne.'NONE'.and.WCSMODE(1:3).ne.'MAT') then
            dRA = rd2x(RA,DE,CRVAL1_DEST,CRVAL2_DEST)
            dDE = rd2y(RA,DE,CRVAL1_DEST,CRVAL2_DEST)
            ug = CRPIX1_DEST + RCD1_1_DEST*dRA + RCD1_2_DEST*dDE
            vg = CRPIX2_DEST + RCD2_1_DEST*dRA + RCD2_2_DEST*dDE
            endif
         if (WCSMODE.eq.'MAT') then
            ug = x1o_mat + GA_mat*(xgc-x2o_mat)
     .                   + GB_mat*(ygc-y2o_mat)
            vg = y1o_mat + GC_mat*(xgc-x2o_mat)
     .                   + GD_mat*(ygc-y2o_mat)
            mmgc = mgc - ZP_mat
            endif
 
 
          x_n(Ns) =   xr            ! raw ; no CTE correction, if even possible
          y_n(Ns) =   yr            ! raw ; no CTE correction, if even possible
          m_n(Ns) =   mr            ! raw ; no corrections
          z_n(Ns) =   fr            ! raw ; no corrections
 
         xx_n(Ns) =   xr            ! CTE correction (if possible)
         yy_n(Ns) =  yyr            ! CTE correction (if possible)
         mm_n(Ns) =  mmr            ! CTE correction (if possible)
 
          u_n(Ns) =  xgc            ! CTE corrected, if possible
          v_n(Ns) =  ygc
          w_n(Ns) =  mgc            !
 
         uu_n(Ns) =   ug            ! maybe orient with North up?!?
         vv_n(Ns) =   vg
         ww_n(Ns) = mmgc
 
          s_n(Ns) = SNGL(sr)
          k_n(Ns) = kr
          r_n(Ns) = ra
          d_n(Ns) = de
          h_n(Ns) = hobs
          i_n(Ns) = ii
          j_n(Ns) = jj
          p_n(Ns) = pixo(ii,jj)
         pp_n(Ns) = FEST
          f_n(Ns) = rpsf_phot(SNGL(ii-xr),SNGL(jj-yr),psfloc)
         ff_n(Ns) = rpsf_phot(0.,0.,psfloc)
          if (.not.(qr.lt.9.99)) qr = 9.99
          q_n(Ns) = qr
         ss_n(Ns) = SNGL(ssr)
         ee_n(Ns) = rske
          t_n(Ns) = rDATuu
          n_n(Ns) = nsat_contig(ii,jj,pixq,NAXIS1,NAXIS2)
          c_n(Ns) = ch
         cc_n(Ns) = cr
          o_n(Ns) = 0.0
         if (pixq(ii,jj).eq.0) then
             call find_oth(ii,jj,
     .                     xr,yr,fr,pixc,NAXIS1,NAXIS2,psfloc,o,oo)
               o_n(Ns) =  o
              oo_n(Ns) = oo
             endif
         sat_n(Ns) = NSAT
         sap_n(Ns) = sap0
         do i = 1, 9
            map_n(i,Ns) = mapN(i)
            enddo
 
         mru = SNGL(-mr)
         if (INSTu.eq.9) mru = mru - 2.5*log10(EXPTu)
 
         if (mru.le. 1.1) mru =  1.1
         if (mru.ge.19.0) mru = 19.9
         imru = int(mru)
         fmru = mru-imru
 
         e_n(Ns) = 0
         if (INSTu.eq.5) then
             e_n(Ns) = e_m_ACS(imru)
     .               + fmru*(e_m_ACS(imru+1)-e_m_ACS(imru))
             if (pixq(ii,jj).eq.1.and.imru.lt.15) e_n(Ns) = e_m_ACS(15)
             endif
         if (INSTu.eq.8) then
             e_n(Ns) = e_m_W3U(imru)
     .               + fmru*(e_m_W3U(imru+1)-e_m_W3U(imru))
             if (pixq(ii,jj).eq.1.and.imru.lt.15) e_n(Ns) = e_m_W3U(15)
             endif
         if (INSTu.eq.9) then
             e_n(Ns) = e_m_W3I(imru)
     .               + fmru*(e_m_W3I(imru+1)-e_m_W3I(imru))
             if (pixq(ii,jj).eq.1.and.imru.lt.15) e_n(Ns) = e_m_W3I(15)
             endif
 
         if (DOAPPHOT) then
             c_n(Ns) = SNGL((p_n(Ns)-sr)/fr)
             endif
 
         if (SHOW_SUB.ne.'-'.and.(.not.SATD)) then
            do i = max(0001,ii-13), min(NAXIS1,ii+13)
            do j = max(0001,jj-13), min(NAXIS2,jj+13)
               dx = SNGL(i-xr)
               dy = SNGL(j-yr)
               pixs(i,j) = SNGL(pixs(i,j)
     .                         -fr*rpsf_phot(dx,dy,psfloc))
               enddo
               enddo
            endif
 
         pixc(ii,jj) = pixc(ii,jj)+1
         pixn(ii,jj) = Ns
 444     continue
         hhist(hu) = hhist(hu) + 1
         if (SHOW_FND.eq.'+') pixy(ii,jj) = hu
c123     format(21x,
c    .          f9.3,1x,f9.3,1x,f8.4,1x,f9.1,1x,f8.2,5x,
c    .          f9.3,1x,f9.3,1x,f8.4,1x,f9.1,1x,f8.2,1x,i6,1x,f6.2)
         continue
         enddo
         enddo
      if (VERBOSE.ge.1) then
          write( *,378)
          write( *,278)
          write( *,378)
          endif
 
      if (Ns.ne.Nx) then
         print*,'                                       '
         print*,'hst2xym problem: too many stars found: '
         print*,'                                       '
         print*,'      _NSTMAX_ = ',_NSTMAX_
         print*,'         Nx = ',Nx
         print*,'         Ns = ',Ns
         print*,'                                       '
         print*,'    need to increase _NSTMAX_          '
         print*,'                                       '
         stop
         endif
 
      if (DOIMA) stop 'NOT READY TO DOIMA...'
 
      iii = 1
      do ii = 1, 190
         if (FILENAMu(ii:ii).eq.'/') iii = ii+1
         enddo
 
      if (SHOW_SUB.eq.'+'.or.SHOW_SUB.eq.'~') then
          if (SHOW_SUB.eq.'+') then
             IMSUBu = PREFIX(1:9) // '_sub.fits'
             print*,'OUTPUT pix_sub: ',IMSUBu
             call writfits_r4(IMSUBu,pixs,NAXIS1,NAXIS2)
             endif
          if (SHOW_SUB.eq.'~') then
             iii = 1
             do i = 1, 200
                if (FILENAMu(i:i).eq.'/') iii = i + 1
                enddo
             IMSUBu = FILENAMu(iii:200)
             if (IMSUBu(10:10).ne.'_') stop 'problem with filename'
             IMSUBu(9:9) = 's'
             if (INSTu.ne.5.and.INSTu.ne.8.and.INSTu.ne.9) then
                 print*,'                                          '
                 print*,' IF YOU WANT TO OUTPUT SUBTRACTED IMAGE   '
                 print*,' IN A SHELL, THEN FOR NOW, THE IMAGE MUST '
                 print*,' BE ONE OF:  ACSWFC, WFC3UV, or WFC3IR.   '
                 print*,'                                          '
                 print*,' YOU CAN OUTPUT IT NORMALLY w/ SHOW_SUB+  '
                 print*,'                                          '
                 stop
                 endif
             if (INSTu.eq.5)
     .           call cpyNrepl_acswfc(FILENAMu,IMSUBu,pixs,'SUB')
             if (INSTu.eq.8)
     .           call cpyNrepl_wfc3uv(FILENAMu,IMSUBu,pixs,'SUB')
             if (INSTu.eq.9)
     .           call cpyNrepl_wfc3ir(FILENAMu,IMSUBu,pixs,'SUB')
             endif
          deallocate(pixs)
          endif
 
      if (SHOW_ART.eq.'+'.or.SHOW_ART.eq.'~') then
          if (SHOW_ART.eq.'+') then
             IMSUBu = PREFIX(1:9) // '_art.fits'
             print*,'OUTPUT pix_sub: ',IMSUBu
             call writfits_r4(IMSUBu,pixa,NAXIS1,NAXIS2)
             IMSUBu = PREFIX(1:9) // '_add.fits'
             print*,'OUTPUT pix_sub: ',IMSUBu
             call writfits_r4(IMSUBu,pixd,NAXIS1,NAXIS2)
             endif
          if (SHOW_ART.eq.'~') then
             iii = 1
             do i = 1, 200
                if (FILENAMu(i:i).eq.'/') iii = i + 1
                enddo
             IMSUBu = FILENAMu(iii:200)
             if (IMSUBu(10:10).ne.'_') stop 'problem with filename'
             if (INSTu.ne.5.and.INSTu.ne.8.and.INSTu.ne.9) then
                 print*,'                                          '
                 print*,' IF YOU WANT TO OUTPUT SUBTRACTED IMAGE   '
                 print*,' IN A SHELL, THEN FOR NOW, THE IMAGE MUST '
                 print*,' BE ONE OF:  ACSWFC, WFC3UV, or WFC3IR.   '
                 print*,'                                          '
                 print*,' YOU CAN OUTPUT IT NORMALLY w/ SHOW_SUB+  '
                 print*,'                                          '
                 stop
                 endif
             IMSUBu(9:9) = 'a'
             if (INSTu.eq.5)
     .           call cpyNrepl_acswfc(FILENAMu,IMSUBu,pixa,'ART')
             if (INSTu.eq.8)
     .           call cpyNrepl_wfc3uv(FILENAMu,IMSUBu,pixa,'ART')
             if (INSTu.eq.9)
     .           call cpyNrepl_wfc3ir(FILENAMu,IMSUBu,pixa,'ART')
             IMSUBu(9:9) = 'd'
             if (INSTu.eq.5)
     .           call cpyNrepl_acswfc(FILENAMu,IMSUBu,pixd,'INS')
             if (INSTu.eq.8)
     .           call cpyNrepl_wfc3uv(FILENAMu,IMSUBu,pixd,'INS')
             if (INSTu.eq.9)
     .           call cpyNrepl_wfc3ir(FILENAMu,IMSUBu,pixd,'INS')
             endif
          deallocate(pixa)
          deallocate(pixd)
          endif
 
      if (SHOW_FND.eq.'+') then
          SHOW_FNDu = PREFIX(1:9) // '_fnd.fits'
          call writfits_b1(SHOW_FNDu,pixy,NAXIS1,NAXIS2)
          deallocate(pixy)
          endif
 
c----------------------------------------
c
c report on why some pixels weren't identified
c as stars
c
      write(HH(HHs+01),'(''#                                       '')')
      write(HH(HHs+02),'(''#======================================='')')
      write(HH(HHs+03),'(''# FINDING STATISTICS                    '')')
      write(HH(HHs+04),'(''# '')')
      write(HH(HHs+05),'(''#  WHY    NPIX      %PIX   EXPLANATION  '')')
      write(HH(HHs+06),'(''#  --- --------  -------   -------------'')')
      HHs = HHs + 6
      if (VERBOSE.ge.1) then
          write( *,  *)
          write(*,'(13x,''-----------------------------------------'')')
          write(*,'(13x,''FINDING STATISTICS'')')
          write(*,'(13x,''-----------------------------------------'')')
          write(*,'(13x,'' Y     NPIX     %PIX    EXPLANATION'')')
          endif
      do hu = 1, 16
         if (VERBOSE.ge.1)
     .   write( *,276) hu,hhist(hu),hhist(hu)/40.96/4096,hhwhy(hu)
         write(HH(HHs+1),277) hu,hhist(hu),hhist(hu)*100./NAXIS1/NAXIS2,
     .                                     hhwhy(hu)
 277     format('#  ',i2,1x,i8,1x,f8.3,'%',3x,a20)
 276     format(13x,i2,1x,i8,1x,f8.3,'%',3x,a20)
         if (VERBOSE.ge.1.and.hu.eq.14)
     .   write(*,'(13x,''-----------------------------------------'')')
         HHs = HHs + 1
         enddo
      HHi = HHs+1
      HHs = HHs + 1
 
      write(HH(HHs+01),'(''#                                       '')')
      write(HH(HHs+02),'(''#======================================='')')
      write(HH(HHs+03),'(''# LUMINOSITY FUNCTION EXTRACTED         '')')
      write(HH(HHs+04),'(''#'')')
      write(HH(HHs+05),'(''#    MAG   LFe    CUMe      LFe/s CUMe/s'')')
      write(HH(HHs+06),'(''#-------- -----  ------   ------- ------'')')
      HHs = HHs + 6
      do b = 1, 30
         hist1(b) = 0
         hist2(b) = 0
         enddo
      do N = 1, Ns
         im1 = INT(-m_n(n) + 0.5)
         im2 = INT(-m_n(n) + 0.5)
         if (INSTu.eq.9) im2 = int(-m_n(n) + 2.5*log10(EXPTu) + 0.5)
         if (INSTu.ne.9) im1 = int(-m_n(n) - 2.5*log10(EXPTu) + 0.5)
         if (im1.lt.01) im1 = 01
         if (im1.gt.30) im1 = 30
         if (im2.lt.01) im2 = 01
         if (im2.gt.30) im2 = 30
         hist1(im1) = hist1(im1) + 1
         hist2(im2) = hist2(im2) + 1
         enddo
      hshow = .false.
      cum1 = 0
      cum2 = 0
      do b = 30, 1, -1
         cum1 = cum1 + hist1(b)
         cum2 = cum2 + hist2(b)
         if (hist1(b).ne.0.or.hist2(b).ne.0.or.b.le.15) hshow = .true.
         if (hshow) then
             HHs = HHs + 1
             write(HH(HHs),1149) -b, hist2(b), cum2, hist1(b), cum1
 1149        format('# LF ',i3,1x,i6,1x,i6,5x,i6,1x,i6)
             endif
         enddo
      write(HH(HHs+01),'(''#-------- -----  ------   ------- ------'')')
      write(HH(HHs+02),'(''# '')')
      HHs = HHs+2
      do HHt = HHi, HHs
         write(*,'(a80)') HH(HHt)(1:80)
         enddo
 
 
 
c---------------------------------------------------------------
c
c define the boundaries...
c
      if (VERBOSE.ge.2) then
         print*,'                '
         print*,'FIND BOUNDARY...'
         print*,'                '
         write(*,'(''# '')')
         write(*,442)
         write(*,441)
         write(*,'(''# '')')
         write(*,239)
         write(*,239) ' CRVAL_INST: ',CRVAL1_INST,CRVAL2_INST
         write(*,239) ' CD1_1_INST: ', CD1_1_INST, CD1_2_INST
         write(*,239) ' CD2_1_INST: ', CD2_1_INST, CD2_2_INST
         write(*,239) 'RCD1_1_INST: ',RCD1_1_INST,RCD1_2_INST
         write(*,239) 'RCD2_1_INST: ',RCD2_1_INST,RCD2_2_INST
         write(*,239) '            '
         write(*,239) 'CRVAL1_DEST: ',CRVAL1_DEST,CRVAL2_DEST
         write(*,239) 'CRPIX1_DEST: ',CRPIX1_DEST,CRPIX2_DEST
         write(*,239) ' CD1_1_DEST: ', CD1_1_DEST, CD1_2_DEST
         write(*,239) ' CD2_1_DEST: ', CD2_1_DEST, CD2_2_DEST
         write(*,239) 'RCD1_1_DEST: ',RCD1_1_DEST,RCD1_2_DEST
         write(*,239) 'RCD2_1_DEST: ',RCD2_1_DEST,RCD2_2_DEST
         write(*,239) '            '
  239    format(a13,3x,f15.8,3x,f15.8)
         endif
 
      do K = 1, Ks
         do P = 1, 4
            xgc = 0.
            ygc = 0.
            RA = 0.
            DE = 0.
            xr = BDRY_XR(P,K)
            yr = BDRY_YR(P,K)
            call xryr2xcyc_stdgc(xr,yr,xgc,ygc,GDCFILE_USE)
            dRA = (xgc-xgc0)*CD1_1_INST + (ygc-ygc0)*CD1_2_INST
            dDE = (xgc-xgc0)*CD2_1_INST + (ygc-ygc0)*CD2_2_INST
            RA = xy2r(dRA,dDE,CRVAL1_INST,CRVAL2_INST)
            DE = xy2d(dRA,dDE,CRVAL1_INST,CRVAL2_INST)
            dRA = rd2x(RA,DE,CRVAL1_DEST,CRVAL2_DEST)
            dDE = rd2y(RA,DE,CRVAL1_DEST,CRVAL2_DEST)
            ug = xgc
            vg = ygc
            uu = ug
            vv = vg
            if (WCSMODE.ne.'NONE') then
               dRA = rd2x(RA,DE,CRVAL1_DEST,CRVAL2_DEST)
               dDE = rd2y(RA,DE,CRVAL1_DEST,CRVAL2_DEST)
               uu = CRPIX1_DEST + RCD1_1_DEST*dRA + RCD1_2_DEST*dDE
               vv = CRPIX2_DEST + RCD2_1_DEST*dRA + RCD2_2_DEST*dDE
               endif
            BDRY_XC(P,K) = xgc
            BDRY_YC(P,K) = ygc
            BDRY_UG(P,K) = ug
            BDRY_VG(P,K) = vg
            BDRY_RA(P,K) = RA
            BDRY_DE(P,K) = DE
            BDRY_UU(P,K) = uu
            BDRY_VV(P,K) = vv
            if (VERBOSE.ge.2) then
                write(*,443) K,P,BDRY_XR(P,K),BDRY_YR(P,K),
     .                           BDRY_XC(P,K),BDRY_YC(P,K),
     .                           BDRY_UG(P,K),BDRY_VG(P,K),
     .                           BDRY_RA(P,K),BDRY_DE(P,K),
     .                           BDRY_UU(P,K),BDRY_VV(P,K)
                if (P.eq.4) write(*,'(''# '')')
                endif
            enddo
c        HHs = HHs + 1
         enddo
 
 
      GA =  GD/(AG*DG-BG*CG)
      GB = -GB/(AG*DG-BG*CG)
      GC = -GC/(AG*DG-BG*CG)
      GD =  GA/(AG*DG-BG*CG)
 
 
c---------------------------------------------------------------
c
c output the final boundary info...
c
      write(HH(HHS+1),'(''#                                     '')')
      write(HH(HHS+2),'(''#====================================='')')
      write(HH(HHs+3),'(''# BOUNDARY INFO   INST='',i1,'' Ks='',i1)')
     .                      INSTu,Ks
      write(HH(HHS+4),'(''#                                     '')')
      write(HH(HHs+5),441)
      write(HH(HHs+6),442)
      write(HH(HHs+7),441)
      HHs = HHs + 7
      do K = 1, Ks
         write(HH(HHs+1),443)'xy',K,(BDRY_XR(P,K),BDRY_YR(P,K),P=1,4)
         write(HH(HHs+2),443)'uv',K,(BDRY_XC(P,K),BDRY_YC(P,K),P=1,4)
         write(HH(HHs+3),443)'rd',K,(BDRY_RA(P,K),BDRY_DE(P,K),P=1,4)
         write(HH(HHs+4),443)'UV',K,(BDRY_UG(P,K),BDRY_VG(P,K),P=1,4)
         HHs = HHs + 4
         write(HH(HHs+1),441)
         HHs = HHs + 1
         enddo
      write(HH(HHS+1),'(''#'')')
      HHs = HHs + 1
 
  443 format('# BDRY_',a2,'_K',i1.1,':',
     .                     5x,f13.7,1x,f13.7,
     .                     5x,f13.7,1x,f13.7,
     .                     5x,f13.7,1x,f13.7,
     .                     5x,f13.7,1x,f13.7)
  442 format('#     SYS CHP',
     .       5x,'    P1a           P1b      ',
     .       5x,'    P2a           P2b      ',
     .       5x,'    P3a           P3b      ',
     .       5x,'    P4a           P4b      ')
  441 format('# -----------',
     .       5x,'------------- -------------',
     .       5x,'------------- -------------',
     .       5x,'------------- -------------',
     .       5x,'------------- -------------')
 
 
 
c-----------------------------------------------------------------
c
c This will output a ref frame... still needed?  I'm not so
c sure --- Jay 2021.06.24
c
      if (SHOW_REF.eq.'+') then
         IMREFu = PREFIX(1:9) // '_ref.fits'
         if (As.ne.0) IMREFu = PREFIX(1:9) // '_rfa.fits'
         print*,'OUTPUT pix_ref: ',IMREFu
         UMIN =  99999
         UMAX = -99999
         VMIN =  99999
         VMAX = -99999
         do K = 1, Ks
         do P = 1, 4
            UMIN = min(UMIN,int(BDRY_UU(P,K)))
            UMAX = max(UMAX,int(BDRY_UU(P,K)))
            VMIN = min(VMIN,int(BDRY_VV(P,K)))
            VMAX = max(VMAX,int(BDRY_VV(P,K)))
            enddo
            enddo
         if (VERBOSE.ge.2) then
            print*,'   UMIN/MAX: ',UMIN,UMAX
            print*,'   VMIN/MAX: ',VMIN,VMAX
            endif
         NAXISU = 1 + UMAX-UMIN
         NAXISV = 1 + VMAX-VMIN
         allocate(pixr(NAXISU,NAXISV))
 
         if (VERBOSE.ge.2) then
            write(*,'(''RCD_INST: '',4f20.10)') RCD1_1_INST,RCD1_2_INST,
     .                                          RCD2_1_INST,RCD2_2_INST
            write(*,'('' CD_INST: '',4f20.10)')  CD1_1_INST, CD1_2_INST,
     .                                           CD2_1_INST, CD2_2_INST
            endif
         write(66,*) '  REF CRPIX1_INST: ',CRPIX1_INST
         write(66,*) '  REF CRPIX2_INST: ',CRPIX2_INST
         write(66,*) '  REF CRVAL1_INST: ',CRVAL1_INST
         write(66,*) '  REF CRVAL2_INST: ',CRVAL2_INST
         print*,'    Ks: ',Ks
         print*,'NAXISU: ',NAXISU
         print*,'NAXISV: ',NAXISV
         do i = 0001, NAXISU
         do j = 0001, NAXISV
            pixr(i,j) = 0.
            ug = UMIN + (i-1)
            vg = VMIN + (j-1)
            Ku = 0
            do k = 1, Ks
                if (inside_poly(ug,vg,BDRY_UU(1,K),BDRY_VV(1,K),4))
     .              Ku = K
                enddo
            if (KSEL.ne.0.and.Ku.ne.KSEL) Ku = 0
            if (Ku.ne.0) then
               dRA = CD1_1_DEST*(ug-CRPIX1_DEST)
     .             + CD1_2_DEST*(vg-CRPIX2_DEST)
               dDE = CD2_1_DEST*(ug-CRPIX1_DEST)
     .             + CD2_2_DEST*(vg-CRPIX2_DEST)
               RA  = xy2r(dRA,dDE,CRVAL1_DEST,CRVAL2_DEST)
               DE  = xy2d(dRA,dDE,CRVAL1_DEST,CRVAL2_DEST)
               dRA = rd2x(RA,DE,CRVAL1_INST,CRVAL2_INST)
               dDE = rd2y(RA,DE,CRVAL1_INST,CRVAL2_INST)
               xgc = xgc0 + RCD1_1_INST*dRA + RCD1_2_INST*dDE
               ygc = ygc0 + RCD2_1_INST*dRA + RCD2_2_INST*dDE
               call xcyc2xryr_stdgc(xgc,ygc,xr,yr,GDCFILE_USE)
               ii = int(xr+0.5)
               jj = int(yr+0.5)
               if (ii.ge.0001.and.ii.le.NAXIS1.and.
     .             jj.ge.0001.and.jj.le.NAXIS2) then
                   pixr(i,j) = pixc(ii,jj)
                   endif
               if (j.eq.NAXISV/2.and.i.eq.i/250*250)
     .             write(*,113) i,j,ug,vg,pixr(i,j),
     .                              xgc,ygc,xr,yr,dRA,dDE
  113          format(2i5,1x,2f10.1,5x,f8.1,
     .                    5x,2f10.2,5x,2f10.2,5x,2f10.5)
               endif
            enddo
            enddo
         call writfits_r4_WCSLTV(IMREFu,pixr,NAXISU,NAXISV,
     .                           CRPIX1_DEST-UMIN+1-(u2o-u1o),
     .                           CRPIX2_DEST-VMIN+1-(v2o-v1o),
     .                           CRVAL1_DEST,CRVAL2_DEST,
     .                           CD1_1_DEST, CD1_2_DEST,
     .                           CD2_1_DEST, CD2_2_DEST,
     .                           -UMIN+1.0d0-(u2o-u1o),
     .                           -VMIN+1.0d0-(v2o-v1o),
     .                           1.0d0,0.0d0,0.0d0,1.0d0)
         deallocate(pixr)
         endif
 
 
      deallocate(pixo)
      deallocate(pixp)
      deallocate(pixx)
      deallocate(pixc)
      deallocate(pixq)
      deallocate(pixn)
 
      if (SHOW_MSK(1:1).ne.'-') deallocate(pixm)
 
      if (INSTu.eq.0) deallocate(pixw)
 
 
      FILTu = FILT_INST
      EXPTu = EXPT_INST
c     RDATu = RDAT_INST
      PROPu = PROP_INST
 
c
c     write(*,'(''# '')')
c     write(*,'(''# EXIT sub_hst2xym_info --- '')')
c     write(*,'(''# '')')
c     write(*,'(''#  CRPIX1_DEST: '',2f14.7)') CRPIX1_DEST, CRPIX2_DEST
c     write(*,'(''#  CRVAL1_DEST: '',2f14.7)') CRVAL1_DEST, CRVAL2_DEST
c     write(*,'(''#   CD1_1_DEST: '',2f14.7)')  CD1_1_DEST,  CD1_2_DEST
c     write(*,'(''#   CD2_1_DEST: '',2f14.7)')  CD2_1_DEST,  CD2_2_DEST
c     write(*,'(''# '')')
c
 
      return
 
 
c 211 format('# Region file format: DS9 version 4.1')
c 212 format('global color=green dashlist=8 3 width=1',
c    .       ' font="helvetica 10 normal" select=1 highlite=1',
c    .       ' dash=0 fixed=0 edit=1 move=1 delete=1 include=1',
c    .       ' source=1')
c 214 format('circle(',f11.7,',',f11.7,',0.05")')                     ! UNSAT rd
c 215 format('circle(',f11.7,',',f11.7,',0.05") # width=4 color=red') !   SAT rd
c 216 format('circle(',f9.2,',',f9.2,',',f5.2,')')                     ! UNSAT xy,XY,uv
c 217 format('circle(',f9.2,',',f9.2,',',f5.2,') # width=4 color=red') !   SAT xy,XY,uv
 
      end
 
 
 
 
 
 
 
 
 
 
 
 
 
 
c-------------------------------------------------
c
c
c
      subroutine fitsat_ir(xx,yy,ss,zz,qq,
     .                     psfloc,pixc,NAXIS1,NAXIS2,
     .                     HIFLAG)
      implicit none
 
      real*8  xx, yy
      real*8  ss, zz
      real    qq
      integer HIFLAG
      integer NAXIS1
      integer NAXIS2
      real    psfloc(101,101)
      real    pixc(NAXIS1,NAXIS2)
 
      integer rsat
      integer Ns
 
      integer U, Us
      real    pu(9999)
      integer iu(9999)
      integer ju(9999)
      real    fu(9999),  fuu(9999)
      real   dxu(9999), dxuu(9999)
      real   dyu(9999), dyuu(9999)
 
      integer ii,jj
      integer i, j
      real    rpsf_phot
      real*8  ptot, ftot, etot
 
      integer NCOUNT
      data    NCOUNT/0/
 
      real*8 xmin
      real*8 ymin
      real*8 zmin
      real*8 emin
 
      integer idx, idy
      real xc, yc
 
      ii = int(xx+0.5)
      jj = int(yy+0.5)
      qq = 0.999
      zz = pixc(ii,jj)
 
      rsat = 3
    1 continue
      Ns = 0
      Us = 0
      do i = -rsat, rsat
      do j = -rsat, rsat
         if (i**2+j**2.le.(rsat+0.5)**2) then
             if (ii+i.lt.000001+1) return
             if (jj+j.lt.000001+1) return
             if (ii+i.gt.NAXIS1-1) return
             if (jj+j.gt.NAXIS2-1) return
             Ns = Ns + 1
             if (pixc(ii+i  ,jj+j  ).lt.HIFLAG.and.
     .           pixc(ii+i-1,jj+j  ).lt.HIFLAG.and.
     .           pixc(ii+i+1,jj+j  ).lt.HIFLAG.and.
     .           pixc(ii+i  ,jj+j-1).lt.HIFLAG.and.
     .           pixc(ii+i  ,jj+j+1).lt.HIFLAG.and.
     .           pixc(ii+i-1,jj+j+1).lt.HIFLAG.and.
     .           pixc(ii+i+1,jj+j+1).lt.HIFLAG.and.
     .           pixc(ii+i-1,jj+j-1).lt.HIFLAG.and.
     .           pixc(ii+i+1,jj+j-1).lt.HIFLAG) then
                 Us = Us + 1
                 pu(Us) = SNGL(pixc(ii+i,jj+j)-ss)
                 iu(Us) = ii+i
                 ju(Us) = jj+j
                 endif
             endif
         enddo
         enddo
 
      if (Us.lt.Ns*0.50) then
          rsat = rsat + 1
          if (rsat.lt.10) goto 1
          endif
 
      if (rsat.ge.10.and.Us.lt.Ns*0.075) return
 
      xmin = ii
      ymin = jj
      emin = 9e9
      zmin = 0.0
      do idx = -20, 20
      do idy = -20, 20
         xc = ii + idx*0.05
         yc = jj + idy*0.05
         do U = 1, Us
            dxu(U) = iu(U)-xc
            dyu(U) = ju(U)-yc
            fu(U) = rpsf_phot(dxu(U),dyu(U),psfloc)
            enddo
         ptot = 0.
         ftot = 0.
         do U = 1, Us
            ptot = ptot + pu(U)-ss
            ftot = ftot + fu(U)
            enddo
         zz = ptot/ftot
         etot = 0
         do U = 1, Us
            etot = etot + abs(pu(U)-zz*fu(U))
            enddo
         if (etot.lt.emin) then
            emin = etot
            xmin = xc
            ymin = yc
            zmin = zz
            do U = 1, Us
                fuu(U) =  fu(U)
               dxuu(U) = dxu(U)
               dyuu(U) = dyu(U)
               enddo
            endif
         enddo
         enddo
 
         if (ftot.le.0) then
             zz = 0.
             qq = 0.
             return
             endif
 
 
      if (.false.) then
         NCOUNT = NCOUNT+1
         do U = 1, Us
            write(81,181) NCOUNT, U, iu(U), ju(U),
     .                    dxuu(U), dyuu(U), fuu(U),
     .                    pu(U), zz
  181       format(1x,i7.7,1x,i5.5,1x,i4,1x,i4,
     .                         3x,f6.2,1x,f6.2,1x,f8.6,
     .                         3x,f8.1,1x,f15.1)
            enddo
         endif
 
      xx = xmin
      yy = ymin
      zz = zmin
      qq = SNGL(emin/ptot)
 
      return
      end
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/find_ctetabcorr_acswfc_v3.f"
c****                                         
c*********************************************
                                              
 
c
c v2.0
c
c ma_0   ma_1   ma_2   ma_3   ma_4   ma_5   ma_6   ma_7   ma_8     ma_9
c
c 0.065  0.060  0.055  0.053  0.056  0.055  0.049  0.043  0.032  0.019
c 0.093  0.088  0.084  0.081  0.080  0.078  0.072  0.056  0.045  0.032
c 0.155  0.135  0.130  0.125  0.121  0.119  0.112  0.101  0.090  0.076
c 0.240  0.210  0.191  0.185  0.180  0.170  0.157  0.135  0.110  0.094
c 0.370  0.315  0.285  0.255  0.245  0.230  0.205  0.175  0.150  0.124
c 0.650  0.470  0.410  0.350  0.315  0.285  0.260  0.225  0.190  0.165
c 1.010  0.695  0.575  0.465  0.410  0.340  0.295  0.245  0.210  0.180
c 1.240  0.915  0.745  0.575  0.460  0.395  0.330  0.270  0.225  0.195
c 1.640  1.115  0.945  0.695  0.510  0.445  0.365  0.285  0.245  0.210
c
c ya_0   ya_1   ya_2   ya_3   ya_4   ya_5   ya_6   ya_7   ya_8     ya_9
c
c 0.053  0.052  0.051  0.050  0.049  0.056  0.055  0.054  0.052  0.050
c 0.105  0.100  0.095  0.090  0.085  0.085  0.080  0.080  0.080  0.075
c 0.165  0.160  0.150  0.140  0.135  0.125  0.120  0.120  0.115  0.105
c 0.220  0.210  0.205  0.195  0.180  0.165  0.158  0.152  0.142  0.127
c 0.330  0.310  0.285  0.260  0.235  0.200  0.180  0.175  0.165  0.145
c 0.470  0.432  0.390  0.340  0.285  0.220  0.208  0.191  0.175  0.155
c 0.600  0.550  0.470  0.395  0.320  0.260  0.230  0.215  0.200  0.175
c 0.730  0.670  0.570  0.460  0.360  0.290  0.265  0.235  0.220  0.195
c 0.840  0.775  0.655  0.530  0.400  0.330  0.295  0.260  0.240  0.215
c
 
 
 
 
c--------------------------------------------------------------
c
c this routine will take in four quantities:
c
c 1)    mr: observed instrumental magnitude
c 2)    yr: observed y position on the detector
c 3)   ssr: the total sky value (observe + postflash + dark current)
c 4)  rdat: date of observation (2020 --> 20.00)
c 5) SENSE: sense of operation
c           +1 = correction (requires iteration)
c           -1 = loss
c
c it will output two quantities
c
c 1) dm_ctetab: the predicted mag offset        (positive)
c 2) dy_ctetab: the predicted astrometric shift (towards gap)
c
c--------------------------------------------------------------
 
      subroutine find_tabctecorr_acswfc(mr,yr,ssr,rdat,SENSE,
     .                                  dm_ctetab,dy_ctetab)
      implicit none
 
      real*8  mr, yr, ssr
      real*8  rdat
      integer SENSE
      real*8  dm_ctetab ! this is the expected mag shift ; it needs to be subtracted
      real*8  dy_ctetab ! this is the expected pos shift ; it needs to be subtracted
 
      real   mru
      real   dmu
      real   dyu
 
      real   ft, fy, fff
 
      integer im, imm
      real    fm
      integer is
      real    fs
      real    sy
      real    rim
 
      integer NIT
 
 
      real dm_m(27)
      real dy_m(27)
 
      real sky_s(10)
      data sky_s /
     .   0.0,  5.0, 10.0, 20.0, 30.0, 40.0, 50.0, 75.0,100.0,150.0/
 
      real mag_m(9)
      data mag_m /
     .   -5.5, -6.5, -7.5, -8.5, -9.5, -10.5, -11.5, -12.5, -13.5 /
 
 
c-----------------------------------------------------------------
      real dm_sm(10,9)
      data dm_sm /
     .  1.675,1.145,0.965,0.710,0.520,0.450,0.365,0.275,0.195,0.150, !  -5.5  [01]
     .  1.350,0.990,0.760,0.585,0.470,0.405,0.335,0.225,0.175,0.140, !  -6.5  [02]
     .  1.060,0.740,0.590,0.480,0.425,0.355,0.300,0.200,0.155,0.125, !  -7.5  [03]
     .  0.670,0.500,0.430,0.370,0.335,0.300,0.260,0.185,0.155,0.120, !  -8.5  [04]
     .  0.385,0.330,0.300,0.270,0.255,0.240,0.205,0.145,0.135,0.115, !  -9.5  [05]
     .  0.250,0.220,0.201,0.195,0.190,0.175,0.155,0.105,0.100,0.085, ! -10.5  [06]
     .  0.165,0.145,0.140,0.135,0.131,0.119,0.110,0.080,0.075,0.058, ! -11.5  [07]
     .  0.098,0.093,0.089,0.087,0.085,0.078,0.072,0.040,0.035,0.030, ! -12.5  [08]
     .  0.070,0.065,0.063,0.061,0.058,0.055,0.050,0.030,0.025,0.020/ ! -13.5  [09]
 
c
c        1     2     3     4     5     6     7     8     9    10
c
c-----------------------------------------------------------------
 
 
c-----------------------------------------------------------------
      real dy_sm(10,9)
      data dy_sm /
     .  0.840,0.775,0.655,0.530,0.400,0.330,0.295,0.210,0.185,0.150, !  -5.5  [01]
     .  0.740,0.690,0.570,0.460,0.360,0.290,0.265,0.210,0.185,0.150, !  -6.5  [02]
     .  0.640,0.610,0.490,0.405,0.320,0.260,0.230,0.210,0.185,0.150, !  -7.5  [03]
     .  0.540,0.470,0.400,0.345,0.275,0.230,0.215,0.205,0.185,0.150, !  -8.5  [04]
     .  0.360,0.325,0.285,0.255,0.225,0.195,0.190,0.190,0.180,0.150, !  -9.5  [05]
     .  0.225,0.210,0.190,0.170,0.160,0.155,0.150,0.145,0.140,0.125, ! -10.5  [06]
     .  0.155,0.150,0.140,0.125,0.120,0.119,0.118,0.117,0.116,0.115, ! -11.5  [07]
     .  0.100,0.095,0.090,0.087,0.084,0.084,0.083,0.083,0.082,0.082, ! -12.5  [08]
     .  0.062,0.062,0.061,0.061,0.060,0.060,0.059,0.059,0.058,0.058/ ! -13.5  [09]
c
c         1     2     3     4     5     6     7     8     9    10
c
c         0     5    10    20    30    40    50    75   100   125
c-----------------------------------------------------------------
 
      common / acsctetab_ / sky_s, mag_m, dm_sm, dy_sm
 
 
      if (SENSE.ne.1.and.SENSE.ne.-1) then
          stop 'find_ctetabcorr_wfc3uv SENSE must be +1 or -1'
          endif
 
 
 
c--------------------------------------
c
c linear date scaling
c
      ft = SNGL((rdat     -2002.25d0)/
     .          (2020.30d0-2002.25d0))
      if (ft.lt.0.0) ft = 0.00
      if (ft.gt.2.0) stop 'ft.gt.2.0'
 
 
c--------------------------------------
c
c linear row scaling and y-shift sense
c
      fy = 0.00
      sy = 0.00
      if (yr.le.2048.00) then
          fy = SNGL(yr/2000.00)
          sy = 1.0
          endif
      if (yr.ge.2048.00) then
          fy = SNGL((4096-yr)/2000.00)
          sy = -1.0
          endif
 
 
      fff = fy*ft
 
 
c---------------------------------------------
c
c first do the interpolation by sky ; create
c 1-D arrays at this sky for all mags so I can
c iterate on mag to get to the true mag
c
      is = 1
      if (ssr.gt.sky_s(2)) is = 2
      if (ssr.gt.sky_s(3)) is = 3
      if (ssr.gt.sky_s(4)) is = 4
      if (ssr.gt.sky_s(5)) is = 5
      if (ssr.gt.sky_s(6)) is = 6
      if (ssr.gt.sky_s(7)) is = 7
      if (ssr.gt.sky_s(8)) is = 8
      if (ssr.gt.sky_s(9)) is = 9
 
      fs = SNGL((   ssr     -sky_s(is))/
     .          (sky_s(is+1)-sky_s(is)))
 
      if (.not.(fs.ge.0)) fs = 0.00
      if (.not.(fs.le.1)) fs = 1.00
 
 
      do im = 1, 9
         dm_m(im) = fff*(dm_sm(is,im)+fs*(dm_sm(is+1,im)-dm_sm(is,im)))
         dy_m(im) = fff*(dy_sm(is,im)+fs*(dy_sm(is+1,im)-dy_sm(is,im)))
         enddo
 
 
 
c------------------------------------------------
c
c iterate to find the true flux, and once we have
c that true flux, we can determine the associated
c astromeric shift
c
      NIT = 0
      mru = SNGL(mr)
    1 continue
      NIT = NIT + 1
      im = 1
      do imm = 2, 8
         if (mru.lt.mag_m(imm)) im = imm
         enddo
      rim = im + (mru        -mag_m(im))/
     .           (mag_m(im+1)-mag_m(im))
      if (im.gt.8) im = 8
      if (im.lt.1) im = 1
      fm = rim-im
      if (.not.(fm.gt.0)) fm = 0.00
      if (.not.(fm.lt.1)) fm = 1.00
 
      dmu = dm_m(im) + fm*(dm_m(im+1)-dm_m(im))
 
 
c     write(*,117) NIT, mr, mru, dmu, mr-dmu, im, fm
 
c 117 format(1x,i1,1x,f8.4,1x,f8.4,1x,f8.4,1x,f8.4,
c    .       5x,i3,1x,f8.4)
 
 
      mru = SNGL(mr - dmu)
 
      if (SENSE.eq.+1.and.NIT.le.5) goto 1
 
      dyu = dy_m(im) + fm*(dy_m(im+1)-dy_m(im))
 
      dm_ctetab = dmu       ! this is the mag shift (always positive)
      dy_ctetab = dyu*sy    ! this is the astrometric shift (towards gap)
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/find_ctetabcorr_wfc3uv.f"
c****                                         
c*********************************************
                                              
 
 
c--------------------------------------------------------------
c
c this routine will take in four quantities:
c
c 1)    mr: observed instrumental magnitude
c 2)    yr: observed y position on the detector
c 3)   ssr: the total sky value (observe + postflash + dark current)
c 4)  rdat: date of observation (2020 --> 20.00)
c 5) SENSE: correction or losses?
c           +1 = correction
c           -1 = loss (no iteration reqd)
c
c
c it will output two quantities
c
c 1) dm_ctetab: the predicted mag offset        (positive)
c 2) dy_ctetab: the predicted astrometric shift (towards gap)
c
c--------------------------------------------------------------
 
      subroutine find_tabctecorr_wfc3uv(mr,yr,ssr,rdat,SENSE,
     .                                  dm_ctetab,dy_ctetab)
      implicit none
 
      real*8  mr, yr, ssr
      real*8  rdat
      integer SENSE
      real*8  dm_ctetab ! this is the expected mag shift ; it needs to be subtracted
      real*8  dy_ctetab ! this is the expected pos shift ; it needs to be subtracted
 
      real   mru
      real   dmu
      real   dyu
 
      real   ft, fy, fff
 
      integer im
      real    fm
      integer is
      real    fs
      real    sy
      real    rim
 
      integer NIT
 
      real sky_s(6)
      data sky_s /  4.0,  10.0,  15.0,  20.0,  25.0,  29.0 /
 
      real dm_m(27)
      real dy_m(27)
 
      real dm_sm_0(6,27)                                      !            This is the smoothed one from the ISR
      data dm_sm_0/2.000, 1.660, 1.560, 1.068, 0.841, 0.513,  ! -00.5   1
     .             2.000, 1.660, 1.560, 1.068, 0.841, 0.513,  ! -01.0   2
     .             2.000, 1.660, 1.560, 1.068, 0.841, 0.513,  ! -01.5   3
     .             2.000, 1.660, 1.560, 1.068, 0.841, 0.513,  ! -02.0   4
     .             2.000, 1.660, 1.560, 1.068, 0.841, 0.513,  ! -02.5   5
     .             2.000, 1.660, 1.560, 1.068, 0.841, 0.513,  ! -03.0   6
     .             2.000, 1.660, 1.560, 1.068, 0.841, 0.513,  ! -03.5   7
     .             1.710, 1.310, 1.110, 0.889, 0.709, 0.490,  ! -04.0   8
     .             1.360, 0.960, 0.860, 0.710, 0.577, 0.461,  ! -04.5   9
     .             1.260, 0.860, 0.760, 0.633, 0.540, 0.435,  ! -05.0  10
     .             1.160, 0.760, 0.660, 0.556, 0.489, 0.410,  ! -05.5  11
     .             1.120, 0.701, 0.600, 0.512, 0.465, 0.390,  ! -06.0  12
     .             1.048, 0.642, 0.540, 0.468, 0.432, 0.370,  ! -06.5  13
     .             0.882, 0.548, 0.464, 0.424, 0.352, 0.304,  ! -07.0  14
     .             0.698, 0.460, 0.398, 0.344, 0.312, 0.284,  ! -07.5  15
     .             0.532, 0.380, 0.324, 0.302, 0.262, 0.236,  ! -08.0  16
     .             0.426, 0.316, 0.292, 0.256, 0.234, 0.220,  ! -08.5  17
     .             0.304, 0.256, 0.242, 0.218, 0.204, 0.190,  ! -09.0  18
     .             0.246, 0.216, 0.202, 0.180, 0.170, 0.162,  ! -09.5  19
     .             0.172, 0.166, 0.164, 0.154, 0.142, 0.132,  ! -10.0  20
     .             0.144, 0.134, 0.134, 0.126, 0.116, 0.114,  ! -10.5  21
     .             0.120, 0.114, 0.110, 0.110, 0.098, 0.096,  ! -11.0  22
     .             0.092, 0.092, 0.088, 0.082, 0.076, 0.074,  ! -11.5  23
     .             0.082, 0.084, 0.086, 0.078, 0.070, 0.068,  ! -12.0  24
     .             0.072, 0.068, 0.064, 0.062, 0.058, 0.048,  ! -12.5  25
     .             0.063, 0.060, 0.057, 0.054, 0.050, 0.046,  ! -13.0  26
     .             0.054, 0.052, 0.050, 0.048, 0.046, 0.044/  ! -13.5  27
 
 
      real dm_sm(6,27)                                        !            This is the improved one at the end of the IS
      data dm_sm / 2.250, 1.790, 1.660, 1.128, 0.931, 0.513,  ! -00.5   1
     .             2.250, 1.790, 1.660, 1.128, 0.931, 0.513,  ! -01.0   2
     .             2.250, 1.790, 1.660, 1.128, 0.931, 0.513,  ! -01.5   3
     .             2.250, 1.790, 1.660, 1.128, 0.931, 0.513,  ! -02.0   4
     .             2.250, 1.790, 1.660, 1.128, 0.931, 0.513,  ! -02.5   5
     .             2.250, 1.790, 1.660, 1.128, 0.931, 0.513,  ! -03.0   6
     .             2.250, 1.790, 1.660, 1.128, 0.931, 0.513,  ! -03.5   7
     .             1.760, 1.440, 1.210, 0.949, 0.799, 0.490,  ! -04.0   8
     .             1.610, 1.090, 0.960, 0.770, 0.700, 0.461,  ! -04.5   9
     .             1.510, 0.990, 0.860, 0.693, 0.666, 0.435,  ! -05.0  10
     .             1.410, 0.890, 0.760, 0.650, 0.633, 0.410,  ! -05.5  11
     .             1.373, 0.830, 0.675, 0.600, 0.530, 0.390,  ! -06.0  12
     .             1.200, 0.740, 0.610, 0.508, 0.500, 0.350,  ! -06.5  13
     .             1.057, 0.634, 0.515, 0.453, 0.364, 0.295,  ! -07.0  14
     .             0.950, 0.529, 0.441, 0.366, 0.321, 0.272,  ! -07.5  15
     .             0.671, 0.435, 0.356, 0.321, 0.270, 0.224,  ! -08.0  16
     .             0.462, 0.362, 0.311, 0.267, 0.239, 0.210,  ! -08.5  17
     .             0.327, 0.297, 0.259, 0.228, 0.210, 0.181,  ! -09.0  18
     .             0.253, 0.255, 0.219, 0.191, 0.176, 0.157,  ! -09.5  19
     .             0.177, 0.187, 0.178, 0.164, 0.151, 0.134,  ! -10.0  20
     .             0.147, 0.148, 0.145, 0.135, 0.124, 0.116,  ! -10.5  21
     .             0.121, 0.121, 0.120, 0.118, 0.102, 0.096,  ! -11.0  22
     .             0.085, 0.097, 0.096, 0.088, 0.076, 0.074,  ! -11.5  23
     .             0.066, 0.089, 0.092, 0.084, 0.073, 0.066,  ! -12.0  24
     .             0.058, 0.074, 0.068, 0.066, 0.061, 0.046,  ! -12.5  25
     .             0.051, 0.067, 0.057, 0.056, 0.048, 0.043,  ! -13.0  26
     .             0.044, 0.061, 0.050, 0.049, 0.042, 0.040/  ! -13.5  27
 
 
 
      real dy_sm_0(6,27)                                     !            This is the smoothed one from the ISR
      data dy_sm_0/0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -0.5
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -1.0
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -1.5
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -2.0
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -2.5
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -3.0
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -3.5
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -4.0
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -4.5
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -5.0
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -5.5
     .             0.829, 0.513, 0.413, 0.352, 0.305, 0.271, !  -6.0
     .             0.769, 0.457, 0.372, 0.322, 0.285, 0.252, !  -6.5
     .             0.663, 0.403, 0.332, 0.297, 0.259, 0.235, !  -7.0
     .             0.550, 0.354, 0.295, 0.277, 0.238, 0.218, !  -7.5
     .             0.451, 0.307, 0.259, 0.238, 0.216, 0.198, !  -8.0
     .             0.364, 0.262, 0.226, 0.211, 0.194, 0.179, !  -8.5
     .             0.297, 0.224, 0.196, 0.184, 0.172, 0.160, !  -9.0
     .             0.236, 0.186, 0.167, 0.159, 0.149, 0.140, !  -9.5
     .             0.168, 0.143, 0.135, 0.133, 0.126, 0.119, !  -10.0
     .             0.123, 0.117, 0.114, 0.111, 0.105, 0.100, !  -10.5
     .             0.102, 0.096, 0.094, 0.090, 0.086, 0.081, !  -11.0
     .             0.073, 0.071, 0.069, 0.067, 0.065, 0.062, !  -11.5
     .             0.058, 0.056, 0.054, 0.052, 0.050, 0.048, !  -12.0
     .             0.046, 0.043, 0.041, 0.039, 0.037, 0.035, !  -12.5
     .             0.028, 0.036, 0.034, 0.032, 0.031, 0.018, !  -13.0
     .             0.035, 0.033, 0.031, 0.029, 0.027, 0.025/ !  -13.5
 
 
      real dy_sm(6,27)                                       !            This is the improved one at the end of the ISR
      data dy_sm / 0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -0.5    1
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -1.0    2
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -1.5    3
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -2.0    4
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -2.5    5
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -3.0    6
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -3.5    7
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -4.0    8
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -4.5    9
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -5.0   10
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -5.5   11
     .             0.960, 0.630, 0.470, 0.390, 0.357, 0.295, !  -6.0   12
     .             0.870, 0.570, 0.420, 0.357, 0.323, 0.275, !  -6.5   13
     .             0.740, 0.511, 0.371, 0.330, 0.291, 0.257, !  -7.0   14
     .             0.611, 0.446, 0.328, 0.305, 0.263, 0.238, !  -7.5   15
     .             0.504, 0.384, 0.286, 0.263, 0.238, 0.214, !  -8.0   16
     .             0.409, 0.326, 0.247, 0.232, 0.213, 0.192, !  -8.5   17
     .             0.329, 0.278, 0.213, 0.201, 0.189, 0.172, !  -9.0   18
     .             0.261, 0.225, 0.181, 0.173, 0.162, 0.150, !  -9.5   19
     .             0.188, 0.172, 0.145, 0.143, 0.136, 0.127, ! -10.0   20
     .             0.138, 0.138, 0.120, 0.117, 0.112, 0.106, ! -10.5   21
     .             0.113, 0.111, 0.097, 0.093, 0.090, 0.084, ! -11.0   22
     .             0.082, 0.080, 0.071, 0.070, 0.069, 0.065, ! -11.5   23
     .             0.062, 0.062, 0.056, 0.055, 0.053, 0.051, ! -12.0   24
     .             0.047, 0.046, 0.043, 0.042, 0.039, 0.038, ! -12.5   25
     .             0.038, 0.036, 0.034, 0.032, 0.030, 0.028, ! -13.0   26
     .             0.035, 0.033, 0.031, 0.029, 0.027, 0.025/ ! -13.5   27
 
 
      if (SENSE.ne.1.and.SENSE.ne.-1) then
          stop 'find_ctetabcorr_wfc3uv SENSE must be +1 or -1'
          endif
 
 
 
      ft = SNGL((rdat     -2009.35d0)/   ! linear date scaling
     .          (2021.98d0-2009.35d0))
      if (ft.lt.0.0) ft = 0.00
      if (ft.gt.2.0) stop 'ft.gt.2.0'
 
      fy = 0.00                 ! linear row scaling
      sy = 0.00
      if (yr.le.2048.00) then
          fy = SNGL(yr/2000.00)
          sy = 1.0
          endif
      if (yr.ge.2048.00) then
          fy = SNGL((4096-yr)/2000.00)
          sy = -1.0
          endif
 
      fff = fy*ft
 
      is = 1
      if (ssr.gt.sky_s(2)) is = 2
      if (ssr.gt.sky_s(3)) is = 3
      if (ssr.gt.sky_s(4)) is = 4
      if (ssr.gt.sky_s(5)) is = 5
 
      fs = SNGL((   ssr     -sky_s(is))/
     .          (sky_s(is+1)-sky_s(is)))
 
      if (.not.(fs.ge.0)) fs = 0.00
      if (.not.(fs.le.1)) fs = 1.00
 
      do im = 1, 27
         dm_m(im) = fff*(dm_sm(is,im)+fs*(dm_sm(is+1,im)-dm_sm(is,im)))
         dy_m(im) = fff*(dy_sm(is,im)+fs*(dy_sm(is+1,im)-dy_sm(is,im)))
         enddo
 
      NIT = 0
      mru = SNGL(mr)
    1 continue
      NIT = NIT + 1
      rim = -mru*2
       im = int(rim)
      if (im.gt.26) im = 26
      if (im.lt.01) im = 01
      fm = rim-im
      if (.not.(fm.gt.0)) fm = 0.00
      if (.not.(fm.lt.1)) fm = 1.00
 
      dmu = dm_m(im) + fm*(dm_m(im+1)-dm_m(im))
 
c     write(*,117) NIT, mr, mru, dmu, mr-dmu, im, fm
 
c 117 format(1x,i1,1x,f8.4,1x,f8.4,1x,f8.4,1x,f8.4,
c    .       5x,i3,1x,f8.4)
 
      mru = SNGL(mr - dmu)
 
      if (SENSE.eq.1.and.NIT.le.5) goto 1
 
      dyu = dy_m(im) + fm*(dy_m(im+1)-dy_m(im))
 
      dm_ctetab = dmu       ! this is the mag shift (always positive)
      dy_ctetab = dyu*sy    ! this is the astrometric shift (towards gap)
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/test_ctetabcorr.f"
c****                                         
c*********************************************
                                              
 
c
c this will do some basic varification
c that the tabcorr is working as
c expected
c
 
      subroutine test_ctetabcorr
      implicit none
 
      real*8   mr_
      real*8   yr_
      real*8  ssr_
      real*8 rdat_
      real*8 dm_ctetab_
      real*8 dy_ctetab_
 
      integer IMR, IYR, ISK
 
 
      if (.false.) then ! one off
           mr_ =   -10.00
           yr_ =  2000.00
          ssr_ =    20.00
         rdat_ =  2020.98
 
         print*,'              '
         print*,'         mr_: ',  mr_
         print*,'         yr_: ',  yr_
         print*,'        ssr_: ', ssr_
         print*,'       rdat_: ',rdat_
         print*,'              '
 
         call find_tabctecorr_acswfc(mr_,yr_,ssr_,rdat_,+1,
     .                               dm_ctetab_,
     .                               dy_ctetab_)
 
         print*,'              '
         print*,'  dm_ctetab_: ',dm_ctetab_
         print*,'  dy_ctetab_: ',dy_ctetab_
         print*,'              '
         stop
         endif
 
      yr_ =  2000.00
 
      open(13,file='test_ctetabcor.out',status='unknown')
 
      do ISK =    0,  155, 1
      do IYR = 2020, 2020
      do IMR = -140, -50
         mr_   = IMR*0.1
         ssr_  = ISK
         rdat_ = IYR
         call find_tabctecorr_acswfc(mr_,yr_,ssr_,rdat_,+1,
     .                               dm_ctetab_,
     .                               dy_ctetab_)
c        write( *,113) IMR, IYR, ISK,
c    .                 mr_, ssr_, rdat_,
c    .                 dm_ctetab_,
c    .                 dy_ctetab_
         write(13,113) IMR, IYR, ISK,
     .                 mr_, ssr_, rdat_,
     .                 dm_ctetab_,
     .                 dy_ctetab_
  113    format(1x,i4,1x,i4,1x,i4,
     .          5x,f8.3,1x,f8.3,1x,f9.4,
     .          5x,f8.5,1x,f8.5)
         enddo
         enddo
         enddo
 
      close(10)
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/fill_charout.f"
c****                                         
c*********************************************
                                              
 
 
 
c-------------------------------------------------------------
c
c fill out the array of possible output values (into a string)
c
c
      subroutine fill_charout(CHAROUT_F,
     .                         u, v, w,
     .                         x, y, m, k,
     .                        xx,yy,mm, h,
     .                         r, d, rr, dd,
     .                         i, j, p, pp,
     .                               f_, ff,
     .                            q, c, s, ss, t,
     .                         uu, vv, ww,
     .                         z,  cc,
     .                         o,  oo,
     .                       sap, map, n, e, ee, Ni)
      implicit none
 
      character*20 CHAROUT_F(_FIELDs_)
      real*8   u,  v,  w
      real*8   x,  y,  m
      integer  k
      real*8  xx, yy, mm
      integer  h
      real*8   r,  d
      real*8  rr, dd
      integer  i,  j
      real     p,  pp, f_, ff
      real     q,  c,  s, ss
      real*8   t
      real*8  uu, vv, ww
      real     z, cc, o, oo, sap, map(9)
      integer n
      real    e, ee
      integer Ni
 
      character*11 ra2sexig
      character*12 de2sexig
 
      integer F, iiii
 
c     write(37,*) u,v,mm,x,y,m,k,xx,yy,h,r,d,
c    .              ra2sexig(r), de2sexig(d),
c    .              i, j, p, q, c, uu, vv, k, s, n
 
 
      write(CHAROUT_F(01),'(f14.4)') u
      write(CHAROUT_F(02),'(f14.4)') v
      write(CHAROUT_F(03),'(f08.3)') mm
      write(CHAROUT_F(04),'(f11.4)') x
      write(CHAROUT_F(05),'(f11.4)') y
      write(CHAROUT_F(06),'(f08.3)') m
      write(CHAROUT_F(07),'(i02.1)') k
      write(CHAROUT_F(08),'(f11.4)') xx
      write(CHAROUT_F(09),'(f11.4)') yy
      write(CHAROUT_F(10),'(i02.1)') h
      write(CHAROUT_F(11),'(f08.2)') h*1.0
      write(CHAROUT_F(12),'(f16.8)') r
      write(CHAROUT_F(13),'(f16.8)') d
c     write(CHAROUT_F(14),'(11a  )') ra2sexig(r)
c     write(CHAROUT_F(15),'(12a  )') de2sexig(d)
      write(CHAROUT_F(14),'(f16.8)') rr
      write(CHAROUT_F(15),'(f16.8)') dd
      write(CHAROUT_F(16),'(i6   )') i
      write(CHAROUT_F(17),'(i6   )') j
      write(CHAROUT_F(18),'(f12.2)') p
      write(CHAROUT_F(19),'(f12.3)') q
      write(CHAROUT_F(20),'(f12.3)') c
      write(CHAROUT_F(21),'(f14.4)') uu
      write(CHAROUT_F(22),'(f14.4)') vv
      write(CHAROUT_F(23),'(i1.1)') k
      write(CHAROUT_F(24),'(''K'',i1.1)') k
      write(CHAROUT_F(25),'(f10.2)') s
      write(CHAROUT_F(26),'(f10.2)') ss
      write(CHAROUT_F(27),'(i6)')  n
      write(CHAROUT_F(28),'(f10.5)') t
      write(CHAROUT_F(29),'(f7.4)')  cc
      write(CHAROUT_F(30),'(f6.4)')  max( o,0.0)
      write(CHAROUT_F(31),'(f6.4)')  max(oo,0.0)
      write(CHAROUT_F(32),'(f8.4)') map(01)
      write(CHAROUT_F(33),'(f8.4)') map(02)
      write(CHAROUT_F(34),'(f8.4)') map(03)
      write(CHAROUT_F(35),'(f8.4)') map(04)
      write(CHAROUT_F(36),'(f8.4)') map(05)
      write(CHAROUT_F(37),'(f8.4)') map(06)
      write(CHAROUT_F(38),'(f8.4)') map(07)
      write(CHAROUT_F(39),'(f8.4)') map(08)
      write(CHAROUT_F(40),'(f8.4)') map(09)
      write(CHAROUT_F(41),'(f8.2)') sap
      write(CHAROUT_F(42),'(f10.1)') z
      write(CHAROUT_F(43),'(''N'',i7.7)') Ni
      write(CHAROUT_F(44),'(f08.3)')  w
      write(CHAROUT_F(45),'(f08.3)') ww
      write(CHAROUT_F(46),'(f05.3)')  e
      write(CHAROUT_F(47),'(f08.5)')  f_
      write(CHAROUT_F(48),'(f08.5)') ff
      write(CHAROUT_F(49),'(f10.2)') pp
      write(CHAROUT_F(50),'(f10.2)') ee
      do F = 1, _FIELDs_
c        write(37,137) F, CHAROUT_F(F)
c 137    format(1x,i2.2,1x,a20)
         do iiii = 01, 20
            if (CHAROUT_F(F)(iiii:iiii).eq.'*')
     .          CHAROUT_F(F)(iiii:iiii) = '0'
            enddo
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/find_rdate.f"
c****                                         
c*********************************************
                                              
 
      subroutine find_rdate(FILENAME,rDAT,TIMESTR,DATESTR)
      implicit none
 
      character*200 FILENAME
      real         rDAT
      character*20 TIMESTR
      character*20 DATESTR
 
      character*20 DATESTRIN
 
c     integer iRAH, iRAM, iRAS, iFRA
      integer iMIN, iSEC
      integer iDAY, iMON, iYIR, iHRS
 
      integer DOY(12)
      data DOY / 000, 031, 059, 090, 120, 151,
     .           181, 212, 243, 273, 304, 334/
 
      character*20 STREAM
 
      iMON = 1
      iDAY = 1
      iYIR = 0
 
      iHRS = 0
      iMIN = 0
      iSEC = 0
 
      TIMESTR = 'TIMELESS'
      DATESTR = 'DATELESS'
 
      call query_hdr(FILENAME,'TIME-OBS ',stream)
      TIMESTR   = stream(02:09)
      call query_hdr(FILENAME,'DATE-OBS ',stream)
      DATESTRIN = stream(02:20)
 
c     print*,'DATESTRIN: ',DATESTRIN
      if (DATESTRIN(1:1).eq.'''') DATESTRIN = DATESTRIN(2:20)
c     print*,'DATESTRIN: ',DATESTRIN
      if (DATESTRIN(3:3).eq.'/') DATESTR(1:8) = DATESTRIN(1:8)
      if (DATESTRIN(5:5).eq.'-') then
          DATESTR(1:2) = DATESTRIN(9:10)
          DATESTR(3:3) = '/'
          DATESTR(4:5) = DATESTRIN(6:7)
          DATESTR(6:6) = '/'
          DATESTR(7:8) = DATESTRIN(3:4)
          endif
 
c     print*,'DATESTR  : ',DATESTR
      if (DATESTR.ne.'DATELESS') then
          read(DATESTR(1:2),*) iDAY
          read(DATESTR(4:5),*) iMON
          read(DATESTR(7:8),*) iYIR
          endif
 
c     print*,'TIMESTR  : ',TIMESTR
      if (TIMESTR.ne.'TIMELESS'.and.
     .    TIMESTR(3:3).eq.':'.and.
     .    TIMESTR(6:6).eq.':') then
          read(TIMESTR(1:2),*) iHRS
          read(TIMESTR(4:5),*) iMIN
          read(TIMESTR(7:8),*) iSEC
          endif
 
      rDAT = iYIR + (DOY(iMON)+iDAY)/365.0
      rDAT = rDAT + (iHRS + iMIN/60. + iSEC/60./60.)/8766.
 
      if (rDAT.gt.050) rDAT = rDAT - 100.0
 
c     print*,' '
c     print*,'FIND rDAT...'
c     print*,'  1) rDAT: ',rDAT
c     print*,'  2) iDMY: ',iDAY,iMON,iYIR
c     print*,'  3) iHMS: ',iHRS,iMIN,iSEC
c     print*,' '
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/lnc.f"
c****                                         
c*********************************************
                                              
 
      integer function LNC(STRING,CMAX)
      implicit none
 
      character(*) STRING
      integer CMAX
 
      LNC = CMAX
    1 continue
      if (STRING(LNC:LNC).ne.' ') return
      if (LNC.gt.1) then
         LNC = LNC - 1
         goto 1
         endif
      return
 
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/output_lists.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------------------
c
c This subroutine outputs the lists of measured parameters to
c a file.  The file starts with the header information, then
c constructs the columns to output and outputs them.
c
      subroutine output_lists(NLISTs,NITEMSO_NL,OUTLIST_NL,
     .                        PREFIX,
     .                        HH, HHs,
     .                        Ns,  u_n,  v_n,  w_n,
     .                             x_n,  y_n,  m_n,  k_n,
     .                            xx_n, yy_n, mm_n,
     .                            uu_n, vv_n, ww_n,
     .                             h_n,
     .                             r_n,  d_n, rr_n, dd_n,
     .                             i_n,  j_n,
     .                             p_n, pp_n,
     .                             f_n, ff_n,
     .                             q_n,  c_n,  s_n, ss_n, t_n,
     .                             z_n,  cc_n,  o_n, oo_n,
     .                           sap_n, map_n, n_n,   e_n, ee_n)
      implicit none
 
 
 
      integer       NLISTs
      character*80  OUTLIST_NL(9)  ! the suffix of the output file
      integer       NITEMSO_NL(9)  ! the number of elements to output
      character*80  PREFIX
 
      integer       HHs
      character*249 HH(999)   ! max 999 header pages!
 
      integer        Ns
      real*8         u_n(_NSTMAX_),  v_n(_NSTMAX_),  w_n(_NSTMAX_)
      real*8         x_n(_NSTMAX_),  y_n(_NSTMAX_),  m_n(_NSTMAX_)
      real*8        xx_n(_NSTMAX_), yy_n(_NSTMAX_), mm_n(_NSTMAX_)
      real*8        uu_n(_NSTMAX_), vv_n(_NSTMAX_), ww_n(_NSTMAX_)
      integer        k_n(_NSTMAX_)
      integer        h_n(_NSTMAX_)
      real*8         r_n(_NSTMAX_),  d_n(_NSTMAX_)
      real*8        rr_n(_NSTMAX_), dd_n(_NSTMAX_)
      integer        i_n(_NSTMAX_),  j_n(_NSTMAX_)
      real           p_n(_NSTMAX_), pp_n(_NSTMAX_)
      real           f_n(_NSTMAX_), ff_n(_NSTMAX_)
      real           q_n(_NSTMAX_),  c_n(_NSTMAX_)
      real           s_n(_NSTMAX_), ss_n(_NSTMAX_)
      real*8         t_n(_NSTMAX_)
      real           z_n(_NSTMAX_)
      real          cc_n(_NSTMAX_)
      real           o_n(_NSTMAX_)
      real          oo_n(_NSTMAX_)
      real         sap_n(_NSTMAX_)
      real         map_n(9,_NSTMAX_)
      integer        n_n(_NSTMAX_)
      real           e_n(_NSTMAX_), ee_n(_NSTMAX_)
 
c
c----------------------------------------------------------
c
      integer         N
      character*999   STRING999
      character*999   STRING999H
      character*999   STRING999N
      integer         F, F_NITEM(99)
c     character*4     CNITEM
      integer         CLAST
      integer         C1_F(_FIELDs_), N1_NITEM(99), N1
      integer         C2_F(_FIELDs_), N2_NITEM(99), N2
      character*23 CHAR_HEADER(_FIELDs_)
      data  CHAR_HEADER / 'u -- u ref-frame       ', ! 01
     .                    'v -- v ref-frame       ', ! 02
     .                    'M -- instl mag (1000s) ', ! 03
     .                    'x -- raw detector x pos', ! 04
     .                    'y -- raw detector y pos', ! 05
     .                    'm -- instl mag         ', ! 06
     .                    'k -- detector chip no  ', ! 07
     .                    'X -- dist-cor x posn   ', ! 08
     .                    'Y -- dist-cor y posn   ', ! 09
     .                    'h -- local isolation   ', ! 10
     .                    'H -- list-based isolatn', ! 11
     .                    'r -- RA (deg)          ', ! 12
     .                    'd -- Dec (deg)         ', ! 13
     .                    'R -- RA (deg; adjustd) ', ! 14
     .                    'D -- Dec (deg; adjustd)', ! 15
     .                    'i -- peak pixel column ', ! 16
     .                    'j -- peak pixel row    ', ! 17
     .                    'p -- peak pixel value  ', ! 18
     .                    'q -- quality of fit    ', ! 19
     .                    'c -- chisq of fit      ', ! 20
     .                    'U -- u ref-frame (corr)', ! 21
     .                    'V -- v ref-frame (corr)', ! 22
     .                    'k -- chip number       ', ! 23
     .                    'K -- chip number (w/K) ', ! 24
     .                    's -- sky value         ', ! 25
     .                    'S -- CTE bkgd value    ', ! 26
     .                    'n -- nsat pixels       ', ! 27
     .                    't -- rdat observation  ', ! 28
     .                    'C -- centpix frac resid', ! 29
     .                    'o -- other flux        ', ! 30
     .                    'O -- max other flux    ', ! 31
     .                    '1 -- diam=1 PBAP (1x1) ', ! 32
     .                    '2 -- diam=2 PBAP (2x2) ', ! 33
     .                    '3 -- diam=3 PBAP (3x3) ', ! 34
     .                    '4 -- diam=4 PBAP flux  ', ! 35
     .                    '5 -- diam=5 PBAP flux  ', ! 36
     .                    '6 -- diam=6 PBAP flux  ', ! 37
     .                    '7 -- diam=7 PBAP flux  ', ! 38
     .                    '8 -- diam=8 PBAP flux  ', ! 39
     .                    '9 -- diam=9 PBAP flux  ', ! 40
     .                    '0 -- PBAPsky: 5.5<r<8.5', ! 41
     .                    'z -- flux (can be neg) ', ! 42
     .                    'N -- star number       ', ! 43
     .                    'w -- dist-corr inst mag', ! 44
     .                    'W -- w, zeropointed    ', ! 45
     .                    'e -- frac error scale  ', ! 46
     .                    'f -- central PSF value ', ! 47
     .                    'F -- central PSF max   ', ! 48
     .                    'P -- 2x2 flux for fndng', ! 49
     .                    'E -- effective sky rad '/ ! 50
 
      integer      NITEM
      integer      NLIST
      character*20 CHAROUT_F(_FIELDs_)
      character*80 FILEOUT
      integer      i
      integer      LNC
 
c--------------------------
c
c output the star lists
c
      print*,'OUTPUT LISTS...'
      print*,'NLISTs: ',NLISTs
 
 
      if (NLISTs.eq.0) return
 
      print*,'SETUPa--- ',_FIELDs_
      do F = 1, _FIELDs_
         C1_F(F) = 20
         C2_F(F) = 01
         enddo
      print*,'SETUPb --- ',Ns
      do N = 1, Ns
         call fill_charout(CHAROUT_F,
     .                      u_n(N),   v_n(N), w_n(N),
     .                      x_n(N),   y_n(N), m_n(N), k_n(N),
     .                     xx_n(N),  yy_n(N),mm_n(N), h_n(N),
     .                      r_n(N),   d_n(N),rr_n(N), dd_n(N),
     .                      i_n(N),   j_n(N),
     .                      p_n(N),  pp_n(N),  ! J: 2023.06.29 -- added pp
     .                      f_n(N),  ff_n(N),  ! J: 2023.06.29 -- added f and ff
     .                      q_n(N),   c_N(N), s_n(N), ss_n(N),  t_n(N),
     .                     uu_n(N),  vv_n(n),ww_n(N),
     .                      z_n(N),  cc_n(N),
     .                      o_n(N),  oo_n(N),
     .                    sap_n(N), map_n(1,N), n_n(N),
     .                      e_n(N),  ee_n(N), N)
         do F = 01, _FIELDs_
            do i = 01, 20
               if (CHAROUT_F(F)(i:i).ne.' ') then
                  if (C1_F(F).gt.i) C1_F(F) = i
                  if (C2_F(F).lt.i) C2_F(F) = i
                  endif
               enddo
            enddo
         enddo
      close(37)
      print*,' '
      print*,'--------------'
      print*,'FIND SPACING: '
      print*,'--------------'
      do F = 01, _FIELDs_
         write(*,419) F,C1_F(F),C2_F(F),CHAR_HEADER(F)
  419    format(5x,'F',i2.2,1x,'(',i2.2,':',i2.2,')',5x,23a)
         enddo
      print*,'                     '
      print*,'*********************'
      print*,'***'
      print*,'*** NLISTs: ',NLISTs
      print*,'***'
      print*,'*********************'
      print*,'                     '
      do NLIST = 1, NLISTs
         write(STRING999H,'(''#'',998('' ''))')
         write(STRING999N,'(''#'',998('' ''))')
         FILEOUT = PREFIX(1:LNC(PREFIX,80))
     .             // '.'
     .             // OUTLIST_NL(NLIST)(1:NITEMSO_NL(NLIST))
         write(*,'(''   NLIST'',i2.2,'':  '',i3,2x,a80)')
     .                  NLIST, NITEMSO_NL(NLIST), FILEOUT
         open(97,file=FILEOUT,status='unknown')
         do i = 01, HHs
            write(97,'(249a)') HH(i)(1:LNC(HH(i),249))
            enddo
         write(97,'(''#'')')
         write(97,'(''#'',51(''=''))')
         write(97,'(''#  FILEOUT: '',a80)') FILEOUT
         write(97,'(''#'',51(''-''))')
         CLAST = 2
         do NITEM = 1, NITEMSO_NL(NLIST)
            F_NITEM(NITEM) = 0
            do F = 1, _FIELDs_
               if (char_header(F)(1:1).eq.
     .             OUTLIST_NL(NLIST)(NITEM:NITEM))
     .             F_NITEM(NITEM) = F
               enddo
            F = F_NITEM(NITEM)
            if (F.eq.0) then
               print*,'          '
               print*,'ERROR IN OUTPUT LIST...',OUTLIST_NL(NLIST)
               print*,'   NITEM: ',NITEM
               print*,'        : ',OUTLIST_NL(NLIST)(NITEM:NITEM)
               print*,'        : '
               print*,'          '
               print*,'FIELD NOT FOUND'
               print*,'          '
               stop 'need to figure out what went wrong...'
               endif
            N1_NITEM(NITEM) = CLAST
            N2_NITEM(NITEM) = CLAST + (C2_F(F)-C1_F(F))
            write(97,297) NITEM,CHAR_HEADER(F),
     .                    N1_NITEM(NITEM),
     .                    N2_NITEM(NITEM),F
  297       format('# (',i2.2,')',2x,a23,
     .                            4x,'c',i3.3,'-c',i3.3,
     .                            4x,'F',i3.3)
            CLAST = N2_NITEM(NITEM) + 2
            do i = N1_NITEM(NITEM), N2_NITEM(NITEM)
               STRING999H(i:i) = '.'
               STRING999N(i:i) = ' '
               enddo
            i = (N1_NITEM(NITEM)+N2_NITEM(NITEM)+1)/2
            if (i.ge.001.and.i.le.999)
     .      STRING999H(i:i) = OUTLIST_NL(NLIST)(NITEM:NITEM)
            if (i.ge.002.and.i.le.998) then
               if (N2_NITEM(NITEM)-N1_NITEM(NITEM).ge.1) then
                   write(STRING999N(i-1:i),'(i2.2)') NITEM
                   endif
               if (N2_NITEM(NITEM)-N1_NITEM(NITEM).ge.3) then
                   STRING999N(i-2:i-2) = '('
                   STRING999N(i+1:i+1) = ')'
                   endif
               endif
            enddo!NITEM
         write(97,'(''#'',51(''-''))')
         if (CLAST.lt.2) CLAST = 2
         write(97,'(''#'')')
         write(97,'(999a)') STRING999N(1:clast)
         write(97,'(''#'')')
         write(97,'(999a)') STRING999H(1:clast)
         write(97,'(''#'')')
         do N = 1, Ns
            call fill_charout(CHAROUT_F,
     .                         u_n(N),   v_n(N), w_n(N),
     .                         x_n(N),   y_n(N), m_n(N), k_n(N),
     .                        xx_n(N),  yy_n(N),mm_n(N), h_n(N),
     .                         r_n(N),   d_n(N),rr_n(N),dd_n(N),
     .                         i_n(N),   j_n(N),
     .                         p_n(N),  pp_n(N),
     .                         f_n(N),  ff_n(N),
     .                         q_n(N),   c_N(N),
     .                         s_n(N),  ss_n(N), t_n(N),
     .                        uu_n(N),  vv_N(N),ww_n(N),
     .                         z_n(N),  cc_n(N),
     .                         o_n(N),  oo_n(N),
     .                       sap_n(N), map_n(1,N), n_n(N),
     .                         e_n(N),  ee_n(N), N)
            write(STRING999,'(999('' ''))')
            do NITEM = 1, NITEMSO_NL(NLIST)
               F  =  F_NITEM(NITEM)
               N1 = N1_NITEM(NITEM)
               N2 = N2_NITEM(NITEM)
               STRING999(N1:N2) = CHAROUT_F(F)(c1_F(F):c2_F(F))
               enddo
            write(97,'(999a)')
     .         STRING999(1:N2_NITEM(NITEMSO_NL(NLIST)))
            enddo
         write(97,'(''#'')')
         write(97,'(999a)') STRING999H(1:clast)
         write(97,'(''#'')')
         write(97,'(999a)') STRING999N(1:clast)
         write(97,'(''#'')')
         close(97)
         enddo!NLIST
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/output_regs.f"
c****                                         
c*********************************************
                                              
 
 
      subroutine output_regs(NREGs,OUTLIST_NR,
     .                       PREFIX,
     .                       Ns,  u_n,  v_n,
     .                            x_n,  y_n,  m_n,
     .                           xx_n, yy_n,
     .                            r_n,  d_n,
     .                            q_n)
      implicit none
 
      integer       NREGs
      character*080 OUTLIST_NR(9)  ! the suffix of the output file
 
      character*080 PREFIX
 
      integer        N, Ns
      real*8         u_n(_NSTMAX_),  v_n(_NSTMAX_)
      real*8         x_n(_NSTMAX_),  y_n(_NSTMAX_),  m_n(_NSTMAX_)
      real*8        xx_n(_NSTMAX_), yy_n(_NSTMAX_)
      real*8         r_n(_NSTMAX_),  d_n(_NSTMAX_)
      real           q_n(_NSTMAX_)
c
c-------------------------------------------------
c
      integer       NREG
      real*8        rr
      integer       LNC
      character*080 FILEOUT
 
      if (NREGs.eq.0) return
 
 
      print*,'                     '
      print*,'*********************'
      print*,'***'
      print*,'***  NREGs: ',NREGs
      print*,'***'
      print*,'*********************'
      print*,'                     '
      do NREG = 1, NREGs
         FILEOUT = PREFIX(1:LNC(PREFIX,80))
     .             // '_'
     .             // OUTLIST_NR(NREG)(1:2)
     .             // '.reg'
         open(98,file=FILEOUT,status='unknown')
         write(98,211)
         write(98,212)
         if (OUTLIST_NR(NREG).eq.'xy') write(98,'(''image'')')
         if (OUTLIST_NR(NREG).eq.'XY') write(98,'(''image'')')
         if (OUTLIST_NR(NREG).eq.'uv') write(98,'(''physical'')')
         if (OUTLIST_NR(NREG).eq.'rd') write(98,'(''fk5'')')
         print*,'    NREG: ',NREG,FILEOUT(1:40)
         do N = 1, Ns
            rr = -m_n(N)*0.50
            if (rr.lt.0.1) rr = 0.1
            if (rr.gt.9.9) rr = 9.9
            if (OUTLIST_NR(NREG).eq.'xy') then
               if (q_n(N).gt.0.00) then
                   write(98,216) x_n(N),y_n(N),rr
                  else
                   write(98,217) x_n(N),y_n(N),rr
                  endif
               endif
            if (OUTLIST_NR(NREG).eq.'XY') then
               if (q_n(N).gt.0.00) then
                   write(98,216) xx_n(N),yy_n(N),rr
                  else
                   write(98,217) xx_n(N),yy_n(N),rr
                  endif
               endif
            if (OUTLIST_NR(NREG).eq.'uv') then
               if (q_n(N).gt.0.00) then
                   write(98,216) u_n(N),v_n(N),rr
                  else
                   write(98,217) u_n(N),v_n(N),rr
                  endif
               endif
            if (OUTLIST_NR(NREG).eq.'rd') then
               if (q_n(N).gt.0.00) then
                   write(98,214) r_n(N),d_n(N)
                  else
                   write(98,215) r_n(N),d_n(N)
                  endif
               endif
            enddo!Ns
         enddo!NREGs
 
  211 format('# Region file format: DS9 version 4.1')
  212 format('global color=green dashlist=8 3 width=1',
     .       ' font="helvetica 10 normal" select=1 highlite=1',
     .       ' dash=0 fixed=0 edit=1 move=1 delete=1 include=1',
     .       ' source=1')
  214 format('circle(',f11.7,',',f11.7,',0.05")')                     ! UNSAT rd
  215 format('circle(',f11.7,',',f11.7,',0.05") # width=4 color=red') !   SAT rd
  216 format('circle(',f9.2,',',f9.2,',',f5.2,')')                     ! UNSAT xy,XY,uv
  217 format('circle(',f9.2,',',f9.2,',',f5.2,') # width=4 color=red') !   SAT xy,XY,uv
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/wfc3ir_ima_xyadj.f"
c****                                         
c*********************************************
                                              
 
c
c
c
c
c
 
      subroutine wfc3ir_ima_xyadj(FILE_IMA,
     .                            Ss,
     .                            SAMPTIME_s, NOBS_s, NFIT_s,
     .                            DXBAR_s, DXSIG_s,
     .                            DYBAR_s, DYSIG_s,
     .                            DMBAR_s, DMSIG_s,
     .                             x_l,  y_l,   m_l, s_l,
     .                                   p_l, sat_l, Ls,
     .                            xx_l, yy_l, mm_l,
     .                            nt_l, wt_l,
     .                            NSATRD0,
     .                            NSATRD1,
     .                            NSATRD2,
     .                            NSATRDF,
     .                            NUNSAT1,
     .                            EXPTIME,
     .                            FILE_STDPSF)
      implicit none
 
      character*200 FILE_IMA
      integer       Ss
      real          SAMPTIME_s(Ss)
      integer       NOBS_s(Ss)
      integer       NFIT_s(Ss)
      real          DXBAR_s(Ss), DXSIG_s(Ss)
      real          DYBAR_s(Ss), DYSIG_s(Ss)
      real          DMBAR_s(Ss), DMSIG_s(Ss)
      integer       Ls
      real*8         x_l(Ls),  y_l(Ls),  m_l(Ls)    ! these are the unadjusted positions
      real*4                   s_l(Ls),  p_l(Ls)
      integer                          sat_l(Ls)
      real*8        xx_l(Ls), yy_l(Ls), mm_l(Ls)    ! these are the   adjusted positions
      integer       nt_l(Ls)
      real          wt_l(Ls)
      integer       NSATRD0
      integer       NSATRD1
      integer       NSATRD2
      integer       NSATRDF
      integer       NUNSAT1
      real          EXPTIME
      character*200 FILE_STDPSF
 
      real          psfloc(101,101)
 
      real,      dimension(:,:,:), allocatable :: pixima_s
      real,      dimension(:,:,:), allocatable :: piximt_s
      integer*2, dimension(:,:,:), allocatable :: piximq_s
 
      real,    dimension(:), allocatable :: z_l ! the expected total number of counts (not per sec)
      real,    dimension(:), allocatable :: e_l ! the expected central-pixel flux     (not per sec)
      integer, dimension(:), allocatable :: u_l ! to use in re-seating?
 
      integer  L
      integer  S
 
      integer  i, j
      real*8   xr, yr, zr, sr
      real*4   qr, cr
 
      real,    dimension(:,:), allocatable :: xr_sl
      real,    dimension(:,:), allocatable :: yr_sl
      real,    dimension(:,:), allocatable :: sr_sl
      real,    dimension(:,:), allocatable :: qr_sl
      real,    dimension(:,:), allocatable :: zr_sl
      real,    dimension(:,:), allocatable :: mr_sl
      integer, dimension(:,:), allocatable :: ur_sl
 
c     real     mbar_sky_NAXIS
      real     z_xyoptXX_NAXIS
 
      integer  Us, Uu
      real*8   dx_u(99999), dxbar, dxsig
      real*8   dy_u(99999), dybar, dysig
      real*8   dm_u(99999), dmbar, dmsig
 
      real*8   xtot, ytot, mtot
      integer  ntot
      real     wtot, w
 
      allocate(z_l(Ls))
      allocate(e_l(Ls))
      allocate(u_l(Ls))
 
 
c-----------------------
c
c read in the ima image
c
      allocate(pixima_s(1014,1014,25))
      allocate(piximt_s(1014,1014,25))
      allocate(piximq_s(1014,1014,25))
 
      call read_wfc3ir_ima_nosub(FILE_IMA,
     .                           pixima_s,
     .                           piximt_s,
     .                           piximq_s,
     .                           Ss, SAMPTIME_s)
 
 
      call locpsfij_stdpsf(507,507,psfloc,FILE_STDPSF)
 
      do L = 1, Ls
         z_l(L) = SNGL(10**(-m_l(L)/2.5)*(EXPTIME+3.0))
         e_l(L) = z_l(L)*psfloc(51,51)
         u_l(L) = 0
         if (e_l(L).ge.80000) u_l(L) = 1
         if (e_l(L).lt.80000.and.p_l(L).gt.32000) u_l(L) = 2
         i = int(x_l(L)+0.5)
         j = int(y_l(L)+0.5)
         if (pixima_s(i,j,1).lt.0.) u_l(L) = -1
         if (sat_l(L).eq.1) u_l(L) = -1
c        write(16,116) L, x_l(L), y_l(L), m_l(L),
c    .                    z_l(L), e_l(L), u_l(L),
c    .                    i,j, sat_l(L),
c    .                    p_l(L),
c    .                    pixima_s(i,j,1),pixima_s(i,j,2),
c    .                    pixima_s(i,j,3),pixima_s(i,j,4),
c    .                    piximt_s(i,j,1),piximt_s(i,j,2),
c    .                    piximt_s(i,j,3),piximt_s(i,j,4)
c 116    format(1x,i6.6,1x,f8.2,1x,f8.2,1x,f8.3,
c    .                  4x,f14.1,1x,f14.1,1x,i2,1x,
c    .                  4x,i4.4,1x,i4.4,1x,i1,
c    .                  4x,f9.1,
c    .                  4x,f9.3,1x,f9.3,1x,f9.3,1x,f9.3,
c    .                  4x,f8.1,1x,f8.1,1x,f8.1,1x,f8.1)
         enddo
 
      allocate(xr_sl(Ss,Ls))
      allocate(yr_sl(Ss,Ls))
      allocate(sr_sl(Ss,Ls))
      allocate(qr_sl(Ss,Ls))
      allocate(zr_sl(Ss,Ls))
      allocate(mr_sl(Ss,Ls))
      allocate(ur_sl(Ss,Ls))
 
      do L = 1, Ls
         do S = 1, Ss
            ur_sl(S,L) = 0
            enddo
         if (u_l(L).gt.0) then
             i = int(x_l(L)+0.5)
             j = int(y_l(L)+0.5)
             call locpsfij_stdpsf(i,j,psfloc,FILE_STDPSF)
             do S = 1, Ss
                ur_sl(S,L) = 0
                xr_sl(S,L) = 0.00
                yr_sl(S,L) = 0.00
                zr_sl(S,L) = 0.00
                mr_sl(S,L) = 0.00
                qr_sl(S,L) = 9.99
                sr_sl(S,L) = 0.00
                if (pixima_s(i,j,S).gt.10) then
c                   sr = mbar_sky_NAXIS(i,j,08,12,
c    .                                  pixima_s(1,1,S),1014,1014)
                    sr = s_l(L)
                    xr = x_l(L)
                    yr = y_l(L)
                    call find_xyzXX_NAXIS(xr,yr,zr,sr,qr,cr,
     .                                    pixima_s(1,1,S),
     .                                    psfloc,1014,1014,1,'5x5')
                    zr = z_xyoptXX_NAXIS(xr,yr,sr,
     .                                   pixima_s(1,1,S),
     .                                   psfloc,
     .                                   1014,1014,1,'5x5')  ! 1 means to weight by S/N
                    ur_sl(S,L) = 1
                    xr_sl(S,L) = SNGL(xr)
                    yr_sl(S,L) = SNGL(yr)
                    zr_sl(S,L) = SNGL(zr)
                    mr_sl(S,L) = SNGL(-2.5*log10(max(zr,0.1)))
                    qr_sl(S,L) = qr
                    sr_sl(S,L) = SNGL(sr)
                    endif
                enddo
             endif
         enddo
 
      do L = 1, Ls
         do S = 1, Ss
            i = int(x_l(L)+0.5)
            j = int(y_l(L)+0.5)
c           write(19,119) L, u_l(L), S, ur_sl(S,L),
c    .                                  xr_sl(S,L), yr_sl(S,L),
c    .                                  mr_sl(S,L), zr_sl(S,L),
c    .                                  qr_sl(S,L), sr_sl(S,L),
c    .                                   x_l(L), y_l(L), m_l(L),
c    .                                  i, j, pixima_s(i,j,S),
c    .                                        piximt_s(i,j,S),
c    .                                        piximq_s(i,j,S)
c 119       format(1x,i6.6,1x,i2,1x,i2.2,1x,i1,
c    .                     5x,f9.4,1x,f9.4,1x,f8.4,
c    .                     1x,f9.2,1x,f5.3,1x,f8.2,
c    .                     5x,f9.4,1x,f9.4,1x,f8.4,
c    .                     5x,i4.4,1x,i4.4,1x,f8.2,1x,f9.1,1x,i6)
            enddo
         enddo
 
 
      do S = 1, Ss
         Us = 0
         NOBS_s(s) = 0
         do L = 1, Ls
            if (ur_sl(S,L).eq.1) NOBS_s(s) = NOBS_s(s) + 1
            if (ur_sl(Ss,L).eq.1.and.
     .          ur_sl(S ,L).eq.1) then
                Us = Us + 1
                dx_u(Us) = xr_sl(S,L)-x_l(L)
                dy_u(Us) = yr_sl(S,L)-y_l(L)
                dm_u(Us) = mr_sl(S,L)-m_l(L)
                endif
            enddo
         if (S.eq.1) then                          ! for the zeroth read...
            Us = 0
            do L = 1, Ls                           ! look only at stars in the
               if (ur_sl(1,L).eq.1.and.            !    first read, but not others
     .             ur_sl(2,L).eq.1.and.
     .             ur_sl(3,L).eq.0) then
                   Us = Us + 1
                   dx_u(Us) = xr_sl(S,L)-x_l(L)
                   dy_u(Us) = yr_sl(S,L)-y_l(L)
                   dm_u(Us) = mr_sl(S,L)-m_l(L)
                   endif
                enddo
             endif
 
         call dbarsigs_3d(dx_u,dy_u,dm_u,Us,
     .                    dxbar,dxsig,
     .                    dybar,dysig,
     .                    dmbar,dmsig,Uu,3.5)
c        write(*,118) S, SAMPTIME_s(S),
c    .                Us, Uu,
c    .                dxbar, dybar, dmbar,
c    .                dxsig, dysig, dmsig
c 118    format(1x,i2.2,1x,f8.2,
c    .          3x,i4,1x,i4,
c    .          3x,f8.4,1x,f8.4,1x,f8.4,
c    .          3x,f8.4,1x,f8.4,1x,f8.4)
         DXBAR_s(S) = SNGL(dxbar)
         DYBAR_s(S) = SNGL(dybar)
         DMBAR_s(S) = SNGL(dmbar)
         DXSIG_s(S) = SNGL(dxsig)
         DYSIG_s(S) = SNGL(dysig)
         DMSIG_s(S) = SNGL(dmsig)
         NFIT_s(S)  = Us
         enddo
 
      DXBAR_s(1) = DXBAR_s(1) + DXBAR_s(2)
      DYBAR_s(1) = DYBAR_s(1) + DYBAR_s(2)
      DMBAR_s(1) = DMBAR_s(1) + DMBAR_s(2)
 
      NSATRD0 = 0
      NSATRD1 = 0
      NSATRD2 = 0
      NSATRDF = 0
      NUNSAT1 = Us
 
      do L = 1, Ls
         xx_l(L) = x_l(L)
         yy_l(L) = y_l(L)
         mm_l(L) = m_l(L)
         xtot = 0.
         ytot = 0.
         mtot = 0.
         ntot = 0
         wtot = 0
         if (u_l(L).ne.-1) then
            do S = 1, Ss
               if (ur_sl(S,L).eq.1) then
                   w = 0.
                   if (S.eq.1) w = SAMPTIME_s(2)
                   if (S.gt.1) w = SAMPTIME_s(S)-SAMPTIME_s(S-1)
                   xtot = xtot + w*(xr_sl(S,L)-DXBAR_s(S))
                   ytot = ytot + w*(yr_sl(S,L)-DYBAR_s(S))
                   mtot = mtot + w*(mr_sl(S,L)-DMBAR_s(S))
                   wtot = wtot + w
                   ntot = ntot + 1
c                   write(17,117) L, S, w, xr_sl(S,L)-DXBAR_s(S),
c    .                                    yr_sl(S,L)-DYBAR_s(S),
c    .                                    mr_sl(S,L)-DMBAR_s(S)
                   endif
               enddo
            nt_l(L) = ntot
            wt_l(L) = wtot
            if (ntot.ge.1.and.ntot.lt.Ss) then
                xx_l(L) = xtot/wtot
                yy_l(L) = ytot/wtot
                mm_l(L) = mtot/wtot
                endif
c           write(17,117) L, ntot, wtot, xx_l(L), yy_l(L), mm_l(L)
c 117       format(1x,i5.5,1x,i2,1x,f8.3,1x,f9.4,1x,f9.4,1x,f9.5)
            if (ur_sl(1,L).eq.1.and.ur_sl(2,L).eq.0) NSATRD0 = NSATRD0+1
            if (ur_sl(2,L).eq.1.and.ur_sl(3,L).eq.0) NSATRD1 = NSATRD1+1
            if (ur_sl(3,L).eq.1.and.ur_sl(4,L).eq.0) NSATRD2 = NSATRD2+1
            if (ur_sl(Ss,L).eq.0)                    NSATRDF = NSATRDF+1
            endif
         enddo
 
      RETURN
      end
 
 
 
 
      subroutine dbarsigs_3d(xlist,ylist,mlist,NTOT,
     .                       xbar,xsig,
     .                       ybar,ysig,
     .                       mbar,msig,NUSE,SIGCLIP)
      implicit none
 
      integer NTOT
      real*8 xlist(NTOT), ylist(NTOT), mlist(NTOT)
      real*8 xbar, ybar, mbar
      real*8 xsig, ysig, msig
      integer NUSE
      real SIGCLIP
 
      integer n
      integer nsum, nsumo
      integer NIT
      real dsig
 
      real*8 xsumb, xsume
      real*8 ysumb, ysume
      real*8 msumb, msume
 
      nsum = 0
      xbar = 0.e0
      ybar = 0.e0
      mbar = 0.e0
      xsig = 9e9
      ysig = 9e9
      msig = 9e9
      do NIT = 1, 20
         dsig = SNGL(sqrt(xsig**2+ysig**2))
         nsumo = nsum
         xsumb = 0.
         xsume = 0.
         ysumb = 0.
         ysume = 0.
         msumb = 0.
         msume = 0.
         nsum = 0.
         do n = 1, NTOT
            if (sqrt((xlist(n)-xbar)**2+(ylist(n)-ybar)**2)
     .                  .le.dsig*SIGCLIP) then
               xsumb = xsumb + xlist(n)
               ysumb = ysumb + ylist(n)
               msumb = msumb + mlist(n)
               xsume = xsume + abs(xlist(n)-xbar)
               ysume = ysume + abs(ylist(n)-ybar)
               msume = msume + abs(mlist(n)-mbar)
               nsum = nsum + 1
               endif
            enddo
         if (nsum.gt.0) then
             xbar = xsumb / nsum
             ybar = ysumb / nsum
             mbar = msumb / nsum
             endif
         if (nsum.gt.1) then
             xsig = xsume/(nsum-1)
             ysig = ysume/(nsum-1)
             msig = msume/(nsum-1)
             endif
         if (nsum.lt.0.35*NTOT.and.NIT.ge.3) return
         if (nsum.eq.nsumo.and.NIT.ge.3) goto 1
         enddo
  1   continue
      NUSE = nsum
      if (nsum.le.1) then
          xsig = 0.999
          ysig = 0.999
          msig = 0.999
          endif
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/find_postflash_wfc3uv.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------------------------
c
c this routine approximates the postflash for UVIS at a given location
c with a given current and shutter position
c
 
      real function find_postflash_wfc3uv(x,y,
     .                                    c1_flashcur,
     .                                    c1_shutrpos)
      implicit none
 
      real*8 x, y
      character*01 c1_flashcur
      character*01 c1_shutrpos
 
      real    ri, rj
      integer ii, jj
      real    fi, fj
 
      real frat_a(9,9)
      real frat_b(9,9)
 
      data frat_a/0.93, 1.00, 1.06, 1.11, 1.11, 1.08, 1.14, 1.18, 1.20,
     .            0.96, 1.06, 1.13, 1.18, 1.18, 1.13, 1.18, 1.25, 1.23,
     .            0.99, 1.08, 1.16, 1.22, 1.26, 1.25, 1.27, 1.27, 1.22,
     .            1.03, 1.09, 1.17, 1.25, 1.30, 1.33, 1.30, 1.27, 1.22,
     .            1.02, 1.10, 1.16, 1.25, 1.32, 1.34, 1.32, 1.27, 1.21,
     .            1.02, 1.09, 1.16, 1.25, 1.32, 1.36, 1.33, 1.27, 1.22,
     .            1.00, 1.07, 1.14, 1.20, 1.26, 1.31, 1.30, 1.25, 1.19,
     .            0.97, 1.04, 1.09, 1.15, 1.19, 1.21, 1.22, 1.19, 1.13,
     .            0.94, 0.99, 1.03, 1.07, 1.10, 1.12, 1.11, 1.10, 1.06/
 
 
      data frat_b/0.87, 0.94, 0.99, 1.04, 1.05, 1.02, 1.08, 1.11, 1.14,
     .            0.90, 0.99, 1.05, 1.11, 1.11, 1.06, 1.11, 1.18, 1.16,
     .            0.92, 1.00, 1.08, 1.14, 1.18, 1.17, 1.19, 1.19, 1.14,
     .            0.95, 1.01, 1.08, 1.15, 1.21, 1.24, 1.21, 1.18, 1.14,
     .            0.94, 1.01, 1.07, 1.15, 1.22, 1.24, 1.23, 1.18, 1.13,
     .            0.93, 1.00, 1.07, 1.15, 1.22, 1.25, 1.23, 1.18, 1.13,
     .            0.91, 0.98, 1.05, 1.10, 1.16, 1.20, 1.20, 1.16, 1.10,
     .            0.89, 0.95, 1.00, 1.06, 1.10, 1.11, 1.12, 1.10, 1.05,
     .            0.85, 0.91, 0.95, 0.98, 1.01, 1.03, 1.02, 1.01, 0.98/
 
      common /frat_ab/frat_a,frat_b
 
 
      ri = SNGL(1 + (x-1)/512.0)
      rj = SNGL(1 + (y-1)/512.0)
      if (ri.lt.1.001) ri = 1.001
      if (rj.lt.1.001) rj = 1.001
      if (ri.gt.8.999) ri = 8.999
      if (rj.gt.8.999) rj = 8.999
 
      ii = int(ri)
      jj = int(rj)
 
      fi = ri-ii
      fj = rj-jj
 
c     if (c1_flashcur.ne.'L'.and.
c    .    c1_flashcur.ne.'Z') then
c         print*,'  c1_flashcur: ',c1_flashcur
c         stop 'flashcur must be LOW or ZERO!'
c         endif
 
      if (c1_shutrpos.ne.'A'.and.
     .    c1_shutrpos.ne.'B') stop 'shutrpos must be A or B'
 
      find_postflash_wfc3uv = 0.0
 
      if (c1_flashcur.ne.'L') return
 
      if (c1_shutrpos.eq.'A') then
          find_postflash_wfc3uv = (1-fi)*(1-fj)*frat_a(ii  ,jj  )
     .                          + (1-fi)*( fj )*frat_a(ii  ,jj+1)
     .                          + ( fi )*(1-fj)*frat_a(ii+1,jj  )
     .                          + ( fi )*( fj )*frat_a(ii+1,jj+1)
          endif
 
      if (c1_shutrpos.eq.'B') then
          find_postflash_wfc3uv = (1-fi)*(1-fj)*frat_b(ii  ,jj  )
     .                          + (1-fi)*( fj )*frat_b(ii  ,jj+1)
     .                          + ( fi )*(1-fj)*frat_b(ii+1,jj  )
     .                          + ( fi )*( fj )*frat_b(ii+1,jj+1)
          endif
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/find_postflash_acswfc.f"
c****                                         
c*********************************************
                                              
 
c---------------------------------------------------------------------
c
c this routine approximates the postflash for UVIS at a given location
c with a given current and shutter position
c
 
      real function find_postflash_acswfc(x,y)
      implicit none
 
      real*8 x, y
 
      real    ri, rj
      integer ii, jj
      real    fi, fj
 
      real frat(9,9)
 
      data frat/
c
c       J=0000 J=0512 J=1024 J=1536 J=2048 J=2560 J=3072 J=3584 J=4096
c
     .    8.12,  8.68,  9.38, 10.07, 10.23,  9.92,  9.43,  8.66,  7.89,  ! I=0000
     .    9.08,  9.63, 10.25, 10.89, 11.13, 11.01, 10.47,  9.76,  8.83,  ! I=0512
     .   10.16, 10.70, 11.46, 12.12, 12.42, 12.19, 11.59, 10.54,  9.48,  ! I=1024
     .   10.77, 11.54, 12.74, 13.82, 13.99, 13.24, 12.46, 11.27, 10.17,  ! I=1536
     .   11.38, 12.30, 14.06, 15.24, 14.99, 13.66, 12.73, 11.85, 10.63,  ! I=2048
     .   11.50, 12.45, 14.15, 15.16, 14.84, 13.46, 12.57, 11.59, 10.55,  ! I=2560
     .   11.19, 11.98, 13.16, 14.00, 13.74, 12.81, 11.88, 10.76,  9.74,  ! I=3072
     .   10.53, 11.11, 11.78, 12.24, 12.12, 11.73, 11.00,  9.94,  8.99,  ! I=3584
     .    9.79, 10.40, 10.88, 11.19, 11.17, 10.79, 10.08,  9.10,  8.28/  ! I=4096
c
c       J=0000 J=0512 J=1024 J=1536 J=2048 J=2560 J=3072 J=3584 J=4096
c
 
      common /fratacs_/frat
 
 
      ri = SNGL(1 + (x-1)/512.0)
      rj = SNGL(1 + (y-1)/512.0)
      if (ri.lt.1.001) ri = 1.001
      if (rj.lt.1.001) rj = 1.001
      if (ri.gt.8.999) ri = 8.999
      if (rj.gt.8.999) rj = 8.999
 
      ii = int(ri)
      jj = int(rj)
 
      fi = ri-ii
      fj = rj-jj
 
      find_postflash_acswfc = (1-fi)*(1-fj)*frat(ii  ,jj  )
     .                      + (1-fi)*( fj )*frat(ii  ,jj+1)
     .                      + ( fi )*(1-fj)*frat(ii+1,jj  )
     .                      + ( fi )*( fj )*frat(ii+1,jj+1)
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/cog_apphot_123456789.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------------------------
c
c this routine will determine the curve-of-growth aperture photometry
c
c
      subroutine cog_apphot_123456789(xr,yr,pix,psf,
     .                                      NAXIS1,NAXIS2,
     .                                sap, map_d)
      implicit none
 
      real*8  xr, yr
      real    pix(NAXIS1,NAXIS2)
      real    psf(101,101)
      integer NAXIS1, NAXIS2
      real    sap, map_d(9)
 
      integer i, j
 
      integer  L, Ls, Lu
      integer  i_l(128)
      integer  j_l(128)
      real     x_l(128)
      real     y_l(128)
      real     p_l(128)
      real     f_l(128)
      real     s_l(128)
      integer  ic, jc
      real     sbar, ssig
      real     z
 
      real    rpsf_phot
      real    xpsf, ypsf
 
      integer i1x1max, j1x1max
      integer i2x2max, j2x2max
      real    p1x1, p1x1max
      real    p2x2, p2x2max
 
      real    ptot
      real    ftot
 
      integer NTOT
      integer NIT
      integer NAP
 
c
c which pixels to use for which apertures?
c for even numbers, the "central" pixel is the
c lower left in the max 2x2
c
      integer uap(9,9,9)
      data uap / 0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 1, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
c
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 2, 2, 0, 0, 0,
     .           0, 0, 0, 0, 2, 2, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
c
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 3, 3, 3, 0, 0, 0,
     .           0, 0, 0, 3, 3, 3, 0, 0, 0,
     .           0, 0, 0, 3, 3, 3, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
c
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 4, 4, 0, 0, 0,
     .           0, 0, 0, 4, 4, 4, 4, 0, 0,
     .           0, 0, 0, 4, 4, 4, 4, 0, 0,
     .           0, 0, 0, 0, 4, 4, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
c
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 5, 5, 5, 0, 0, 0,
     .           0, 0, 5, 5, 5, 5, 5, 0, 0,
     .           0, 0, 5, 5, 5, 5, 5, 0, 0,
     .           0, 0, 5, 5, 5, 5, 5, 0, 0,
     .           0, 0, 0, 5, 5, 5, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
c
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 6, 6, 6, 6, 0, 0,
     .           0, 0, 6, 6, 6, 6, 6, 6, 0,
     .           0, 0, 6, 6, 6, 6, 6, 6, 0,
     .           0, 0, 6, 6, 6, 6, 6, 6, 0,
     .           0, 0, 6, 6, 6, 6, 6, 6, 0,
     .           0, 0, 0, 6, 6, 6, 6, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
c
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
     .           0, 0, 0, 7, 7, 7, 0, 0, 0,
     .           0, 0, 7, 7, 7, 7, 7, 0, 0,
     .           0, 7, 7, 7, 7, 7, 7, 7, 0,
     .           0, 7, 7, 7, 7, 7, 7, 7, 0,
     .           0, 7, 7, 7, 7, 7, 7, 7, 0,
     .           0, 0, 7, 7, 7, 7, 7, 0, 0,
     .           0, 0, 0, 7, 7, 7, 0, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
c
     .           0, 0, 0, 8, 8, 8, 8, 0, 0,
     .           0, 0, 8, 8, 8, 8, 8, 8, 0,
     .           0, 8, 8, 8, 8, 8, 8, 8, 8,
     .           0, 8, 8, 8, 8, 8, 8, 8, 8,
     .           0, 8, 8, 8, 8, 8, 8, 8, 8,
     .           0, 8, 8, 8, 8, 8, 8, 8, 8,
     .           0, 0, 8, 8, 8, 8, 8, 8, 0,
     .           0, 0, 0, 8, 8, 8, 8, 0, 0,
     .           0, 0, 0, 0, 0, 0, 0, 0, 0,
c
     .           0, 0, 9, 9, 9, 9, 9, 0, 0,
     .           0, 9, 9, 9, 9, 9, 9, 9, 0,
     .           9, 9, 9, 9, 9, 9, 9, 9, 9,
     .           9, 9, 9, 9, 9, 9, 9, 9, 9,
     .           9, 9, 9, 9, 9, 9, 9, 9, 9,
     .           9, 9, 9, 9, 9, 9, 9, 9, 9,
     .           9, 9, 9, 9, 9, 9, 9, 9, 9,
     .           0, 9, 9, 9, 9, 9, 9, 9, 0,
     .           0, 0, 9, 9, 9, 9, 9, 0, 0/
 
 
 
c------------------------------------------------
c
c start with default, unfilled values
c
      sap = 0
      do NAP = 1, 9
         map_d(NAP) = 0.0
         enddo
 
      ic = int(xr+0.5)
      jc = int(yr+0.5)
      if (ic.lt.1+8.or.ic.gt.NAXIS1-9.or.                  ! if the apertura and sky cannot be completely
     .    jc.lt.1+8.or.jc.gt.NAXIS2-9) return              ! contained within the image,  bail
 
 
c--------------------------------------------------
c
c find the brightest pixel
c
      i1x1max = int(xr+0.5)
      j1x1max = int(yr+0.5)
      p1x1max = pix(i1x1max,j1x1max)
      do i = int(xr+0.5)-1, int(xr+0.5)+1
      do j = int(yr+0.5)-1, int(yr+0.5)+1
         p1x1 = pix(i,j)
         if (p1x1.gt.p1x1max) then
             i1x1max = i
             j1x1max = j
             p1x1max = p1x1
             endif
         enddo
         enddo
 
 
c--------------------------------------------------
c
c find the brightest 2x2 pixel sum, near the center
c
      i2x2max = int(xr-0.5)
      j2x2max = int(yr-0.5)
      p2x2max = pix(i2x2max,j2x2max  )+pix(i2x2max+1,j2x2max  )
     .        + pix(i2x2max,j2x2max+1)+pix(i2x2max+1,j2x2max+1)
      do i = i1x1max-1, i1x1max
      do j = j1x1max-1, j1x1max
         p2x2 = pix(i,j)+pix(i+1,j)+pix(i,j+1)+pix(i+1,j+1)
         if (p2x2.gt.p2x2max) then
             i2x2max = i
             j2x2max = j
             p2x2max = p2x2
             endif
         enddo
         enddo
 
 
c------------------------------------------------------
c
c iterate to find the best sky for the 5x5 pix aperture;
c need to find a sky, then a flux, then sky, then flux
c
      Ls = 0
      do i = -8, 8
      do j = -8, 8
         if (i**2+j**2.ge.5.5**2.and.
     .       i**2+j**2.le.8.5**2) then
             if (i1x1max+i.ge.000001.and.
     .           i1x1max+i.le.NAXIS1.and.
     .           j1x1max+j.ge.000001.and.
     .           j1x1max+j.le.NAXIS2) then
                 Ls = Ls + 1
                 j_l(Ls) = j1x1max + j
                 if (Ls.gt.128) stop 'Ls.gt.128.. how?!?'
                 i_l(Ls) = i1x1max + i
                 j_l(Ls) = j1x1max + j
                 p_l(Ls) = pix(i_l(Ls),j_l(Ls))
                 x_l(Ls) = SNGL(i_l(Ls)-xr)
                 y_l(Ls) = SNGL(j_l(Ls)-yr)
                 f_l(Ls) = rpsf_phot(x_l(Ls),y_l(Ls),psf)
                 endif
             endif
         enddo
         enddo
 
      ptot = 0.
      ftot = 0.
      do i = i1x1max-1, i1x1max+1
      do j = j1x1max-1, j1x1max+1
         xpsf = SNGL(i-xr)
         ypsf = SNGL(j-yr)
         ptot = ptot + pix(i,j)
         ftot = ftot + rpsf_phot(xpsf,ypsf,psf)
         enddo
         enddo
 
      z = 0.
      do NIT = 1, 9
         do L = 1, Ls
            s_l(L) = p_l(L)-z*f_l(L)
            enddo
         call rbarsigs(s_l,Ls,sbar,ssig,Lu,2.75)
         z = (ptot - 9*sbar)/ftot
         enddo
      sap = sbar
 
      do NAP = 1, 9
         ntot = 0
         ptot = 0.
         ftot = 0.
         if (NAP-NAP/2*2.eq.1) then
             ic = i1x1max
             jc = j1x1max
             endif
         if (NAP-NAP/2*2.eq.0) then
             ic = i2x2max
             jc = j2x2max
             endif
         do i = -4, 4
         do j = -4, 4
            if (uap(5+i,5+j,NAP).ne.0) then
                xpsf = SNGL(ic+i-xr)
                ypsf = SNGL(jc+j-yr)
                ptot = ptot + pix(ic+i,jc+j) - sbar
                ftot = ftot + rpsf_phot(xpsf,ypsf,psf)
                ntot = ntot + 1
                endif
            z = ptot/ftot
            enddo
            enddo
         map_d(NAP) = -2.5*log10(max(z,1.00))
c        write(*,119) NAP, ptot, ftot, map_d(NAP)
c 119    format(1x,i3,1x,f10.4,1x,f8.6,1x,f8.4)
         enddo
 
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/nsat_contig.f"
c****                                         
c*********************************************
                                              
 
 
      integer function nsat_contig(ii,jj,pixq,
     .                             NAXIS1,NAXIS2)
      implicit none
 
      integer ii, jj
      integer NAXIS1
      integer NAXIS2
      byte    pixq(NAXIS1,NAXIS2)
 
      integer IR
      integer i, j
      integer NSATs
      integer NTOTs
 
      if (pixq(ii,jj).eq.0) then
         nsat_contig = 0
         return
         endif
 
      IR = 2
    1 continue
      IR = IR + 1
 
      NSATs = 0
      NTOTs = 0
      do i = -IR, IR
      do j = -IR, IR
         if (i**2+j**2.le.IR**2) then
         if (ii+i.ge.1.and.ii+i.le.NAXIS1.and.
     .       jj+j.ge.1.and.jj+j.le.NAXIS2) then
             NTOTs = NTOTs + 1
             if (pixq(ii+i,jj+j).eq.1) NSATs = NSATs + 1
             endif
             endif
         enddo
         enddo
      if (NSATs.gt.NTOTs/2) goto 1
 
      nsat_contig = NSATs
      return
      end
 
 
 
      integer function nsat_contigh(ii,jj,pixq,
     .                             NAXIS1,NAXIS2)
      implicit none
 
      integer ii, jj
      integer NAXIS1
      integer NAXIS2
      byte    pixq(NAXIS1,NAXIS2)
 
      integer L, LL, Ls, Ls0
      integer i_l(99999)
      integer j_l(99999)
 
      integer dL
      integer NIT
 
      integer i, j
 
      Ls = 0
      if (pixq(ii,jj).eq.0) goto 777
 
      Ls = 1
      i_l(Ls) = ii
      j_l(Ls) = jj
 
      NIT = 0
    1 continue
      NIT = NIT + 1
 
      Ls0 = Ls
 
 
      dL = 0
      do L = 1, Ls0
         do i = max(0001,i_l(L)-1), min(NAXIS1,i_l(L)+1)
         do j = max(0001,j_l(L)-1), min(NAXIS2,j_l(L)+1)
            do LL = 1, Ls
               if (i.eq.i_l(LL).and.j.eq.j_l(LL)) goto 666
               enddo
            if (pixq(i,j).eq.1) then
                dL = dL + 1
                Ls = Ls + 1
                if (Ls.ge.99999) goto 777
                i_l(Ls) = i
                j_l(Ls) = j
                endif
 666        continue
            enddo
            enddo
         enddo
      if (dL.ge.1) goto 1
 
 
 777  continue
      nsat_contigh = Ls
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/find_oth.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------------
c
c
c
c
      subroutine find_oth(ic,jc,
     .                    xr,yr,fr,pixc,NAXIS1,NAXIS2,psfloc,
     .                    o,oo)
      implicit none
 
      integer ic, jc
      real*8  xr, yr, fr
      integer NAXIS1, NAXIS2
      real    pixc(NAXIS1,NAXIS2)
      real    psfloc(101,101)
      real    o, oo
 
      real pixloc(41,41)
      real modloc(41,41)
      integer iu, ju
 
      real otot, ootot
      real rpsf_phot
      real xpsf,ypsf
      real f, p
      real xopt, yopt, sopt, zopt, ropt
      real x, y, s, z, r
 
      integer i, ii, idx, ipsf
      integer j, jj, idy, jpsf
 
      integer L, Ls
      integer i_l(25)
      integer j_l(25)
      real    p_l(25)
      real    f_l(25)
      real    w_l(25)
 
      character*80 STRING80
      real oloc, ooloc, floc
 
      o  = 0.
      oo = 0.
 
      if (fr.lt.1) return
 
      do i = 01, 41
      do j = 01, 41
         iu = ic + (i-21)
         ju = jc + (j-21)
         pixloc(i,j) = -999
         if (iu.ge.0001.and.iu.le.NAXIS1.and.
     .       ju.ge.0001.and.ju.le.NAXIS1) pixloc(i,j) = pixc(iu,ju)
         enddo
         enddo
 
      do i = 01, 41
      do j = 01, 41
         xpsf = SNGL(ic + (i-21) - xr)
         ypsf = SNGL(jc + (j-21) - yr)
         p = SNGL(fr*rpsf_phot(xpsf,ypsf,psfloc))
         modloc(i,j) = p
         if (pixloc(i,j).gt.-999) pixloc(i,j) = pixloc(i,j)-p
         enddo
         enddo
 
      if (.false.) then
         write(STRING80,'(''lookyloo.'',i4.4,''_'',i4.4,''.fits'')')
     .                      ic, jc
         call writfits_r4(STRING80,pixloc,41,41)
         endif
 
      otot  = 0.
      ootot = 0.
      do i = 01+3, 41-3
      do j = 01+3, 41-3
         if (pixloc(i,j).lt.-900) goto 333
         if ((i-21)**2+(j-21)**2.le.15.5**2.and.
     .       (i-21)**2+(j-21)**2.ge. 2.5**2) then
             do ii = i-2, i+2
             do jj = j-2, j+2
                if (pixloc(ii,jj).lt.-900)        goto 333
                if (pixloc(i,j).lt.pixloc(ii,jj)) goto 333
                enddo
                enddo
             Ls = 0
             do ii = -2, +2
             do jj = -2, +2
                Ls = Ls + 1
                i_l(Ls) = ii
                j_l(Ls) = jj
                p_l(Ls) = pixloc(i+ii,j+jj)
                enddo
                enddo
             ropt = 0.
             sopt = 0.
             zopt = 0.
             xopt = 0.
             yopt = 0.
             do idx = -2, 2
             do idy = -2, 2
                x = i + idx*0.25
                y = j + idy*0.25
                do L = 1, Ls
                   f_l(L) = psfloc(51+4*i_l(L)-idx,
     .                             51+4*j_l(L)-idy)
                   w_l(L) = 1.00
                   enddo
                call linfit(f_l,p_l,w_l,25,s,z,r)
                if (r.gt.ropt) then
                    ropt = r
                    zopt = z
                    sopt = s
                    xopt = x
                    yopt = y
                    endif
                enddo
                enddo
             if (zopt.lt.modloc(i,j)*10) goto 333
 
              floc = 0.
              oloc = 0.
             ooloc = 0.
             do ii = 19, 23
             do jj = 19, 23
                ipsf = int(51 + (ii-xopt)*4 +0.5)
                jpsf = int(51 + (jj-yopt)*4 +0.5)
                f = 0
                if (ipsf.ge.001.and.ipsf.le.101.and.
     .              jpsf.ge.001.and.jpsf.le.101)
     .              f = psfloc(ipsf,jpsf)
                ooloc = ooloc + f*zopt
                floc  =  floc + f
                if (ropt.gt.0.90) then
                    oloc = oloc + zopt*f
                    endif
                enddo
                enddo
             ootot  = ootot  + ooloc
              otot  =  otot  +  oloc
c            write(19,119) ic, jc,
c    .                     i,j,
c    .                     xopt,yopt,ropt,
c    .                     sopt,zopt,zopt/fr,
c    .                     modloc(i,j),
c    .                     oloc/fr, ooloc/fr,
c    .                     floc
c 119        format(1x,i4.4,1x,i4.4,
c    .              1x,i2.2,1x,i2.2,
c    .              1x,f8.3,1x,f8.3,1x,f8.5,
c    .              1x,f8.2,1x,f9.1,1x,f8.4,1x,f9.6,
c    .              5x,f8.5,1x,f8.5,1x,f9.6)
             endif
c        write(19,*)
  333    continue
         enddo
         enddo
 
      o  = SNGL( otot/fr)
      oo = SNGL(ootot/fr)
 
c     print*,'  o: ', o, otot,fr
c     print*,' oo: ',oo,ootot,fr
 
      return
      end
 
 
 
 
 
C      SUBROUTINE LINFIT   (BEVINGTON)
C
C      PURPOSE
C        MAKE A LEAST SQUARES FIT TO DATA WITH A STRAIGHT LINE
C
C      USAGE
C        CALL LINFIT ( X, Y, SIGMAY, NPTS, MODE, A, SIGMAA, B, SIGMAB, R)
C
C      DESCRIPTION OF A PARAMETERS
C        X      - ARRAY OF ADAT POINTS FOR INDEPENDENT VARIABLE
C        Y      - ARRAY OF DATA POINTS FOR DEPENDENT VARIABLE
C        SIGMAY - ARRAY OF STANDARD DEVIATIONS FOR Y DATA POINTS
C        NPTS   - NUMBER OF PAIRS OF DATA POINTS
C        MODE   - DETERMINES METHOD OF WEIGHTING LEAST-SQUARES FIT
C                 +1 (INSTRUMENTAL) WEIGHT(I) = 1./SIGMAY(I)**2
C                  0 (NO WEIGHTING) WEIGHT(I) = 1.
C                 -1 (STATISTICAL)  WEIGHT(I) = 1./Y(I)
C        A      - Y INTERCEPT OF FITTED STRAIGHT LINE
C        SIGMAA - STANDARD DEVIATION OF A
C        B      - SLOPE OF FITTED STRAIGHT LINE
C        SIGMAB - STANDARD DEVIATION OF B
C        R      - LINEAR CORRELATION COEFFICIENT
C
C        SUBROUTINES AND FUNCTION SUBPROGRAMS REQUIRED
C          NONE
C
C        MODIFICATIONS FOR FORTRAN II
C          OMIT DOUBLE PRECISION SPECIFICATIONS
C          CHANGE DSQRT TO SQRTF IN STATEMENTS 67, 68, AND 71
 
      SUBROUTINE LINFIT(X,Y,WT,NPTS,A,B,R)
      INTEGER NPTS
      REAL SUM, SUMX, SUMY, SUMX2, SUMXY, SUMY2
      REAL DELTA
      REAL X(*), Y(*), WT(*)
      real r
C
C     ACCUMULATE WEIGHTED SUMS
C         ----> weight by 1/sqrt(y)
 
 
      SUM = 0
      SUMX = 0
      SUMY = 0
      SUMX2 = 0
      SUMXY = 0
      SUMY2 = 0
      DO 59  I = 1, NPTS
           XI = X(I)
           YI = Y(I)
           SUM   = SUM   + 1    *wt(i)
           SUMX  = SUMX  + XI   *wt(i)
           SUMY  = SUMY  + YI   *wt(i)
           SUMX2 = SUMX2 + XI*XI*wt(i)
           SUMXY = SUMXY + XI*YI*wt(i)
           SUMY2 = SUMY2 + YI*YI*wt(i)
   59 CONTINUE
C
C                CALCULATE COEFFICIENTS AND STANDARD DEVIATIONS
C
 
      DELTA = SUM*SUMX2 - SUMX*SUMX
      A = (SUMX2*SUMY - SUMX*SUMXY) / DELTA
      B = (SUMXY*SUM  - SUMX*SUMY ) / DELTA
      R = 0.00
      IF (DELTA*(SUM*SUMY2 - SUMY*SUMY).GE.0) THEN
          R = (SUM*SUMXY - SUMX*SUMY) /
     C        SQRT(DELTA*(SUM*SUMY2 - SUMY*SUMY))
          ENDIF
 
 
      RETURN
      END
 
 
 
C      SUBROUTINE LINFIT   (BEVINGTON)
C
C      PURPOSE
C        MAKE A LEAST SQUARES FIT TO DATA WITH A STRAIGHT LINE
C
C      USAGE
C        CALL LINFIT ( X, Y, SIGMAY, NPTS, MODE, A, SIGMAA, B, SIGMAB, R)
C
C      DESCRIPTION OF A PARAMETERS
C        X      - ARRAY OF ADAT POINTS FOR INDEPENDENT VARIABLE
C        Y      - ARRAY OF DATA POINTS FOR DEPENDENT VARIABLE
C        SIGMAY - ARRAY OF STANDARD DEVIATIONS FOR Y DATA POINTS
C        NPTS   - NUMBER OF PAIRS OF DATA POINTS
C        MODE   - DETERMINES METHOD OF WEIGHTING LEAST-SQUARES FIT
C                 +1 (INSTRUMENTAL) WEIGHT(I) = 1./SIGMAY(I)**2
C                  0 (NO WEIGHTING) WEIGHT(I) = 1.
C                 -1 (STATISTICAL)  WEIGHT(I) = 1./Y(I)
C        A      - Y INTERCEPT OF FITTED STRAIGHT LINE
C        SIGMAA - STANDARD DEVIATION OF A
C        B      - SLOPE OF FITTED STRAIGHT LINE
C        SIGMAB - STANDARD DEVIATION OF B
C        R      - LINEAR CORRELATION COEFFICIENT
C
C        SUBROUTINES AND FUNCTION SUBPROGRAMS REQUIRED
C          NONE
C
C        MODIFICATIONS FOR FORTRAN II
C          OMIT DOUBLE PRECISION SPECIFICATIONS
C          CHANGE DSQRT TO SQRTF IN STATEMENTS 67, 68, AND 71
 
      SUBROUTINE LINFIT1(X,Y,NPTS,A,B,R)
      INTEGER NPTS
      REAL SUM, SUMX, SUMY, SUMX2, SUMXY, SUMY2
      REAL DELTA
      DIMENSION X(1), Y(1)
 
      SUM = 0
      SUMX = 0
      SUMY = 0
      SUMX2 = 0
      SUMXY = 0
      SUMY2 = 0
      DO 59  I = 1, NPTS
           XI = X(I)
           YI = Y(I)
           SUM   = SUM   + 1
           SUMX  = SUMX  + XI
           SUMY  = SUMY  + YI
           SUMX2 = SUMX2 + XI*XI
           SUMXY = SUMXY + XI*YI
           SUMY2 = SUMY2 + YI*YI
   59 CONTINUE
C
C                CALCULATE COEFFICIENTS AND STANDARD DEVIATIONS
C
 
      DELTA = SUM*SUMX2 - SUMX*SUMX
      A = (SUMX2*SUMY - SUMX*SUMXY) / DELTA
      B = (SUMXY*SUM  - SUMX*SUMY ) / DELTA
      R = 0.00
      IF (DELTA*(SUM*SUMY2 - SUMY*SUMY).GE.0) THEN
          R = (SUM*SUMXY - SUMX*SUMY) /
     C        SQRT(DELTA*(SUM*SUMY2 - SUMY*SUMY))
          ENDIF
 
      RETURN
      END
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/HST1PASS/ROUTINES/readmat2trans.f"
c****                                         
c*********************************************
                                              
 
 
 
      subroutine readmat2trans(MATFILE,Ls_mat,
     .                         AG_mat,BG_mat,CG_mat,DG_mat,
     .                         x1o_mat,y1o_mat,
     .                         x2o_mat,y2o_mat,
     .                         ZP_mat)
      implicit none
 
      character*80 MATFILE
      integer Ls_mat
      real*8  AG_mat,BG_mat,CG_mat,DG_mat
      real*8  x1o_mat, y1o_mat
      real*8  x2o_mat, y2o_mat
      real*8  ZP_mat
 
      real*8  x1_l(99999), y1_l(99999)
      real*8  x2_l(99999), y2_l(99999)
      real*8  m1_l(99999), m2_l(99999)
      integer Ls, Lu
      real    dm_l(99999), dmbar, dmsig
 
      character*200 STRING200
 
 
      open(11,file=MATFILE,status='old')
 
      Ls = 0
    1 read(11,'(a200)',end=2) STRING200
      if (STRING200(1:1).eq.'#') goto 1
      Ls = Ls + 1
      if (Ls.gt.99999) stop 'MATFILE has more than 99999 stars!'
      read(STRING200,*) x1_l(Ls), y1_l(Ls), x2_l(Ls), y2_l(Ls),
     .                  m1_l(Ls), m2_l(Ls)
      dm_l(Ls) = SNGL(m2_l(Ls)-m1_l(Ls))
      goto 1
    2 close(11)
 
      call glob_fit6nrDP(x1_l,y1_l,x2_l,y2_l,Ls,
     .                   AG_mat,BG_mat,CG_mat,DG_mat,
     .                   x1o_mat,y1o_mat,
     .                   x2o_mat,y2o_mat)
 
      call rbarsigs(dm_l,Ls,dmbar,dmsig,Lu,2.75)
 
c      write(*,'('' '')')
c      write(*,'(''    Ls: '',i5)')
c      write(*,'('' '')')
c      write(*,'(''    AB: '',2f12.7)') AG_mat, BG_mat
c      write(*,'(''    CD: '',2f12.7)') CG_mat, DG_mat
c      write(*,'('' '')')
c      write(*,'(''    x1: '',2f12.7)') x1o_mat, y1o_mat
c      write(*,'(''    x2: '',2f12.7)') x2o_mat, y2o_mat
c      write(*,'('' '')')
c      write(*,'(''    dM: '',2f12.7,2i6)') dmbar,dmsig,Ls,Lu
c      write(*,'('' '')')
 
      ZP_mat = dmbar
      Ls_mat = Ls
 
      return
      end
 
 
 
c--------------------------------------------------------------
c
c this routine does a least squares solution (with no
c data rejection or weighting) for the 6-param linear
c fit for:
c
c
c    x2 = A*(x1-x1o) + B*(y1-y1o) + x2o
c    y2 = C*(x1-x1o) + D*(y1-y1o) + y2o
c
c it may look like there are 8 params, but two of the
c offsets are arbitrary and are just set to the centroid
c of the distribution.
c
c
 
      subroutine glob_fit6nrDP(x1,y1,x2,y2,NUSE,
     .                         A,B,C,D,x1o,y1o,x2o,y2o)
      implicit none
 
      real*8 x1(*), y1(*)
      real*8 x2(*), y2(*)
      integer NUSE
      real*8 A, B, C, D
      real*8 x1o, y1o, x2o, y2o
 
      real*8 sxx, sx, swx, szx
      real*8 syy, sy, swy, szy
      real*8 sw,  sz, sxy
      real*8 dlta
      real*8 dsxx, dsyy, dsxy
      real*8 dswx, dswy, dszx, dszy
 
      integer n
 
      if (NUSE.lt.3) goto 999
 
      x1o = 0
      y1o = 0
      x2o = 0
      y2o = 0
      do n = 1, NUSE
         x1o = x1o + x1(n)
         y1o = y1o + y1(n)
         x2o = x2o + x2(n)
         y2o = y2o + y2(n)
         enddo
 
      x1o = x1o/NUSE
      y1o = y1o/NUSE
      x2o = x2o/NUSE
      y2o = y2o/NUSE
 
      sxx = 0.0
      sx  = 0.0
      syy = 0.0
      sy  = 0.0
      swx = 0.0
      swy = 0.0
      szx = 0.0
      szy = 0.0
      sw  = 0.0
      sz  = 0.0
      sxy = 0.0
      do n = 1, NUSE
         sxy = sxy + (x1(n)-x1o)*(y1(n)-y1o)
         sxx = sxx + (x1(n)-x1o)*(x1(n)-x1o)
         sx  = sx  + (x1(n)-x1o)
         syy = syy + (y1(n)-y1o)*(y1(n)-y1o)
         sy  = sy  + (y1(n)-y1o)
         swx = swx + (x2(n)-x2o)*(x1(n)-x1o)
         swy = swy + (x2(n)-x2o)*(y1(n)-y1o)
         sw  = sw  + (x2(n)-x2o)
         szx = szx + (y2(n)-y2o)*(x1(n)-x1o)
         szy = szy + (y2(n)-y2o)*(y1(n)-y1o)
         sz  = sz  + (y2(n)-y2o)
         enddo
 
 
      dsxx = sx*sx - NUSE*sxx
      dsyy = sy*sy - NUSE*syy
      dsxy = sx*sy - NUSE*sxy
 
      dlta = dsxx*dsyy - dsxy*dsxy
 
      if (dlta.eq.0) goto 999
 
      dswx = sw*sx - NUSE*swx
      dswy = sw*sy - NUSE*swy
      dszx = sz*sx - NUSE*szx
      dszy = sz*sy - NUSE*szy
 
      A =   (dswx*dsyy-dswy*dsxy)/dlta
      B =   (dswy*dsxx-dswx*dsxy)/dlta
      C =   (dszx*dsyy-dszy*dsxy)/dlta
      D =   (dszy*dsxx-dszx*dsxy)/dlta
 
      return
 
 999  continue
      A  = 1
      B  = 0
      C  = 0
      D  = 1
      x1o = 0
      y1o = 0
      x2o = 0
      y2o = 0
      return
      end
 
 
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_i2e.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------------------------
c
c read in an i2 image with extensions
c
      subroutine readfits_i2e(FILEI,pix,NDIMX,NDIMY,NEXTENU)
      implicit none
 
      character*(*) FILEI
      integer   NDIMX,NDIMY
      integer   NEXTENU
      integer*2 pix(NDIMX,NDIMY)
 
      character*199 FILEU
      character*070 INFO(10)
c     common / fitsinfo / INFO
 
      integer naxes
      integer laxis(3)
      integer NXF
      integer NYF
 
      character*8  field
      character*40 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
c     integer j
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
      character*70 HDR(25)
c     common/HDR/HDR
 
      logical DIAG
      data DIAG /.false./
      integer NEND
      integer ii, jj
 
      FILEU = FILEI
      do i = 195,2,-1
         if (FILEI(i:i+4).eq.'.fits') then
            FILEU = FILEI(1:i+4)
            do ii = i+5, 80
               FILEU(ii:ii) = ' '
               enddo
            endif
         enddo
 
      if (DIAG) then
         print*,'enter readfits_i2e...'
         write(*,'(''FILEI: '',80a)') FILEI
         write(*,'(''FILEU: '',80a)') FILEU
         endif
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened'
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
 
      BSCALE = 1.0
      BZERO  = 0.0
 
      NEXTEND = 0
      NEND = -1
      i = 0
      nread = 0
 100  continue
      i = i + 1
      if (DIAG) print*,'READREC: ',i
      read(10,rec=i,iostat=ios) buffc
      do k = 0, 35, 1
         if (DIAG) write(*,'(i8,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+51)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'EXPTIME ') INFO(1) = stream
         if (field.eq.'FILTNAM1') INFO(2) = stream
         if (field.eq.'FILENAME') INFO(3) = stream
         if (field.eq.'DATE-OBS') INFO(4) = stream
         if (field.eq.'TIME-OBS') INFO(5) = stream
         if (field.eq.'DEC_TARG') INFO(6) = stream
         if (field.eq.'RA_TARG ') INFO(7) = stream
         if (field.eq.'DEC_DEG ') INFO(6) = stream
         if (field.eq.'RA_DEG  ') INFO(7) = stream
         if (field.eq.'PA_V3   ') INFO(8) = stream
         if (field.eq.'PROPOSID') INFO(9) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'RA_DEG  ') HDR(19) = stream
         if (field.eq.'DEC_DEG ') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER1 ') HDR(22) = stream
         if (field.eq.'FILTER2 ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
         if (field.eq.'CCDGAIN ') HDR(25) = stream
         if (field.eq.'END     ') then
            if (NEXTENU.gt.NEXTEND.and.NEXTENU.gt.1) then
               print*,'                     '
               write(*,'(''readfits_i2e: '',80a)') FILEI
               print*,'     NEXTENU.lt.NEXTEND...'
               print*,'     ---> NEXTEND: ',NEXTEND
               print*,'     ---> NEXTENU: ',NEXTENU
               print*,'                          '
               stop
               endif
            NEND = NEND + 1
            if (NEND.ge.1) goto 101
            endif
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,' '
         print*,'----------------------------------------'
         print*,'   NREAD: ',nread
         print*,' NEXTEND: ',nextend
         print*,' NEXTENU: ',nextenu
         print*,'   NAXIS: ',naxes
         print*,'   LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,'  BITPIX: ',bitpix
         print*,'  BSCALE: ',bscale
         print*,'   BZERO: ',bzero
         print*,'   NDIMX: ',NDIMX
         print*,'   NDIMY: ',NDIMY
         print*,' '
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      NXF = laxis(1)
      NYF = laxis(2)
 
      nbper  = 2*laxis(1)*laxis(2)
      if (BITPIX.eq.  8) nbper = 1*laxis(1)*laxis(2)
      if (BITPIX.eq. 32) nbper = 4*laxis(1)*laxis(2)
      if (BITPIX.eq.-32) nbper = 4*laxis(1)*laxis(2)
      if (BITPIX.eq.-64) nbper = 8*laxis(1)*laxis(2)
 
      npt    =   laxis(1)*laxis(2)
      npt    =   min(NDIMX*NDIMY,npt)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (DIAG) then
          print*,'  i : ',i
          print*,'  i1: ',i1
          print*,'  i2: ',i2
          print*,' npt: ',npt
          print*,'NEND: ',NEND,NEXTENU,BITPIX
          endif
 
 
c     print*,'NEND: ',NEND,NEXTENU,BITPIX
      if (NEND.ne.NEXTENU) then
          if (naxes.ne.0) i = i2
          goto 100
          endif
 
      if (DIAG) then
          print*,' '
          print*,'OK!  TIME TO READ...'
          print*,'      i1: ',i1
          print*,'      i2: ',i2
          print*,'     npt: ',npt
          print*,'   NDIMX: ',NDIMX
          print*,'   NDIMY: ',NDIMY
          print*,' '
          endif
 
      if (BITPIX.ne.16) then
         print*,' '
         print*,'Problem in readfits_i2e...'
         print*,' '
         print*,'   FILEI: ',FILEI
         print*,'   NDIMX: ',NDIMX
         print*,'   NDIMY: ',NDIMY
         print*,' NEXTENU: ',NEXTENU
         print*,'  BITPIX: ',BITPIX
         print*,'            prob... BITPIX be 16 for readfits_i2e...'
         print*,' '
         do ii = 1, NDIMX
         do jj = 1, NDIMY
            pix(ii,jj) = 0
            enddo
            enddo
         stop
         endif
 
      do i = i1, i2, 1
         if (DIAG) write(*,1115) i
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/2 + 1
         np2 = (nbyteE-nbyte1)/2 + 1
         if (DIAG) write(*,1115) i,np1,np2,npt
         call buff2pix_i2e(buffb,pix,np1,npt)
         if (DIAG) write(*,1115) i,np1,np2,npt,i/laxis(1)
 1115    format(1x,i8,1x,i10,1x,i10,1x,i10,1x,i6.6)
         enddo
 
 
      close(10)
      return
 
 900  continue
      print*,'FILEU: ',FILEU
      print*,'READFITS_I2E ERROR'
      stop
 
      end
 
 
 
 
      subroutine buff2pix_i2e(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      integer*2 pix(*)
      integer n1,nt
 
      byte b(2)
      integer*2 ii
      equivalence(ii,b)
 
      integer i, npu, nbu
 
      logical islinux
 
      do i = 1, 1440
         npu = n1+i-1
         nbu = (i-1)*2
         if (.not.islinux()) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            endif
         if (islinux()) then
            b(2) = buff(nbu+1)
            b(1) = buff(nbu+2)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = ii
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_i4e.f"
c****                                         
c*********************************************
                                              
 
c----------------------------------------------------------
c
c read in an i4 image with extensions
c
 
      subroutine readfits_i4e(FILEI,pix,NDIMX,NDIMY,NEXTENU)
      implicit none
 
      character*200 FILEI
      integer       NDIMX,NDIMY
      integer       NEXTENU
      integer*4     pix(NDIMX,NDIMY)
 
      character*200 FILEU
      character*070 INFO(10)
      common / fitsinfo / INFO
 
      integer naxes
      integer laxis(3)
      integer NXF
      integer NYF
 
      character*8  field
      character*40 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
      integer j
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real*8 bscale, bzero
      integer bitpix
 
      character*70 HDR(25)
      common/HDR/HDR
 
      logical DIAG
      data DIAG /.false./
      integer NEND
      integer ii
 
      FILEU = FILEI
      do i = 195,2,-1
         if (FILEI(i:i+4).eq.'.fits') then
            FILEU = FILEI(1:i+4)
            do ii = i+5, 200
               FILEU(ii:ii) = ' '
               enddo
            endif
         enddo
 
      if (DIAG) then
         print*,'enter readfits_i2e...'
         write(*,'(''FILEI: '',200a)') FILEI
         write(*,'(''FILEU: '',200a)') FILEU
         endif
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened'
 
      naxes = -1
      laxis(1) = 0
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
 
      BSCALE = 1.0
      BZERO  = 0.0
 
      NEXTEND = 999
      NEND = -1
      i = 0
      nread = 0
 100  continue
      i = i + 1
      if (DIAG) print*,'READREC: ',i
      read(10,rec=i,iostat=ios) buffc
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+51)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'EXPTIME ') INFO(1) = stream
         if (field.eq.'FILTNAM1') INFO(2) = stream
         if (field.eq.'FILENAME') INFO(3) = stream
         if (field.eq.'DATE-OBS') INFO(4) = stream
         if (field.eq.'TIME-OBS') INFO(5) = stream
         if (field.eq.'DEC_TARG') INFO(6) = stream
         if (field.eq.'RA_TARG ') INFO(7) = stream
         if (field.eq.'DEC_DEG ') INFO(6) = stream
         if (field.eq.'RA_DEG  ') INFO(7) = stream
         if (field.eq.'PA_V3   ') INFO(8) = stream
         if (field.eq.'PROPOSID') INFO(9) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'RA_DEG  ') HDR(19) = stream
         if (field.eq.'DEC_DEG ') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER1 ') HDR(22) = stream
         if (field.eq.'FILTER2 ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
         if (field.eq.'CCDGAIN ') HDR(25) = stream
         if (field.eq.'END     ') then
            if (NEXTENU.gt.NEXTEND) then
               print*,'                     '
               write(*,'(''readfits_i2e: '',80a)') FILEI
               print*,'     NEXTENU.lt.NEXTEND...'
               print*,'     ---> NEXTEND: ',NEXTEND
               print*,'     ---> NEXTENU: ',NEXTENU
               print*,'                          '
               stop
               endif
            NEND = NEND + 1
            if (NEND.ge.1) goto 101
            endif
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,' '
         print*,'----------------------------------------'
         print*,'   NREAD: ',nread
         print*,' NEXTEND: ',nextend
         print*,' NEXTENU: ',nextenu
         print*,'   NAXIS: ',naxes
         print*,'   LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,'  BITPIX: ',bitpix
         print*,'  BSCALE: ',bscale
         print*,'   BZERO: ',bzero
         print*,'   NDIMX: ',NDIMX
         print*,'   NDIMY: ',NDIMY
         print*,' '
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      NXF = laxis(1)
      NYF = laxis(2)
 
      nbper  = 4*laxis(1)*laxis(2)
      npt    =   laxis(1)*laxis(2)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
c     print*,'NEND: ',NEND,NEXTENU,BITPIX
      if (NEND.ne.NEXTENU) goto 100
 
      if (NAXES.eq.0) return
 
      if (BITPIX.ne.32) then
         print*,'readfits_i4e: '
         print*,'BITPIX: ',BITPIX
         print*,'prob'
         stop
         endif
 
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         call buff2pix_i4e(buffb,pix(1,1),np1,npt)
         if (DIAG) write(*,1115) i,np1,np2,npt,i/laxis(1)
 1115    format(1x,i8,1x,i10,1x,i10,1x,i10,1x,i6.6)
         enddo
 
c      if (BZERO.ne.0) then
c          print*,'   BZERO: ',BZERO
c          print*,'  BSCALE: ',BSCALE
c          print*,'pix(1712,1408): ',pix(1712,1408)
c          print*,'pix(1712,1418): ',pix(1712,1418)
c          print*,'pix(1614,1485): ',pix(1614,1485)
c          endif
 
      close(10)
 
      do i = 1, NDIMX
      do j = 1, NDIMY
         pix(i,j) = int(BZERO + BSCALE*pix(i,j))
         enddo
         enddo
 
c     if (BZERO.ne.0) then
c         print*,'   BZERO: ',BZERO
c         print*,'  BSCALE: ',BSCALE
c         print*,'pix(1712,1408): ',pix(1712,1408)
c         print*,'pix(1712,1418): ',pix(1712,1418)
c         print*,'pix(1614,1485): ',pix(1614,1485)
c         endif
 
      close(10)
      return
 
 900  continue
      print*,'readfits_i4e ERROR'
      stop
 
      end
 
 
 
 
      subroutine buff2pix_i4e(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      integer*4 pix(*)
      integer n1,nt
 
      byte b(4)
      integer ii
      equivalence(ii,b)
 
      integer i, npu, nbu
      logical islinux
 
      do i = 0001, 0720
         npu = n1+i-1
         nbu = (i-1)*4
         if (.not.(islinux())) then
             b(1) = buff(nbu+1)
             b(2) = buff(nbu+2)
             b(3) = buff(nbu+3)
             b(4) = buff(nbu+4)
            else
             b(4) = buff(nbu+1)
             b(3) = buff(nbu+2)
             b(2) = buff(nbu+3)
             b(1) = buff(nbu+4)
             endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = ii
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_r4_4D.f"
c****                                         
c*********************************************
                                              
 
 
c------------------------------------------------------
c
c
c
      subroutine readfits_r4_4D(FILE,pix,N1,N2,N3,N4)
      implicit none
 
      character*80 FILE
      integer N1, N2, N3, N4
      real*4  pix(N1,N2,N3,N4)
 
      integer naxes
      integer laxis(4)
 
      character*8  field
      character*20 stream
 
      real    pixu
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
      integer ii, jj, kk, ll
      integer n
      integer N1U, N2U, N3U, N4U
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      real*4 rbuff(720)
 
      integer ifirst, i1, i2
      integer j
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
      integer r2i
 
      logical LINUX
      data LINUX/.true./
      logical DIAG
      data DIAG /.false./
 
 
      character*80 FILEU
 
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened'
 
      bscale = 1
      bzero  = 0
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      laxis(4) = 1
      nextend = 0
 
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buffc
      if (DIAG) print*,'READREC: ',i
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+31)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NAXIS4  ') read(stream,*) laxis(4)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
         if (field.eq.'END     ') goto 101
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,'----------------------------------------'
         print*,'  NREAD: ',nread
         print*,'NEXTEND: ',nextend
         print*,'  NAXIS: ',naxes
         print*,'  LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,' BITPIX: ',bitpix
         print*,' BSCALE: ',bscale
         print*,'  BZERO: ',bzero
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      if (BITPIX.ne.-32) then
         print*,'readfits_r4...: '
         print*,'                '
         print*,'   you called a routine to read in an'
         print*,'   real*4 mage, and the image you'
         print*,'   gave it has BITPIX = ',BITPIX
         print*,'   '
         print*,'   FILEU: ',FILEU
         print*,'   '
         stop
         endif
 
      nbper = 4*laxis(1)*laxis(2)*laxis(3)*laxis(4)
      npt   =   laxis(1)*laxis(2)*laxis(3)*laxis(4)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (laxis(1).ne.N1.or.
     .    laxis(2).ne.N2.or.
     .    laxis(3).ne.N3.or.
     .    laxis(4).ne.N4) then
         write(*,'(''readfits_r4_4D: '',80a)') FILE
         write(*,'(''readfits_r4_4D: '',80a)') FILEU
         print*,' '
         print*,'  laxis1: ',laxis(1)
         print*,'      N1: ',N1
         print*,' '
         print*,'  laxis2: ',laxis(2)
         print*,'      N2: ',N2
         print*,' '
         print*,'  laxis3: ',laxis(3)
         print*,'      N3: ',N3
         print*,' '
         print*,'  laxis4: ',laxis(4)
         print*,'      N4: ',N4
         print*,' '
         stop
         endif
 
      N1U = laxis(1)
      N2U = laxis(2)
      N3U = laxis(3)
      N4U = laxis(4)
 
      if (DIAG) then
         print*,'     N1: ',N1
         print*,'     N2: ',N2
         print*,'     N3: ',N3
         print*,'     N4: ',N4
         print*,'  NBPER: ',nbper
         print*,'  NBYT1: ',nbyte1
         print*,'  NBYT2: ',nbyte2
         print*,' IFIRST: ',ifirst
         print*,'     I1: ',i1
         print*,'     I2: ',i2
         print*,'    NPT: ',NPT
         endif
 
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         np2 = min(np2,npt)
         call buff2pix_r4_4D(buffb,rbuff,0001,0720)
         do n = np1, np2, 1
            ll = n/(N1U*N2U*N3U)
            kk = (n-ll*N1U*N2U*N3U)/N1U/N2U
            jj = (n-ll*N1U*N2U*N3U-kk*N1U*N2U)/N1U
            ii =  n-ll*N1U*N2U*N3U-kk*N1U*N2U-jj*N1U
            pixu = rbuff(n-np1+1)*bscale+bzero
            pix(ii,jj+1,kk+1,ll+1) = pixu
            enddo
         enddo
 
      if (DIAG) then
         print*,'  NBPER: ',nbper
         print*,'  NBYT1: ',nbyte1
         print*,'  NBYT2: ',nbyte2
         print*,' IFIRST: ',ifirst
         print*,'     I1: ',i1
         print*,'     I2: ',i2
         print*,'    NPT: ',NPT
         endif
 
 
      close(10)
      return
 
 900  continue
      print*,' '
      print*,'subroutine readfits_r4_4D'
      print*,' '
      print*,'  FILE OPEN ERROR'
      print*,'  FILE : ',FILE
      print*,'  FILEU: ',FILEU
      print*,' '
      stop
 
      end
 
 
 
      subroutine buff2pix_r4_4D(buff,pix,n1,nt)
      implicit none
      byte    buff(2880)
      real*4  pix(720)
      integer n1,nt
 
      byte   b(4)
      real*4 r
      equivalence(r,b)
 
      integer i, npu, nbu
      logical islinux
 
      do i = 0001, 0720
         npu = n1+i-1
         nbu = (i-1)*4
         if (.not.islinux()) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            b(3) = buff(nbu+3)
            b(4) = buff(nbu+4)
            endif
         if (islinux()) then
            b(4) = buff(nbu+1)
            b(3) = buff(nbu+2)
            b(2) = buff(nbu+3)
            b(1) = buff(nbu+4)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = r
         enddo
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/rdate_header.f"
c****                                         
c*********************************************
                                              
 
 
      real*8 function rdate_header(FILENAME)
      implicit none
 
      integer i
      character filename*200
c     integer NCHAR
 
c     integer iEXPT
c     real    rEXPT
      integer iPA
      real    rPA
      integer iPID
c     character*6 FILTSTR
c     character*9 ROOTSTR
      real rRA
      real rDEC
 
      character*20 DATESTR
      character*20 TIMESTR
 
      integer       iMIN, iSEC
c     character decsgn
c     real    rRA0, rDC0
c     real    dRA
      real    rSUNA
      real    rTEMP
c     real    vaFAC
 
      integer iDAY
      integer iMON
      integer iYIR
      integer iHRS
 
      real*8  rDAT
 
      character*8  field
      character*20 stream
 
      integer ios, k
 
      character*2880 buff
 
      integer nread
 
 
c     character*11 OBJNAME
 
      integer DOY(12)
      data DOY / 000, 031, 059, 090, 120, 151,
     .           181, 212, 243, 273, 304, 334/
 
 
c     character*8 CHINJVAL
 
      rdate_header = 0.0
 
      DATESTR  = 'DATELESS'
      TIMESTR  = 'TIMELESS'
      rRA  = 0.
      rDEC = 0.
      iPID = 0
      iPA  = 0
      rPA  = 0
      rSUNA = 0.
      rTEMP = 0.
 
      open(10,file=FILENAME,status='old',
     .  err=900,recl=2880,form='UNFORMATTED',
     .  access='DIRECT')
 
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buff
      if (ios.lt.0) goto 900
      do k = 0, 35, 1
         field  = buff(k*80+01:k*80+08)
         stream = buff(k*80+11:k*80+31)
         if (field.eq.'TIME-OBS') TIMESTR = stream(01:20)
         if (field.eq.'DATE-OBS') DATESTR = stream(01:20)
         if (field.eq.'END     ') goto 101
         enddo
      goto 100
  101 close(10)
 
      if (DATESTR(06:06).eq.'-'.and.DATESTR(09:09).eq.'-')
     .                    DATESTR = DATESTR(02:13)
      if (DATESTR(07:07).eq.'-'.and.DATESTR(10:10).eq.'-')
     .                    DATESTR = DATESTR(03:14)
      if (DATESTR(08:08).eq.'-'.and.DATESTR(11:11).eq.'-')
     .                    DATESTR = DATESTR(04:15)
      if (TIMESTR(04:04).eq.':'.and.TIMESTR(07:07).eq.':')
     .                    TIMESTR = TIMESTR(02:09)
      if (TIMESTR(05:05).eq.':'.and.TIMESTR(05:05).eq.':')
     .                    TIMESTR = TIMESTR(03:10)
 
      if (DATESTR.eq.'DATELESS') return
      if (TIMESTR.eq.'TIMELESS') return
 
      if (DATESTR.ne.'DATELESS') then
         read(DATESTR(01:04),*) iYIR
         read(DATESTR(06:07),*) iMON
         if (iMON.lt.01.or.iMON.gt.12) then
            print*,'---> iMON: ',iMON
            print*,'---> DATE: ',DATESTR
            stop
            endif
         read(DATESTR(09:10),*) iDAY
         endif
 
      if (TIMESTR.ne.'TIMELESS') then
         read(TIMESTR(1:2),*) iHRS
         read(TIMESTR(4:5),*) iMIN
         read(TIMESTR(7:8),*) iSEC
         endif
 
 
      rDAT = iYIR + (DOY(iMON)+iDAY)/365.0d0
      rDAT = rDAT + (iHRS + iMIN/60. + iSEC/60./60.)/8766.d0
 
      rdate_header = rDAT
 
      return
 
  900 continue
      print*,'               '
      print*,'rdate_header...'
      print*,'   PROBLEM OPENING FILE: ',FILENAME
      print*,'               '
      stop
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/WFC3IR/read_wfc3ir_flt_full.f"
c****                                         
c*********************************************
                                              
 
 
      subroutine read_wfc3ir_flt_full_simpl(FILENAME,pixr)
      implicit none
 
      character*200 FILENAME
      real          pixr(1014,1014)
      real          pixo(1014,1014)
 
      real*8    CRPIX1, CRPIX2
      real*8    CRVAL1, CRVAL2
      real*8    CD1_1,  CD1_2
      real*8    CD2_1,  CD2_2
 
      integer   LOFLAG, HIFLAG
      real*8    BDRY_XR(4,4)
      real*8    BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
 
      call read_wfc3ir_flt_full(FILENAME,pixr,pixo,
     .                          CRPIX1, CRPIX2,
     .                          CRVAL1, CRVAL2,
     .                          CD1_1,  CD1_2,
     .                          CD2_1,  CD2_2,
     .                          LOFLAG, HIFLAG,
     .                          BDRY_XR,BDRY_YR,
     .                          FILT,EXPT,RDAT,PROP)
 
      return
      end
 
 
      subroutine read_wfc3ir_flt_full(FILENAME,pixr,pixo,
     .                                CRPIX1, CRPIX2,
     .                                CRVAL1, CRVAL2,
     .                                CD1_1,  CD1_2,
     .                                CD2_1,  CD2_2,
     .                                LOFLAG, HIFLAG,
     .                                BDRY_XR,BDRY_YR,
     .                                FILT,EXPT,RDAT,PROP)
      implicit none
 
      character*200 FILENAME
      real      pixr(1014,1014)
      real      pixo(1014,1014)
 
      real*8    CRPIX1, CRPIX2
      real*8    CRVAL1, CRVAL2
      real*8    CD1_1,  CD1_2
      real*8    CD2_1,  CD2_2
 
      integer   LOFLAG, HIFLAG
      real*8    BDRY_XR(4,4)
      real*8    BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
 
 
c
c-----------------------------------
c
 
c     real      pix(1014,1014)
c     real      pmax
c     integer*2 pox(1014,1014)
c     integer   pux(1014,1014)
      integer  i, j
      integer ii,jj
c     real xsum, ysum
c     real xbar, ybar
c     real mbar_sky
      character*70 INFO(10)
      common / fitsinfo / INFO
 
c     real EXPTIME
c     integer k
c     real pval
c     integer ival
 
      real      pixi(1014,1014)
      real      pixh(1014,1014)
      integer*2 pixi2(1014,1014)
      integer   pixi2_l
 
      real*4,    dimension(:,:), allocatable ::  pixi_sub
      integer*2, dimension(:,:), allocatable :: pixi2_sub
 
 
      real rsum
      real dd
c     integer Ls
c     real    plist(9)
c     integer*2 i2
 
      character*20 STREAM
      character*20 STRING_APER
      integer i4_query_hdre
      real*4  r4_query_hdre
      real*8  r8_query_hdre
      real*8  rdate_header
      real*8  PA_APER
      real*8  PA_V3
      real*8  COSPA, SINPA
 
c
c--------------------------------------------------
c
 
      do i = 0001, 1014
      do j = 0001, 1014
         pixi(i,j)  = -50.0
         pixi2(i,j) =   0
         enddo
         enddo
 
      call query_hdre_r8(FILENAME,'CRPIX1  ',CRPIX1,-1)
      call query_hdre_r8(FILENAME,'CRPIX2  ',CRPIX2,-1)
      call query_hdre_r8(FILENAME,'CRVAL1  ',CRVAL1,-1)
      call query_hdre_r8(FILENAME,'CRVAL2  ',CRVAL2,-1)
c     call query_hdre_r8(FILENAME,'CD1_1   ',CD1_1,-1)
c     call query_hdre_r8(FILENAME,'CD1_2   ',CD1_2,-1)
c     call query_hdre_r8(FILENAME,'CD2_1   ',CD2_1,-1)
c     call query_hdre_r8(FILENAME,'CD2_2   ',CD2_2,-1)
 
      call query_hdre(FILENAME,'APERTURE',STRING_APER,-1)
 
      if (STRING_APER(2:9).eq.'IRSUB512') then                  ! this works for IRSUB512 and IRSUB512-FIX
          print*,'WFC3IR SPECIAL APERTURE: ',STRING_APER(2:20)
          allocate( pixi_sub(512,512))
          allocate(pixi2_sub(512,512))
          call readfits_r4e(FILENAME, pixi_sub,512,512,1)
          call readfits_i2e(FILENAME,pixi2_sub,512,512,3)
          do i = 001, 512
          do j = 001, 512
              pixi(i+251,j+251) =  pixi_sub(i,j)
             pixi2(i+251,j+251) = pixi2_sub(i,j)
             enddo
             enddo
          CRPIX1 = CRPIX1 + 251
          CRPIX2 = CRPIX2 + 251
          LOFLAG = LOFLAG*4
          HIFLAG = HIFLAG*4
          deallocate( pixi_sub)
          deallocate(pixi2_sub)
          goto 3
          endif
 
      if (STRING_APER(2:9).eq.'IRSUB256') then                   ! this works for IRSUB256 and IRSUB256-FIX
          print*,'WFC3IR SPECIAL APERTURE: ',STRING_APER(2:20)
          allocate( pixi_sub(256,256))
          allocate(pixi2_sub(256,256))
          call readfits_r4e(FILENAME, pixi_sub,256,256,1)
          call readfits_i2e(FILENAME,pixi2_sub,256,256,3)
          do i = 001, 256
          do j = 001, 256
              pixi(i+379,j+379) =  pixi_sub(i,j)
             pixi2(i+379,j+379) = pixi2_sub(i,j)
             enddo
             enddo
          CRPIX1 = CRPIX1 + 379
          CRPIX2 = CRPIX2 + 379
          LOFLAG = LOFLAG*16
          HIFLAG = HIFLAG*16
          deallocate( pixi_sub)
          deallocate(pixi2_sub)
          goto 3
          endif
 
      if (STRING_APER(2:9).eq.'IRSUB128') then                  ! this works for IRSUB128 and IRSUB128-FIX
          print*,'WFC3IR SPECIAL APERTURE: ',STRING_APER(2:20)
          allocate( pixi_sub(128,128))
          allocate(pixi2_sub(128,128))
          call readfits_r4e(FILENAME, pixi_sub,128,128,1)
          call readfits_i2e(FILENAME,pixi2_sub,128,128,3)
          do i = 001, 128
          do j = 001, 128
              pixi(i+443,j+443) =  pixi_sub(i,j)
             pixi2(i+443,j+443) = pixi2_sub(i,j)
             enddo
             enddo
          CRPIX1 = CRPIX1 + 443
          CRPIX2 = CRPIX2 + 443
          LOFLAG = LOFLAG*64
          HIFLAG = HIFLAG*64
          deallocate( pixi_sub)
          deallocate(pixi2_sub)
          goto 3
          endif
 
      if (STRING_APER(2:8).eq.'IRSUB64') then                  ! this works for IRSUB64 and IRSUB64-FIX
          print*,'WFC3IR SPECIAL APERTURE: ',STRING_APER(2:20)
          allocate( pixi_sub(64,64))
          allocate(pixi2_sub(64,64))
          call readfits_r4e(FILENAME, pixi_sub,64,64,1)
          call readfits_i2e(FILENAME,pixi2_sub,64,64,3)
          do i = 001, 064
          do j = 001, 064
              pixi(i+475,j+475) =  pixi_sub(i,j)
             pixi2(i+475,j+475) = pixi2_sub(i,j)
             enddo
             enddo
          CRPIX1 = CRPIX1 + 475
          CRPIX2 = CRPIX2 + 475
          LOFLAG = LOFLAG*256
          HIFLAG = HIFLAG*256
          deallocate( pixi_sub)
          deallocate(pixi2_sub)
          goto 3
          endif
 
 
      call readfits_r4e(FILENAME,pixi ,1014,1014,1)
      call readfits_i2e(FILENAME,pixi2,1014,1014,3)
 
    3 continue
 
      do i = 0001, 1014
      do j = 0001, 1014
         pixo(i,j) = pixi(i,j)
         enddo
         enddo
 
      PA_APER = r8_query_hdre(FILENAME,'PA_APER ',-1)
      PA_V3   = PA_APER + 0.1256971
 
      COSPA = cos(PA_V3*3.14159/180.0)
      SINPA = sin(PA_V3*3.14159/180.0)
 
      CD1_1 = -COSPA*0.120978/60/60
      CD1_2 =  SINPA*0.120978/60/60
      CD2_1 =  SINPA*0.120978/60/60
      CD2_2 =  COSPA*0.120978/60/60
 
      PROP = i4_query_hdre(FILENAME,'PROPOSID',-1)
 
c     print*,'PROP: ',PROP
 
      EXPT = r4_query_hdre(FILENAME,'EXPTIME ',-1)
      call query_hdre(FILENAME,     'FILTER  ',STREAM,-1)
 
      if (STREAM(1:1).eq.'F') FILT = STREAM(1:5)  ! allow quotes in the filter name...
      if (STREAM(2:2).eq.'F') FILT = STREAM(2:6)
 
      RDAT = SNGL(rdate_header(FILENAME))
 
      LOFLAG =   -50
      HIFLAG = 30000
 
      do i = 1, 4
      do j = 1, 4
         BDRY_XR(i,j) = 0.
         BDRY_YR(i,j) = 0.
         enddo
         enddo
 
      BDRY_XR(1,1) = 0001.
      BDRY_YR(1,1) = 0001.
      BDRY_XR(2,1) = 1013.
      BDRY_YR(2,1) = 0001.
      BDRY_XR(3,1) = 1013.
      BDRY_YR(3,1) = 1013.
      BDRY_XR(4,1) = 0001.
      BDRY_YR(4,1) = 1013.
 
      do i = 0001, 1014
      do j = 0001, 1014
         pixi2_l = pixi2(i,j)
         if (iand(pixi2_l,00001).ne.0) continue             ! Reed-Solomon decoding error
         if (iand(pixi2_l,00002).ne.0) continue             ! data missing/replaced by fill
         if (iand(pixi2_l,00004).ne.0) pixi(i,j) = -500     ! bad detector pixel
         if (iand(pixi2_l,00008).ne.0) continue             ! deviant zero-read (bias) value
         if (iand(pixi2_l,00016).ne.0) continue             ! hot pixel
         if (iand(pixi2_l,00032).ne.0) continue             ! unstable response
         if (iand(pixi2_l,00256).ne.0) continue             ! full-well saturation
         if (iand(pixi2_l,00512).ne.0) pixi(i,j) = -500     ! bad/uncertain value (blob)
         if (iand(pixi2_l,01024).ne.0) continue             ! (reserved)
         if (iand(pixi2_l,02048).ne.0) continue             ! signal in zero-read
         if (iand(pixi2_l,04096).ne.0) continue             ! CR detected by MDriz
         if (iand(pixi2_l,08192).ne.0) continue             ! CR detected during up-the-ramp
         if (iand(pixi2_l,16384).ne.0) continue             ! pixel affected by ghost/crosstalk
 
 
         pixr(i,j) = pixi(i,j)
         if (pixi2_l.eq.00256) pixr(i,j) = HIFLAG+1 ! full-well saturation ; only if there are no other flags
         enddo
         enddo
 
      do i = 1, 1014
      do j = 1, 1014
         pixh(i,j) = pixr(i,j)
         enddo
         enddo
 
      do i = 1, 1014
      do j = 1, 1014
         rsum = 0.
         if (pixr(i,j).ge.HIFLAG) then
            do ii = max(0001,i-5), min(1014,i+5)
            do jj = max(0001,j-5), min(1014,j+5)
               dd = sqrt(1.*(i-ii)**2+(j-jj)**2)
               rsum = rsum + 1.0/(1+dd)**2*pixh(ii,jj)
               enddo
               enddo
            pixr(i,j) = pixr(i,j) + rsum
            endif
         enddo
         enddo
 
 
c------------------------------------------------
c
c blank out the death star
c
      do i = 0001, 1014
      do j = 0001, 1014
         rsum = sqrt((i-359.)**2+(j-55.)**2)
         if (rsum.lt.25) pixr(i,j) = -751
         enddo
         enddo
 
c     print*,'EXIT WFC3IR_READ_FULL_WSUB: '
c     print*,'     CRPIX: ',CRPIX1,CRPIX2
c     print*,'     CRVAL: ',CRVAL1,CRVAL2
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/WFC3IR/read_wfc3ir_ima_nosub.f"
c****                                         
c*********************************************
                                              
 
c if (iand(pixi2(i,j),00256).ne.0)
 
 
c
c#define _LINUX_ .true.
c
c
c      program test_readima
c      implicit none
c
c      character*200 FILE_IMA
c      real          pixima_s(1014,1014,25)
c      integer       SAMPNUMs
c      real          SAMPTIME_s(25)
c
c      integer       S, Ss
c
c      FILE_IMA = 'idv704hyq_ima.fits'
c
c      call read_wfc3ir_ima_nosub(FILE_IMA,pixima_s,
c     .                           SAMPNUMs,SAMPTIME_s)
c
cc     print*,'SAMPNUMs: ',SAMPNUMs
c      Ss = SAMPNUMs
c
c      do S = 1, Ss
c         write(*,114) S, SAMPTIME_S(S), pixima_s(497,504,S)
c  114    format(1x,i3.3,1x,f8.2,1x,f10.3)
c         enddo
c
c
c      STOP
c      end
c
c
 
 
c-----------------------------------------------------------------
c
c reads an r4 fits image, with extensions (reads in one extension)
c
c
      subroutine read_wfc3ir_ima_nosub(FILE_IMA,
     .                                 pixima_s,
     .                                 piximt_s,
     .                                 piximq_s,
     .                                 SAMPNUMs,SAMPTIME_s)
      implicit none
 
      character*200 FILE_IMA
      real          pixima_s(1014,1014,25)
      real          piximt_s(1014,1014,25)
      integer*2     piximq_s(1014,1014,25)
      integer       SAMPNUMs
      real          SAMPTIME_s(25)
 
      integer       SAMPNUM
      real          SAMPTIME
 
 
 
      integer naxes
      integer laxis(3)
      common/laxis3_/laxis
 
      character*8  field
      character*40 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
      integer j
      integer nn, nx, ny, qq
 
      character*2880 buffc
      byte           buffb(2880)
      real*4         buffr(720)
      equivalence (buffc,buffb)
 
      integer i0
      integer i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
c     character    char
 
      logical DIAG
      data    DIAG /.false./
      integer NEND
c     integer iend
      logical DOEXTEND
      data    DOEXTEND /.false./
 
 
c     integer is, js
      integer S, Ss
 
      real*4,    dimension(:,:,:), allocatable :: pixr_s
      real*4,    dimension(:,:,:), allocatable :: pixt_s
      integer*2, dimension(:,:,:), allocatable :: pixq_s
      real*4,    dimension(:,:,:), allocatable :: pixd_s
 
      logical ISSCI
      logical ISERR
      logical ISDQ
 
      allocate(pixr_s(1024,1024,25))
      allocate(pixt_s(1024,1024,25))
      allocate(pixq_s(1024,1024,25))
      allocate(pixd_s(1014,1014,25))
 
 
      open(90,file=FILE_IMA,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      BSCALE = 1.0
      BZERO  = 0.0
 
      SAMPNUM  =  0
      SAMPNUM  = -1
      SAMPNUMs =  0
 
      i = 0
      nread = 0
      NEND  = 0
  99  continue
c     print*,'NEND = ',NEND,i,SAMPNUM
      naxes = 0
      laxis(1) = 0
      laxis(2) = 0
      laxis(3) = 0
c     SAMPNUM = -1
 
      i0 = i+1
      ISSCI = .false.
      ISERR = .false.
      ISDQ  = .false.
 
 100  continue
      i  = i  + 1
      if (DIAG) print*,'READREC: ',i
      read(90,rec=i,iostat=ios) buffc
      if (ios.eq.5002) goto 999
      if (ios.ne.0) then
          print*,'NEND: ',NEND
          print*,' ios: ',ios
          stop 'ios.ne.0'
          endif
      k = 0
      if (DIAG) write(*,'(i8.8,1x,i2.2,1x,80a)')
     .                   i,k,buffc(k*80+1:k*80+80)
      do k = 0, 35, 1
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+51)
         if (buffc(k*80+1:k*80+7).ne.'COMMENT'.and.
     .       buffc(k*80+1:k*80+7).ne.'HISTORY'.and.
     .       buffc(k*80+9:k*80+9).ne.' '.and.
     .       buffc(k*80+9:k*80+9).ne.'=') then
             print*,'  FIELD: ',field
             print*,' STREAM: ',stream
             stop 'fits header error'
             endif
         if (field.eq.'XTENSION'.and.NEND.gt.1)
     .       buffc(k*80+01:k*80+80) = 'SIMPLE  =                    T'
         if (field.eq.'EXTEND  '.and.NEND.eq.0)
     .       DOEXTEND = .true.
         if (field.eq.'NEXTEND '.and.NEND.eq.0)
     .       buffc(k*80+01:k*80+80) = ' '
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
         if (field.eq.'SAMPNUM ') then
             read(stream,*) SAMPNUM
             SAMPNUM = SAMPNUM+1
             if (SAMPNUM.gt.SAMPNUMs) SAMPNUMs = SAMPNUM
             endif
         if (field.eq.'EXTNAME ') then
             ISSCI = stream(2:4).eq.'SCI'
             ISERR = stream(2:4).eq.'ERR'
             ISDQ  = stream(2:4).eq.'DQ '
             endif
         if (field.eq.'SAMPTIME') read(stream,*) SAMPTIME
         if (field.eq.'END     ') then
            if (.not.DOEXTEND) stop 'NO EXTEND=T CARD'
            NEND = NEND + 1
            if (NEND.eq.1) then
               !print*,'NEND.eq.1...'
               !print*,'* goto 99...'
                goto 99
                endif
            goto 101
            endif
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,' '
         print*,'----------------------------------------'
         print*,'READ DATA... '
         print*,'----------------------------------------'
         print*,'   NEND: ',nend
         print*,'  NREAD: ',nread
         print*,'  LAXIS: ',laxis(1),laxis(2),laxis(3),naxes
         print*,' BITPIX: ',bitpix
         print*,' '
         endif
 
      nbper  = 0
 
      if (BITPIX.eq.16) then
          nbper  = 2*laxis(1)*laxis(2)
          npt    = laxis(1)*laxis(2)
          nbyte1 = 1
          nbyte2 = nbper
          i1 = i+1 + nbyte1/2880
          i2 = i+1 + nbyte2/2880
          if (nbper.ne.0) then
              do i = i1, i2, 1
                 read(90,rec=i ,iostat=ios) buffc
                 if (SAMPNUM.ne.-1.and.ISDQ) then
                     nbyte0 = (i-i1)*2880+   1
                     nbyteE = (i-i1)*2880+2880
                     np1 = (nbyte0-nbyte1)/2 + 1
                     np2 = (nbyteE-nbyte1)/2 + 1
                     call buff2pix_i2x(buffb,
     .                                 pixq_s(1,1,SAMPNUM),
     .                                 np1,npt)
                     endif
                 enddo
              i = i2
              endif
c         print*,'SAMPNUM: ',SAMPNUM,NREAD,NEND,BITPIX,
c    .                       pixq_s(613+5,952+5,SAMPNUM),
c    .                       pixr_s(613+5,952+5,SAMPNUM)
          goto 99
          endif
 
      if (BITPIX.eq.-32) then
          if (SAMPNUM.ne.-1)
     .        SAMPTIME_S(SAMPNUM) = SAMPTIME
          nbper  = 4*laxis(1)*laxis(2)
          npt    = laxis(1)*laxis(2)
          nbyte1 = 1
          nbyte2 = nbper
          i1 = i+1 + nbyte1/2880
          i2 = i+1 + nbyte2/2880
          if (nbper.ne.0) then
              do i = i1, i2, 1
                 read( 90,rec=i ,iostat=ios) buffc
                 if (SAMPNUM.ne.-1.and.ISSCI) then
                     nbyte0 = (i-i1)*2880+   1
                     nbyteE = (i-i1)*2880+2880
                     np1 = (nbyte0-nbyte1)/4 + 1
                     np2 = (nbyteE-nbyte1)/4 + 1
                     call buff2pix_r4x(buffb,buffr,0001,0720)
                     do qq = 001, 720
                        nn = np1 + (qq-1)
                        ny = 1 + (nn-1)/laxis(1)
                        nx = nn-(ny-1)*laxis(1)
                        if (nn.le.np2.and.
     .                      nx.ge.001.and.nx.le.1024.and.
     .                      ny.ge.001.and.ny.le.1024) then
                            pixr_s(nx,ny,SAMPNUM) = buffr(qq)
                            endif
                        enddo
                     endif
                  enddo
              i = i2
              endif
c         print*,'SAMPNUM: ',SAMPNUM,NREAD,NEND,BITPIX,
c    .                       pixq_s(613+5,952+5,SAMPNUM),
c    .                       pixr_s(613+5,952+5,SAMPNUM)
          goto 99
          endif
 
      print*,'BITPIX: ',BITPIX
      stop '... not ready for that BITPIX.'
 
 900  continue
      print*,' '
      print*,'EXPLODE_R4E_R4 --- 900 --- READFITS ERROR'
      print*,' '
      print*,'FILE_IMA: ',FILE_IMA
      print*,' '
      stop
 
 999  continue
 
c     print*,' '
c     print*,' '
c     print*,'DONE READING IMA FILE!'
c     print*,' '
c     print*,' '
 
      do SAMPNUM = 1, SAMPNUMs
         do i = 0001, 1024
         do j = 0001, 1024
            pixt_s(i,j,SAMPNUM) = pixr_s(i,j,SAMPNUM)
     .                            *SAMPTIME_S(SAMPNUM)
            if (SAMPNUM.eq.1)
     .      pixt_s(i,j,SAMPNUM) = 0.
            enddo
            enddo
c        print*,SAMPNUM,SAMPTIME_S(SAMPNUM),pixr_s(512,512,SAMPNUM),
c    .                                      pixt_s(512,512,SAMPNUM)
         enddo
c     print*,' '
      do SAMPNUM = 1, SAMPNUMs
         do i = 0001, 1014
         do j = 0001, 1014
            if (SAMPNUM.gt.1) then
                pixd_s(i,j,SAMPNUM) = (pixt_s(i+5,j+5,SAMPNUM  )
     .                                -pixt_s(i+5,j+5,SAMPNUM-1))
     .                                /(SAMPTIME_S(SAMPNUM  )
     .                                 -SAMPTIME_S(SAMPNUM-1))
                if (pixt_s(i+5,j+5,SAMPNUM).gt.80000)
     .              pixd_s(i,j,SAMPNUM) = -100
                endif
            if (SAMPNUM.eq.1) then
                pixd_s(i,j,SAMPNUM) = pixr_s(i+5,j+5,SAMPNUM)
                if (pixt_s(i+5,j+5,SAMPNUM).gt.80000)
     .              pixd_s(i,j,SAMPNUM) = -100
                endif
            enddo
            enddo
         enddo
 
      Ss = SAMPNUMs
 
      print*,' '
      do S = 1, Ss
         do i = 0001, 1014
         do j = 0001, 1014
            pixima_s(i,j,S) = pixd_s(i+0,j+0,S)
            piximt_s(i,j,S) = pixt_s(i+5,j+5,S)
            piximq_s(i,j,S) = pixq_s(i+5,j+5,S)
            if (iand(int(piximq_s(i,j,S)),int(00256)).ne.0) then
                     pixima_s(i,j,S) = -100
                     piximt_s(i,j,S) = -100
                     endif
            enddo
            enddo
         write(*,114) S,pixima_s(613,952,S),
     .                  piximt_s(613,952,S),
     .                  piximq_s(613,952,S),
     .                  SAMPTIME_S(S)
  114    format(1x,i2.2,1x,f8.2,1x,f9.1,1x,i5,1x,f9.3)
         enddo
      print*,' '
 
      RETURN
 
 
      end
 
 
 
 
      subroutine buff2pix_r4x(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      real pix(*)
      integer n1,nt
 
      byte b(4)
      real r
      equivalence(r,b)
 
      integer i, npu, nbu
      logical islinux
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (.not.islinux()) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            b(3) = buff(nbu+3)
            b(4) = buff(nbu+4)
            endif
         if (islinux()) then
            b(4) = buff(nbu+1)
            b(3) = buff(nbu+2)
            b(2) = buff(nbu+3)
            b(1) = buff(nbu+4)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = r
         enddo
 
      return
      end
 
 
 
 
 
      subroutine buff2pix_i2x(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      integer*2 pix(*)
      integer n1,nt
 
      byte b(2)
      integer*2 ii
      equivalence(ii,b)
 
      integer i, npu, nbu
 
      logical islinux
 
      do i = 1, 1440
         npu = n1+i-1
         nbu = (i-1)*2
         if (.not.islinux()) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            endif
         if (islinux()) then
            b(2) = buff(nbu+1)
            b(1) = buff(nbu+2)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = ii
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/ACSWFC/read_acswfc_flt_full.f"
c****                                         
c*********************************************
                                              
 
 
c--------------------------------------------------
c
c
      subroutine read_acswfc_flt_smpl(FILENAME,pix)
      implicit none
 
      character*200 FILENAME
      real          pix(4096,4096)
 
      real*8    CRPIX1, CRPIX2
      real*8    CRVAL1, CRVAL2
      real*8    CD1_1,  CD1_2
      real*8    CD2_1,  CD2_2
 
      integer   LOFLAG, HIFLAG
      real*8    BDRY_XR(4,4)
      real*8    BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
      real         GAIN
 
      byte, dimension(:,:), allocatable :: pxq
 
      allocate(pxq(4096,4096))
 
      call read_acswfc_flt_full(FILENAME,pix,pxq,
     .                          CRPIX1, CRPIX2,
     .                          CRVAL1, CRVAL2,
     .                          CD1_1,  CD1_2,
     .                          CD2_1,  CD2_2,
     .                          LOFLAG, HIFLAG,
     .                          BDRY_XR,  BDRY_YR,
     .                          FILT,EXPT,
     .                          RDAT,PROP,GAIN)
 
      deallocate(pxq)
 
      return
      end
 
 
 
c---------------------------------------------------
c
c
      subroutine read_acswfc_flt_full(FILENAME,pix,pxq,
     .                                CRPIX1, CRPIX2,
     .                                CRVAL1, CRVAL2,
     .                                CD1_1,  CD1_2,
     .                                CD2_1,  CD2_2,
     .                                LOFLAG, HIFLAG,
     .                                BDRY_XR,  BDRY_YR,
     .                                FILT,EXPT,
     .                                RDAT,PROP,GAIN)
      implicit none
 
      character*200 FILENAME
      real      pix(4096,4096)
      byte      pxq(4096,4096)
 
      real*8    CRPIX1, CRPIX2
      real*8    CRVAL1, CRVAL2
      real*8    CD1_1,  CD1_2
      real*8    CD2_1,  CD2_2
 
      integer   LOFLAG, HIFLAG
      real*8    BDRY_XR(4,4)
      real*8    BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
      real*4       GAIN
 
c
c----------------------------------------------------
c
 
      integer NAXIS1
      integer NAXIS2
 
      real*8 COSPA, SINPA
      real*8 PA_APER
      real*8 PA_V3
 
      real      pix2k2k(2048,2048)
      integer*2 pxd2k2k(2048,2048)
 
      character*20 APERTURE
      character*80 FILTU
      character*80 FILT1, FILT2, FILT3, FILT4
      real*8  r8_query_hdre
      real*4  r4_query_hdre
      integer i4_query_hdre
      real*8  rdate_header
 
      integer i, j
      logical str_contains
 
 
      real*4,    dimension(:,:),   allocatable :: pxz
      integer*2, dimension(:,:),   allocatable :: pxd ! data quality array
 
 
      if (.false.) then
         print*,'   '
         print*,'ENTER: subroutine read_acswfc_flt_full '
         print*,'---> FILENAME: ',FILENAME
         print*,'   '
         endif
 
      NAXIS1 = int(r8_query_hdre(FILENAME,'NAXIS1  ',-1))
      NAXIS2 = int(r8_query_hdre(FILENAME,'NAXIS2  ',-1))
 
      if (NAXIS1.lt.4096.and.NAXIS2.lt.2048)
     .    stop 'only FLT ACS full frame (for now)'
 
      CRPIX1 = r8_query_hdre(FILENAME,'CRPIX1  ',-1)
      CRPIX2 = r8_query_hdre(FILENAME,'CRPIX2  ',-1)
      CRVAL1 = r8_query_hdre(FILENAME,'CRVAL1  ',-1)
      CRVAL2 = r8_query_hdre(FILENAME,'CRVAL2  ',-1)
 
      PA_APER = r8_query_hdre(FILENAME,'PA_APER ',-1)
      PA_V3   = PA_APER + 0.2181083
 
      COSPA = cos(PA_V3*3.14159/180.0)
      SINPA = sin(PA_V3*3.14159/180.0)
 
      CD1_1 = -COSPA*0.049730/60/60
      CD1_2 =  SINPA*0.049730/60/60
      CD2_1 =  SINPA*0.049730/60/60
      CD2_2 =  COSPA*0.049730/60/60
 
      PROP = i4_query_hdre(FILENAME,'PROPOSID',-1)
      EXPT = r4_query_hdre(FILENAME,'EXPTIME ',-1)
      RDAT = SNGL(rdate_header(FILENAME))
 
      call query_hdre(FILENAME,'FILTER  ',FILTU,-1)
      call query_hdre(FILENAME,'FILTER1 ',FILT1,-1)
      call query_hdre(FILENAME,'FILTER2 ',FILT2,-1)
      call query_hdre(FILENAME,'FILTNAM1',FILT3,-1)
      call query_hdre(FILENAME,'FILTNAM2',FILT4,-1)
 
      call query_hdre(FILENAME,'APERTURE',APERTURE,-1)
 
 
      FILT = FILTU(1:5)
      if (FILT1(1:1).eq.'F')  FILT = FILT1(1:5)
      if (FILT2(1:1).eq.'F')  FILT = FILT2(1:5)
      if (FILT3(1:1).eq.'F')  FILT = FILT3(1:5)
      if (FILT4(1:1).eq.'F')  FILT = FILT4(1:5)
      if (FILT1(2:2).eq.'F')  FILT = FILT1(2:6)
      if (FILT2(2:2).eq.'F')  FILT = FILT2(2:6)
      if (FILT3(2:2).eq.'F')  FILT = FILT3(2:6)
      if (FILT4(2:2).eq.'F')  FILT = FILT4(2:6)
 
      LOFLAG =   -50
      HIFLAG = 76000
 
      GAIN = 2
      GAIN = r4_query_hdre(FILENAME,'CCDGAIN ',-1)
 
      if (GAIN.eq.1) HIFLAG = 55000
 
      do i = 1, 4
      do j = 1, 4
         BDRY_XR(i,j) = 0.
         BDRY_YR(i,j) = 0.
         enddo
         enddo
 
      BDRY_XR(1,2) = 0001
      BDRY_YR(1,2) = 0001
      BDRY_XR(2,2) = 4095
      BDRY_YR(2,2) = 0001
      BDRY_XR(3,2) = 4095
      BDRY_YR(3,2) = 2047
      BDRY_XR(4,2) = 0001
      BDRY_YR(4,2) = 2047
 
      BDRY_XR(1,1) = 0001
      BDRY_YR(1,1) = 2049
      BDRY_XR(2,1) = 4095
      BDRY_YR(2,1) = 2049
      BDRY_XR(3,1) = 4095
      BDRY_YR(3,1) = 4095
      BDRY_XR(4,1) = 0001
      BDRY_YR(4,1) = 4095
 
 
      if (_SKIPPX_) then
          do i = 0001, 4096
          do j = 0001, 4096
             pix(i,j) = -750
             enddo
             enddo
          goto 444
          endif
 
c P000003 L21 E00 APERTURE= 'WFC1B-2K        '   / aperture name                                   00001 jehr02leq_flt.f
 
      if (APERTURE(2:9).eq.'WFC1B-2K') then
          call readfits_r4e(FILENAME,pix2k2k,2048,2048,1)
          call readfits_i2e(FILENAME,pxd2k2k,2048,2048,3)
          allocate(pxd(4096,4096))
          do i = 0001, 4096
          do j = 0001, 4096
             pix(i,j) = -750
             pxd(i,j) = -750
             enddo
             enddo
          do i = 0001, 2048
          do j = 0001, 2048
             pix(i+2048,j+2048) = pix2k2k(i,j)
             pxd(i+2048,j+2048) = pxd2k2k(i,j)
             enddo
             enddo
          do i = 0001, 4096
          do j = 0001, 4096
             if (iand(pxd(i,j),int( 256,2)).gt.0) pxq(i,j) = 1  ! physical saturation
             if (iand(pxd(i,j),int(2048,2)).gt.0) pxq(i,j) = 1  ! a2d saturation
             enddo
             enddo
          deallocate(pxd)
          goto 444
          endif
 
      if (str_contains(FILENAME,200,'_flt.fits',09).or.
     .    str_contains(FILENAME,200,'_flc.fits',09).or.
     .    str_contains(FILENAME,200,'_crj.fits',09).or.
     .    str_contains(FILENAME,200,'_crc.fits',09)) then
          call readfits_WFC(FILENAME,pix(0001,2049),4)
          call readfits_WFC(FILENAME,pix(0001,0001),1)
          allocate(pxd(4096,4096))
          call readfits_i2e(FILENAME,pxd(0001,2049),4096,2048,6)
          call readfits_i2e(FILENAME,pxd(0001,0001),4096,2048,3)
          do i = 0001, 4096
          do j = 0001, 4096
             if (iand(pxd(i,j),int( 256,2)).gt.0) pxq(i,j) = 1  ! physical saturation
             if (iand(pxd(i,j),int(2048,2)).gt.0) pxq(i,j) = 1  ! a2d saturation
             enddo
             enddo
          deallocate(pxd)
          goto 444
          endif
 
      if (str_contains(FILENAME,200,'_WJC.fits',09).or.
     .    str_contains(FILENAME,200,'_WJX.fits',09).or.
     .    str_contains(FILENAME,200,'_WXC.fits',09).or.
     .    str_contains(FILENAME,200,'_WJ2.fits',09)) then
          call readfits_j2r(FILENAME,pix(0001,0001),4096,4096)
          goto 444
          endif
 
      if (str_contains(FILENAME,200,'_raw.fits',09)) then
          call readfits_acsraw2r(FILENAME,pix)
          goto 444
          endif
 
      if (str_contains(FILENAME,200,'_raz.fits',09).or.
     .    str_contains(FILENAME,200,'_rzc.fits',09)) then
          allocate(pxz(8288,2068))
          call readfits_r4(FILENAME,pxz,8288,2068)
          do i = 0001, 2048
          do j = 0001, 2048
             pix(i+0000,j+0000) = pxz(0*2072+24+i,j)
             pix(4097-i,j+0000) = pxz(1*2072+24+i,j)
             pix(i+0000,4097-j) = pxz(2*2072+24+i,j)
             pix(4097-i,4097-j) = pxz(3*2072+24+i,j)
             enddo
             enddo
          deallocate(pxz)
          goto 444
          endif
 
      print*,'PROB : subroutine read_acswfc_flt_full '
      print*,'       could not read in file: '
      print*,'       ',FILENAME
      stop
  444 continue
 
      do i = 0001, 4096
      do j = 2046, 2051
         pix(i,j) = -750
         enddo
         enddo
 
c     if (GAIN.eq.1) then
c        do i = 0001, 4096
c        do j = 0001, 4096
c           if (pix(i,j).gt.55000) pix(i,j) = 71500
c           enddo
c           enddo
c        endif
 
      return
      end
 
 
 
 
 
      subroutine readfits_WFC(FILE,pix,nimg)
      implicit none
 
      character*(*) FILE
      real pix(4096,2048)
 
      character*70 INFO(10)
      common / fitsinfo / INFO
 
      integer nimg
      integer naxes
      integer laxis(3)
 
      character*8  field
      character*20 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
 
      logical LINUX
      data LINUX/.true./
 
      logical first_header
 
      integer NH_RECs
      character*2880 HEADER_STRING(99)
      common /HEADER_STRING_INFO/NH_RECs,HEADER_STRING
 
      character*200 FILEu
 
      FILEu = 'NONE'
      do i = 1, 195
         if (FILE(i:i).eq.' ') then
             print*,'readfits_WJC filename problem'
             print*,'   space before .fits '
             print*,'   FILE: ',FILE
             stop
             endif
         if (FILE(i:i+4).eq.'.fits') then
             FILEu = FILE(1:i+4)
             goto 3
             endif
         enddo
      if (FILE(i:i).eq.' ') then
          print*,'readfits_WJC filename problem'
          print*,'   space before .fits '
          print*,'   FILE: ',FILE
          stop
          endif
 
    3 continue
      open(10,file=FILEu,status='old',iostat=ios,
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      bscale = 1.0
      bzero  = 0.0
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
 
      NH_RECs = 0
      first_header = .true.
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buffc
      if (first_header) then
         NH_RECs = NH_RECs + 1
         HEADER_STRING(NH_RECs) = buffc
         endif
      do k = 0, 35, 1
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+31)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'END     ') then
            first_header = .false.
            goto 101
            endif
         enddo
      goto 100
 101  continue
 
 
      nread = nread + 1
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      if (naxes.eq.0) then    ! maybe multiple images stored as extensions
         if (nextend.eq.0) then
            print*,'THIS IS A NULL IMAGE: '
            print*,'NAXES: ',NAXES
            print*,'NEXND: ',NEXTEND
            stop
            endif
         endif
 
      if (nread.ne.nimg+1) then
         nbper  = abs(BITPIX/8)*laxis(1)*laxis(2)
         if (NAXES.eq.0) nbper = 0
         i = int(i + 1.0*nbper/2880 + 0.9999)
         goto 100
         endif
 
      if (laxis(1).ne.4096.or.
     .    laxis(2).ne.2048) then
          print*,'  laxis1: ',laxis(1)
          print*,'  laxis2: ',laxis(2)
          print*,'    4096: ',4096
          print*,'    2048: ',2048
          stop
          endif
 
      if (naxes.eq.2) then   ! nimg is irrelevant; ignore
         nbper  = 4*laxis(1)*laxis(2)
         npt    = laxis(1)*laxis(2)
         nbyte1 = 1
         nbyte2 = nbper
         i1 = i+1 + nbyte1/2880
         i2 = i+1 + nbyte2/2880
         endif
 
      if (naxes.eq.3) then
         nbper  = 4*laxis(1)*laxis(2)
         nbyte1 = 1 + nbper*(nimg-1)
         nbyte2 =     nbper*(nimg  )
         i1 = i+1 + nbyte1/2880
         i2 = i+1 + nbyte2/2880
         npt = laxis(1)*laxis(2)
         endif
 
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         call buff2pix_r4_wfc(buffb,pix,np1,npt)
         enddo
 
      return
 
 900  continue
      print*,'readfits_WFC: READFITS ERROR'
      print*,'FILE : ',FILE
      print*,'FILEu: ',FILEu
      print*,'  ios: ',ios
      stop
 
      end
 
 
      subroutine buff2pix_r4_wfc(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      real pix(*)
      integer n1,nt
 
      byte b(4)
      real r
      equivalence(r,b)
 
      integer i, npu, nbu
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (.not.(_LINUX_)) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            b(3) = buff(nbu+3)
            b(4) = buff(nbu+4)
            endif
         if ((_LINUX_)) then
            b(4) = buff(nbu+1)
            b(3) = buff(nbu+2)
            b(2) = buff(nbu+3)
            b(1) = buff(nbu+4)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = r
         enddo
 
      return
      end
 
 
 
      subroutine sub_wfcacs_readraw2raz(FILEI,pixz)
      implicit none
 
      character*80 FILEI
      real*4       pixz(8288,2068)
 
 
c----------------------
c
c progression of fix...
c
      real, dimension(:,:,:), allocatable ::  pixa0 ! original amp real pixa1(2072,2068,4) ! corrected for ref-pixels
      real, dimension(:,:,:), allocatable ::  pixa1 ! ref pixels corrected for column
      real, dimension(:,:,:), allocatable ::  pixa2 ! whole image corrected for average
      real, dimension(:,:,:), allocatable ::  pixa3 ! whole image corrected for column/average/row
 
      integer i,j,k
 
 
      real*8 barj(2068)
      real*8 sigj(2068)
 
      real    refbar(4), refsig(4)
      integer refuse(4)
 
      real   refcolbar(24,4)
      real   refcolsig(24,4)
 
      real*8  ptot
      integer ntot
      real*8  bark(4), barb
      real*8  sigk(4)
c     real    dx
 
      real    rj
      integer jj
      real    fj
 
      byte    rowuse(2068,4)
      real    rowref(2068,4)
      real    rowbar(2068,4)
      integer rowtot(4)
 
      byte    usek(2068,4)
 
      integer nskip
      integer nfixd
 
      character*80 FILEB
      character*80 FILEO
 
      integer n
      integer Ls, Lu
      real*8  xl(9999), xbar, xsig
      real*8  bias_shift_bar_kn(4,16)
      real*8  bias_shift_sig_kn(4,16)
      integer NARG
 
      real rn, fn
      integer  nn
 
      real bias_shift(4,17)
      data bias_shift /
     .       0.0000,   0.0000,   0.0000,   0.0000,
     .       2.7270,   2.6762,   2.4282,   2.4256,
     .       5.2498,   5.1106,   4.4137,   4.7800,
     .       7.3278,   7.0069,   5.6505,   7.0362,
     .       9.0420,   8.2736,   6.4285,   8.7642,
     .      10.3455,   9.1745,   7.0294,   9.8053,
     .      11.4173,   9.7687,   7.5445,  10.5576,
     .      12.3301,  10.1248,   8.0041,  11.2053,
     .      13.0142,  10.5457,   8.3000,  11.9011,
     .      13.7405,  10.9688,   8.3529,  12.5295,
     .      14.0843,  11.1583,   8.5229,  13.0714,
     .      14.4022,  11.2714,   8.6627,  13.5581,
     .      15.0245,  11.3666,   8.8438,  14.0528,
     .      15.5655,  11.5520,   9.0489,  14.4749,
     .      15.9700,  11.7052,   9.1862,  14.6787,
     .      16.1995,  11.7212,   9.2854,  14.9770,
     .      16.4175,  11.8703,   9.1763,  15.4222/
 
      real*4, dimension(:,:), allocatable :: pix1
      real*4, dimension(:,:), allocatable :: pix4
 
      integer GAIN
      real    r4_query_hdre
 
 
 
      allocate(pixa0(2072,2068,4))
      allocate(pixa1(2072,2068,4))
      allocate(pixa2(2072,2068,4))
      allocate(pixa3(2072,2068,4))
 
      allocate(pix1(4144,2068))
      allocate(pix4(4144,2068))
 
      if (FILEI(10:18).ne.'_raw.fits') then
          print*,' '
          print*,'FILENAME must have the string "_raw.fits" '
          print*,'         characters 10 through 18.'
          print*,' '
          print*,'         restrictive, I know... '
          print*,' '
          stop
          endif
 
 
c------------------------------------------------------
c
c output image will have _rrs.fits instead of _raw.fits
c
      FILEB = FILEI
      FILEO = FILEI
      FILEO(11:13) = 'raz'
 
      write(*,*)
      write(*,'(''INPUT   INT*2: '',a18)') FILEI(01:18)
      write(*,'(''OUTPUT REAL*4: '',a18)') FILEO(01:18)
      write(*,*)
 
c------------------------------------------------------
c
c read-in the pixel data into 3-d arrays: (2072x2068x4)
c one per amplifier
c
      print*,'read_acsraw_pixa...'
      call read_acsraw_pixa(FILEI,pixa0)
 
      GAIN = 2
      GAIN = int(r4_query_hdre(FILEI,'CCDGAIN ',-1) + 0.5)
 
c------------------------------------------------------
c
c STEP1: compute the column-by-column residual for each
c        column in the reference pixels of each amplifier
c        remove the trend so that the ref pixels are flat.
c
      print*,'------------------------------------------------------'
      print*,' '
      print*,'STEP1:  FIND COLUMN BY COLUMN DEPENDENCE...'
      print*,' '
      do k = 1, 4
         call find_refcol(pixa0(1,1,k),refcolbar(1,k),refcolsig(1,k))
         call subt_refcol(pixa0(1,1,k),refcolbar(1,k),
     .                    pixa1(1,1,k))
         enddo
 
 
 
c
c this output just shows the column-by-column trends for
c each amplifier, and also shows how similar the columns
c are with respect to one another.
c
      print*,' '
      print*,'        AMP --- AVERAGE COLUMN RESPONSE (DNs)'
      print*,' '
      write(*,'(9x,1x,3x,24(1x,''i='',i2.2))') (i,i=1,24)
      do k = 1, 4
         write(*,'(9x,i1,3x,24(1x,f4.1))') k,(refcolbar(i,k),i=1,24)
         enddo
 
      print*,' '
      print*,'        AMP --- RMS BY COLUMN (DNs)'
      print*,' '
      write(*,'(9x,1x,3x,24(1x,''i='',i2.2))') (i,i=1,24)
      do k = 1, 4
         write(*,'(9x,i1,3x,24(1x,f4.1))') k,(refcolsig(i,k),i=1,24)
         enddo
      print*,' '
 
 
 
 
 
 
c---------------------------------------------------------
c
c STEP2: Figure out which rows have too much flux to use as
c        reference pixels; at some point if we get the bias
c        drift calibrated, then we may be able to make some
c        of the reference pixels usable again; but until then,
c        it's best to just flag as unusable those that have
c        too much signal; for this, I use an average of 75 DN,
c        which amounts to about 0.4 DN of throw in the bias.
c
      print*,'------------------------------------------------------'
      print*,' '
      print*,'STEP2:  FIND COMPROMISED ROWS...'
      print*,' '
      print*,'        AMP   ROW_USE  ROW_REJ'
      do k = 1, 4
         rowuse(1,k) = 0 ! never use the first row
         rowtot(k) = 0
         ptot = 0.
         do i = 0001, 0024
            ptot = ptot + pixa1(i,1,k)
            enddo
         rowref(1,k) = SNGL(ptot/24)
         rowbar(1,k) = 0.00
         do j = 0002, 2068
            ptot = 0.
            do i = 0001, 0024
               ptot = ptot + pixa1(i,j-1,k)
               ptot = ptot + pixa1(i,j  ,k) ! use avg ref corr...
               enddo
            rowref(j,k) = SNGL(ptot/48)
            ptot = 0.
            do i = 0025, 2072
               ptot = ptot + (pixa1(i,j,k)-rowref(j,k))
               enddo
            rowbar(j,k) = SNGL(ptot/2048)
            rowuse(j,k) = 1
c
c conditions under which we should not use this row to
c tell us about the row-by-row 1/f-noise correction
c
            if (rowbar(j,k).gt.99)      rowuse(j,k) = 0  ! average pixel value of less than 100 e-...
            if (pixa1(25,j,k).gt.25000) rowuse(j,k) = 0  ! near-saturated pixel that may have bled into...
            if (pixa1(26,j,k).gt.25000) rowuse(j,k) = 0
            if (pixa1(27,j,k).gt.25000) rowuse(j,k) = 0
            if (pixa1(28,j,k).gt.25000) rowuse(j,k) = 0
            if (pixa1(29,j,k).gt.25000) rowuse(j,k) = 0
            if (pixa1(30,j,k).gt.25000) rowuse(j,k) = 0
            rowtot(k) = rowtot(k) + rowuse(j,k)
            enddo
         write(*,'(10x,i1,7x,i4,5x,i4)') k,rowtot(k),2067-rowtot(k) ! report the number of good rows per amp
         enddo
      print*,' '
 
 
 
c--------------------------------------------------------
c
c STEP3: Compute the average DC offset for each amplifier
c        Use the good reference rows to determine the
c        average ref-pixel correction for each amplifier.
c        Then remove it.  There is double insurance against
c        bad rows coming in.  We start using only the good
c        rows, but we also find a robust, sigma-clipped
c        mean of the remaining rows.
c
      print*,'------------------------------------------------------'
      print*,' '
      print*,'STEP3:  AVERAGE REFERENCE SUB (DNs)'
      print*,' '
      write(*,119)
  119 format(12x,'AMP',3x,'   BLEV ',7x,'   SIGMA',
     .                 3x,'NREF_USE',3x,'NREF_REJ')
  118 format(12x,i3,   3x,f8.2,      7x,f8.2,
     .                 3x,i8,3x,i8)
      do k = 1, 4
         call find_refbar(pixa1(1,1,k),rowuse(1,k),
     .                    refbar(k),refsig(k),refuse(k),6.0)
         call subt_refbar(pixa1(1,1,k),refbar(k),
     .                    pixa2(1,1,k))
         write(*,118) k,refbar(k),refsig(k),  ! output the RMS
     .                            refuse(k),
     .                    24*2068-refuse(k)
         enddo
      print*,' '
 
 
c----------------------------------------------
c
c this is not needed for the BLEV_COR stage;
c it's a diagnostic to help me see how the bias
c drift correlates with signal in the pixel
c
c     call dump_testf(pixa2,NARG)
 
 
 
c--------------------------------------------------
c
c STEP4: find the line-by-line reference correction;
c        use only the lines that we believe should be
c        good from each amplifier
c
      print*,'------------------------------------------------------'
      print*,' '
      print*,'STEP4:  DEFINE REF CORRECTION LINE BY LINE...'
      print*,'        (assume all 4 amps are the same)     '
 
      nskip = 0
      nfixd = 0
      do j = 0001, 2068 ! go through line by line...
         do k = 01, 04
            ptot = 0.
            do i = 01, 24
               ptot = ptot + pixa2(i,j,k)
               enddo
            bark(k) = ptot/24
            enddo
         do k = 01, 04
            ptot = 0.
            do i = 01, 24
               ptot = ptot + (pixa2(i,j,k)-bark(k))**2
               enddo
            sigk(k) = sqrt(ptot/(24-1))
            enddo
         do k = 1, 4
            usek(j,k) = 0
            if (sigk(k).lt.7.5.and.rowuse(j,k).eq.1) usek(j,k) = 1
            enddo
c
c usek(j,k) now contains 1 for the amplifiers where the row
c is usable; things can be unusable either because
c (1) they have saturated pixels too close
c (2) the flux in that row is high enough to make
c     the bias-drift correction significant
c (3) the rms of the 24 pixels within the ref row are
c     greater than 7.5 DN (typical is 2)
c
         ptot = 0.
         ntot = 0
         do k = 1, 4
            ptot = ptot + usek(j,k)*bark(k)
            ntot = ntot + usek(j,k)
            enddo
         barj(j) = 0.
         sigj(j) = 0.
         if (ntot.ge.2) then                       ! give this row a row-specific
            barj(j) = ptot/ntot                    ! correction only if there are
            ptot = 0.                              ! at least two amps contributing,
            do k = 1, 4                            ! otherwise, use no row correction
               ptot = ptot + usek(j,k)*(bark(k)-barj(j))**2
               enddo
            sigj(j) = sqrt(ptot/(ntot-1))/sqrt(1.*ntot)
            endif
c        write(77,177) NARG,j,barj(j), sigj(j), ntot, ! this is just diagnostic; it allows
c    .                       (bark(k),k=1,4),         ! me to plot the correction implied for
c    .                       (sigk(k),k=1,4),         ! a given row for amp1 against that for
c    .                       (usek(j,k),k=1,4),       ! amp2; they should be well correlated
c    .                       (rowbar(j,k),k=1,4)
c    .
c 177    format(i4,1x,i4.4,1x,f8.4,1x,f8.4,1x,i1,
c    .             5x,4f8.4,
c    .             5x,4f8.4,
c    .             5x,4i2,
c    .             5x,f8.1)
         if (ntot.ge.2) nfixd = nfixd + 1  ! keep a tally of how many rows have the 1/f
         if (ntot.lt.2) nskip = nskip + 1  !    correction performed
         enddo
 
      write(*,*)
      write(*,'(10x,''  ROWS FIXED: '',i4)') nfixd
      write(*,'(10x,''  ROWS SKIPD: '',i4)') nskip
      write(*,*)
 
c
c Now that we have the row-based correction, determine which
c correction to use for each pixel.  Pixels in the data image
c are somewhere between the reference pixels of their row and
c those of the row above; use linear interpolation to determine
c how to weight them.  I could use a spline to do this, but
c maybe that's overkill...
c
      do i = 0001, 2072
      do j = 0001, 2068
         rj = j + (i-12.50)/(2072.0+146.0)
         jj = int(rj)
         if (jj.lt.0001) jj = 0001
         if (jj.gt.2067) jj = 2067
         fj = rj-jj
         barb = barj(jj) + fj*(barj(jj+1)-barj(jj))
         do k =    1,    4
            pixa3(i,j,k) = SNGL(pixa2(i,j,k) - barb)
            enddo
         enddo
         enddo
      print*,' '
 
 
 
c--------------------------------------------------
c
c STEP5: output the results
c
      print*,'------------------------------------------------------'
      print*,'                              '
      print*,'STEP5:  OUTPUT THE RESULTS... '
      print*,'                              '
 
c---------------------------------------------------
c
c The full correction.  Includes
c (1) column correction for each amp,
c (2) average for ref-pixel correction for each amp,
c (3) and the average row-by-row correction over
c     the four amps
c
      call pixa2pix14(pixa3,pix1,pix4)                    ! copies the by-amp cube into by-chip images
 
      do i = 0001, 2072
      do j = 0001, 2068
         pixz(i+(1-1)*2072,j) = pixa3(i,j,1)*2.0170000E+00 ! calibrated gain for amplifier C  ATODGNC
         pixz(i+(2-1)*2072,j) = pixa3(i,j,2)*2.0109999E+00 ! calibrated gain for amplifier D  ATODGND
         pixz(i+(3-1)*2072,j) = pixa3(i,j,3)*2.0200000E+00 ! calibrated gain for amplifier A  ATODGNA
         pixz(i+(4-1)*2072,j) = pixa3(i,j,4)*1.8860000E+00 ! calibrated gain for amplifier B  ATODGNB
         enddo
         enddo
 
      if (GAIN.eq.1) then
          do i = 0001, 8288
          do j = 0001, 2068
             pixz(i,j) = pixz(i,j)/2
             if (pixz(i,j).gt.50000) pixz(i,j) = 65000
             enddo
             enddo
          endif
 
      do k = 1, 4
         do i = 0001, 2048
            rn = 1 + i/128.0
            nn = int(rn)
            fn = rn-nn
            xbar =     bias_shift(k,nn)
     .           + fn*(bias_shift(k,nn+1)
     .                -bias_shift(k,nn  ))
            do j = 0001, 2068
               pixz(24+(k-1)*2072+i,j) =
     .         SNGL(pixz(24+(k-1)*2072+i,j) - xbar)
               enddo
            enddo
         enddo
 
 
      if (.false.) then
         print*,' '
         print*,' '
         do n = 01, 16
            do k = 1, 4
               Ls = 0
               do i = max(0001,(n-2)*128+64),
     .                min(2048,(n-1)*128+64)
               do j = 2063, 2068
                  Ls = Ls + 1
                  xl(Ls) = pixz(24+(k-1)*2072+i,j)
                  enddo
                  enddo
               call barsiga(xl,Ls,xbar,xsig,2.25,Lu)
               bias_shift_bar_kn(k,n) = xbar
               bias_shift_sig_kn(k,n) = xsig
               enddo
            write(91,'(i3,1x,i2,5x,4f10.3,5x,4f10.3,5x,4f10.3)')
     .                NARG,n,
     .            (bias_shift_bar_kn(k,n),k=1,4),
     .               (bias_shift_sig_kn(k,n),k=1,4),
     .               (bias_shift_bar_kn(k,n)
     .               -bias_shift_bar_kn(k,1),k=1,4)
            write(* ,'(i3,1x,i2,5x,4f10.3,5x,4f10.3,5x,4f10.3)')
     .                NARG,n,
     .               (bias_shift_bar_kn(k,n),k=1,4),
     .               (bias_shift_sig_kn(k,n),k=1,4),
     .               (bias_shift_bar_kn(k,n)
     .               -bias_shift_bar_kn(k,1),k=1,4)
            enddo
         print*,' '
         print*,' '
         endif
 
 
c     call cowritfits_raw_r4w(FILEI,FILEO,pix1,pix4)      ! output the chips, using the fits-header of the input image
c     call writfits_r4h(FILEO,pixz,8288,2068,STRING_HEAD)
 
 
c---------------------------------------------------
c
c all but the row-by-row correction...
c
c     call pixa2pix14(pixa2,pix1,pix4)
c     call cowritfits_raw_r4w(FILEI,FILEB,pix1,pix4)
 
      deallocate(pixa0)
      deallocate(pixa1)
      deallocate(pixa2)
      deallocate(pixa3)
 
      return
      end
 
 
 
 
c---------------------------------------------
c
c convert from x-extended format to amp format
c
      subroutine pixb2pixa(pixb0,pixa0)
      implicit none
 
      real pixb0(8288,2068)
      real pixa0(2072,2068,4)
 
      integer i, j, k
 
      do k = 1, 4
         do i = 0001, 2072
         do j = 0001, 2068
            pixa0(i,j,k) = pixb0(i+(k-1)*2072,j)
            enddo
            enddo
         enddo
 
      return
      end
 
 
c---------------------------------------------
c
c convert from amp format to x-extended format
c
      subroutine pixa2pixb(pixa,pixb)
      implicit none
 
      real pixa(2072,2068,4)
      real pixb(8288,2068)
 
      integer i, j, k
      do k = 1, 4
         do i = 0001, 2072
         do j = 0001, 2068
            pixb(i+(k-1)*2072,j) = pixa(i,j,k)
            enddo
            enddo
         enddo
 
      return
      end
 
 
 
 
 
 
 
 
 
c--------------------------------------------------------------
c
c this will read-in a standard-format _raw image into a
c three-dimensional array, 2072x2068 for each of the 4 amps
c
      subroutine read_acsraw_pixa(FILENAME,pix_ijk)
      implicit none
 
      character*80 FILENAME
      real pix_ijk(2072,2068,4)
 
      integer*2, dimension(:,:), allocatable :: pixi
 
      integer i, j
 
      print*,'enter read-acsraw_pixa...'
      allocate(pixi(4144,2068))
 
      call readfits_i2e(FILENAME,pixi,4144,2068,1)
 
      do i = 0001, 2072
      do j = 0001, 2068
         pix_ijk(i,j,1) = pixi(0000+i,0000+j)+32768
         pix_ijk(i,j,2) = pixi(4145-i,0000+j)+32768
         enddo
         enddo
 
      call readfits_i2e(FILENAME,pixi,4144,2068,4)
 
      do i = 0001, 2072
      do j = 0001, 2068
         pix_ijk(i,j,3) = pixi(0000+i,2069-j)+32768
         pix_ijk(i,j,4) = pixi(4145-i,2069-j)+32768
         enddo
         enddo
 
      deallocate(pixi)
 
      return
      end
 
 
c--------------------------------------------------------------
c
c this routine will subtract the average reference-pixel value
c from each amplifer
c
      subroutine subt_refbar(pix_ij_bef,refbar,
     .                       pix_ij_aft)
      real pix_ij_bef(2072,2068)
      real refbar
      real pix_ij_aft(2072,2068)
 
      integer i, j
 
      do j = 0001, 2068
      do i = 0001, 2072
         pix_ij_aft(i,j) = pix_ij_bef(i,j) - refbar
         enddo
         enddo
 
      return
      end
 
 
 
c--------------------------------------------------------------
c
c
c
      subroutine avg_overk(psplink,psplinb,psplins,Ns)
      implicit none
 
      integer Ns
      real psplink(Ns,4)
      real psplinb(Ns)
      real psplins(Ns)
 
      integer n
 
      do n = 1, Ns
         psplinb(n) = (psplink(n,1)+psplink(n,2)
     .                +psplink(n,3)+psplink(n,4))/4.0
         psplins(n) = (abs(psplink(n,1)-psplinb(n))
     .                +abs(psplink(n,2)-psplinb(n))
     .                +abs(psplink(n,3)-psplinb(n))
     .                +abs(psplink(n,4)-psplinb(n)))/3.0
         enddo
 
      return
      end
 
 
c--------------------------------------------------------------
c
c
      subroutine subt_refspline(pix_ij,vsplinb)
      implicit none
 
      real pix_ij(2072,2068)
      real vsplinb(2068)
 
      integer i, j
      real vcor
      real f
 
      do j = 0001, 2068
      do i = 0001, 2072
         f = (i-12.5)/(2072.00-12.5)
         if (f.lt.0) f = 0.0
         vcor = vsplinb(2068)
         if (i.le.2067) then
            vcor = (1-f)*vsplinb(j  )
     .           + ( f )*vsplinb(j+1)
            endif
         pix_ij(i,j) = pix_ij(i,j) - vcor
         enddo
         enddo
 
      return
      end
 
 
 
 
      subroutine pixa2pix14(pix_ijk,pix1,pix4)
      implicit none
 
      real pix_ijk(2072,2068,4)
      real pix1(4144,2068)
      real pix4(4144,2068)
 
      integer i, j
 
      do i = 0001, 2072
      do j = 0001, 2068
         pix1(0000+i,0000+j) = pix_ijk(i,j,1)
         pix1(4145-i,0000+j) = pix_ijk(i,j,2)
         enddo
         enddo
 
      do i = 0001, 2072
      do j = 0001, 2068
         pix4(0000+i,2069-j) = pix_ijk(i,j,3)
         pix4(4145-i,2069-j) = pix_ijk(i,j,4)
         enddo
         enddo
 
      return
      end
 
 
c-------------------------------------------------------------
c
c
      subroutine copy_pixa(pixa1,pixa2)
      implicit none
 
      real pixa1(2072,2068,4)
      real pixa2(2072,2068,4)
 
      integer i, j, k
 
      do k = 1, 4
         do i = 0001, 2072
         do j = 0001, 2068
            pixa2(i,j,k) = pixa1(i,j,k)
            enddo
            enddo
         enddo
 
      return
      end
 
 
 
 
c-----------------------------------------------------
c
c will write a real*4 into the header-shell of an
c integer*2 raw image (FILEI)
c
c There are 6 extensions total, but only #1 and #4
c have any data.
c
      subroutine cowritfits_raw_r4w(FILEI,FILEO,pix1,pix4)
      implicit none
 
      character*80 FILEI, FILEO
      real*4 pix1(4096,2048)
      real*4 pix4(4096,2048)
 
c     integer nimg
      integer naxes
      integer laxis(3)
 
      character*8  field
      character*20 stream
 
      integer nbyte0
      integer nbyteE
      integer nbperi, nbyte1i, nbyte2i, npti
      integer nbperj, nbyte1j, nbyte2j, nptj
      integer ios, k! , kk
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
 
      integer np1, np2
      integer NREAD
c     integer bitpix
 
c     real dtde_l(11)
c     real chg_leak(4,17)
c     common /dtde_l_  /dtde_l
c     common /chg_leak_/chg_leak
 
      logical atend
 
      real rDAT
      character*12 DATESTR
      character*12 TIMESTR
      common /rDAT_/rDAT,DATESTR,TIMESTR
 
      real CTE_FRAC
      common /CTE_FRAC_/CTE_FRAC
 
      integer NMOD
      common /MMOD_/NMOD
      character*11 HOW(4)
 
      integer NIT2DO
      common/NIT2DO_/NIT2DO
 
      real pix1min, pix1max
      real pix4min, pix4max
      integer i, ifirst, i1, i2
      integer j, jfirst, j1, j2
 
      logical DIAG
      common /DIAG_/DIAG
      data DIAG/.false./
 
 
      pix1min = 0.0
      pix1max = 0.0
      pix4min = 0.0
      pix4max = 0.0
      do i = 0001, 4144
      do j = 0001, 2068
         if (pix1(i,j).lt.pix1min) pix1min = pix1(i,j)
         if (pix4(i,j).lt.pix4min) pix4min = pix4(i,j)
         if (pix1(i,j).gt.pix1max) pix1max = pix1(i,j)
         if (pix4(i,j).gt.pix4max) pix4max = pix4(i,j)
         enddo
         enddo
 
      if (DIAG) then
         print*,'---> pix1min: ',pix1min, pix1max
         print*,'---> pix4min: ',pix4min, pix4max
         endif
 
      HOW(1) = 'NONE       '
      HOW(2) = 'LINEAR-3   '
      HOW(3) = 'QUADRATIC-5'
      HOW(4) = 'LINEAR-5   '
 
      if (.true.) then
         print*,'        ENTER COWRITE_RAW: '
         print*,'              ----> FILEI: ',FILEI(1:30)
         print*,'              ----> FILEO: ',FILEO(1:30)
         print*,'                           '
         endif
 
      if (DIAG) print*,'OPEN10 FILEI: ',FILEI
      open(10,file=FILEI,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      HOW(1) = 'NONE       '
      HOW(2) = 'LINEAR-3   '
      HOW(3) = 'QUADRATIC-5'
      HOW(4) = 'LINEAR-5   '
 
      if (DIAG) then
         print*,'ENTER COWRITE_RAW: '
         print*,'      ----> FILEI: ',FILEI(1:30)
         print*,'      ----> FILEO: ',FILEO(1:30)
         endif
 
      if (DIAG) print*,'OPEN10 FILEI: ',FILEI
      open(10,file=FILEI,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'OPEN11 FILEO: ',FILEO
      open(11,file=FILEO,status='unknown',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      i = 0
      j = 0
      NREAD = -1
 099  continue
      NREAD = NREAD + 1
      if (DIAG) print*,'   '
      naxes =  0
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
 100  continue
      i = i + 1
      j = j + 1
      if (DIAG) write(*,'(80(''-''))')
      read(10,rec=i,iostat=ios) buffc
      atend = .false.
      do k = 00, 35
         if (DIAG)
     .   write(*,'(''NREAD='',i1,3x,
     .             ''IREC='',i9.9,1x,
     .             ''JREC='',i9.9,1x,i2,1x,a80)')
     .               NREAD,i,j,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+31)
 
 
 
         if (NREAD.eq.1.or.NREAD.eq.4) then
            if (field.eq.'BITPIX  ') write(buffc(k*80+01:k*80+80),111)
  111             format('BITPIX  =                  -32 / bits pe',
     .                   'r data value                            ')
            if (field.eq.'BZERO   ') write(buffc(k*80+01:k*80+80),112)
  112             format('BZERO   =                  0.0 / physica',
     .                   'l value for an array value of zero      ')
            endif
         if (NREAD.eq.1) then
            if (field.eq.'DATAMIN ')
     .          write(buffc(k*80+01:k*80+80),113) pix1min
            if (field.eq.'DATAMAX ')
     .          write(buffc(k*80+01:k*80+80),114) pix1max
            endif
         if (NREAD.eq.4) then
            if (field.eq.'DATAMIN ')
     .          write(buffc(k*80+01:k*80+80),113) pix4min
            if (field.eq.'DATAMAX ')
     .          write(buffc(k*80+01:k*80+80),114) pix4max
            endif
  113    format('DATAMIN =             ',f8.2,' / physica',
     .          'l value for an array value of zero      ')
  114    format('DATAMAX =             ',f8.2,' / physica',
     .          'l value for an array value of zero      ')
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (buffc(k*80+01:k*80+3).eq.'END') atend = .true.
         enddo
      if (.not.atend) then
         write(11,rec=j,iostat=ios) buffc
         goto 100
         endif
      write(11,rec=j,iostat=ios) buffc
 
      if (DIAG) then
         print*,' '
         print*,'PROCESS...'
         print*,'   NREAD = ',NREAD
         print*,'   NAXIS = ',NAXES
         print*,'   LAXIS1= ',laxis(1)
         print*,'   LAXIS2= ',laxis(2)
         print*,' '
         endif
 
      if (NREAD.eq.6) then
         close(10)
         close(11)
         return
         endif
 
      if (naxes.eq.0) goto 099
 
      ifirst = i+1 ! first record of the image in this extension
      jfirst = j+1 ! first record of the image in this extension
 
      nbperi  = 2*laxis(1)*laxis(2)
      npti    =   laxis(1)*laxis(2)
      nbyte1i = 1
      nbyte2i = nbperi
      i1 = i+1 + nbyte1i/2880
      i2 = i+1 + nbyte2i/2880
 
      nbperj  = 4*laxis(1)*laxis(2)
      nptj    =   laxis(1)*laxis(2)
      nbyte1j = 1
      nbyte2j = nbperj
      j1 = j+1 + nbyte1j/2880
      j2 = j+1 + nbyte2j/2880
 
      if (NREAD.eq.2.or.NREAD.eq.3.or.
     .    NREAD.eq.5.or.NREAD.eq.6) then
          print*,'NREAD = ',NREAD
          print*,'naxes = ',naxes
          print*,'we shouldnt be here for anything'
          print*,'but NREAD=1 and NREAD=4 '
          stop
          endif
 
      if (NREAD.eq.1) then
         if (DIAG) print*,'NREAD = 1... OUTPUT IMAGE'
         do j = j1, j2, 1
            nbyte0 = (j-jfirst)*2880+   1
            nbyteE = (j-jfirst)*2880+2880
            np1 = (nbyte0-nbyte1j)/4 + 1
            np2 = (nbyteE-nbyte1j)/4 + 1
            call pix2buff_r4_(buffb,pix1,np1,nptj)
            write(11,rec=j,iostat=ios) buffc
            enddo
         i = i2
         j = j2
         goto 099
         endif
 
      if (NREAD.eq.4) then
         if (DIAG) print*,'NREAD = 4... OUTPUT IMAGE'
         do j = j1, j2, 1
            nbyte0 = (j-jfirst)*2880+   1
            nbyteE = (j-jfirst)*2880+2880
            np1 = (nbyte0-nbyte1j)/4 + 1
            np2 = (nbyteE-nbyte1j)/4 + 1
            call pix2buff_r4_(buffb,pix4,np1,nptj)
            write(11,rec=j,iostat=ios) buffc
            enddo
         i = i2
         j = j2
         goto 099
         endif
 
      print*,'cowrite_raw_rbc should never get here...'
      stop
 
      return
 
 900  continue
      print*,'cowritefits_raw: READFITS ERROR'
      stop
 
      end
 
 
 
c-------------------------------------------------------
c
c
      subroutine pix2buff_r4_(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      real*4 pix(*)
      integer n1,nt
 
      byte b(4)
      real*4 r
      equivalence(r,b)
 
      integer i, npu, nbu
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (npu.ge.1.and.npu.le.nt) r = pix(npu)
         if (.not.(_LINUX_)) then
            buff(nbu+1) = b(1)
            buff(nbu+2) = b(2)
            buff(nbu+3) = b(3)
            buff(nbu+4) = b(4)
            endif
         if ((_LINUX_)) then
            buff(nbu+1) = b(4)
            buff(nbu+2) = b(3)
            buff(nbu+3) = b(2)
            buff(nbu+4) = b(1)
            endif
         enddo
 
      return
      end
 
 
 
c------------------------------------------------
c
c find the average value of the reference pixels;
c with sigma clipping at SIG_CLIP
c
c
      subroutine find_refbar(pix_ij,rowuse,
     .                       refbar,refsig,refuse,SIG_CLIP)
      implicit none
 
      real    pix_ij(2072,2068)
      byte    rowuse(2068)
      real    refbar
      real    refsig
      integer refuse
      real SIG_CLIP
 
 
      integer i, j
      real*8  stot
      real*8  ptot
      integer ntot
      integer ntoto
      real*8  bar, sig
      byte    pixu(24,2068)
      integer NIT
 
      ntot = 0
      do i = 0001, 0024
      do j = 0001, 2068
         pixu(i,j) = rowuse(j)
         ntot = ntot + pixu(i,j)
         enddo
         enddo
 
      NIT = 0
    1 continue
      ntoto = ntot
      NIT = NIT + 1
 
      ptot = 0.
      ntot = 0
      do i = 0001, 0024
      do j = 0001, 2068
         ptot = ptot + pixu(i,j)*pix_ij(i,j)
         ntot = ntot + pixu(i,j)
         enddo
         enddo
      bar = ptot/ntot
 
      stot = 0.
      do i = 0001, 0024
      do j = 0001, 2068
         stot = stot + pixu(i,j)*abs(pix_ij(i,j)-bar)
         enddo
         enddo
      sig = stot/ntot
 
      ntot = 0
      do i = 0001, 0024
      do j = 0001, 2068
         if (abs(pix_ij(i,j)-bar).gt.SIG_CLIP*sig) pixu(i,j) = 0
         ntot = ntot + pixu(i,j)
         enddo
         enddo
      close(31)
 
      if (NIT.le.05) goto 1
      if (NIT.le.10.and.ntot.lt.ntoto) goto 1  ! iterate max 10 times; only repeat if we've rejected pixels
 
      refbar = SNGL(bar)
      refsig = SNGL(sig)
      refuse = ntot
 
 
      stot = 0.
      ntot = 0
      do i = 0001, 0024
      do j = 0001, 2068
         stot = stot + pixu(i,j)*(pix_ij(i,j)-bar)**2
         ntot = ntot + pixu(i,j)
         enddo
         enddo
      refsig = SNGL(sqrt(stot/ntot))
 
      return
      end
 
 
 
 
c--------------------------------------------------------------
c
c this will find the column-by-column residual for each row
c      refcolbar(i) is the average of each column relative
c      refcolsig(i) is the sigma along the column
c
      subroutine find_refcol(pix_ij,refcolbar,refcolsig)
      implicit none
 
      real pix_ij(2072,2068)
      real refcolbar(24)
      real refcolsig(24)
 
      integer i, j
      real*8  ptot
      real*8  pnorm(24,2068)
      real*8  collist(2068)
      real*8  bar, sig
      integer Ns, Nu
 
c---------------------------------------------
c
c Subtract the average for each row, so that we can
c focus on the column-by-column behavior.  Since
c most of the columns start high and asymtote after
c 12 pixels or so, let's define the average by the
c right half.
c
      do j = 0001, 2068
         ptot = 0.
         do i = 0013, 0024
            ptot = ptot + pix_ij(i,j)
            enddo
         bar = ptot/12
         do i = 0001, 0024
            pnorm(i,j) = pix_ij(i,j) - bar  ! pnorm is the residual
            enddo
         enddo
 
      do i = 01, 24
         Ns = 0
         do j = 0001, 2068
            if (pix_ij(25,j).lt.25000.and.   ! I have found that if there are saturated
     .          pix_ij(26,j).lt.25000.and.   !    pixels near the reference pixels,
     .          pix_ij(27,j).lt.25000.and.   !    they can bleed into the ref pixels
     .          pix_ij(28,j).lt.25000.and.   !    and mess up the column by column
     .          pix_ij(29,j).lt.25000.and.   !    trends ; so only use columns that
     .          pix_ij(30,j).lt.25000) then  !    are free of trends.
                Ns = Ns + 1
                collist(Ns) = pnorm(i,j)
                endif
            enddo
         call barsig_r4(collist,Ns,bar,sig,5.0,Nu) ! this takes the list of good residuals
c 199    format(i2,1x,f10.2,1x,f10.3,1x,i4)     !   for column#i and determines the
         refcolbar(i) = SNGL(bar)               !   average excess/deficit and its rms
         refcolsig(i) = SNGL(sig)               !   the average will be used to adjust the
         enddo                                  !   column by column ref-pix trends
 
      return
      end
 
 
 
 
c-------------------------------------------------------
c
c
c
      subroutine barsig_r4(xlist,NTOT,bar,sig,SIG_REJ,NUSE)
      implicit none
 
      integer NTOT
      real*8 xlist(NTOT)
      real*8 bar
      real*8 sig
      real   SIG_REJ
      integer NUSE
 
      integer n
      real*8    bsum, ssum
      integer nsum
      integer NIT
 
 
      bar = 0.e0
      sig = 9e9
      do NIT = 1, 5
         bsum = 0.
         ssum = 0.
         nsum = 0.
         do n = 1, NTOT
            if (abs(xlist(n)-bar).le.SIG_REJ*sig) then
               bsum = bsum + xlist(n)
               ssum = ssum + (xlist(n)-bar)**2
               nsum = nsum + 1
               endif
            enddo
         if (nsum.gt.0) bar = bsum / nsum
         if (nsum.gt.1) sig = sqrt(ssum/(nsum-1))
         enddo
      NUSE = nsum
      if (nsum.le.1) sig = 0.999
 
      return
      end
 
 
c-------------------------------------------------------
c
c
c
      subroutine barsiga(xlist,NTOT,bar,sig,SIG_REJ,NUSE)
      implicit none
 
      integer NTOT
      real*8 xlist(NTOT)
      real*8 bar
      real*8 sig
      real   SIG_REJ
      integer NUSE
 
      integer n
      real*8    bsum, ssum
      integer nsum
      integer NIT
 
 
      bar = 0.e0
      sig = 9e9
      do NIT = 1, 15
         bsum = 0.
         ssum = 0.
         nsum = 0.
         do n = 1, NTOT
            if (abs(xlist(n)-bar).le.SIG_REJ*sig) then
               bsum = bsum + xlist(n)
               ssum = ssum + abs(xlist(n)-bar)
               nsum = nsum + 1
               endif
            enddo
         if (nsum.gt.0) bar = bsum / nsum
         if (nsum.gt.1) sig = ssum / (nsum-1)
         enddo
      NUSE = nsum
      if (nsum.le.1) sig = 0.999
 
      return
      end
 
 
c--------------------------------------------------------------
c
c this will subtract the column-by-column trends from the
c reference pixels.
c
      subroutine subt_refcol(pix_ij_BEF,refcolbar,
     .                       pix_ij_AFT)
      implicit none
 
      real pix_ij_BEF(2072,2068)
      real refcolbar(24)
      real pix_ij_AFT(2072,2068)
 
      integer i, j
 
      do i = 0001, 0024
      do j = 0001, 2068
         pix_ij_AFT(i,j) = pix_ij_BEF(i,j) - refcolbar(i)
         enddo
         enddo
 
      do i = 0025, 2072
      do j = 0001, 2068
         pix_ij_AFT(i,j) = pix_ij_BEF(i,j)
         enddo
         enddo
 
      return
      end
 
 
 
c--------------------------------------------------------------
c
c this will output the data needed to optimize the
c correction for bias-drift ; Matt, there's no need
c to translate this routine
c
      subroutine dump_testf(pix_ijk,NARG)
      implicit none
 
      real    pix_ijk(2072,2068,4)
      integer NARG
 
      integer i, j, k, n
 
      real*8  a(20)
      real    f(20)
      real    val
      real*8  ptot, refbar
 
      data f / 0.00100, 0.00095, 0.00090, 0.00085, 0.00080,
     .         0.00075, 0.00070, 0.00065, 0.00060, 0.00055,
     .         0.00050, 0.00045, 0.00040, 0.00035, 0.00030,
     .         0.00025, 0.00020, 0.00015, 0.00010, 0.00005/
 
      open(99,file='dump_testf.ACS_bias',status='unknown')
      do k = 1, 4
         do n = 1, 20
            a(n) = 0.00
            enddo
         do j = 0001, 2068
            ptot = 0
            do i = 01, 24
               ptot = ptot + pix_ijk(i,j,k)
               enddo
            refbar = ptot/24
            write(99,199) NARG,k,j,refbar,(a(n),n=1,20)
  199       format(i3.3,1x,i1,1x,i4.4,3x,f8.2,3x,20(f8.1,1x))
            do i = 0001, 2068+146
               val = 0.00
               if (i.ge.0001.and.i.le.2068) val = pix_ijk(i,j,k)
               do n = 1, 20
                  a(n) = a(n) + (val-a(n))*f(n)
                  enddo
               enddo
            enddo!j
         enddo!k
      close(99)
 
      return
      end
 
 
      subroutine readfits_acsraw2r(FILENAME,pix)
      implicit none
 
      character*80 FILENAME
      real         pix(4096,4096)
 
      real         pixz(8288,2068)
 
      integer i, j
 
      call sub_wfcacs_readraw2raz(FILENAME,pixz)
 
      do i = 0001, 2048
      do j = 0001, 2048
         pix(i+0000,j+0000) = pixz(0*2072+24+i,j)
         pix(4097-i,j+0000) = pixz(1*2072+24+i,j)
         pix(i+0000,4097-j) = pixz(2*2072+24+i,j)
         pix(4097-i,4097-j) = pixz(3*2072+24+i,j)
         enddo
         enddo
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/ACSHRC/read_acshrc_flt_full.f"
c****                                         
c*********************************************
                                              
 
      subroutine read_acshrc_flt_smpl(FILENAME,pix)
      implicit none
 
      character*200 FILENAME
      real      pix(1024,1024)
 
      real*8    CRPIX1, CRPIX2
      real*8    CRVAL1, CRVAL2
      real*8    CD1_1,  CD1_2
      real*8    CD2_1,  CD2_2
 
      integer   LOFLAG, HIFLAG
      real*8    BDRY_XR(4,4)
      real*8    BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
 
      call read_acshrc_flt_full(FILENAME,pix,
     .                          CRPIX1, CRPIX2,
     .                          CRVAL1, CRVAL2,
     .                          CD1_1,  CD1_2,
     .                          CD2_1,  CD2_2,
     .                          LOFLAG, HIFLAG,
     .                          BDRY_XR,  BDRY_YR,
     .                          FILT,EXPT,
     .                          RDAT,PROP)
 
      return
      end
 
 
 
      subroutine read_acshrc_flt_full(FILENAME,pix,
     .                                CRPIX1, CRPIX2,
     .                                CRVAL1, CRVAL2,
     .                                CD1_1,  CD1_2,
     .                                CD2_1,  CD2_2,
     .                                LOFLAG, HIFLAG,
     .                                BDRY_XR,  BDRY_YR,
     .                                FILT,EXPT,
     .                                RDAT,PROP)
      implicit none
 
 
 
 
      character*200 FILENAME
      real      pix(1024,1024)
 
      real*8    CRPIX1, CRPIX2
      real*8    CRVAL1, CRVAL2
      real*8    CD1_1,  CD1_2
      real*8    CD2_1,  CD2_2
 
      integer   LOFLAG, HIFLAG
      real*8    BDRY_XR(4,4)
      real*8    BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
 
      integer NAXIS1
      integer NAXIS2
 
      real*8 COSPA, SINPA
      real*8 PA_APER
      real*8 PA_V3
 
      character*200 FILTU
      character*80 FILT1, FILT2, FILT3, FILT4
      real*8  r8_query_hdre
      real*4  r4_query_hdre
      integer i4_query_hdre
      real*8  rdate_header
 
      integer i, j
 
      print*,'   '
      print*,'ENTER: subroutine read_wfcacs_flt_full '
      print*,'---> FILENAME: ',FILENAME
      print*,'   '
 
      NAXIS1 = INT(r8_query_hdre(FILENAME,'NAXIS1  ',-1))
      NAXIS2 = INT(r8_query_hdre(FILENAME,'NAXIS2  ',-1))
 
      if (NAXIS1.ne.1024.and.NAXIS2.ne.1024)
     .    stop 'only FLT ACS/HRC full frame (for now)'
 
      CRPIX1 = r8_query_hdre(FILENAME,'CRPIX1  ',-1)
      CRPIX2 = r8_query_hdre(FILENAME,'CRPIX2  ',-1)
      CRVAL1 = r8_query_hdre(FILENAME,'CRVAL1  ',-1)
      CRVAL2 = r8_query_hdre(FILENAME,'CRVAL2  ',-1)
 
      PA_APER = r8_query_hdre(FILENAME,'PA_APER ',-1)
      PA_V3   = PA_APER - 0.001
 
      COSPA = cos(PA_V3*3.14159/180.0)
      SINPA = sin(PA_V3*3.14159/180.0)
 
      CD1_1 = -COSPA*0.02829/60/60
      CD1_2 =  SINPA*0.02829/60/60
      CD2_1 =  SINPA*0.02829/60/60
      CD2_2 =  COSPA*0.02829/60/60
 
      PROP = i4_query_hdre(FILENAME,'PROPOSID',-1)
      EXPT = r4_query_hdre(FILENAME,'EXPTIME ',-1)
      RDAT = SNGL(rdate_header(FILENAME))
 
      call query_hdre(FILENAME,'FILTER  ',FILTU,-1)
      call query_hdre(FILENAME,'FILTER1 ',FILT1,-1)
      call query_hdre(FILENAME,'FILTER2 ',FILT2,-1)
      call query_hdre(FILENAME,'FILTNAM1',FILT3,-1)
      call query_hdre(FILENAME,'FILTNAM2',FILT4,-1)
 
      FILT = FILTU(1:5)
      if (FILT1(1:1).eq.'F')  FILT = FILT1(1:5)
      if (FILT2(1:1).eq.'F')  FILT = FILT2(1:5)
      if (FILT3(1:1).eq.'F')  FILT = FILT3(1:5)
      if (FILT4(1:1).eq.'F')  FILT = FILT4(1:5)
      if (FILT1(2:2).eq.'F')  FILT = FILT1(2:6)
      if (FILT2(2:2).eq.'F')  FILT = FILT2(2:6)
      if (FILT3(2:2).eq.'F')  FILT = FILT3(2:6)
      if (FILT4(2:2).eq.'F')  FILT = FILT4(2:6)
 
      LOFLAG =    -50
      HIFLAG = 125000
 
      do i = 1, 4
      do j = 1, 4
         BDRY_XR(i,j) = 0.
         BDRY_YR(i,j) = 0.
         enddo
         enddo
 
      BDRY_XR(1,1) = 0002
      BDRY_YR(1,1) = 0002
      BDRY_XR(2,1) = 1023
      BDRY_YR(2,1) = 0002
      BDRY_XR(3,1) = 1023
      BDRY_YR(3,1) = 1023
      BDRY_XR(4,1) = 0002
      BDRY_YR(4,1) = 1023
 
 
      call readfits_HRC(FILENAME,pix,1)
 
      call HRCIMGFIX(pix)
 
      return
      end
 
 
 
 
 
      subroutine readfits_HRC(FILE,pix,nimg)
      implicit none
 
      character*(*) FILE
      real pix(1024,1024)
 
      character*70 INFO(10)
      common / fitsinfo / INFO
 
      integer nimg
      integer naxes
      integer laxis(3)
 
      character*8  field
      character*20 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
 
      logical LINUX
      data LINUX/.true./
 
      logical first_header
 
      integer NH_RECs
      character*2880 HEADER_STRING(99)
      common /HEADER_STRING_INFO/NH_RECs,HEADER_STRING
 
      open(10,file=FILE,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      bscale = 1.0
      bzero  = 0.0
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
 
      NH_RECs = 0
      first_header = .true.
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buffc
      if (first_header) then
         NH_RECs = NH_RECs + 1
         HEADER_STRING(NH_RECs) = buffc
         endif
      do k = 0, 35, 1
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+31)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'END     ') then
            first_header = .false.
            goto 101
            endif
         enddo
      goto 100
 101  continue
 
 
      nread = nread + 1
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      if (naxes.eq.0) then    ! maybe multiple images stored as extensions
         if (nextend.eq.0) then
            print*,'THIS IS A NULL IMAGE: '
            print*,'NAXES: ',NAXES
            print*,'NEXND: ',NEXTEND
            stop
            endif
         endif
 
      if (nread.ne.nimg+1) then
         nbper  = abs(BITPIX/8)*laxis(1)*laxis(2)
         if (NAXES.eq.0) nbper = 0
         i = int(i + 1.0*nbper/2880 + 0.9999)
         goto 100
         endif
 
      if (laxis(1).ne.1024.or.
     .    laxis(2).ne.1024) then
          print*,'  laxis1: ',laxis(1)
          print*,'  laxis2: ',laxis(2)
          print*,'    1024: ',1024
          print*,'    1024: ',1024
          stop
          endif
 
      if (naxes.eq.2) then   ! nimg is irrelevant; ignore
         nbper  = 4*laxis(1)*laxis(2)
         npt    = laxis(1)*laxis(2)
         nbyte1 = 1
         nbyte2 = nbper
         i1 = i+1 + nbyte1/2880
         i2 = i+1 + nbyte2/2880
         endif
 
      if (naxes.eq.3) then
         nbper  = 4*laxis(1)*laxis(2)
         nbyte1 = 1 + nbper*(nimg-1)
         nbyte2 =     nbper*(nimg  )
         i1 = i+1 + nbyte1/2880
         i2 = i+1 + nbyte2/2880
         npt = laxis(1)*laxis(2)
         endif
 
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         call buff2pix_r4_hrc(buffb,pix,np1,npt)
         enddo
 
      return
 
 900  continue
      print*,'readfits_WFC: READFITS ERROR'
      stop
 
      end
 
 
      subroutine buff2pix_r4_hrc(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      real pix(*)
      integer n1,nt
 
      byte b(4)
      real r
      equivalence(r,b)
 
      integer i, npu, nbu
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (.not.(_LINUX_)) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            b(3) = buff(nbu+3)
            b(4) = buff(nbu+4)
            endif
         if ((_LINUX_)) then
            b(4) = buff(nbu+1)
            b(3) = buff(nbu+2)
            b(2) = buff(nbu+3)
            b(1) = buff(nbu+4)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = r
         enddo
 
      return
      end
 
 
c-----------------------------------------------------
c
c black-out the occulting finger, so no stars will be
c sought there
c
      subroutine HRCIMGFIX(pix)
      implicit none
      real pix(1024,1024)
 
      integer i, j, ic
 
      do j = 1024, 0777, -1
         ic = 349 + (432-349)*(1024-j)/(1024-0777)
         do i = ic-15, ic+15
            pix(i,j) = -100
            enddo
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/WFC3UV/read_wfc3uv_flt_full.f"
c****                                         
c*********************************************
                                              
c
c#include "/user/jayander/FORTRAN/PARLOR/islinux.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/query_hdre.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/query_hdre_i4.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/query_hdre_r4.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/query_hdre_r8.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/rdate_header.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_i2e.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_j2r.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_r4.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_r4e.f"
c#include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_r8e_r4.f"
c#include "/user/jayander/FORTRAN/ROUTINES/STRING/str_contains.f"
c
 
      subroutine read_wfc3uv_flt_smpl(FILENAME,pix)
      character*200 FILENAME
      real      pix(4096,4096)
 
      real*8    CRPIX1, CRPIX2
      real*8    CRVAL1, CRVAL2
      real*8    CD1_1,  CD1_2
      real*8    CD2_1,  CD2_2
 
      integer   LOFLAG, HIFLAG
      real*8    BDRY_XR(4,4)
      real*8    BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
      byte, dimension(:,:), allocatable :: pixq
 
      allocate(pixq(4096,4096))
 
c     print*,'ENTER read_wfc3uv_flt_smpl...'
 
      call read_wfc3uv_flt_full(FILENAME,pix,pixq,
     .                          CRPIX1, CRPIX2,
     .                          CRVAL1, CRVAL2,
     .                          CD1_1,  CD1_2,
     .                          CD2_1,  CD2_2,
     .                          LOFLAG, HIFLAG,
     .                          BDRY_XR,  BDRY_YR,
     .                          FILT,EXPT,
     .                          RDAT,PROP)
 
      deallocate(pixq)
 
c     print*,'EXIT  read_wfc3uv_flt_smpl...'
 
      return
      end
 
 
      subroutine read_wfc3uv_flt_full(FILENAME, pix, pxq,
     .                                CRPIX1, CRPIX2,
     .                                CRVAL1, CRVAL2,
     .                                CD1_1,  CD1_2,
     .                                CD2_1,  CD2_2,
     .                                LOFLAG, HIFLAG,
     .                                BDRY_XR,  BDRY_YR,
     .                                FILT,EXPT,
     .                                RDAT,PROP)
      implicit none
 
 
 
 
      character*200 FILENAME
      real pix(4096,4096)
      byte pxq(4096,4096)
 
      real*8    CRPIX1, CRPIX2
      real*8    CRVAL1, CRVAL2
      real*8    CD1_1,  CD1_2
      real*8    CD2_1,  CD2_2
 
      integer   LOFLAG, HIFLAG
      real*8    BDRY_XR(4,4)
      real*8    BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
 
      integer NAXIS1
      integer NAXIS2
 
      real*8 COSPA, SINPA
      real*8 PA_APER
      real*8 PA_V3
 
      character*20 STREAM
      real*8  r8_query_hdre
      real*4  r4_query_hdre
      integer i4_query_hdre
      real*8  rdate_header
 
      integer i, j
      logical str_contains
 
      real*4, dimension(:,:),   allocatable :: pixz
 
 
c     print*,'   '
c     print*,'ENTER: subroutine read_wfc3uv_flt_full '
c     print*,'---> FILENAME: ',FILENAME
c     print*,'   '
 
      do i = 0001, 4096
      do j = 0001, 4096
         pix(i,j) = -750
         pxq(i,j) =    0
         enddo
         enddo
 
      NAXIS1 = int(r8_query_hdre(FILENAME,'NAXIS1  ',-1))
      NAXIS2 = int(r8_query_hdre(FILENAME,'NAXIS2  ',-1))
 
      CRPIX1 = r8_query_hdre(FILENAME,'CRPIX1  ',-1)
      CRPIX2 = r8_query_hdre(FILENAME,'CRPIX2  ',-1)
      CRVAL1 = r8_query_hdre(FILENAME,'CRVAL1  ',-1)
      CRVAL2 = r8_query_hdre(FILENAME,'CRVAL2  ',-1)
 
      PA_APER = r8_query_hdre(FILENAME,'PA_APER ',-1)
      PA_V3   = PA_APER - 0.0645919
      if (PA_V3.gt.360.0) PA_V3 = PA_V3 - 360.0
      if (PA_V3.lt.000.0) PA_V3 = PA_V3 + 360.0
      COSPA = cos(PA_V3*3.14159/180.0)
      SINPA = sin(PA_V3*3.14159/180.0)
 
      CD1_1 = -COSPA*0.039773/60/60
      CD1_2 =  SINPA*0.039773/60/60
      CD2_1 =  SINPA*0.039773/60/60
      CD2_2 =  COSPA*0.039773/60/60
 
      PROP = i4_query_hdre(FILENAME,'PROPOSID',-1)
      EXPT = r4_query_hdre(FILENAME,'EXPTIME ',-1)
      RDAT = SNGL(rdate_header(FILENAME))
 
      call query_hdre(FILENAME,'FILTER  ',STREAM,-1)
 
      FILT = 'FXXXW'
      if (STREAM(1:1).eq.'F')  FILT = STREAM(1:5)
      if (STREAM(2:2).eq.'F')  FILT = STREAM(2:6)
 
      LOFLAG =   -50
      HIFLAG = 64000
 
      do i = 1, 4
      do j = 1, 4
         BDRY_XR(i,j) = 0.
         BDRY_YR(i,j) = 0.
         enddo
         enddo
 
      BDRY_XR(1,2) = 0001
      BDRY_YR(1,2) = 0001
      BDRY_XR(2,2) = 4095
      BDRY_YR(2,2) = 0001
      BDRY_XR(3,2) = 4095
      BDRY_YR(3,2) = 2047
      BDRY_XR(4,2) = 0001
      BDRY_YR(4,2) = 2047
 
      BDRY_XR(1,1) = 0001
      BDRY_YR(1,1) = 2049
      BDRY_XR(2,1) = 4095
      BDRY_YR(2,1) = 2049
      BDRY_XR(3,1) = 4095
      BDRY_YR(3,1) = 4095
      BDRY_XR(4,1) = 0001
      BDRY_YR(4,1) = 4095
 
      if (str_contains(FILENAME,200,'_flt.fits',09).or.
     .    str_contains(FILENAME,200,'_flc.fits',09)) then
         !print*,'call readfits_WFC4: ',FILENAME(1:40)
          call WFC3UV_FLTREAD(FILENAME,pix,pxq)
          goto 444
          endif
 
      if (str_contains(FILENAME,200,'_WJC.fits',09).or.
     .    str_contains(FILENAME,200,'_WJX.fits',09).or.
     .    str_contains(FILENAME,200,'_WXC.fits',09).or.
     .    str_contains(FILENAME,200,'_WJ2.fits',09)) then
          call readfits_j2r(FILENAME,pix(0001,0001),4096,4096)
          do i = 0001, 4096
          do j = 0001, 4096
             pxq(i,j) = 0
             if (pix(i,j).gt.HIFLAG) pxq(i,j) = 1
             enddo
             enddo
          goto 444
          endif
 
c
c raz type file...
c
      if (NAXIS1.eq.8412.and.NAXIS2.eq.2070) then
          allocate(pixz(8412,2070))
          call readfits_r4(FILENAME,pixz,8412,2070)
          do i = 0001, 2048
          do j = 0001, 2048
             pix(0000+i,0000+j) = pixz(0025+i,j)
             pix(2048+i,0000+j) = pixz(4177-i,j)
             pix(0000+i,4097-j) = pixz(4231+i,j+3)
             pix(2048+i,4097-j) = pixz(8383-i,j+3)
             enddo
             enddo
          deallocate(pixz)
          goto 444
          endif
 
      print*,'PROB : subroutine read_wfc3uv_flt_full '
      print*,'       could not read in file: '
      print*,'       ',FILENAME
      stop
 
 
  444 continue
      do i = 0001, 4096
      do j = 2046, 2051
         pix(i,j) = -750
         enddo
         enddo
 
c     print*,'   '
c     print*,'EXIT : subroutine read_wfc3uv_flt_full '
c     print*,'   '
 
      return
      end
 
 
 
 
 
 
 
 
 
 
 
c--------------------------------------------------------------
c
c check: UVIS-CENTER     --- full array --- ic9r16asq
c        UVIS1           --- udef sub   --- ichl08ujq
c        UVIS2           --- udef sub   --- ichl08ulq
c        UVIS2-M1K1C-SUB --- std sub    --- icdw04ljq_flt.fits
c        UVIS2-C1K1C-SUB --- std sub    --- icck01leq
c        UVIS2-C512C-SUB --- std sub    --- icjd04ezq_flt.fits
c        UVIS2-2K2C-SUB  --- std sub    --- icp601pyq_flt.fits
c        UVIS2-M512C-SUB --- std sub    --- ic8ea1eeq_flt.fits
c
c--------------------------------------------------------------
 
c--------------------------------------------
c
c
      subroutine WFC3UV_FLTREAD(FILE,pix,pxq)
      implicit none
      character*200 FILE
      real pix(4096,4096)
      byte pxq(4096,4096)
 
      character*20 NAMEAP
      real pix0512(0512,0512)
      real pix0513(0513,0512)
      real pix1024(1024,1024)
      real pix1025(1025,1024)
      real pix4096(4096,2051)
      real pix2048(2048,2048)
      real pix2047(2047,2050)
      real pix4096g(4096,2050)
      integer i, j
      character*20 STREAM
 
      integer*2 pix0512i(0512,0512)
      integer*2 pix0513i(0513,0512)
      integer*2 pix1024i(1024,1024)
      integer*2 pix1025i(1025,1024)
      integer*2 pix4096i(4096,2051)
      integer*2 pix4096h(4096,2050)
      integer*2 pix2048i(2048,2048)
      integer*2 pix2047i(2047,2050)
 
 
 
      character*20 STREAM_CENTERA1
      character*20 STREAM_CENTERA2
      character*20 STREAM_SIZAXIS1
      character*20 STREAM_SIZAXIS2
      character*20 STREAM_NAXIS1
      character*20 STREAM_NAXIS2
      character*20 STREAM_BITPIX
      character*20 STREAM_CCDAMP
      character*20 STREAM_BINAXIS1
      character*20 STREAM_BINAXIS2
 
      integer CENTERA1
      integer CENTERA2
      integer SIZAXIS1
      integer SIZAXIS2
      integer NAXIS1
      integer NAXIS2
      integer BITPIX
      character*4 CCDAMP
      integer BINAXIS1
      integer BINAXIS2
 
c
c----------------------------------------------------------
c
 
      logical ISSUBARRAY
 
      ISSUBARRAY = .true.
 
      call query_hdre(FILE,'APERTURE',NAMEAP,-1)
      call query_hdre(FILE,'SUBARRAY',STREAM,-1)
      call query_hdre(FILE,'CENTERA1',STREAM_CENTERA1,-1)
      call query_hdre(FILE,'CENTERA2',STREAM_CENTERA2,-1)
      call query_hdre(FILE,'SIZAXIS1',STREAM_SIZAXIS1,-1)
      call query_hdre(FILE,'SIZAXIS2',STREAM_SIZAXIS2,-1)
      call query_hdre(FILE,'NAXIS1  ',STREAM_NAXIS1,-1)
      call query_hdre(FILE,'NAXIS2  ',STREAM_NAXIS2,-1)
      call query_hdre(FILE,'BITPIX  ',STREAM_BITPIX,-1)
      call query_hdre(FILE,'CCDAMP  ',STREAM_CCDAMP,-1)
 
      BINAXIS1 = 1
      BINAXIS2 = 1
      call query_hdre(FILE,'BINAXIS1',STREAM_BINAXIS1,-1)
      call query_hdre(FILE,'BINAXIS2',STREAM_BINAXIS2,-1)
 
      if (STREAM_CENTERA1(1:4).eq.'NULL') STREAM_CENTERA1 = '0'
      if (STREAM_CENTERA2(1:4).eq.'NULL') STREAM_CENTERA2 = '0'
      if (STREAM_SIZAXIS1(1:4).eq.'NULL') STREAM_SIZAXIS1 = '0'
      if (STREAM_SIZAXIS2(1:4).eq.'NULL') STREAM_SIZAXIS2 = '0'
      if (  STREAM_NAXIS1(1:4).eq.'NULL')   STREAM_NAXIS1 = '0'
      if (  STREAM_NAXIS2(1:4).eq.'NULL')   STREAM_NAXIS2 = '0'
      if (STREAM_BINAXIS1(1:4).eq.'NULL') STREAM_BINAXIS1 = '0'
      if (STREAM_BINAXIS2(1:4).eq.'NULL') STREAM_BINAXIS2 = '0'
 
      read(STREAM_CENTERA1,*) CENTERA1
      read(STREAM_CENTERA2,*) CENTERA2
      read(STREAM_SIZAXIS1,*) SIZAXIS1
      read(STREAM_SIZAXIS2,*) SIZAXIS2
      read(STREAM_NAXIS1  ,*) NAXIS1
      read(STREAM_NAXIS2  ,*) NAXIS2
      read(STREAM_BITPIX  ,*) BITPIX
      read(STREAM_BINAXIS1,*) BINAXIS1
      read(STREAM_BINAXIS2,*) BINAXIS2
 
      CCDAMP = STREAM_CCDAMP(2:5)
 
      do i = 0001, 4096
      do j = 0001, 4096
         pix(i,j) = -750
         enddo
         enddo
 
      if (BINAXIS1.ne.1.or.
     .    BINAXIS2.ne.1) then
          print*,'   '
          print*,'***********************************'
          print*,'*** '
          print*,'*** BINNED IMAGE ',FILE
          print*,'***    '
          print*,'*** DO NOT READ IN...'
          print*,'***    '
          print*,'***********************************'
          print*,'   '
          print*,'  STREAM_BINAXIS1:   ',BINAXIS1,STREAM_BINAXIS1
          print*,'  STREAM_BINAXIS2:   ',BINAXIS2,STREAM_BINAXIS2
          print*,'   '
          return
          endif
 
      if (NAMEAP(01:01).eq.'''') NAMEAP = NAMEAP(02:20)
      do i = 1, 20
         if (NAMEAP(i:i).eq.'''') NAMEAP(i:i) = ' '
         enddo
 
      read(STREAM,*) ISSUBARRAY
 
c     write(*,'(''WFC3UV_FLTREAD NAMEAP: '',20a,'' SUB? '',l1,5x,80a)')
c    .            NAMEAP,ISSUBARRAY,FILE
 
      if (NAMEAP(01:06).eq.'UVIS  '.or.
     .    NAMEAP(01:06).eq.'UVIS1 '.or.
     .    NAMEAP(01:06).eq.'UVIS2 '.or.
     .    NAMEAP(01:09).eq.'UVIS-FIX '.or.
     .    NAMEAP(01:09).eq.'UVIS1-FIX'.or.
     .    NAMEAP(01:09).eq.'UVIS2-FIX'.or.
     .    NAMEAP(01:09).eq.'G280-REF '.or.
     .    NAMEAP(01:09).eq.'UVIS-QUAD'.or.
     .    NAMEAP(01:11).eq.'UVIS-CENTER'.or.
     .    NAMEAP(01:11).eq.'UVIS-IR-FIX'.or.
     .    NAMEAP(01:12).eq.'UVIS1-IR-FIX'.or.
     .    NAMEAP(01:12).eq.'UVIS2-IR-FIX'.or.
     .    NAMEAP(01:15).eq.'UVIS1-C1K1C-CTE'.or.
     .    NAMEAP(01:15).eq.'UVIS2-C1K1C-CTE'.or.
     .    NAMEAP(01:15).eq.'UVIS2-C512C-CTE'.or.
     .    NAMEAP(01:13).eq.'UVIS-QUAD-FIX') then
          if (ISSUBARRAY) then
             print*,' '
             print*,'IMAGE:                    '
             print*,' '
             print*,FILE
             print*,' '
             print*,'HAS A FULL-FRAME APERTURE '
             print*,'BUT IT HAS THE SUBARRAY   '
             print*,'KEYWORD SET TO TRUE.      '
             print*,' '
             print*,'     NAMEAP: ',NAMEAP
             print*,' ISSUBARRAY: ',ISSUBARRAY
             print*,' '
             print*,'ROUTINE IS NOT DESIGNED TO DEAL WITH '
             print*,'USER-DEFINED SUBARRAYS.   '
             print*,' '
             print*,'STOP'
             stop
             endif
          call readfits_WFC3(FILE,pix4096 ,1)
          call readfits_i2e(FILE,pix4096i,4096,2051,3)
          do i = 0001, 4096
          do j = 0001, 2048
             pix(i,j+0000) = pix4096(i,j)
             pxq(i,j+0000) = 0
             if (iand(pix4096i(i,j),int(256,2)).eq.256)
     .           pxq(i,j+0000) = 1
             enddo
             enddo
          call readfits_WFC3(FILE,pix4096,4)
          call readfits_i2e(FILE,pix4096i,4096,2051,6)
          do i = 0001, 4096
          do j = 0001, 2048
             pix(i,j+2048) = pix4096(i,j)
             pxq(i,j+2048) = 0
             if (iand(pix4096i(i,j),int(256,2)).eq.256)
     .           pxq(i,j+2048) = 1
             enddo
             enddo
          do i = 0001, 4096
          do j = 2048-2, 2049+2
             pix(i,j) = -750
             enddo
             enddo
          return
          endif
 
      if (NAMEAP(01:15).eq.'UVIS1-C512A-SUB') then
          call readfits_r4e(FILE,pix0513 ,0513,0512,1)
          call readfits_i2e(FILE,pix0513i,0513,0512,3)
          do i = 0001, 0513
          do j = 0001, 0512-2
             pix(i+0000,j+1538+2048) = pix0513(i,j)
             enddo
             enddo
          do i = 0001, 0513
          do j = 0002, 0511-2
             pxq(i+0000,j+1538+2048) = 0
             if (iand(pix0513i(i,j),int(256,2)).eq.256) then
                pxq(i+0000,j+1538+2048) = 1
                endif
             enddo
             enddo
          return
          endif
 
      if (NAMEAP(01:15).eq.'UVIS2-C1K1C-SUB') then
         !print*,'C1K1Ca: ',FILE
          call readfits_r4e(FILE,pix1025 ,1025,1024,1)
          call readfits_i2e(FILE,pix1025i,1025,1024,3)
          do i = 0001, 1025
          do j = 0001, 1024
             pix(i+0000,j+0001) = pix1025(i,j)
             pxq(i+0000,j+0001) = 0
             if (iand(pix1025i(i,j),int(256,2)).eq.256) then
                pxq(i+0000,j+0001) = 1
                endif
             enddo
             enddo
         !call writfits_r4('pix1025.fits' ,pix1025 ,1025,1024)
         !call writfits_i2('pix1025i.fits',pix1025i,1025,1024)
         !print*,'C1K1Cb: ',FILE
          return
          endif
 
      if (NAMEAP(01:15).eq.'UVIS2-M1K1C-SUB') then
          call readfits_r4e(FILE,pix1024 ,1024,1024,1)
          call readfits_i2e(FILE,pix1024i,1024,1024,3)
          do i = 0001, 1024
          do j = 0001, 1024
             pix(i+1023,j+1027) = pix1024(i,j)
             pxq(i+1023,j+1027) = 0
             if (iand(pix1024i(i,j),int(256,2)).eq.256) then
                      pxq(i+1023,j+1027) = 1
                endif
             enddo
             enddo
          return
          endif
 
      if (NAMEAP(01:15).eq.'UVIS2-C512C-SUB') then
          call readfits_r4e(FILE,pix0513 ,0513,0512,1)
          call readfits_i2e(FILE,pix0513i,0513,0512,3)
          do i = 0001, 0513
          do j = 0001, 0512
             pix(i+0000,j+0001) = pix0513(i,j)
             pxq(i+0000,j+0001) = 0
             if (iand(pix0513i(i,j),int(256,2)).eq.256) then
                pxq(i+0000,j+0001) = 1
                endif
             enddo
             enddo
          return
          endif
 
      if (NAMEAP(01:15).eq.'UVIS2-C512D-SUB') then
          call readfits_r4e(FILE,pix0513 ,0513,0512,1)
          call readfits_i2e(FILE,pix0513i,0513,0512,3)
          do i = 0001, 0513
          do j = 0001, 0512
             pix(i+3583,j+0001) = pix0513(i,j)
             pxq(i+3583,j+0001) = 0
             if (iand(pix0513i(i,j),int(256,2)).eq.256) then
                pxq(i+3583,j+0001) = 1
                endif
             enddo
             enddo
          return
          endif
 
      if (NAMEAP(01:15).eq.'UVIS1-C512B-SUB') then
          call readfits_r4e(FILE,pix0513 ,0513,0512,1)
          call readfits_i2e(FILE,pix0513i,0513,0512,3)
          do i = 0001, 0513
          do j = 0001, 0512-2
             pix(i+3583,j+1538+2048) = pix0513(i,j)
             pxq(i+3583,j+1538+2048) = 0
             if (iand(pix0513i(i,j),int(256,2)).eq.256) then
                pxq(i+3583,j+1538+2048) = 1
                endif
             enddo
             enddo
          return
          endif
 
      if (NAMEAP(01:14).eq.'UVIS2-M512-SUB') then
          call readfits_r4e(FILE,pix0512 ,0512,0512,1)
          call readfits_i2e(FILE,pix0512i,0512,0512,3)
          do i = 0001, 0512
          do j = 0001, 0512
             pix(i+1791,j+1539) = pix0512(i,j)
             pxq(i+1791,j+1539) = 0
             if (iand(pix0512i(i,j),int(256,2)).eq.256) then
                pxq(i+1791,j+1539) = 1
                endif
             enddo
             enddo
          return
          endif
 
      if (NAMEAP(01:15).eq.'UVIS2-M512C-SUB') then
          call readfits_r4e(FILE,pix0512 ,0512,0512,1)
          call readfits_i2e(FILE,pix0512i,0512,0512,3)
          do i = 0001, 0512
          do j = 0001, 0512
             pix(i+1535,j+1539) = pix0512(i,j)
             pxq(i+1535,j+1539) = 0
             if (iand(pix0512i(i,j),int(256,2)).eq.256) then
                pxq(i+1535,j+1539) = 1
                endif
             enddo
             enddo
          return
          endif
 
      if (NAMEAP(01:14).eq.'UVIS1-M512-SUB') then
          call readfits_r4e(FILE,pix0512 ,0512,0512,1)
          call readfits_i2e(FILE,pix0512i,0512,0512,3)
          do i = 0001, 0512
          do j = 0001, 0512
             pix(i+1791,j+2048) = pix0512(i,j)
             pxq(i+1791,j+2048) = 0
             if (iand(pix0512i(i,j),int(256,2)).eq.256) then
                pxq(i+1791,j+2048) = 1
                endif
             enddo
             enddo
          return
          endif
 
 
      if (NAMEAP(01:15).eq.'UVIS2-2K2C-SUB ') then
          call readfits_r4e(FILE,pix2047 ,2047,2050,1)
          call readfits_i2e(FILE,pix2047i,2047,2050,3)
          do i = 0001, 2047
          do j = 0001, 2050
             pix(i+0000,j+0001) = pix2047(i,j)
             pxq(i+0000,j+0001) = 0
             if (iand(pix2047i(i,j),int(256,2)).eq.256) then
                pxq(i+0000,j+0001) = 1
                endif
             enddo
             enddo
          return
          endif
 
      if (NAMEAP(01:15).eq.'UVIS2-2K2D-SUB ') then
          call readfits_r4e(FILE,pix2047 ,2047,2050,1)
          call readfits_i2e(FILE,pix2047i,2047,2050,3)
          do i = 0001, 2047
          do j = 0001, 2050
             pix(i+2049,j+0001) = pix2047(i,j)
             pxq(i+2049,j+0001) = 0
             if (iand(pix2047i(i,j),int(256,2)).eq.256) then
                pxq(i+2049,j+0001) = 1
                endif
             enddo
             enddo
          return
          endif
 
 
      if (NAMEAP(01:15).eq.'UVIS1-2K2B-SUB ') then
c         print*,'read1...'
          call readfits_r4e(FILE,pix2047 ,2047,2050,1)
c         print*,'read3...'
          call readfits_i2e(FILE,pix2047i,2047,2050,3)
          do i = 0001, 2047
          do j = 0001, 2048
             pix(i+2049,j+2048) = pix2047(i,j)
             pxq(i+2049,j+2048) = 0
             if (iand(pix2047i(i,j),int(256,2)).eq.256) then
                pxq(i+2049,j+2048) = 1
                endif
             enddo
             enddo
          return
          endif
 
 
      if (NAMEAP(01:15).eq.'UVIS1-2K2A-SUB ') then
          call readfits_r4e(FILE,pix2047 ,2047,2050,1)
          call readfits_i2e(FILE,pix2047i,2047,2050,3)
          do i = 0001, 2047
          do j = 0001, 2048
             pix(i+0000,j+2048) = pix2047(i,j)
             pxq(i+0000,j+2048) = 0
             if (iand(pix2047i(i,j),int(256,2)).eq.256) then
                pxq(i+0000,j+2048) = 1
                endif
             enddo
             enddo
          return
          endif
 
 
      if (NAMEAP(01:15).eq.'UVIS2          ') then
         print*,'UVIS2... user defined subarray...'
         print*,'UVIS2... really!...'
         print*,'CENTERA1 = ',CENTERA1
         print*,'CENTERA2 = ',CENTERA2
         print*,'SIZAXIS1 = ',SIZAXIS1
         print*,'SIZAXIS2 = ',SIZAXIS2
         do i = 0001, 4096
         do j = 0001, 4096
            pix(i,j) = 0.00
            enddo
            enddo
         if (CENTERA1.eq.1557.and.
     .       CENTERA2.eq.1540.and.
     .       SIZAXIS1.eq.1024.and.
     .       SIZAXIS2.eq.1024) then
             call readfits_r4e(FILE,pix1024 ,1024,1024,1)
             call readfits_i2e(FILE,pix1024i,1024,1024,3)
             do i = 0001, 1024
             do j = 0001, 1024
                pix(i+1020-1,j+1028-1) = pix1024(i,j)
                pxq(i+1020-1,j+1028-1) = 0
                if (iand(pix1024i(i,j),int(256,2)).eq.256) then
                   pxq(i+1020-1,j+1028-1) = 1
                   endif
                enddo
                enddo
             return
             endif
         if (CENTERA2.ne.1027) stop 'CENTERA2.ne.1027'
         if (SIZAXIS1.ne.2048) stop 'SIZAXIS1.ne.2048'
         if (SIZAXIS2.ne.2048) stop 'SIZAXIS2.ne.2048'
         if (CCDAMP.ne.'C   ') stop 'CCDAMP.ne."C   "'
         call readfits_r4e(FILE,pix2048 ,2048,2048,1)
         call readfits_i2e(FILE,pix2048i,2048,2048,3)
         do i = 0001, 2048
         do j = 0001, 2048
            pix(i+1024-1,j+0003-1) = pix2048(i,j)
            pxq(i+1024-1,j+0003-1) = 0
            if (iand(pix2048i(i,j),int(256,2)).eq.256) then
                pxq(i+1024-1,j+0003-1) = 1
                endif
            enddo
            enddo
         return
         endif
 
 
      if (NAMEAP(01:15).eq.'UVIS1          ') then
         print*,'UVIS1... user defined subarray...'
         if (CENTERA1.ne.2073) stop 'CENTERA1.ne.2073'
         if (CENTERA2.ne.1027) stop 'CENTERA2.ne.1027'
         if (SIZAXIS1.ne.2048) stop 'SIZAXIS1.ne.2048'
         if (SIZAXIS2.ne.2048) stop 'SIZAXIS2.ne.2048'
         if (CCDAMP.ne.'A   ') stop 'CCDAMP.ne."A   "'
         print*,' FILE: ',FILE
         print*,'CALL readfits_r4e...'
         call readfits_r4e(FILE,pix2048 ,2048,2048,1)
         call readfits_i2e(FILE,pix2048i,2048,2048,3)
         print*,'RETN readfits_r4e...'
         print*,'LOOP1...'
         print*,'LOOP2...'
         do i = 0001, 2048
         do j = 0001, 2048
            if (i+1024-0001.ge.0001.and.i+1024-0001.le.4096.and.
     .          j+0003+2048.ge.0001.and.j+0003+2048.le.4096) then
                pix(i+1024-1,j+0003+2048-1) = pix2048(i,j)
                pxq(i+1024-1,j+0003+2048-1) = 0
                if (iand(pix2048i(i,j),int(256,2)).eq.256) then
                    pxq(i+1024-1,j+0003+2048-1) = 1
                    endif
                endif
            enddo
            enddo
         print*,'LOOP3...'
         print*,'RETN'
         return
         endif
 
      if (NAMEAP(01:15).eq.'UVIS2-2K4-SUB  ') then
         if (CENTERA1.ne.2074) stop 'CENTERA1.ne.2074'
         if (CENTERA2.ne.1027) stop 'CENTERA2.ne.1027'
         if (CCDAMP.ne.'D   ') stop 'CCDAMP.ne."D   "'
         print*,'FILE: ',FILE
         print*,'CALL readfits_r4e...'
         call readfits_r4e(FILE,pix4096g,4096,2050,1)
         print*,'CALL readfits_i2e...'
         call readfits_i2e(FILE,pix4096h,4096,2050,3)
        !print*,'RETN readfits_r4e...'
        !print*,'LOOP1...'
         do i = 0001, 4096
         do j = 0001, 2048
            pix(i,j) = pix4096g(i,j)
            pxq(i,j) = 0
            if (iand(pix4096h(i,j),int(256,2)).eq.256) pxq(i,j) = 1
            enddo
            enddo
c        print*,'OUTPUT TEMP...'
c        call writfits_r4('temp.fits',pix,4096,4096)
c        if (.true.) stop
         return
         endif
 
 
      if (NAMEAP(01:15).eq.'UVIS1-2K4-SUB  ') then
c        if (CENTERA1.ne.2074) stop 'CENTERA1.ne.2074'
c        if (CENTERA2.ne.1027) stop 'CENTERA2.ne.1027'
c        if (CCDAMP.ne.'D   ') stop 'CCDAMP.ne."D   "'
        !print*,'FILE: ',FILE
        !print*,'CALL readfits_r4e...'
         call readfits_r4e(FILE,pix4096g,4096,2050,1)
         call readfits_i2e(FILE,pix4096h,4096,2050,3)
        !print*,'RETN readfits_r4e...'
        !print*,'LOOP1...'
         do i = 0001, 4096
         do j = 0001, 2048
            pix(i,j+2048) = pix4096g(i,j)
            pxq(i,j+2048) = 0
            if (iand(pix4096h(i,j),int(256,2)).eq.256) pxq(i,j+2048) = 1
            enddo
            enddo
c        print*,'OUTPUT TEMP...'
c        call writfits_r4('temp.fits',pix,4096,4096)
         return
         endif
 
c4444 continue
 
      do i = 0001, 4096
      do j = 0001, 4096
         pix(i,j) = -1000
         pxq(i,j) = 0
         pxq(i,j) = 1
         enddo
         enddo
 
      print*,' '
      print*,'4444 '
      print*,' '
      print*,'WFC3UV_FLTREAD not yet designed to operate on'
      print*,'          '
      print*,'    FILE: ',FILE(1:200)
      print*,'          '
      print*,'aperture: ',NAMEAP
      print*,'subarray: ',ISSUBARRAY
      print*,'AS A SUBARRAY...'
      print*,' '
      return
 
      end
 
 
 
 
 
c--------------------------------------------
c
c
      subroutine readfits_WFC3(FILE,pix,nimg)
      implicit none
 
      character*200 FILE
      real pix(4096,2051)
 
      character*70 INFO(10)
      common / fitsinfo / INFO
 
      integer nimg
      integer naxes
      integer laxis(3)
 
      character*8  field
      character*20 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
      logical islinux, islinuxu
 
 
      character*70 HDR(25)
      common/HDR/HDR
 
      open(10,file=FILE,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
 
      bscale = 1.0
      bzero  = 0.0
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
      do i = 1, 25
         HDR(i) = ' '
         enddo
 
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buffc
      do k = 0, 35, 1
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+31)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'EXPTIME ') INFO(01) = stream
         if (field.eq.'FILTER  ') INFO(02) = stream
         if (field.eq.'FILENAME') INFO(03) = stream
         if (field.eq.'DATE-OBS') INFO(04) = stream
         if (field.eq.'TIME-OBS') INFO(05) = stream
         if (field.eq.'DEC_TARG') INFO(06) = stream
         if (field.eq.'RA_TARG ') INFO(07) = stream
         if (field.eq.'PA_V3   ') INFO(08) = stream
         if (field.eq.'PROPOSID') INFO(09) = stream
         if (field.eq.'CCDGAIN ') INFO(10) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER  ') HDR(22) = stream
         if (field.eq.'FILTER  ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
         if (field.eq.'CCDGAIN ') HDR(25) = stream
         if (field.eq.'END     ') goto 101
         enddo
      goto 100
 101  continue
 
 
      nread = nread + 1
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      if (naxes.eq.0) then    ! maybe multiple images stored as extensions
         if (nextend.eq.0) then
            print*,'THIS IS A NULL IMAGE: '
            print*,'NAXES: ',NAXES
            print*,'NEXND: ',NEXTEND
            stop
            endif
         endif
 
      if (nread.ne.nimg+1) then
         nbper  = abs(BITPIX/8)*laxis(1)*laxis(2)
         if (NAXES.eq.0) nbper = 0
         i = int(i + 1.0*nbper/2880 + 0.9999)
         goto 100
         endif
 
      if (laxis(1).ne.4096.or.
     .    laxis(2).ne.2051) then
          print*,'  laxis1: ',laxis(1)
          print*,'  laxis2: ',laxis(2)
          print*,'    4096: ',4096
          print*,'    2051: ',2051
          stop
          endif
 
      if (naxes.eq.2) then   ! nimg is irrelevant; ignore
         nbper  = 4*laxis(1)*laxis(2)
         npt    = laxis(1)*laxis(2)
         nbyte1 = 1
         nbyte2 = nbper
         i1 = i+1 + nbyte1/2880
         i2 = i+1 + nbyte2/2880
         endif
 
      if (naxes.eq.3) then
         nbper  = 4*laxis(1)*laxis(2)
         nbyte1 = 1 + nbper*(nimg-1)
         nbyte2 =     nbper*(nimg  )
         i1 = i+1 + nbyte1/2880
         i2 = i+1 + nbyte2/2880
         npt = laxis(1)*laxis(2)
         endif
 
      islinuxu = islinux()
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         call buff2pix_r4q(buffb,pix,np1,npt,islinuxu)
         enddo
 
      return
 
 900  continue
      print*,'readfits_WFC3: READFITS ERROR'
      stop
 
      end
 
 
      subroutine buff2pix_r4q(buff,pix,n1,nt,islinuxu)
      implicit none
      byte buff(2880)
      real pix(*)
      integer n1,nt
      logical islinuxu
 
      byte b(4)
      real r
      equivalence(r,b)
 
      integer i, npu, nbu
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
         if (.not.islinuxu) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            b(3) = buff(nbu+3)
            b(4) = buff(nbu+4)
            endif
         if (islinuxu) then
            b(4) = buff(nbu+1)
            b(3) = buff(nbu+2)
            b(2) = buff(nbu+3)
            b(1) = buff(nbu+4)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = r
         enddo
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/WFPC2/read_wfpc2_flt_full.f"
c****                                         
c*********************************************
                                              
 
      subroutine read_wfpc2_flt_full(FILENAME,pix,
     .                               CRPIX1, CRPIX2,
     .                               CRVAL1, CRVAL2,
     .                               CD1_1,  CD1_2,
     .                               CD2_1,  CD2_2,
     .                               LOFLAG, HIFLAG,
     .                               BDRY_XR,  BDRY_YR,
     .                               FILT,EXPT,
     .                               RDAT,PROP)
      implicit none
 
 
 
 
      character*(*) FILENAME
      real      pix(1600,1600)
 
      real*8    CRPIX1, CRPIX2
      real*8    CRVAL1, CRVAL2
      real*8    CD1_1,  CD1_2
      real*8    CD2_1,  CD2_2
 
      integer   LOFLAG, HIFLAG
      real*8    BDRY_XR(4,4)
      real*8    BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
 
      integer NAXIS1
      integer NAXIS2
 
c     real*8 COSPA, SINPA
      real*8 PA_V3
 
      real   rGAIN
      character*80 FILTU
      character*80 FILT3
      character*80 FILT4
      real*8  r8_query_hdre
      real*4  r4_query_hdre
      integer i4_query_hdre
      real*8  rdate_header
 
      integer i, j
c     integer k
 
      real*4, dimension(:,:,:), allocatable :: pix_3D
      character*03 TYP
c     character*80 STREAM
 
 
      allocate(pix_3d(800,800,4))
 
      HIFLAG = 25000
      LOFLAG = -50.0
      print*,' '
      print*,'read in pix file...',FILENAME
      print*,' '
 
      TYP = 'XXX'
      do i = 1, 75
         if (FILENAME(i:i+8).eq.'_c0f.fits') TYP = 'c0f'
         if (FILENAME(i:i+8).eq.'_c0m.fits') TYP = 'c0m'
         enddo
      if (TYP.eq.'c0f') then
          print*,'readfits_r4_3D...',FILENAME
          call readfits_r4_3D(FILENAME,pix_3D,800,800,4)
          endif
      if (TYP.eq.'c0m') then
          print*,'readfits_r4e...',FILENAME
          call readfits_r4e(FILENAME,pix_3D(1,1,1),800,800,1)
          call readfits_r4e(FILENAME,pix_3D(1,1,2),800,800,2)
          call readfits_r4e(FILENAME,pix_3D(1,1,3),800,800,3)
          call readfits_r4e(FILENAME,pix_3D(1,1,4),800,800,4)
          endif
 
      NAXIS1 = 1600
      NAXIS2 = 1600
 
      rGAIN = r4_query_hdre(FILENAME,'ATODGAIN',-1)
 
      do i = 001, 800
      do j = 001, 800
         if (i.lt.045) pix_3D(i,j,1) = -999.9
         if (j.lt.055) pix_3D(i,j,1) = -999.9
         if (i.lt.050) pix_3D(i,j,2) = -999.9
         if (j.lt.025) pix_3D(i,j,2) = -999.9
         if (i.lt.030) pix_3D(i,j,3) = -999.9
         if (j.lt.045) pix_3D(i,j,3) = -999.9
         if (i.lt.045) pix_3D(i,j,4) = -999.9
         if (j.lt.045) pix_3D(i,j,4) = -999.9
         if (i.gt.797) then
            pix_3D(i,j,1) = -999.9
            pix_3D(i,j,2) = -999.9
            pix_3D(i,j,3) = -999.9
            pix_3D(i,j,4) = -999.9
            endif
         if (j.gt.797) then
            pix_3D(i,j,1) = -999.9
            pix_3D(i,j,2) = -999.9
            pix_3D(i,j,3) = -999.9
            pix_3D(i,j,4) = -999.9
            endif
         pix(i+000,j+000) = pix_3D(i,j,1)*rGAIN
         pix(i+800,j+000) = pix_3D(i,j,2)*rGAIN
         pix(i+800,j+800) = pix_3D(i,j,3)*rGAIN
         pix(i+000,j+800) = pix_3D(i,j,4)*rGAIN
         enddo
         enddo
      deallocate(pix_3D)
 
      CRPIX1 = r8_query_hdre(FILENAME,'CRPIX1  ',-1)
      CRPIX2 = r8_query_hdre(FILENAME,'CRPIX2  ',-1)
      CRVAL1 = r8_query_hdre(FILENAME,'CRVAL1  ',-1)
      CRVAL2 = r8_query_hdre(FILENAME,'CRVAL2  ',-1)
 
      PA_V3 = r4_query_hdre(FILENAME,'PA_V3   ',-1)
      PA_V3 = PA_V3 - 0.1884335 - 315.0 - 0.321
      CD1_1 = -2.77778e-05*cos(PA_V3*3.14159/180.0)/1.003
      CD2_1 =  2.77778e-05*sin(PA_V3*3.14159/180.0)/1.003
      CD1_2 =  2.77778e-05*sin(PA_V3*3.14159/180.0)/1.003
      CD2_2 =  2.77778e-05*cos(PA_V3*3.14159/180.0)/1.003
 
      PROP = i4_query_hdre(FILENAME,'PROPOSID',-1)
      EXPT = r4_query_hdre(FILENAME,'EXPTIME ',-1)
      RDAT = SNGL(rdate_header(FILENAME))
 
      call query_hdre(FILENAME,'FILTER  ',FILTU,-1)
      call query_hdre(FILENAME,'FILTNAM1',FILT3,-1)
      call query_hdre(FILENAME,'FILTNAM2',FILT4,-1)
 
      if (FILTU(1:1).eq.'F') FILT = FILTU(1:5)
      if (FILTU(2:2).eq.'F') FILT = FILTU(2:6)
      if (FILT3(1:1).eq.'F') FILT = FILT3(1:5)
      if (FILT3(2:2).eq.'F') FILT = FILT3(2:6)
      if (FILT4(1:1).eq.'F') FILT = FILT4(1:5)
      if (FILT4(2:2).eq.'F') FILT = FILT4(2:6)
 
      BDRY_XR(1,1) = 0075
      BDRY_YR(1,1) = 0075
      BDRY_XR(2,1) = 0797
      BDRY_YR(2,1) = 0075
      BDRY_XR(3,1) = 0797
      BDRY_YR(3,1) = 0797
      BDRY_XR(4,1) = 0075
      BDRY_YR(4,1) = 0797
 
      BDRY_XR(1,2) = 0075 + 800
      BDRY_YR(1,2) = 0075
      BDRY_XR(2,2) = 0797 + 800
      BDRY_YR(2,2) = 0075
      BDRY_XR(3,2) = 0797 + 800
      BDRY_YR(3,2) = 0797
      BDRY_XR(4,2) = 0075 + 800
      BDRY_YR(4,2) = 0797
 
      BDRY_XR(1,3) = 0075 + 800
      BDRY_YR(1,3) = 0075 + 800
      BDRY_XR(2,3) = 0797 + 800
      BDRY_YR(2,3) = 0075 + 800
      BDRY_XR(3,3) = 0797 + 800
      BDRY_YR(3,3) = 0797 + 800
      BDRY_XR(4,3) = 0075 + 800
      BDRY_YR(4,3) = 0797 + 800
 
      BDRY_XR(1,4) = 0075
      BDRY_YR(1,4) = 0075 + 800
      BDRY_XR(2,4) = 0797
      BDRY_YR(2,4) = 0075 + 800
      BDRY_XR(3,4) = 0797
      BDRY_YR(3,4) = 0797 + 800
      BDRY_XR(4,4) = 0075
      BDRY_YR(4,4) = 0797 + 800
 
      return
 
      end
 
 
c      COSPA = cos(PA_V3*3.14159/180.0)
c      SINPA = sin(PA_V3*3.14159/180.0)
c
c      CD1_1 = -COSPA*0.049730/60/60
c      CD1_2 =  SINPA*0.049730/60/60
c      CD2_1 =  SINPA*0.049730/60/60
c      CD2_2 =  COSPA*0.049730/60/60
c
c      call query_hdre(FILENAME,'FILTER  ',FILT )
c      call query_hdre(FILENAME,'FILTER1 ',FILT1)
c      call query_hdre(FILENAME,'FILTER2 ',FILT2)
c      call query_hdre(FILENAME,'FILTNAM1',FILT3)
c      call query_hdre(FILENAME,'FILTNAM2',FILT4)
c
c      if (FILT1(1:1).eq.'F')  FILT = FILT1(1:5)
c      if (FILT2(1:1).eq.'F')  FILT = FILT2(1:5)
c      if (FILT3(1:1).eq.'F')  FILT = FILT3(1:5)
c      if (FILT4(1:1).eq.'F')  FILT = FILT4(1:5)
c      if (FILT1(2:2).eq.'F')  FILT = FILT1(2:6)
c      if (FILT2(2:2).eq.'F')  FILT = FILT2(2:6)
c      if (FILT3(2:2).eq.'F')  FILT = FILT3(2:6)
c      if (FILT4(2:2).eq.'F')  FILT = FILT4(2:6)
c
c      LOFLAG =   -50
c      HIFLAG = 60000
c
c      do i = 1, 4
c      do j = 1, 4
c         BDRY_XR(i,j) = 0.
c         BDRY_YR(i,j) = 0.
c         enddo
c         enddo
c
c      BDRY_XR(1,1) = 0001
c      BDRY_YR(1,1) = 0001
c      BDRY_XR(2,1) = 4095
c      BDRY_YR(2,1) = 0001
c      BDRY_XR(3,1) = 4095
c      BDRY_YR(3,1) = 2047
c      BDRY_XR(4,1) = 0001
c      BDRY_YR(4,1) = 2047
c
c      BDRY_XR(1,2) = 0001
c      BDRY_YR(1,2) = 2049
c      BDRY_XR(2,2) = 4095
c      BDRY_YR(2,2) = 2049
c      BDRY_XR(3,2) = 4095
c      BDRY_YR(3,2) = 4095
c      BDRY_XR(4,2) = 0001
c      BDRY_YR(4,2) = 4095
c
c
c      call readfits_WFC(FILENAME,pix(0001,2049),4)
c      call readfits_WFC(FILENAME,pix(0001,0001),1)
c
c      do i = 0001, 4096
c      do j = 2046, 2051
c         pix(i,j) = -750
c         enddo
c         enddo
c
c      return
c      end
c
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/HSTDRZ/read_hstdrz_full.f"
c****                                         
c*********************************************
                                              
 
 
c*********************************************
c****
c**** #include "/user/jayander/FORTRAN/FITSIO/HSTDRZ/read_hstdrz_full.f"
c****
c*********************************************
 
 
 
      subroutine read_hstdrz_full(FILENAME,
     .                            pix,NAXIS1,NAXIS2,
     .                            CRPIX1,   CRPIX2,
     .                            CRVAL1,   CRVAL2,
     .                            CD1_1,    CD1_2,
     .                            CD2_1,    CD2_2,
     .                            LOFLAG,   HIFLAG,
     .                            BDRY_XR,  BDRY_YR,
     .                            FILT,     EXPT,
     .                            RDAT,     PROP)
      implicit none
 
      character*200 FILENAME
      real          pix(NAXIS1,NAXIS2)
      integer       NAXIS1
      integer       NAXIS2
 
      real*8       CRPIX1, CRPIX2
      real*8       CRVAL1, CRVAL2
      real*8       CD1_1,  CD1_2
      real*8       CD2_1,  CD2_2
 
      integer      LOFLAG, HIFLAG
      real*8       BDRY_XR(4,4)
      real*8       BDRY_YR(4,4)
 
      character*05 FILT
      real*4       EXPT
      real*4       RDAT
      integer      PROP
 
      character*200 FILENAMEu
 
      byte            , dimension(:,:), allocatable :: sat
      integer (kind=4), dimension(:,:), allocatable :: pxn
      real    (kind=4), dimension(:,:), allocatable :: pxf
      real    (kind=4), dimension(:,:), allocatable :: pxg
      byte            , dimension(:,:), allocatable :: uuu
 
      integer Ns
      integer i, j, k, kk, kkx
      integer i_k(4), j_k(4)
      real    t_k(4)
 
      real*8       rdate_header
      integer*4    i4_query_hdre
      real*4       r4_query_hdre
      real*8       r8_query_hdre
      character*20 STREAM
 
      integer ii, jj
 
      real DMAX, dx, dy, dd, tt, atan2
 
      allocate(sat(NAXIS1,NAXIS2))
      allocate(pxn(NAXIS1,NAXIS2))
      allocate(pxf(NAXIS1,NAXIS2))
      allocate(pxg(NAXIS1,NAXIS2))
      allocate(uuu(NAXIS1,NAXIS2))
 
      LOFLAG = -50
      HIFLAG = 1e9
 
      call query_hdre(FILENAME,'EXTEND  ',STREAM,-1)
 
      if (STREAM(1:4).eq.'NULL') then
          print*,'readfits_r4e[0]: ',FILENAME(1:30)
          call readfits_r4e(FILENAME,pix,NAXIS1,NAXIS2,0)
          CRPIX1 = r8_query_hdre(FILENAME,'CRPIX1  ',-1)
          CRPIX2 = r8_query_hdre(FILENAME,'CRPIX2  ',-1)
          CRVAL1 = r8_query_hdre(FILENAME,'CRVAL1  ',-1)
          CRVAL2 = r8_query_hdre(FILENAME,'CRVAL2  ',-1)
          CD1_1  = r8_query_hdre(FILENAME,'CD1_1   ',-1)
          CD1_2  = r8_query_hdre(FILENAME,'CD1_2   ',-1)
          CD2_1  = r8_query_hdre(FILENAME,'CD2_1   ',-1)
          CD2_2  = r8_query_hdre(FILENAME,'CD2_2   ',-1)
          BDRY_XR(1,1) = 1
          BDRY_YR(1,1) = 1
          BDRY_XR(2,1) = 1
          BDRY_YR(2,1) = NAXIS2
          BDRY_XR(3,1) = NAXIS1
          BDRY_YR(3,1) = NAXIS2
          BDRY_XR(4,1) = NAXIS1
          BDRY_YR(4,1) = 1
          return
         else
          print*,'readfits_r4e[1]: ',FILENAME(1:30)
          call readfits_r4e(FILENAME,pix,NAXIS1,NAXIS2,1)
          print*,'readfits_i4e[3]: ',FILENAME(1:30)
          call readfits_i4e(FILENAME,pxn,NAXIS1,NAXIS2,3)
         endif
 
      do i = 0001, NAXIS1
      do j = 0001, NAXIS2
         sat(i,j) = 0
         uuu(i,j) = 0
         if (.not.(pix(i,j).gt.-999)) then
             sat(i,j) = 2
             pix(i,j) = -999
             endif
         enddo
         enddo
 
      do i = 0001+2, NAXIS1-2
      do j = 0001+2, NAXIS2-2
         do ii = i-1, i+1
         do jj = j-1, j+1
            if (pxn(ii,jj).eq.0.and.sat(i,j).eq.0) sat(i,j) = 1
            enddo
            enddo
         enddo
         enddo
 
      do i = 0001, NAXIS1
         pxn(i,NAXIS2  ) = -999.0
         sat(i,NAXIS2  ) =    1
         pxn(i,NAXIS2-1) = -999.0
         sat(i,NAXIS2-1) =    1
         pxn(i,0001) = -999.0
         sat(i,0001) =    1
         pxn(i,0002) = -999.0
         sat(i,0002) =    1
         enddo
 
      do j = 0001, NAXIS2
         pxn(NAXIS1  ,j) = -999.0
         sat(NAXIS1  ,j) = 1
         pxn(NAXIS1-1,j) = -999.0
         sat(NAXIS1-1,j) = 1
         pxn(0001,j) = -999.0
         sat(0001,j) =    1
         pxn(0002,j) = -999.0
         sat(0002,j) =    1
         enddo
 
      print*,'CALL: blank_edges...'
      call blank_edges(pix,sat,NAXIS1,NAXIS2)
      print*,'CALL: fill_pxf...   '
      call fill_pxf(pix,sat,pxf,pxg,NAXIS1,NAXIS2)
      print*,' SAT = 2 --> -999   '
 
      do i = 0001, NAXIS1
      do j = 0001, NAXIS2
         if (sat(i,j).eq.2) pix(i,j) = -999.0
         enddo
         enddo
 
 
      CRPIX1 = r8_query_hdre(FILENAME,'CRPIX1  ',-1)
      CRPIX2 = r8_query_hdre(FILENAME,'CRPIX2  ',-1)
      CRVAL1 = r8_query_hdre(FILENAME,'CRVAL1  ',-1)
      CRVAL2 = r8_query_hdre(FILENAME,'CRVAL2  ',-1)
      CD1_1  = r8_query_hdre(FILENAME,'CD1_1   ',-1)
      CD1_2  = r8_query_hdre(FILENAME,'CD1_2   ',-1)
      CD2_1  = r8_query_hdre(FILENAME,'CD2_1   ',-1)
      CD2_2  = r8_query_hdre(FILENAME,'CD2_2   ',-1)
 
      print*,'CRPIX: ',CRPIX1,CRPIX2
      print*,'CRVAL: ',CRVAL1,CRVAL2
 
      if (.false.) then
         FILENAMEu = 'sat.fits'
         print*,'writfits_b1: ',FILENAME(1:30)
         call writfits_b1(FILENAMEu,sat,NAXIS1,NAXIS2)
 
         FILENAMEu = 'pxf.fits'
         print*,'writfits_r4: ',FILENAMEu(1:30)
         call writfits_r4(FILENAMEu,pxf,NAXIS1,NAXIS2)
 
         FILENAMEu = 'pxg.fits'
         print*,'writfits_r4: ',FILENAMEu(1:30)
         call writfits_r4(FILENAMEu,pxg,NAXIS1,NAXIS2)
 
         FILENAMEu = 'pix.fits'
         print*,'writfits_r4: ',FILENAMEu(1:30)
         call writfits_r4(FILENAMEu,pix,NAXIS1,NAXIS2)
         endif
 
      PROP = i4_query_hdre(FILENAME,'PROPOSID',-1)
      EXPT = r4_query_hdre(FILENAME,'EXPTIME ',-1)
      RDAT = SNGL(rdate_header(FILENAME))
 
      call query_hdre(FILENAME,'FILTER  ',STREAM,-1)
 
      FILT = 'FXXXW'
      if (STREAM(1:1).eq.'F')  FILT = STREAM(1:5)
      if (STREAM(2:2).eq.'F')  FILT = STREAM(2:6)
 
 
      do k = 1, 4
         Ns = 0
         t_k(k) = -999
         DMAX = 0
         do i = 0001, NAXIS1, 5
         do j = 0001, NAXIS2, 5
            if (pix(i,j).gt.0) then
                dx = (i-NAXIS1/2)
                dy = (j-NAXIS2/2)
                tt = atan2(dy,dx)*180.0/3.14159
                kkx = 0
                do kk = 1, k-1
                   if (abs(tt-t_k(kk)-000).lt.45.or.
     .                 abs(tt-t_k(kk)-360).lt.45.or.
     .                 abs(tt-t_k(kk)+360).lt.45) kkx = kk
                   enddo
                dd = sqrt(dx**2+dy**2)
                Ns = Ns + 1
                if (dd.gt.DMAX.and.kkx.eq.0) then
                    DMAX = dd
                    i_k(k) = i
                    j_k(k) = j
                    t_k(k) = tt
                    endif
                continue
                endif
            enddo
            enddo
         print*,'  k: ',k,i_k(k),j_k(k),t_k(k),dmax,Ns
         BDRY_XR(k,1) = i_k(K)
         BDRY_YR(k,1) = j_k(K)
         enddo
 
      call cosort_rdd(t_k,BDRY_XR,BDRY_YR,4)
 
      do k = 1, 4
         print*,'k: ',k,t_k(K),BDRY_XR(k,1), BDRY_YR(k,1)
         enddo
 
      print*,'        '
      print*,'read_hstdrz_full: '
      print*,'        '
      print*,'CRPIX1: ',CRPIX1,CRPIX2
      print*,'CRVAL1: ',CRVAL1,CRVAL2
      print*,' CD1_1: ',CD1_1, CD1_2
      print*,' CD2_1: ',CD2_1, CD2_2
      print*,'LOFLAG: ',LOFLAG
      print*,'HIFLAG: ',HIFLAG
      print*,'BDRY_X: ',(BDRY_XR(k,1),k=1,4)
      print*,'BDRY_Y: ',(BDRY_YR(k,1),k=1,4)
      print*,'  FILT: ',FILT
      print*,'  EXPT: ',EXPT
      print*,'  RDAT: ',RDAT
      print*,'  PROP: ',PROP
      print*,'        '
 
      return
      end
 
      subroutine cosort_rdd(a,b,c,Ls)
      implicit none
 
      integer Ls
      real*4  a(Ls)
      real*8  b(Ls)
      real*8  c(Ls)
 
      real*8  aa,bb,cc
      integer L, LL
 
      do L = 1, Ls
         do LL = 1, Ls-1
            if (a(LL).gt.a(LL+1)) then
                aa = a(LL)
                bb = b(LL)
                cc = c(LL)
                a(LL) = a(LL+1)
                b(LL) = b(LL+1)
                c(LL) = c(LL+1)
                a(LL+1) = SNGL(aa)
                b(LL+1) = bb
                c(LL+1) = cc
                endif
            enddo
         enddo
 
      return
      end
 
 
 
c----------------------------------------------
c
c
      subroutine blank_edges(pix,sat,PXDIMX,PXDIMY)
      implicit none
 
      integer PXDIMX
      integer PXDIMY
      real pix(PXDIMX,PXDIMY)
      byte sat(PXDIMX,PXDIMY)
 
      integer i, j
      integer iu,ju
      integer NIT
      integer NCHG
      integer SX, SY ! sense
 
c     call writfits_b1('INP_SATa.fits',sat,PXDIMX,PXDIMY)
 
      do i = 0001, PXDIMX, +1
      do j = 0001, PXDIMX, +1
         if (sat(i,j).eq.0) goto 111
         sat(i,j) = 2
         pix(i,j) = -999.9
         enddo
  111    continue
         enddo
 
      do i = 0001, PXDIMX, +1
      do j = PXDIMX, 0001, -1
         if (sat(i,j).eq.0) goto 222
         sat(i,j) = 2
         pix(i,j) = -999.9
         enddo
  222    continue
         enddo
 
      do j = 0001, PXDIMX, +1
      do i = 0001, PXDIMX, +1
         if (sat(i,j).eq.0) goto 333
         sat(i,j) = 2
         pix(i,j) = -999.9
         enddo
  333    continue
         enddo
 
      do j = 0001, PXDIMX, +1
      do i = PXDIMX, 0001, -1
         if (sat(i,j).eq.0) goto 444
         sat(i,j) = 2
         pix(i,j) = -999.9
         enddo
  444    continue
         enddo
 
 
c      NIT = 0
c    1 NIT = NIT + 1
c      NCHG = 0
c      do i = 0001+1, PXDIMX-1, 01
c      do j = 0001+1, PXDIMY-1, 01
c         do SX = 0, 1, 1
c         do SY = 0, 1, 1
c            iu = i
c            ju = j
c            if (SX.eq.1) iu = PXDIMX-(i-1)
c            if (SY.eq.1) ju = PXDIMY-(j-1)
c            if (sat(iu,ju).eq.1) then
c               if (sat(iu+1,ju  ).eq.2.or.
c     .             sat(iu-1,ju  ).eq.2.or.
c     .             sat(iu  ,ju+1).eq.2.or.
c     .             sat(iu  ,ju-1).eq.2.or.
c     .             sat(iu+1,ju+1).eq.2.or.
c     .             sat(iu+1,ju-1).eq.2.or.
c     .             sat(iu-1,ju+1).eq.2.or.
c     .             sat(iu-1,ju-1).eq.2) then
c                   NCHG = NCHG + 1
c                   sat(iu,ju) = 2
c                   endif
c               endif
c            enddo
c            enddo
c         enddo
c         enddo
c      write(*,'(''blank_edges --- NIT: '',i4,1x,i8)') NIT,NCHG
c      if (NCHG.gt.0) goto 1
c
c     call writfits_b1('INP_SATb.fits',sat,PXDIMX,PXDIMY)
 
      return
      end
 
 
 
 
      subroutine fill_pxf(pix,sat,pxf,pxg,PXDIMX,PXDIMY)
      implicit none
 
      integer PXDIMX, PXDIMY
      real pix(PXDIMX,PXDIMY)
      byte sat(PXDIMX,PXDIMY)
      real pxf(PXDIMX,PXDIMY)
      real pxg(PXDIMX,PXDIMY)
 
      integer i,  j
      integer ii, jj
      integer rr
      integer NS, NT
      integer L, Ls, Lo, LL
      integer il(99999)
      integer jl(99999)
      real    fl(99999), fmax
      real    pl(99999), pmax, ptot
 
      integer iu, ju
      integer sx, sy
      integer NIT, NCHG
c     logical ISSAT
 
      do i = 0001, PXDIMX
      do j = 0001, PXDIMY
         pxf(i,j) = 0.
         if (sat(i,j).eq.1) then
            rr = 1
    1       rr = rr+1
            Ls = 0
            NT = 0
            NS = 0
            ptot = 0.
            do ii = -rr, rr
            do jj = -rr, rr
               if (ii**2+jj**2.le.(rr+0.5)**2) then
                   if (i+ii.ge.0001+1.and.i+ii.le.PXDIMX-1.and.
     .                 j+jj.ge.0001+1.and.j+jj.le.PXDIMY-1) then
                       NT = NT + 1
                       if (sat(i+ii,j+jj).eq.1) NS = NS + 1
                       Ls = Ls + 1
                       if (Ls.gt.99999) then
                           print*,'  i: ',i
                           print*,'  j: ',j
                           print*,' rr: ',rr
                           print*,' Ls: ',Ls
                           print*,' pt: ',ptot
                           stop 'Ls.gt.99999'
                           endif
                       ptot = ptot + max(pix(i+ii,j+jj),0.0)
                       endif
                   endif
               enddo
               enddo
            if (NS.gt.0.750*NT) goto 1
            pxf(i,j) = ptot
            endif
         enddo
         enddo
 
      do i = 0001, PXDIMX
      do j = 0001, PXDIMY
         pxg(i,j) = pix(i,j)
         enddo
         enddo
 
      if (.false.) then
      do i = 0001, PXDIMX
      do j = 0001, PXDIMY
         pxg(i,j) = pxf(i,j)
         enddo
         enddo
 
      NIT = 0
    2 NIT = NIT + 1
      NCHG = 0
      do i = 0001+1, PXDIMX-1, 01
      do j = 0001+1, PXDIMX-1, 01
         do SX = 0, 1, 1
         do SY = 0, 1, 1
            iu = i
            ju = j
            if (SX.eq.1) iu = PXDIMX-(i-1)
            if (SY.eq.1) ju = PXDIMY-(j-1)
            if (sat(iu,ju).eq.1) then
               if (pxg(iu,ju).lt.pxg(iu+1,ju  )) then
                   pxg(iu,ju) =  pxg(iu+1,ju  )
                   NCHG = NCHG + 1
                   endif
               if (pxg(iu,ju).lt.pxg(iu-1,ju  )) then
                   pxg(iu,ju) =  pxg(iu-1,ju  )
                   NCHG = NCHG + 1
                   endif
               if (pxg(iu,ju).lt.pxg(iu  ,ju+1)) then
                   pxg(iu,ju) =  pxg(iu  ,ju+1)
                   NCHG = NCHG + 1
                   endif
               if (pxg(iu,ju).lt.pxg(iu  ,ju-1)) then
                   pxg(iu,ju) =  pxg(iu  ,ju-1)
                   NCHG = NCHG + 1
                   endif
               endif
            enddo
            enddo
         enddo
         enddo
      write(*,'(''glom_pxf --- NIT: '',i4,1x,i8)') NIT,NCHG
      if (NCHG.gt.0) goto 2
      endif!
 
      Ns = 0
      do i = 0001+3, PXDIMX-3
      do j = 0001+3, PXDIMY-3
         if (sat(i,j).eq.1) then
             Ns = Ns + 1
             Ls = 1
             il(Ls) = i
             jl(Ls) = j
             pl(Ls) = pix(i,j)
   9         continue
             Lo = Ls
             do L = 1, Ls
                do ii = max(0003,il(L)-1), min(PXDIMX-3,il(L)+1)
                do jj = max(0003,jl(L)-1), min(PXDIMY-3,jl(L)+1)
                   if (sat(ii,jj).eq.2) goto 7
                   if (sat(ii,jj).eq.1) then
                       do LL = 1, Ls
                          if (il(LL).eq.ii.and.jl(LL).eq.jj) goto 8
                          enddo
                       Ls = Ls + 1
                       if (Ls.gt.9999) then
                           print*,'  Ls: ',Ls
                           print*,'   i: ',i,j
                           print*,'  ii: ',ii,jj
                           stop
                           endif
                       il(Ls) = ii
                       jl(Ls) = jj
                       pl(Ls) = pix(ii,jj)
                       fl(Ls) = pxf(ii,jj)
                       endif
    8              continue
                   enddo
                   enddo
                enddo
             if (Ls.gt.Lo) goto 9
    7        continue
             ptot = 0
             pmax = 0
             fmax = 0
             ii   = 1
             jj   = 1
             do L = 1, Ls
                ptot = ptot + pl(L)
                if (pl(L).gt.pmax) then
                    pmax = pl(L)
                    endif
                if (fl(L).gt.fmax) then
                    fmax = fl(L)
                    ii = il(L)
                    jj = jl(L)
                    endif
                enddo
             do L = 1, Ls
                pix(il(L),jl(L)) = -999
                sat(il(L),jl(L)) = 3
                enddo
             if (ii.ge.3.and.ii.le.PXDIMX-3.and.
     .           jj.ge.3.and.jj.le.PXDIMY-3) then
                 pix(ii  ,jj  ) = ptot
                 pix(ii-1,jj  ) = 0.
                 pix(ii+1,jj  ) = 0.
                 pix(ii  ,jj-1) = 0.
                 pix(ii  ,jj+1) = 0.
                 pix(ii-1,jj-1) = 0.
                 pix(ii+1,jj-1) = 0.
                 pix(ii-1,jj+1) = 0.
                 pix(ii+1,jj+1) = 0.
                 pix(ii-2,jj-2) = -999
                 pix(ii-2,jj-1) = -999
                 pix(ii-2,jj  ) = -999
                 pix(ii-2,jj+1) = -999
                 pix(ii-2,jj+2) = -999
                 pix(ii+2,jj-2) = -999
                 pix(ii+2,jj-1) = -999
                 pix(ii+2,jj  ) = -999
                 pix(ii+2,jj+1) = -999
                 pix(ii+2,jj+2) = -999
                 pix(ii+1,jj-2) = -999
                 pix(ii  ,jj-2) = -999
                 pix(ii-1,jj-2) = -999
                 pix(ii-1,jj+2) = -999
                 pix(ii  ,jj+2) = -999
                 pix(ii+1,jj+2) = -999
                 endif
             endif
         enddo
         enddo
 
      print*,'Ns: ',Ns
 
      return
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/GEN/readfits_j2r.f"
c****                                         
c*********************************************
                                              
 
cc-----------------------------------------------------
c
c This reads in an image in jay's integer*2 format into
c a real*4 pixel array
c
      subroutine readfits_j2r(FILE,pix,NX,NY)
      implicit none
 
      character*(*) FILE
      integer NX, NY
      real*4 pix(NX,NY)
 
      character*70 INFO(10)
      common / fitsinfo / INFO
 
      integer naxes
      integer laxis(3)
 
      character*8  field
      character*20 stream
 
      real*4 pixu
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
      integer ii, jj
      integer n
      integer NXU, NYU
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer*2 ibuff(1440)
 
      integer ifirst, i1, i2
c     integer j
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
c     integer r2i
 
      logical LINUX
      data LINUX/.true./
      logical DIAG
      data DIAG /.false./
 
 
      character*70 HDR(25)
      common/HDR/HDR
      character*199 FILEU
 
      FILEU = FILE
      do i = 75,2,-1
         if (FILE(i:i+4).eq.'.fits') FILEU = FILE(1:i+4)
         enddo
 
      open(10,file=FILEU,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      if (DIAG) print*,'...opened'
 
      bscale = 1
      bzero  = 0
 
      naxes = -1
      laxis(1) = 1
      laxis(2) = 1
      laxis(3) = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
      do i = 1, 25
         HDR(i) = ' '
         enddo
      HDR(24) = '  1.000 '
 
      i = 0
      nread = 0
 100  continue
      i = i + 1
      read(10,rec=i,iostat=ios) buffc
      if (DIAG) print*,'READREC: ',i
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+31)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis(1)
         if (field.eq.'NAXIS2  ') read(stream,*) laxis(2)
         if (field.eq.'NAXIS3  ') read(stream,*) laxis(3)
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
 
         if (field.eq.'EXPTIME ') INFO(01) = stream
         if (field.eq.'FILTNAM1') INFO(02) = stream
         if (field.eq.'FILENAME') INFO(03) = stream
         if (field.eq.'DATE-OBS') INFO(04) = stream
         if (field.eq.'TIME-OBS') INFO(05) = stream
         if (field.eq.'DEC_TARG') INFO(06) = stream
         if (field.eq.'RA_TARG ') INFO(07) = stream
         if (field.eq.'PA_V3   ') INFO(08) = stream
         if (field.eq.'PROPOSID') INFO(09) = stream
         if (field.eq.'CCDGAIN ') INFO(10) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER  ') HDR(22) = stream
         if (field.eq.'FILTER  ') HDR(23) = stream
         if (field.eq.'FILTER1 ') HDR(22) = stream
         if (field.eq.'FILTER2 ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
 
         if (field.eq.'END     ') goto 101
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,'----------------------------------------'
         print*,'  NREAD: ',nread
         print*,'NEXTEND: ',nextend
         print*,'  NAXIS: ',naxes
         print*,'  LAXIS: ',laxis(1),laxis(2),laxis(3)
         print*,' BITPIX: ',bitpix
         print*,' BSCALE: ',bscale
         print*,'  BZERO: ',bzero
         endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      if (BITPIX.ne.16) then
         print*,'                '
         print*,'readfits_j2r...: '
         print*,'                '
         print*,'   you called a routine to read in an'
         print*,'   unsigned i2 image, and the image you'
         print*,'   gave it has BITPIX = ',BITPIX
         print*,'   '
         print*,'   FILEU: ',FILEU
         print*,'   '
         do ii = 1, NX
         do jj = 1, NY
            pix(ii,jj) = 0
            enddo
            enddo
         stop
         endif
 
      nbper = 2*laxis(1)*laxis(2)
      npt   =   laxis(1)*laxis(2)
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (laxis(1).gt.NX.and.laxis(2).gt.NY) then
         print*,' not enough image space! '
         print*,' '
         print*,'  laxis1: ',laxis(1)
         print*,'      NX: ',NX
         print*,' '
         print*,'  laxis2: ',laxis(2)
         print*,'      NY: ',NY
         print*,' '
         stop
         endif
 
      NXU = laxis(1)
      NYU = laxis(2)
 
      if (DIAG) then
         print*,'     NX: ',NX
         print*,'     NY: ',NY
         print*,'  NBPER: ',nbper
         print*,'  NBYT1: ',nbyte1
         print*,'  NBYT2: ',nbyte2
         print*,' IFIRST: ',ifirst
         print*,'     I1: ',i1
         print*,'     I2: ',i2
         print*,'    NPT: ',NPT
         endif
      do i = i1, i2, 1
         read(10,rec=i,iostat=ios) buffc
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/2 + 1
         np2 = (nbyteE-nbyte1)/2 + 1
         np2 = min(np2,npt)
         call buff2pix_j2r(buffb,ibuff,0001,1440)
         do n = np1, np2, 1
            jj = n/NXU   + 1
            ii = n-NXU*(jj-1)
            pixu = ibuff(n-np1+1)*bscale+bzero
            if (pixu.gt.55000) pixu = 55000 + (pixu-55000)*5
            pix(ii,jj) = pixu
            enddo
         enddo
 
      if (DIAG) then
         print*,'  NBPER: ',nbper
         print*,'  NBYT1: ',nbyte1
         print*,'  NBYT2: ',nbyte2
         print*,' IFIRST: ',ifirst
         print*,'     I1: ',i1
         print*,'     I2: ',i2
         print*,'    NPT: ',NPT
         endif
 
 
      return
 
 900  continue
      print*,'READFITS_I2 ERROR'
      print*,'    FILE: ',FILE
      stop
 
      end
 
 
 
      subroutine buff2pix_j2r(buff,pix,n1,nt)
      implicit none
      byte buff(2880)
      integer*2 pix(*)
      integer n1,nt
 
      byte b(2)
      integer*2 ii
      equivalence(ii,b)
 
      integer i, npu, nbu
 
      logical islinux
 
      do i = 1, 1440
         npu = n1+i-1
         nbu = (i-1)*2
         if (.not.islinux()) then
            b(1) = buff(nbu+1)
            b(2) = buff(nbu+2)
            endif
         if (islinux()) then
            b(2) = buff(nbu+1)
            b(1) = buff(nbu+2)
            endif
         if (npu.ge.1.and.npu.le.nt) pix(npu) = ii
         enddo
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/STRING/str_contains.f"
c****                                         
c*********************************************
                                              
 
c-----------------------------------------
c
c this routine will return whether STRING1
c contains an incidence STRING2
c
       logical function str_contains(STRING1,L1,STRING2,L2)
       implicit none
 
       character*(*) STRING1
       integer L1
       character*(*) STRING2
       integer L2
 
       integer L1u
       integer L2u
 
       integer L1t
 
       L1u = L1
       L2u = L2
 
       if (L1u.eq.0) then
           L1u = 0
   11      continue
           if (STRING1(L1u+1:L1u+1).eq.' ') goto 12
           goto 11
   12      continue
           endif
 
       if (L2u.eq.0) then
           L2u = 0
   21      continue
           if (STRING1(L2u+1:L2u+1).eq.' ') goto 22
           goto 21
   22      continue
           endif
 
       str_contains = .true.
 
       do L1t = 1, L1u-L2u+1
          if (STRING1(L1t:L1t+L2u-1).eq.STRING2(1:L2u)) return
          enddo
 
       str_contains = .false.
       return
       end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/NOISE/noisesig.f"
c****                                         
c*********************************************
                                              
c
c this function will return random noise in terms of sigma.  The return value
c will be between -2 and 2 and will have a gaussian distribution centered about
c 1 with a sigma of 1  ( exp( (-x**2)/2 ) )
c
 
      real function noise_sig_()
      implicit none
 
      real rand
 
      noise_sig_ = cos(3.1415927*2*rand(0))*sqrt(-2*log(rand(0)))
 
      return
      end
 
 
c
c this function will return random noise in terms of sigma.  The return value
c will be between -2 and 2 and will have a gaussian distribution centered about
c 1 with a sigma of 1  ( exp( (-x**2)/2 ) )
c
 
      real function noise_sig()
      implicit none
 
      real rand
      real rand1
      real rand2
 
      rand1 = rand(0)
      rand2 = rand(0)
      if (rand2.eq.0) rand2 = rand(0)
      noise_sig = cos(3.1415927*2*rand1)*sqrt(-2*log(rand2))
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PSFs/PERT/smoo_psfpert_new.f"
c****                                         
c*********************************************
                                              
 
c-------------------------------------
c
c
      subroutine smoo_psfpert(mi,mo)
      implicit none
 
      real mi(101,101)
      real mo(101,101)
 
      real m0(101,101)
      real m3(101,101)
 
      real ma(101,101)
      real mb(101,101)
 
      real mx(101,101)
 
      integer i, j
      real    r
 
      real cenrat
      common /smoo_psf_/cenrat
 
 
      do i = 1, 101
      do j = 1, 101
         m0(i,j) = mi(i,j)
         enddo
         enddo
 
      call sm3plan(m0,m3,101,101)
 
      do i = 1, 101
      do j = 1, 101
         r = sqrt((i-51.)**2+(j-51.)**2)/4.0
         mx(i,j) = m0(i,j) - m3(i,j)
         enddo
         enddo
 
      call sm5quad(mx,ma,101,101)
      call sm7quad(mx,ma,101,101)
      call sm9quad(mx,ma,101,101)
      call sm5plan(mx,mb,101,101)
 
      do i = 1, 101
      do j = 1, 101
         r = sqrt((i-51.)**2+(j-51.)**2)/4.0
         mo(i,j) = m3(i,j) + mb(i,j)
         if (r.lt.08) mo(i,j) = m3(i,j) + (ma(i,j)+mb(i,j))/2
         if (r.lt.04) mo(i,j) = m3(i,j) +  ma(i,j)
         enddo
         enddo
 
 
 
      return
      end
 
 
 
 
c-----------------------------------
c
c
      subroutine sm3plan(r,s,NX,NY)
      implicit none
 
      integer NX, NY
      real r(NX,NY)
      real s(NX,NY)
 
      integer i, j
      integer im, jm
 
      real A
 
      do i = 1, NX
      do j = 1, NY
         A = 0.
         do im = max(i-1,1), min(i+1,NX)
         do jm = max(j-1,1), min(j+1,NX)
            A = A + r(im,jm)/09
            enddo
            enddo
         s(i,j) = A
         enddo
         enddo
 
      return
      end
 
c------------------------------------
c
c
      subroutine sm5plan(r,s,NX,NY)
      implicit none
 
      integer NX, NY
      real r(NX,NY)
      real s(NX,NY)
 
      integer i, j
      integer iu, ju
      integer im, jm
 
      real dx, dy
      real A, B, C
 
      real AA( 5, 5)
      data AA / ! SUM:     16.0
     .      0.2500,   0.5000,   0.5000,   0.5000,   0.2500,
     .      0.5000,   1.0000,   1.0000,   1.0000,   0.5000,
     .      0.5000,   1.0000,   1.0000,   1.0000,   0.5000,
     .      0.5000,   1.0000,   1.0000,   1.0000,   0.5000,
     .      0.2500,   0.5000,   0.5000,   0.5000,   0.2500/
 
      real BB( 5, 5)
      data BB / ! SUM:     0.0
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000,
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000,
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000,
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000,
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000/
 
      real CC( 5, 5)
      data CC / ! SUM:     0.0
     .     -1.0000,  -1.0000,  -1.0000,  -1.0000,  -1.0000,
     .     -0.5000,  -0.5000,  -0.5000,  -0.5000,  -0.5000,
     .      0.0000,   0.0000,   0.0000,   0.0000,   0.0000,
     .      0.5000,   0.5000,   0.5000,   0.5000,   0.5000,
     .      1.0000,   1.0000,   1.0000,   1.0000,   1.0000/
 
 
      do i = 1, NX
      do j = 1, NY
         iu = max(min(i,NX-2),3)
         ju = max(min(j,NY-2),3)
         A = 0.
         B = 0.
         C = 0.
         do im = 1, 5
         do jm = 1, 5
            A = A + AA(im,jm)*r(iu-3+im,ju-3+jm)/16
            B = B + BB(im,jm)*r(iu-3+im,ju-3+jm)/25
            C = C + CC(im,jm)*r(iu-3+im,ju-3+jm)/25
            enddo
            enddo
         dx = i-iu
         dy = j-ju
         s(i,j) = (A + B*dx + C*dy)
         enddo
         enddo
 
      return
      end
 
 
c------------------------------------
c
c
      subroutine sm5quad(r,s,NX,NY)
      implicit none
 
      integer NX, NY
      real r(NX,NY)
      real s(NX,NY)
 
      integer i, j
      integer iu, ju
      integer im, jm
 
      real dx, dy
      real A, B, C, D, E, F
 
      real AA( 5, 5)
      data AA / ! SUM:     1.0
     .     -1.8571,   0.2857,   1.0000,   0.2857,  -1.8571,
     .      0.2857,   2.4286,   3.1429,   2.4286,   0.2857,
     .      1.0000,   3.1429,   3.8571,   3.1429,   1.0000,
     .      0.2857,   2.4286,   3.1429,   2.4286,   0.2857,
     .     -1.8571,   0.2857,   1.0000,   0.2857,  -1.8571/
 
      real BB( 5, 5)
      data BB / ! SUM:     0.0
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000,
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000,
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000,
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000,
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000/
 
      real CC( 5, 5)
      data CC / ! SUM:     0.0
     .     -1.0000,  -1.0000,  -1.0000,  -1.0000,  -1.0000,
     .     -0.5000,  -0.5000,  -0.5000,  -0.5000,  -0.5000,
     .      0.0000,   0.0000,   0.0000,   0.0000,   0.0000,
     .      0.5000,   0.5000,   0.5000,   0.5000,   0.5000,
     .      1.0000,   1.0000,   1.0000,   1.0000,   1.0000/
 
      real DD( 5, 5)
      data DD / ! SUM:     0.0
     .      0.7143,  -0.3571,  -0.7143,  -0.3571,   0.7143,
     .      0.7143,  -0.3571,  -0.7143,  -0.3571,   0.7143,
     .      0.7143,  -0.3571,  -0.7143,  -0.3571,   0.7143,
     .      0.7143,  -0.3571,  -0.7143,  -0.3571,   0.7143,
     .      0.7143,  -0.3571,  -0.7143,  -0.3571,   0.7143/
 
      real EE( 5, 5)
      data EE / ! SUM:     0.0
     .      1.0000,   0.5000,   0.0000,  -0.5000,  -1.0000,
     .      0.5000,   0.2500,   0.0000,  -0.2500,  -0.5000,
     .      0.0000,   0.0000,   0.0000,   0.0000,   0.0000,
     .     -0.5000,  -0.2500,   0.0000,   0.2500,   0.5000,
     .     -1.0000,  -0.5000,   0.0000,   0.5000,   1.0000/
 
      real FF( 5, 5)
      data FF / ! SUM:     0.0
     .      0.7143,   0.7143,   0.7143,   0.7143,   0.7143,
     .     -0.3571,  -0.3571,  -0.3571,  -0.3571,  -0.3571,
     .     -0.7143,  -0.7143,  -0.7143,  -0.7143,  -0.7143,
     .     -0.3571,  -0.3571,  -0.3571,  -0.3571,  -0.3571,
     .      0.7143,   0.7143,   0.7143,   0.7143,   0.7143/
 
 
      do i = 1, NX
      do j = 1, NY
         iu = max(min(i,NX-2),3)
         ju = max(min(j,NY-2),3)
         A = 0.
         B = 0.
         C = 0.
         D = 0.
         E = 0.
         F = 0.
         do im = 1, 5
         do jm = 1, 5
            A = A + AA(im,jm)*r(iu-3+im,ju-3+jm)/25
            B = B + BB(im,jm)*r(iu-3+im,ju-3+jm)/25
            C = C + CC(im,jm)*r(iu-3+im,ju-3+jm)/25
            D = D + DD(im,jm)*r(iu-3+im,ju-3+jm)/25
            E = E + EE(im,jm)*r(iu-3+im,ju-3+jm)/25
            F = F + FF(im,jm)*r(iu-3+im,ju-3+jm)/25
            enddo
            enddo
         dx = i-iu
         dy = j-ju
         s(i,j) = (A +
     .             B*dx    + C*dy    +
     .             D*dx**2 + E*dx*dy + F*dy**2)
         enddo
         enddo
 
      return
      end
 
 
c------------------------------------
c
c
      subroutine sm7quad(r,s,NX,NY)
      implicit none
 
      integer NX, NY
      real r(NX,NY)
      real s(NX,NY)
 
      integer i, j
      integer iu, ju
      integer im, jm
 
      real*8 A
      real AA(7,7)
 
      data AA / ! SUM:     49.0
     .-2.3333,-0.6667, 0.3333, 0.6667, 0.3333,-0.6667,-2.3333,
     .-0.6667, 1.0000, 2.0000, 2.3333, 2.0000, 1.0000,-0.6667,
     . 0.3333, 2.0000, 3.0000, 3.3333, 3.0000, 2.0000, 0.3333,
     . 0.6667, 2.3333, 3.3333, 3.6667, 3.3333, 2.3333, 0.6667,
     . 0.3333, 2.0000, 3.0000, 3.3333, 3.0000, 2.0000, 0.3333,
     .-0.6667, 1.0000, 2.0000, 2.3333, 2.0000, 1.0000,-0.6667,
     .-2.3333,-0.6667, 0.3333, 0.6667, 0.3333,-0.6667,-2.3333/
 
      do i = 1, NX
      do j = 1, NY
         A = 0.
         do im = 1, 7
         do jm = 1, 7
            iu = i + (im-4)
            ju = j + (jm-4)
            if (iu.ge.001.and.iu.le.NX.and.
     .          ju.ge.001.and.ju.le.NY) then
                A = A + AA(im,jm)*r(iu,ju)/49
                endif
            enddo
            enddo
         s(i,j) = SNGL(A)
         enddo
         enddo
 
      return
      end
 
 
 
c------------------------------------
c
c
      subroutine sm9quad(r,s,NX,NY)
      implicit none
 
      integer NX, NY
      real r(NX,NY)
      real s(NX,NY)
 
      integer i, j
      integer iu, ju
      integer im, jm
 
      real*8 A
 
      real AA( 9, 9)
      data AA / ! SUM:     1.0
     .      0.0000,  -1.9501,  -0.7828,  -0.0824,   0.1511,
     .               -0.0824,  -0.7828,  -1.9501,   0.0000,
     .     -1.9501,  -0.3159,   0.8514,   1.5518,   1.7853,
     .                1.5518,   0.8514,  -0.3159,  -1.9501,
     .     -0.7828,   0.8514,   2.0187,   2.7191,   2.9526,
     .                2.7191,   2.0187,   0.8514,  -0.7828,
     .     -0.0824,   1.5518,   2.7191,   3.4195,   3.6529,
     .                3.4195,   2.7191,   1.5518,  -0.0824,
     .      0.1511,   1.7853,   2.9526,   3.6529,   3.8864,
     .                3.6529,   2.9526,   1.7853,   0.1511,
     .     -0.0824,   1.5518,   2.7191,   3.4195,   3.6529,
     .                3.4195,   2.7191,   1.5518,  -0.0824,
     .     -0.7828,   0.8514,   2.0187,   2.7191,   2.9526,
     .                2.7191,   2.0187,   0.8514,  -0.7828,
     .     -1.9501,  -0.3159,   0.8514,   1.5518,   1.7853,
     .                1.5518,   0.8514,  -0.3159,  -1.9501,
     .      0.0000,  -1.9501,  -0.7828,  -0.0824,   0.1511,
     .               -0.0824,  -0.7828,  -1.9501,   0.0000/
 
      do i = 1, NX
      do j = 1, NY
         A = 0.
         do im = 1, 9
         do jm = 1, 9
            iu = i + (im-5)
            ju = j + (jm-5)
            if (iu.ge.001.and.iu.le.NX.and.
     .          ju.ge.001.and.ju.le.NY) then
                A = A + AA(im,jm)*r(iu,ju)/77
                endif
            enddo
            enddo
         s(i,j) = SNGL(A)
         enddo
         enddo
 
      return
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/SATN/fitsat_ccdXthenY.f"
c****                                         
c*********************************************
                                              
 
c------------------------------------------------------------
c
c
c
c
      subroutine fitsat_ccdXthenY(psfu,pixu,NAXIS1,NAXIS2,SKYBAR,
     .                            xfit,yfit,zfit,ysigfit)
      implicit none
 
      real    psfu(101,101)
      integer NAXIS1, NAXIS2
      real    pixu(NAXIS1,NAXIS2)
      real    SKYBAR
      real    xfit, yfit, zfit, ysigfit
 
      integer Ls, L
c     integer il(9999)
      integer jl(9999)
      real    pl(9999)
      real    fl(9999)
 
      real    xl(9999)
 
      integer i0, j0
c     integer ie, je
      real    dx
 
      integer  i,  j
      real     rpsf_phot
 
      real    xmin, zmin, zminx
      real    emin, e
      integer idx,  idy
c     real    x, y
      real    z
 
      real*8  ftot, ptot
      real    etot, sig
c     integer lmax
c     integer NREJ
 
      real*8  p_ii(11)
      real*8  f_ii(11)
      integer j_ii(11)
      integer ii
      integer jj, jju
      real    xpsf, ypsf
c     real    dxu
      real    ss
c     real    mbar_sky
 
      real*8  p_imin(5)
      real*8  f_imin(5)
      integer j_imin(5)
 
      integer juse
 
      integer jmin, j1, j2
      real    e_j(6001)
 
      integer Uu, Us
      real    xu(999), yu(999)
      real    wu(999), wtot
      integer gu(999)
      real    eu(999)
      real    su(999)
      real    ybar
      real    ysig
 
 
      i0 = int(xfit+0.5)
      j0 = int(yfit+0.5)
 
      xfit = i0
      yfit = j0
      ysigfit = 9.99
 
      if (i0.gt.4086) return
      if (j0.gt.4086) return
      if (i0.lt.  11) return
      if (j0.lt.  11) return
 
      if (-2.5*log10(max(zfit,1.0)).lt.-20) return
 
      ss = SKYBAR
 
      if (.false.) then
         print*,' '
         print*,'ENTER fitsat_ccdXthenY...'
         print*,' '
         print*,'   i0: ',i0,xfit
         print*,'   j0: ',j0,yfit
         print*,' '
         write(*,138) (i,i=i0-10,i0+10)
         do j = j0+10, j0-10,-1
            write(*,139) j,
     .          (min(int(pixu(i,j)+0.5),99999),i=i0-10,i0+10)
            enddo
  139    format(1x,i4.4,1x,10i6,3x,i5,3x,10i6)
  138    format(1x,  4x,1x,10i6,3x,i5,3x,10i6)
         print*,' '
         print*,' '
         endif
 
 
c------------------------
c
c integrate up the pixels
c
      do ii = -5, 5
         jju = 2
   3     if (pixu(i0+ii,j0+jju).gt.55000.or.
     .       pixu(i0+ii,j0-jju).gt.55000) then
             jju = jju + 1
             if (j0-jju.le.0001) return
             if (j0+jju.ge.4096) return
             if (jju.lt.25) goto 3
             endif
         p_ii(6+ii) = 0.
         do jj = -jju, jju
            p_ii(6+ii) = p_ii(6+ii) + (pixu(i0+ii,j0+jj)-ss)
            enddo
         j_ii(6+ii) = jju
c        write(*,'(i4,1x,f14.1,1x,i4)') i,p_ii(6+ii),j_ii(6+ii)
         enddo
 
c----------------------
c
c find the best x shift
c
c     print*,'      fitsat_ccdXthenY 2: '
      emin = 9e9
      xmin = 0.00
      zmin = 0.00
      do idx = -2000, 2000, 1
         dx = idx*0.001
         do ii = -5, 5
            f_ii(6+ii) = 0.
            do jj = -j_ii(6+ii), j_ii(6+ii)
               xpsf = ii - dx
               ypsf = jj
               f_ii(6+ii) = f_ii(6+ii) + rpsf_phot(xpsf,ypsf,psfu)
               enddo
            enddo
         ptot = 0.
         ftot = 0.
         do ii = -2, 2
            ptot = ptot + p_ii(6+ii)
            ftot = ftot + f_ii(6+ii)
            enddo
         z = SNGL(ptot/ftot)
         etot = 0.
         do ii = -2, 2
            e    = SNGL( abs((p_ii(6+ii)-z*f_ii(6+ii))))
            sig  = SNGL(sqrt((p_ii(6+ii)+0.01**2*p_ii(6+ii)**2)))
            etot = etot + (e/sig)**2
            enddo
         etot = sqrt(etot/4)
c        write(87,187) idx, etot,z,ptot,ftot
c 187    format(1x,i5,1x,f12.5,1x,f12.0,1x,f12.0,1x,f8.6)
         if (etot.lt.emin) then
             emin = etot
             xmin = idx*0.001
             zmin = z
             do ii = -2, 2
                p_imin(3+ii) = p_ii(6+ii)
                f_imin(3+ii) = f_ii(6+ii)
                j_imin(3+ii) = j_ii(6+ii)
                enddo
             endif
         enddo
 
c     write(88,188) emin,xmin,zmin
c 188 format(f12.2,1x,f8.3,1x,f12.1)
 
      zminx = zmin
 
c     print*,'      fitsat_ccdXthenY 3: '
c     print*,'OUTPUT FORT89...'
c     do ii = -2, 2
c        write( *,189) p_imin(3+ii), f_imin(3+ii), zmin,
c    .                 j_imin(3+ii)
c        write(89,189) p_imin(3+ii), f_imin(3+ii), zmin,
c    .                 j_imin(3+ii)
c        enddo
c 189 format(1x,f9.1,1x,f8.5,1x,f9.0,1x,i2)
 
      wtot = 0.
      Us   = 0
      do ii = -8, 8
         juse = max(2,abs(ii))
         Ls = 0
         do jj = -juse, juse
            Ls = Ls + 1
            if (Ls.gt.9999) stop 'Ls.gt.9999'
            xl(Ls) = ii - xmin
            jl(Ls) = jj
            pl(Ls) = pixu(i0+ii,j0+jj)-ss
            if (pixu(i0+ii,j0+jj).gt.60000) then
                Ls = 0
                goto 3333
                endif
            enddo
c        do L = 1, Ls
c           write(91,191) ii, L, xl(L), jl(L), pl(L)
c 191       format(1x,i3,1x,i4.4,1x,f8.3,1x,i4,1x,f9.1)
c           enddo
         do idy = -3000, 3000
            ptot = 0.
            ftot = 0.
            do L = 1, Ls
               xpsf = xl(L)
               ypsf = jl(L) - idy*0.001
               fl(L) = rpsf_phot(xpsf,ypsf,psfu)
               ptot = ptot + pl(L)
               ftot = ftot + fl(L)
               enddo
            z = SNGL(ptot/ftot)
            if (z.lt.0) goto 3332
            etot = 0.
            do L = 1, Ls
               e = abs(pl(L)-z*fl(L))
               sig  = sqrt(abs(pl(L))+0.01**2*pl(L)**2)
               etot = etot + (e/sig)**2
               enddo
            etot = sqrt(etot/(Ls-1))
            e_j(3001+idy) = etot
c           write(92,192) ii,idy,etot,z
c 192       format(1x,i3,1x,i5,1x,f12.3,1x,f15.1)
 3332       continue
            enddo
         emin = 9e9
         jmin = 0
         do j = 1, 6001
            if (e_j(j).lt.emin) then
                emin = e_j(j)
                jmin = j
                endif
            enddo
         if (jmin.eq.0) goto 3333
         do j1 = jmin, 0001,-1
            if (e_j(j1).gt.emin*1.5) goto 3301
            enddo
 3301    continue
         do j2 = jmin, 6001,+1
            if (e_j(j2).gt.emin*1.5) goto 3302
            enddo
 3302    continue
c        write(*,1333) ii,Ls,emin,(jmin-3001),j2-j1
         Us = Us + 1
         xu(Us) = xpsf
         yu(Us) = (jmin-3001)*0.001
         eu(Us) = 0.001*(j2-j1)/2.0
         su(Us) = eu(Us)
         wu(Us) = 1/eu(Us)
         gu(Us) = 1
         wtot = wtot + wu(Us)
c1333    format(1x,i4,1x,i4,1x,f10.2,1x,i4,1x,i4)
 3333    continue
         enddo
 
 
c     print*,'      fitsat_ccdXthenY 4: '
c     print*,' '
c     do Uu = 1, Us
c        write(*,1334) ii,Uu,xu(Uu),yu(Uu),wu(Uu),eu(Uu),su(Uu)
c1334    format(1x,i3,1x,i4,1x,f10.4,1x,f10.4,8(1x,f8.4))
c        enddo
 
      call rbarsigw_empir(yu,wu,gu,eu,su,Us,ybar,ysig,Uu)
 
c     print*,' '
c     write(*,'(''  ybar: '',f8.4)') ybar
c     write(*,'(''  ysig: '',f8.4)') ysig
c     print*,' '
c1338 format(1x,3x,1x,4x,1x,10x,1x,f10.4,1x,f8.4)
 
 
c     print*,'      fitsat_ccdXthenY 5: '
c      print*,' '
c      do Uu = 1, Us
c         write(*,1339) ii,Uu,xu(Uu),yu(Uu),
c     .                       wu(Uu),eu(Uu),su(Uu),gu(Uu)
c 1339    format(1x,i3,1x,i4,1x,f10.4,1x,f10.4,
c     .                1x,f8.4,3x,f8.4,3x,f8.4,3x,i1)
c         enddo
c      print*,' '
 
c     if (.not.(xmin.lt.9.99)) xmin = 9.99
c     if (.not.(emin.lt.9999)) emin = 9999
c     if (.not.(zmin.lt.9e11)) zmin = 9e11
c     write(98,198) xmin, emin,zmin,pixu(i0,j0),
c    .              ybar, ysig
c 198 format(1x,f7.3,1x,f12.5,1x,f12.0,1x,f8.1,
c    .       3x,f7.3,1x,f7.3)
 
      xfit = i0 + xmin
      yfit = j0 + ybar
      zfit = zmin
 
c     write(99,199) xfit, yfit, zfit, emin,
c    .              pixu(i0,j0),
c    .              xmin, ybar, ysig
c 199 format(1x,f9.3,1x,f9.3,1x,f11.1,1x,f7.2,
c    .               1x,f9.1,1x,
c    .               1x,f8.3,1x,f8.3,1x,f8.3)
 
c     print*,'      fitsat_ccdXthenY 6: '
      ysigfit = ysig
 
c     close(87)
c     close(91)
c     close(92)
c     close(89)
c     close(98)
c     print*,'CONTINUE? '
c     read(*,*) cchar
 
      return
      end
 
 
      real function findz(pl,fl,Ls,e,zi)
      implicit none
 
      integer Ls
      real pl(Ls)
      real fl(Ls)
      real e
      real zi
 
      integer L
      real z0, zP, zM
      real e0, eP, eM
 
      e0 = 0.
      eP = 0.
      eM = 0.
      z0 = zi
 
    1 continue
      zP = z0*1.005
      zM = z0*0.995
      do L = 1, Ls
         e0 = e0 + abs(fl(L)*z0-pl(L))
         eP = eP + abs(fl(L)*zP-pl(L))
         eM = eM + abs(fl(L)*zM-pl(L))
         enddo
      if (eP.lt.e0) then
          z0 = zP
          goto 1
          endif
      if (eM.lt.e0) then
          z0 = zM
          goto 1
          endif
      e = e0
      findz = z0
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/SATN/rbarsigw_empir.f"
c****                                         
c*********************************************
                                              
 
c-------------------------------------------------------
c
c
c
      subroutine rbarsigw_empir(yu,wu,gu,eu,su,Us,ybar,ysig,Uu)
      implicit none
 
      integer Us
      real    yu(Us)
      real    wu(Us)
      integer gu(Us)
      real    eu(Us)
      real    su(Us)
      real    ybar
      real    ysig
      integer Uu
 
      integer U
      real    ytot
      real    wtot
      real    ztot
      integer ntot
      real    stot
 
      real    fac
 
      ytot = 0.
      wtot = 0.
      ntot = 0
      do U = 1, Us
         ytot = ytot + gu(U)*wu(U)*yu(U)
         wtot = wtot + gu(U)*wu(U)
         ntot = ntot + gu(U)
         enddo
      ybar = ytot/wtot
 
      ytot = 0.
      wtot = 0.
      ntot = 0
      do U = 1, Us
         ytot = ytot + gu(U)*wu(U)*(yu(U)-ybar)**2
         wtot = wtot + gu(U)*wu(U)
         ntot = ntot + gu(U)
         enddo
      ysig = sqrt(ytot/wtot)
 
      ytot = 0.
      ntot = 0
      do U = 1, Us
         ytot = ytot + gu(U)*(yu(U)-ybar)**2/eu(U)**2
         ntot = ntot + gu(U)
         enddo
 
      fac = (ntot-1)/ytot
 
c     print*,' '
c     print*,' '
c     print*,' '
c     print*,' '
c
c     print*,' '
c     print*,'---> fac: ',fac
c     print*,'     mod: ',sqrt(fac)
c     print*,'    ytot: ',ytot
c     print*,' '
 
      do U = 1, Us
         su(U) = eu(U)/sqrt(fac)
         enddo
 
      ytot = 0.
      ztot = 0.
      ntot = 0.
c     write(*,108)
c     write(*,109)
      do U = 1, Us
c        write(*,119) U, yu(U), (yu(U)-ybar),wu(U)/wtot,
c    .                   eu(U), (yu(U)-ybar)**2/eu(U)**2,
c    .                     sqrt((yu(U)-ybar)**2/eu(U)**2),
c    .                   su(U), (yu(U)-ybar)**2/su(U)**2,
c    .                     sqrt((yu(U)-ybar)**2/su(U)**2),
c    .                   gu(U)
         ytot = ytot + gu(U)*(yu(U)-ybar)**2/eu(U)**2
         ztot = ztot + gu(U)*(yu(U)-ybar)**2/su(U)**2
         ntot = ntot + gu(U)
c 108    format(1x,'   U',1x,
c     .          1x,'...yu...',
c    .          1x,'...dyu..',
c    .          1x,'...wu...',
c    .          1x,'...eu...',
c    .          1x,'..erat2.',
c    .          1x,'..erat..',
c    .          1x,'...su...',
c    .          1x,'..srat2.',
c    .          1x,'..srat..')
c 109    format(1x,'....',1x,
c    .          1x,'........',
c    .          1x,'........',
c    .          1x,'........',
c    .          1x,'........',
c    .          1x,'........',
c    .          1x,'........',
c    .          1x,'........',
c    .          1x,'........',
c    .          1x,'........')
c 119    format(1x,i4,1x,9(1x,f8.3),1x,i1)
c 118    format(1x,i4,1x,9x,9x,9x,9x,1x,f8.3,9x,9x,1x,f8.3)
         enddo
c     print*,' '
c     write(*,118) ntot,ytot, ztot
c     print*,' '
 
      stot = 0.
      do U = 1, Us
         stot = stot + 1/su(U)**2
         enddo
 
c     print*,'       '
c     write(*,'(1x,i4,1x,f9.3)') ntot,sqrt(1/stot)
c     print*,'       '
 
      ysig = sqrt(1/stot)
 
      if (.not.(ybar.gt.-9.99)) ybar =  9.99
      if (.not.(ysig.gt. 0.00)) ysig =  9.99
 
      Uu = ntot
 
      return
      end
 
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/PARLOR/islinux.f"
c****                                         
c*********************************************
                                              
 
c      program q
c      implicit none
c
c      logical islinux, islinux_var
c
c      islinux_var = islinux()
c
c      islinux_var = islinux()
c
c      stop
c      end
 
 
      logical function islinux()
      implicit none
 
      logical islinux_save
 
      integer i
      data i/0/
      data islinux_save/.true./
 
      common /islinux_/i,islinux_save
 
      byte    b(2)
      equivalence(i,b)
 
      if (i.eq.1) goto 1
 
      i = 1
      islinux_save = .false.
      if (b(1).eq.1) islinux_save = .true.
 
    1 islinux = islinux_save
      return
      end
 
 
 
c#include "/user/jayander/FORTRAN/HST1PASS/gaia4hst/hst_gaia_rdmat.f"
c#include "/user/jayander/FORTRAN/HST1PASS/gaia4hst/sub_extract_gaia4hst_str.f"
c#include "/user/jayander/FORTRAN/HST1PASS/gaia4hst/sub_extract_gaia4hst_xym.f"
c#include "/user/jayander/FORTRAN/HST1PASS/gaia4hst/find_pifac_USNO.f"
c#include "/user/jayander/FORTRAN/HST1PASS/gaia4hst/sub_hdr_keyword_repl.f"
c#include "/user/jayander/FORTRAN/HST1PASS/gaia4hst/hst2gaia_match.f"
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/CPYNREPL/cpyNrepl_acswfc.f"
c****                                         
c*********************************************
                                              
 
 
      subroutine cpyNrepl_acswfc(FILEI,FILEO,pixp,LAB3)
 
      character*200 FILEI
      character*200 FILEO
      real          pixp(4096,4096)
      character*3   LAB3
 
      integer i
 
      byte    b2880(2880)
      integer ios
      character*2880 c2880
      equivalence (b2880,c2880)
 
 
 
 
c----------------------
c
c copy FILEI into FILEO
c
c     print*,'OPEN11: ',FILEI(1:40)
      open(11,file=FILEI,
     .        status='old',
     .        iostat=ios,
     .        err=900,
     .        recl=2880,
     .        form='UNFORMATTED',
     .        access='DIRECT')
c     print*,'OPEN12: ',FILEO(1:40)
      open(12,file=FILEO,status='unknown',
     .     err=901,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
c     print*,'FILEI: ',FILEI(1:40)
      print*,'cpyNrepl_acswfc: ',FILEO(1:40)
 
      i = 0
    1 i = i + 1
      read(11,rec=i,iostat=ios) b2880
      if (i.eq.1) then
          do k = 1, 80
             if (c2880((k-1)*80+01:(k-1)*80+08).eq.'        ') then
                 c2880((k-1)*80+01:(k-1)*80+15) = 'HST1PASS= '
     .                                        // ''''
     .                                        // LAB3
     .                                        // ''''
                 goto 777
                 endif
             enddo
          endif
  777 continue
      if (ios.eq.5002) goto 2 ! end of file
      if (ios.ne.0) then
          print*,'iostat: ',ios,i
          goto 2
          endif
      write(12,rec=i,iostat=ios) b2880
      goto 1
    2 continue
      close(11)
      close(12)
 
      call replfits_r4e(FILEO,pixp(0001,0001),4096,2048,1)
      call replfits_r4e(FILEO,pixp(0001,2049),4096,2048,4)
 
      return
 
  900 continue
      print*,'  ios: ',ios
      stop '900'
 
  901 continue
      stop '901'
      end
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/CPYNREPL/cpyNrepl_wfc3uv.f"
c****                                         
c*********************************************
                                              
 
      subroutine cpyNrepl_wfc3uv(FILEI,FILEO,pixp,LAB3)
 
      character*200 FILEI
      character*200 FILEO
      real          pixp(4096,4096)
      character*3   LAB3
 
      integer i, k
 
      byte           b2880(2880)
      character*2880 c2880
      integer ios
 
      equivalence (b2880,c2880)
 
      print*,'cpyNrepl_wfc3uv: ',FILEO(1:40)
 
c----------------------
c
c copy FILEI into FILEO
c
c     print*,'OPEN11: ',FILEI(1:40)
      open(11,file=FILEI,
     .        status='old',
     .        iostat=ios,
     .        err=900,
     .        recl=2880,
     .        form='UNFORMATTED',
     .        access='DIRECT')
c     print*,'OPEN12: ',FILEO(1:40)
      open(12,file=FILEO,status='unknown',
     .     err=901,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
c     print*,'FILEI: ',FILEI(1:40)
c     print*,'FILEO: ',FILEO(1:40)
      i = 0
    1 i = i + 1
      read(11,rec=i,iostat=ios) b2880
      if (i.eq.1) then
          do k = 1, 80
             if (c2880((k-1)*80+01:(k-1)*80+08).eq.'        ') then
                 c2880((k-1)*80+01:(k-1)*80+15) = 'HST1PASS= '
     .                                        // ''''
     .                                        // LAB3
     .                                        // ''''
                 goto 777
                 endif
             enddo
          endif
  777 continue
      if (ios.eq.5002) goto 2 ! end of file
      if (ios.ne.0) then
          print*,'iostat: ',ios,i
          goto 2
          endif
      write(12,rec=i,iostat=ios) b2880
      goto 1
    2 continue
      close(11)
      close(12)
 
      call replfits_r4e(FILEO,pixp(0001,0001),4096,2048,1)
      call replfits_r4e(FILEO,pixp(0001,2049),4096,2048,4)
 
      return
 
  900 continue
      print*,'  cpyNrepl_wfc3uv --- ios: ',ios
      stop '900'
 
  901 continue
      stop '901'
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/CPYNREPL/cpyNrepl_wfc3ir.f"
c****                                         
c*********************************************
                                              
 
 
c-------------------------------------------------
c
c this routine copies FILEI into FILEO then
c replaces the pixels... even if it's a subarray.
c brilliant!
c
      subroutine cpyNrepl_wfc3ir(FILEI,FILEO,pixp,LAB3)
      implicit none
 
      real          pixp(1014,1014)
      character*200 FILEI
      character*200 FILEO
      character*3   LAB3
 
 
      integer i, ios
      integer k
 
      byte           b2880(2880)
      character*2880 c2880
 
      equivalence (b2880,c2880)
 
 
      print*,'cpyNrepl_wfc3ir ',FILEO(1:40)
 
c----------------------
c
c copy FILEI into FILEO
c
      open(11,file=FILEI,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
      open(12,file=FILEO,status='unknown',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
      i = 0
    1 i = i + 1
      read(11,rec=i,iostat=ios) b2880
      if (i.eq.1) then
          do k = 1, 80
             if (c2880((k-1)*80+01:(k-1)*80+08).eq.'        ') then
                 c2880((k-1)*80+01:(k-1)*80+15) = 'HST1PASS= '
     .                                        // ''''
     .                                        // LAB3
     .                                        // ''''
                 goto 777
                 endif
             enddo
          endif
  777 continue
      if (ios.eq.5002) goto 2 ! end of file
      if (ios.ne.0) then
          print*,'iostat: ',ios,i
          goto 2
          endif
      write(12,rec=i,iostat=ios) b2880
      goto 1
    2 continue
      close(11)
      close(12)
 
c----------------------
c
c replace the pixels!
c
      call replfits_r4e(FILEo,pixp,1014,1014,1)
 
      return
 
 
  900 continue
      print*,'900 error...'
      end
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/FITSIO/CPYNREPL/replfits_r4e.f"
c****                                         
c*********************************************
                                              
 
 
c----------------------
c apertures to add:
c----------------------
c 18042 UVIS2-C512C-SUB <--- done
c 11537 UVIS2-C1K1C-SUB <--- done
c  6995 UVIS1-C512A-SUB
c  5743 UVIS2-M512C-SUB
c  3698 UVIS2-2K2C-SUB  <--- done
c  2176 UVIS2-C512B-SUB
c  1716 UVIS1-M512-SUB
c  1160 UVIS1-2K2A-SUB
c----------------------
 
c-----------------------------------------------------------------
c
c takes an existing fits image with extensions and replaces
c one real*4 extension
c
      subroutine replfits_r4e(FILEo,pix,NDIMX,NDIMY,NEXTENU)
      implicit none
 
      character*(*) FILEo
      integer NDIMX,NDIMY
      real    pix(NDIMX,NDIMY)
      integer NEXTENU
 
      character*199 FILEUo
      character*70 INFO(10)
      common / fitsinfo / INFO
 
      integer naxes
      integer laxis(3)
      common/laxis3_/laxis
      integer laxis1
      integer laxis2
      integer laxis3
 
      integer NXF
      integer NYF
 
      character*8  field
      character*40 stream
 
      integer nbyte0
      integer nbyteE
      integer nbyte1
      integer nbyte2
      integer nbper
      integer i,ios, k
c     integer j
 
      character*2880 buffc
      byte buffb(2880)
      equivalence (buffc,buffb)
 
      integer ifirst, i1, i2
      integer ii, jj
      integer iiu,jju
 
      integer np1, np2, npt
      integer nextend
      integer nread
      real bscale, bzero
      integer bitpix
 
      character*70 HDR(25)
      common/HDR/HDR
 
      logical DIAG
      data DIAG /.false./
      integer NEND
      integer iend
 
      character*20 STREAM_APER
      character*20 STREAM_INST
 
      real*4, dimension(:,:), allocatable :: pixtemp
      integer NDIMXu, NDIMYu
 
      NDIMXu = NDIMX
      NDIMYu = NDIMY
 
      FILEUo = FILEo
      iend = 0
      do i = 196,1,-1
         if (FILEo(i:i+4).eq.'.fits') iend = i+4
         enddo
      if (iend.eq.0) stop 'NO .fits in FILEo'
      FILEUo = FILEo(1:iend)
 
      if (DIAG) then
         print*,'purge...'
         print*,'FILEUo: ',FILEUo
         endif
 
      open(10,file=FILEUo,status='old',
     .     err=900,recl=2880,form='UNFORMATTED',
     .     access='DIRECT')
 
      naxes = -1
      laxis1 = 1
      laxis2 = 1
      laxis3 = 1
      nextend = 0
 
      do i = 1, 10
         INFO(i) = ' '
         enddo
 
      BSCALE = 1.0
      BZERO  = 0.0
 
      NEND = 0
      i = 0
      nread = 0
 100  continue
      i = i + 1
      if (DIAG) print*,'READREC: ',i
      read(10,rec=i,iostat=ios) buffc
      do k = 0, 35, 1
         if (DIAG) write(*,'(i4,1x,i4,1x,a80)')
     .                   i,k,buffc(k*80+1:k*80+80)
         field  = buffc(k*80+01:k*80+08)
         stream = buffc(k*80+11:k*80+51)
         if (field.eq.'NAXIS   ') read(stream,*) naxes
         if (field.eq.'NAXIS1  ') read(stream,*) laxis1
         if (field.eq.'NAXIS2  ') read(stream,*) laxis2
         if (field.eq.'NAXIS3  ') read(stream,*) laxis3
         if (field.eq.'NEXTEND ') read(stream,*) nextend
         if (field.eq.'BITPIX  ') read(stream,*) bitpix
         if (field.eq.'BSCALE  ') read(stream,*) bscale
         if (field.eq.'BZERO   ') read(stream,*) bzero
         if (field.eq.'APERTURE') STREAM_APER = stream
         if (field.eq.'INSTRUME') STREAM_INST = stream
 
         if (field.eq.'EXPTIME ') INFO(1) = stream
         if (field.eq.'FILTER  ') INFO(2) = stream
         if (field.eq.'FILTNAM1') INFO(2) = stream
         if (field.eq.'FILENAME') INFO(3) = stream
         if (field.eq.'DATE-OBS') INFO(4) = stream
         if (field.eq.'TIME-OBS') INFO(5) = stream
         if (field.eq.'DEC_TARG') INFO(6) = stream
         if (field.eq.'RA_TARG ') INFO(7) = stream
         if (field.eq.'PA_V3   ') INFO(8) = stream
         if (field.eq.'PROPOSID') INFO(9) = stream
 
         if (field.eq.'CRPIX1  ') HDR(01) = stream
         if (field.eq.'CRPIX2  ') HDR(02) = stream
         if (field.eq.'CRVAL1  ') HDR(03) = stream
         if (field.eq.'CRVAL2  ') HDR(04) = stream
         if (field.eq.'CTYPE1  ') HDR(05) = stream
         if (field.eq.'CTYPE2  ') HDR(06) = stream
         if (field.eq.'CD1_1   ') HDR(07) = stream
         if (field.eq.'CD1_2   ') HDR(08) = stream
         if (field.eq.'CD2_1   ') HDR(09) = stream
         if (field.eq.'CD2_2   ') HDR(10) = stream
         if (field.eq.'ORIENTAT') HDR(11) = stream
         if (field.eq.'PA_APER ') HDR(12) = stream
         if (field.eq.'PA_V3   ') HDR(13) = stream
         if (field.eq.'DATE-OBS') HDR(14) = stream
         if (field.eq.'TIME-OBS') HDR(15) = stream
         if (field.eq.'EXPTIME ') HDR(16) = stream
         if (field.eq.'ROOTNAME') HDR(17) = stream
         if (field.eq.'TARGNAME') HDR(18) = stream
         if (field.eq.'RA_TARG ') HDR(19) = stream
         if (field.eq.'DEC_TARG') HDR(20) = stream
         if (field.eq.'PROPOSID') HDR(21) = stream
         if (field.eq.'FILTER ')  HDR(22) = stream
         if (field.eq.'FILTER1 ') HDR(22) = stream
         if (field.eq.'FILTER2 ') HDR(23) = stream
         if (field.eq.'VAFACTOR') HDR(24) = stream
 
         if (field.eq.'END     ') then
           !print*,' ---> NEND: ',NEND,NEXTENU
            if (NEND.eq.NEXTENU) goto 101
            NEND = NEND + 1
            endif
         enddo
      goto 100
 101  continue
 
      nread = nread + 1
      if (DIAG) then
         print*,' '
         print*,'----------------------------------------'
         print*,'  NREAD: ',nread
         print*,'NEXTEND: ',nextend
         print*,'  NAXIS: ',naxes
         print*,'  LAXIS: ',laxis1,laxis2,laxis3
         print*,' BITPIX: ',bitpix
         print*,' BSCALE: ',bscale
         print*,'  BZERO: ',bzero
         print*,'  NDIMX: ',NDIMX,NDIMXu
         print*,'  NDIMY: ',NDIMY,NDIMYu
         print*,' '
         endif
 
c     print*,'STREAM_APER: ',STREAM_APER
c     print*,'STREAM_INST: ',STREAM_INST
 
      allocate(pixtemp(NDIMXu,NDIMYu))
      do ii = 0001, NDIMXu
      do jj = 0001, NDIMYu
         pixtemp(ii,jj) = pix(ii,jj)
         enddo
         enddo
 
      if (laxis2.eq.2051) laxis2 = 2048  ! for wfc3uv
 
      if (STREAM_INST(2:5).eq.'WFC3') then
          if (laxis2.ge.2048.and.
     .        laxis1.eq.4096) goto 444                        ! WFC3/UVIS full frame!
          if (STREAM_APER(02:16).eq.'UVIS2-C512C-SUB') then
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 pixtemp(ii,jj) = pix(ii,jj+1)
                 enddo
                 enddo
              goto 444
              endif
          if (STREAM_APER(02:16).eq.'UVIS2-C1K1C-SUB') then
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 if (ii.le.2048.and.jj.le.2047)
     .                     pixtemp(ii,jj) = pix(ii,jj+1)
                 enddo
                 enddo
              goto 444
              endif
          if (STREAM_APER(02:15).eq.'UVIS2-2K2C-SUB') then
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 if (ii.le.2048.and.jj.le.2047)
     .                     pixtemp(ii,jj) = pix(ii,jj+1)
                 enddo
                 enddo
              goto 444
              endif
          if (STREAM_APER(02:16).eq.'UVIS1-C512A-SUB') then
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              print*,'NDIMXu: ',NDIMXu
              print*,'NDIMYu: ',NDIMYu
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 iiu = ii
                 jju = jj+1538+2048
                 if (iiu.ge.0001.and.iiu.le.4096.and.
     .               jju.ge.0001.and.jju.le.4096)
     .               pixtemp(ii,jj) = pix(iiu,jju)
                 enddo
                 enddo
              goto 444
              endif
          if (STREAM_APER(02:16).eq.'UVIS1-C512B-SUB') then
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              print*,'NDIMXu: ',NDIMXu
              print*,'NDIMYu: ',NDIMYu
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 iiu = ii+3583
                 jju = jj+1538
                 if (iiu.ge.0001.and.iiu.le.4096.and.
     .               jju.ge.0001.and.jju.le.4096)
     .               pixtemp(ii,jj) = pix(iiu,jju)
                 enddo
                 enddo
              goto 444
              endif
          if (STREAM_APER(02:15).eq.'UVIS1-2K2A-SUB') then
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              print*,'NDIMXu: ',NDIMXu
              print*,'NDIMYu: ',NDIMYu
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 iiu = ii+0000
                 jju = jj+2048
                 if (iiu.ge.0001.and.iiu.le.4096.and.
     .               jju.ge.0001.and.jju.le.4096)
     .               pixtemp(ii,jj) = pix(iiu,jju)
                 enddo
                 enddo
              goto 444
              endif
 
 
          if (STREAM_APER(02:09).eq.'IRSUB512') then
              print*,'replfits_r4e:  '
              print*,'        APER:  ',STREAM_APER(2:20)
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              print*,'      NDIMXu: ',NDIMXu
              print*,'      NDIMYu: ',NDIMYu
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 iiu = ii+0251
                 jju = jj+0251
                 if (iiu.ge.0001.and.iiu.le.1014.and.
     .               jju.ge.0001.and.jju.le.1014)
     .               pixtemp(ii,jj) = pix(iiu,jju)
                 enddo
                 enddo
              goto 444
              endif
 
          if (STREAM_APER(02:09).eq.'IRSUB256') then
              print*,'replfits_r4e:  '
              print*,'        APER:  ',STREAM_APER(2:20)
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              print*,'      NDIMXu: ',NDIMXu
              print*,'      NDIMYu: ',NDIMYu
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 iiu = ii+0379
                 jju = jj+0379
                 if (iiu.ge.0001.and.iiu.le.1014.and.
     .               jju.ge.0001.and.jju.le.1014)
     .               pixtemp(ii,jj) = pix(iiu,jju)
                 enddo
                 enddo
              goto 444
              endif
 
 
 
          if (STREAM_APER(02:09).eq.'IRSUB128') then
              print*,'replfits_r4e:  '
              print*,'        APER:  ',STREAM_APER(2:20)
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              print*,'      NDIMXu: ',NDIMXu
              print*,'      NDIMYu: ',NDIMYu
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 iiu = ii+0443
                 jju = jj+0443
                 if (iiu.ge.0001.and.iiu.le.1014.and.
     .               jju.ge.0001.and.jju.le.1014)
     .               pixtemp(ii,jj) = pix(iiu,jju)
                 enddo
                 enddo
              goto 444
              endif
 
          if (STREAM_APER(02:08).eq.'IRSUB64') then
              print*,'replfits_r4e:  '
              print*,'        APER:  ',STREAM_APER(2:20)
              if (NEXTENU.eq.4) return
              NDIMXu = laxis1
              NDIMYu = laxis2
              deallocate(pixtemp)
              allocate(pixtemp(NDIMXu,NDIMYu))
              print*,'      NDIMXu: ',NDIMXu
              print*,'      NDIMYu: ',NDIMYu
              do ii = 1, NDIMXu
              do jj = 1, NDIMYu
                 iiu = ii+0475
                 jju = jj+0475
                 if (iiu.ge.0001.and.iiu.le.1014.and.
     .               jju.ge.0001.and.jju.le.1014)
     .               pixtemp(ii,jj) = pix(iiu,jju)
                 enddo
                 enddo
              goto 444
              endif
 
 
          print*,' '
          print*,'Error in replfits_r4e --- '
          print*,' '
          print*,'The WFC3 subarray you have requested'
          print*,' '
          print*,'  APERTURE: ',STREAM_APER(02:16)
          print*,' '
          print*,'is not yet supported as a destination shell.'
          print*,' '
          print*,'Send a note to help@stsci.edu to request '
          print*,'support.                                  '
          print*,' '
          endif
 
 444  continue
 
      if (laxis1.ne.NDIMXu.or.
     .    laxis2.ne.NDIMYu) then
          print*,'                              '
          print*,'ERROR in replfits_r4e ...'
          print*,'                              '
          print*,'        FILE: ',FILEo
          print*,'        APER: ',STREAM_APER
          print*,'   EXTENSION: ',NEXTENU
          print*,'  SIZE ISSUE: '
          print*,'         IN : ',NDIMX ,' x ',NDIMY
          print*,'         INu: ',NDIMXu,' x ',NDIMYu
          print*,'         OUT: ',laxis1,' x ',laxis2
          print*,'                              '
          print*,'   Perhaps the routine is not '
          print*,'   properly set up for this   '
          print*,'   subarray.                  '
          print*,'                              '
          print*,'   Send a request to help@stsci.edu '
          print*,'   to get this aperture added.      '
          print*,'                              '
          stop
          endif
 
      ifirst = i+1
      i1 = i
      i2 = i
 
      NXF = laxis1
      NYF = laxis2
 
      nbper  = 4*laxis1*laxis2
      npt    = laxis1*laxis2
      nbyte1 = 1
      nbyte2 = nbper
      i1 = i+1 + nbyte1/2880
      i2 = i+1 + nbyte2/2880
 
      if (BITPIX.ne.-32) then
         print*,'readfits_r4e...'
         print*,'BITPIX: ',BITPIX
         print*,'prob'
         stop
         endif
 
      do i = i1, i2, 1
         nbyte0 = (i-ifirst)*2880+   1
         nbyteE = (i-ifirst)*2880+2880
         np1 = (nbyte0-nbyte1)/4 + 1
         np2 = (nbyteE-nbyte1)/4 + 1
         read(10,rec=i,iostat=ios) buffc
         call pix2buff_r4e_cprp(pixtemp,buffb,np1,npt,
     .                          NDIMXu,NDIMYu,
     .                          laxis1,laxis2)
         write(10,rec=i,iostat=ios) buffc
         enddo
 
      close(10)
      if (DIAG) print*,'...closed ',FILEUo
      deallocate(pixtemp)
      return
 
 900  continue
      print*,'READFITS ERROR'
      stop
 
      end
 
 
c------------------------------------------------------
c
c
      subroutine pix2buff_r4e_cprp(pix,buff,n1,nt,
     .                             NXP,NYP,NXF,NYF)
      implicit none
      integer NXP,NYP
      real pix(NXP,NYP)
      byte buff(2880)
      integer n1,nt
      integer NXF,NYF
 
      real pbuff(720)
      common /sneaky/pbuff
      integer i
      integer npu, nbu
      integer NX, NY
 
      byte b(4)
      real r
      equivalence(r,b)
 
      if (NYF.eq.0) continue
 
      do i = 1, 720
         npu = n1+i-1
         nbu = (i-1)*4
c        write(*,199) i, npu, nbu
c 199    format(5i8,1x,f10.3,1x,4i4)
         if (npu.ge.1.and.npu.le.nt) then
            NX = npu - (npu-1)/NXF*NXF
            NY = 1 + (npu-1)/NXF
c           write(*,199) i, npu, nbu, NX, NY
            if (NX.le.NXP.and.NY.le.NYP) then
                r = pix(NX,NY)
                if (.not.(_LINUX_)) then
                   buff(nbu+1) = b(1)
                   buff(nbu+2) = b(2)
                   buff(nbu+3) = b(3)
                   buff(nbu+4) = b(4)
                   endif
                if ((_LINUX_)) then
                   buff(nbu+1) = b(4)
                   buff(nbu+2) = b(3)
                   buff(nbu+3) = b(2)
                   buff(nbu+4) = b(1)
                   endif
               endif
c           write(*,199) i, npu, nbu, NX, NY,r,
c    .                   buff(nbu+1), buff(nbu+1),
c    .                   buff(nbu+1), buff(nbu+1)
            endif
         enddo
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/TRANS/glob_fit6nrDPU_REJ.f"
c****                                         
c*********************************************
                                              
 
 
c---------------------------------------------------------------------
c
c    RMS2D:  report the fitting residual
c SIG_CLIP:  the sigma clipping threshold
c  RES_MIN:  never reject anything within this residual (where to stop)
c  RES_MAX:  never accept anything within this residual
c
c---------------------------------------------------------------------
 
      subroutine glob_fit6nrDPU_REJ(x1,y1,x2,y2,uu,Ns,Nu,           ! added Nu
     .                              A,B,C,D,x1o,y1o,x2o,y2o,
     .                              RMS2D,SIG_CLIP,RES_MIN,RES_MAX) ! added sev
      implicit none
 
      real*8 x1(*), y1(*)
      real*8 x2(*), y2(*)
      integer uu(*)
      integer Ns
      integer Nu
      real*8 A, B, C, D
      real*8 x1o, y1o, x2o, y2o
      real   RMS2D
      real   SIG_CLIP
      real   RES_MIN
      real   RES_MAX
 
      integer n, Us
      real dx, dy, dd
 
      real    dmax
      integer nmax
      real    drms, drmsX
 
      if (Ns.gt.99999) stop 'Ns.gt.99999'
 
      drms = 0.
 
    1 continue
      Us = 0
      do N = 1, Ns
         Us = Us + uu(N)
         enddo
      if (Us.le.3) goto 3
 
      call glob_fit6nrDPU(x1,y1,x2,y2,uu,Ns,
     .                    A,B,C,D,x1o,y1o,x2o,y2o)
 
      drms = 0.
      dmax = 0.
      nmax = 0
      do N = 1, Ns
         if (uu(N).eq.1) then
             dx = SNGL(x2(N)-x2o-A*(x1(N)-x1o)-B*(y1(N)-y1o))
             dy = SNGL(y2(N)-y2o-C*(x1(N)-x1o)-D*(y1(N)-y1o))
             dd = sqrt(dx**2+dy**2)
             if (dd.gt.dmax) then
                 dmax = dd
                 nmax = n
                 endif
             drms = drms + dd**2
             endif
         enddo
 
      drmsX  = drms - dmax**2
      drmsX  = sqrt(drmsX/(Us-2))
      drms   = sqrt(drms /(Us-1))
 
      if (dmax.le.RES_MIN) goto 3 ! everything is all within specs
 
      if (dmax.gt.RES_MAX) then ! one point is beyond specs
          uu(nmax) = 0
          goto 1
          endif
 
      if (dmax.gt.drmsX*SIG_CLIP) then ! sigma-clip this point
          uu(nmax) = 0
          goto 1
          endif
 
    3 continue
      call glob_fit6nrDPU(x1,y1,x2,y2,uu,Ns,
     .                    A,B,C,D,x1o,y1o,x2o,y2o)
 
      Nu = Us
      RMS2D = drms
 
 
      return
      end
 
 
 
                                              
c*********************************************
c****                                         
c**** #include "/user/jayander/FORTRAN/ROUTINES/TRANS/glob_fit6nrDPU.f"
c****                                         
c*********************************************
                                              
 
 
      subroutine glob_fit6nrDPU(x1,y1,x2,y2,uu,Ns,
     .                          A,B,C,D,x1o,y1o,x2o,y2o)
      implicit none
 
      real*8 x1(*), y1(*)
      real*8 x2(*), y2(*)
      integer uu(*)
      integer Ns
      real*8 A, B, C, D
      real*8 x1o, y1o, x2o, y2o
 
      real*8 sxx, sx, swx, szx
      real*8 syy, sy, swy, szy
      real*8 sw,  sz, sxy
      real*8 dlta
      real*8 dsxx, dsyy, dsxy
      real*8 dswx, dswy, dszx, dszy
 
      integer n, nnn, NNu
 
      real*8 x1a, y1a, x1b, y1b
      real*8 x2a, y2a, x2b, y2b
      real*8 x2ae,y2ae
      real*8 dx1, dy1
      real*8 dx2, dy2
 
      if (Ns.lt.3) goto 999
 
      x1a = 0.
      x1b = 0.
      y1a = 0.
      y1b = 0.
 
      x2a = 0.
      x2b = 0.
      y2a = 0.
      y2b = 0.
 
      x1o = 0
      y1o = 0
      x2o = 0
      y2o = 0
      nnn = 0
      do n = 1, Ns
           x1o = x1o + uu(n)*x1(n)
           y1o = y1o + uu(n)*y1(n)
           x2o = x2o + uu(n)*x2(n)
           y2o = y2o + uu(n)*y2(n)
           nnn = nnn + uu(n)
           enddo
 
      x1o = x1o/NNN
      y1o = y1o/NNN
      x2o = x2o/NNN
      y2o = y2o/NNN
 
      if (NNN.eq.1) then
         A = 1.000
         B = 0.000
         C = 0.000
         D = 1.000
         return
         endif
 
      if (NNN.eq.2) then
          NNu = 0
          do N = 1, Ns
             if (uu(N).eq.1.and.NNu.eq.2) stop 'prob:  NNu.eq.2'
             if (uu(N).eq.1.and.NNu.eq.1) then
                 x1b = x1(n)
                 y1b = y1(n)
                 x2b = x2(n)
                 y2b = y2(n)
                 NNu = 2
                 endif
             if (uu(N).eq.1.and.NNu.eq.0) then
                 x1a = x1(n)
                 y1a = y1(n)
                 x2a = x2(n)
                 y2a = y2(n)
                 NNu = 1
                 endif
             enddo
          x1o = (x1a+x1b)/2.0
          y1o = (y1a+y1b)/2.0
          x2o = (x2a+x2b)/2.0
          y2o = (y2a+y2b)/2.0
          dx1 = (x1b-x1a)
          dy1 = (y1b-y1a)
          dx2 = (x2b-x2a)
          dy2 = (y2b-y2a)
          A =  (dx1*dx2+dy1*dy2)/(dx1**2+dy1**2)
          B =  (dy1*dx2-dx1*dy2)/(dx1**2+dy1**2)
          C = -B
          D =  A
          x2ae = x2o + A*(x1a-x1o) + B*(y1a-y1o)
          y2ae = y2o + C*(x1a-x1o) + D*(y1a-y1o)
          return
          endif
 
 
      sxx = 0.0
      sx  = 0.0
      syy = 0.0
      sy  = 0.0
      swx = 0.0
      swy = 0.0
      szx = 0.0
      szy = 0.0
      sw  = 0.0
      sz  = 0.0
      sxy = 0.0
      do n = 1, Ns
           sxy = sxy + uu(n)*(x1(n)-x1o)*(y1(n)-y1o)
           sxx = sxx + uu(n)*(x1(n)-x1o)*(x1(n)-x1o)
           sx  = sx  + uu(n)*(x1(n)-x1o)
           syy = syy + uu(n)*(y1(n)-y1o)*(y1(n)-y1o)
           sy  = sy  + uu(n)*(y1(n)-y1o)
           swx = swx + uu(n)*(x2(n)-x2o)*(x1(n)-x1o)
           swy = swy + uu(n)*(x2(n)-x2o)*(y1(n)-y1o)
           sw  = sw  + uu(n)*(x2(n)-x2o)
           szx = szx + uu(n)*(y2(n)-y2o)*(x1(n)-x1o)
           szy = szy + uu(n)*(y2(n)-y2o)*(y1(n)-y1o)
           sz  = sz  + uu(n)*(y2(n)-y2o)
           enddo
 
      dsxx = sx*sx - NNN*sxx
      dsyy = sy*sy - NNN*syy
      dsxy = sx*sy - NNN*sxy
 
      dlta = dsxx*dsyy - dsxy*dsxy
 
      if (dlta.eq.0) goto 999
 
      dswx = sw*sx - NNN*swx
      dswy = sw*sy - NNN*swy
      dszx = sz*sx - NNN*szx
      dszy = sz*sy - NNN*szy
 
      A =   (dswx*dsyy-dswy*dsxy)/dlta
      B =   (dswy*dsxx-dswx*dsxy)/dlta
      C =   (dszx*dsyy-dszy*dsxy)/dlta
      D =   (dszy*dsxx-dszx*dsxy)/dlta
 
 
      return
 
 999  continue
      A  = 1
      B  = 0
      C  = 0
      D  = 1
      x1o = 0
      y1o = 0
      x2o = 0
      y2o = 0
      return
      end
 
 
 
 
