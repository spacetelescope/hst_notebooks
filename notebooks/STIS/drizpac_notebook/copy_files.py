# Created June 11, 2020
# Last updated Apr 8, 2022
# Written by Laura Prichard

import os
import glob
import shutil
import numpy as np
import pandas as pd

def copy_files_check(src_dir, dst_dir, files='*', rename=False, src_str='', dst_str='', move=False, print_cmd=False):
    """Check for and copy or move files.

    Function to copy or move files (``files``) from a source directory (``src_dir``) to a 
    destination directory (``dst_dir``). The destination directory will be made if it 
    does not exist and specified files to the destination directory if they are not 
    there already. Files can be renamed (``rename=True``) by specifying a string in 
    the source file (``src_str``) to be replaced with a new string for the destination 
    file (``dst_str``). If it is slow to copy the files within the Jupyter Notebook, print 
    the command instead (``print_cmd=True``) to paste into a terminal. If 
    ``move=True``, files will be moved rather than copied between the input 
    directories and renamed if specified. Written by Laura Prichard.

    Parameters
    ----------
    src_dir : str
        Full path of source directory of files to be copied
    dst_dir : str
        Full path of destination directory for files to be copied to
    files : str or list or array_like or pandas Series of str, optional
        List of files or string of files to glob within directory (default *, i.e., all the files 
        within the source directory)
    rename : bool, optional
        To rename the copied/moved files, set ``rename=True`` (default=False)
    src_str: str, optional
        If ``rename=True``, set the string in the source files to be replaced in the 
        destination directory
    dst_str : str, optional
        If ``rename=True``, set the string in the destination files to replace with 
        ``src_str`` in the destination directory
    move : bool, optional
        Move the files instead of copying them with ``move=True`` (default is False, 
        files will be copied)
    print_cmd : bool, optional
        Print the copy/move command instead of running the function (default is 
        False, function will run)

    Returns
    -------
    cmd : str
        If ``print_cmd=True`` the copy/move command will be printed and returned rather than executed

    """

    # Get current working directory before changing
    cwd = os.getcwd()

    # Get full input directories
    src_dir_full = os.path.abspath(src_dir)
    dst_dir_full = os.path.abspath(dst_dir)
    
    # Move to source directory to get files
    os.chdir(src_dir_full)

    # Set mode to copy or move
    if move == False:
        mode = 'copy'
        md = 'cp'
    else:
        mode = '~move~'
        md = 'mv'
    
    # Check for files to copy
    # If a string is provided for the files, make a list with glob, else assume a list/array/pandas Series provided 
    if isinstance(files, str):
        files_ext = files
        files = glob.glob(files)
    else:
        files_ext = None
    
    # Print summary
    print('=====================================================================')
    print('{} files to {} from {} to {}'.format(len(files), mode, src_dir, dst_dir))
    if rename == True: 
        print('Renaming {} to {} in files'.format(src_str, dst_str))
        rnm_str, rnmd_str = ' and renaming ', ' and renamed '
    else: rnm_str = rnmd_str = ''
    print('=====================================================================')
    
    # Check for destination directory and make it if it doesn't exist
    if os.path.exists(dst_dir_full):
        print('Destination directory exists:', dst_dir)
    else:
        os.makedirs(dst_dir_full, 0o774)
        print('Created destination directory:', dst_dir)  
    
    # If printing the copy command, set the starting cmd variable
    if print_cmd == True: cmd = ''
        
    # Loop over each file, create a source and destination, check if it exists, and copy/move if not 
    n=0
    for file in files:
        if os.path.isfile(file):
            # Define source and destination paths for each file
            src_full = os.path.join(src_dir_full, file)              # Full source filepath of file to be copied/moved
            src = os.path.join(src_dir, file)                        # Relative path for printing

            # If a file is to be renamed with a replacement extension
            if rename == False:
                dst_full = os.path.join(dst_dir_full, file)   # Full estination filepath of file to be copied/moved and renamed
                dst = os.path.join(dst_dir, file) 
            else: 
                # Replace the specified component with the new component
                dst_full = os.path.join(ddst_dir_full, file.replace(src_str, dst_str)) 
                dst = os.path.join(dst_dir, file.replace(src_str, dst_str))

            # Check if the file is already in the destination directory, if not it is copied/moved
            if not os.path.exists(dst_full):
                # Either copy/move the files or add to the cmd variable
                if print_cmd == False:
                    if move == False:
                        print('Copying{} {} to {}'.format(rnm_str, src, dst))
                        shutil.copy(src_full, dst_full)
                    else:
                        print('~Moving~{} {} to {}'.format(rnm_str, src, dst))
                        shutil.move(src_full, dst_full)
                # Or set command to copy/move the file to print for command line
                else:
                    if n > 0: cmd += ' && '
                    cmd += '{} {} {}'.format(md, src_full, dst_full)
                n += 1
            else:
                if move == False:
                    print('File exists: {}, not copying from {}'.format(dst, src_dir))
                else:
                    print('File exists: {}, not ~moving~ from {}'.format(dst, src_dir))
        else: print('WARNING: {} is not a file, skipping...'.format(file))

    # Move back into working directory
    os.chdir(cwd)

    # Print the command to copy the files or a summary of the copied files
    if print_cmd == True:
        # Check if all the specified files with the string extension provided need to be copied/moved
        if isinstance(files_ext, str) and ('*' in files_ext) and (len(files) == n) and (rename == False):
            all_files = os.path.join(src_dir_full, files_ext)
            print("Command to {} all {} '{}' files:".format(mode, n, files_ext))
            cmd = '{} {} {}'.format(md, all_files, dst_dir_full)
        else:
            # Else copy/move just the missing files
            print('Command to {} {} files:'.format(mode, n))
        
        print(cmd)
        return cmd
    else:
        if move == False:
            print('Copied{} {} files to {}'.format(rnmd_str, n, dst_dir))
        else: 
            print('~Moved~{} {} files to {}'.format(rnmd_str, n, dst_dir))
        
        
def rename(direc, files='*', src_str='', dst_str=''):
    """Rename files in a directory.

    Function to rename files (``files``) in a directory (``direc``) by specifying a 
    source string in the filename (``src_str``) to be replaced with a new string for 
    the destination file (``dst_str``).

    Parameters
    ----------
    direc : str
        Full path of directory with files to rename
    files : str or list or array_like or pandas Series of str, optional
        List of files or string of files to glob within directory (default *, i.e., all the files 
        within the source directory)
    src_str: str, optional
        String in the filenames to replace
    dst_str : str, optional
        String in the destination files to replace with ``src_str``

    """
 
    # Move to input directroy
    dir_full = os.path.abspath(direc)
    os.chdir(dir_full)

    # Check for files to rename
    # If a string is provided for the files, make a list with glob, else assume a list if provided 
    if isinstance(files, str):
        files_ext = files
        files = glob.glob(files)
    else:
        files_ext = None

    # List all specified files and rename 
    for f in files:
        os.rename(f, f.replace(src_str, dst_str))
    print('--------------------------------------------')
    print('Renamed {} files in {} from {} to {}'.format(len(glob.glob('*{}*'.format(dst_str))), direc, src_str, dst_str))
    print('--------------------------------------------')