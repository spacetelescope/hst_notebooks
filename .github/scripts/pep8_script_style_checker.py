"""
This script uses flake8 to perform a PEP8 style check on python scripts
Based on https://github.com/spacetelescope/jdat_notebooks/blob/main/.github/helpers/pep8_nb_checker.py.

"""
import argparse
import os
import pathlib
import subprocess
import sys


def remove_temp_files(warn_file):
    """Removes temp files created to perform pep8 style check

    Parameters
    ----------
    warn_file : str
        name of the temp file containing the resulting pep8 warnings

    Returns
    -------
    Nothing!
    """
    if os.path.exists(warn_file):
        os.remove(warn_file)


def script_style_checker(py_file):
    """Use flake8 to perform a PEP8 style check on python scripts

    Parameters
    ----------
    py_file : str
        Name of the python script to check

    Returns
    -------
    Returns integer value '0' if no errors are found and integer value '99' if one or more PEP8 style
    issue(s) are found.
    """
    # save relevant file paths
    warn_file = pathlib.Path(f"{py_file.stem}_pep8.txt")

    # without spawning a shell, run flake8 and save any PEP8 warnings to a new file
    with open(warn_file, 'w') as wf:
        # flake8's command line options are specified in base repo folder's .flake8
        subprocess.run(['flake8', py_file], stdout=wf)

    # read in the PEP8 warnings
    with open(warn_file) as wf:
        warns = wf.readlines()

    # Ignore lines with PEP 8 codes on ignore list
    codes_to_ignore = ["E261", # At least two spaces before inline comment
                       "E501", # line too long
                       "F821", # undefined name
                       "W291", # Trailing whitespace
                       "W293"] # Blank line contains whitespace
    lines_to_ignore = []
    for item in enumerate(warns):
        line_num = item[0]
        warn_line = item[1]
        pep8_code = warn_line.split(":")[3].split(" ")[1]
        if pep8_code in codes_to_ignore:
            lines_to_ignore.append(line_num)
    if len(lines_to_ignore) > 0:
        warns = [i for j, i in enumerate(warns) if j not in lines_to_ignore]

    # if there are none, QUIT while we're ahead
    if not warns:
        print(f"{py_file} is clean!")
        remove_temp_files(warn_file)
        return 0

    # else, read in the script
    with open(py_file) as cf:
        script = cf.readlines()
    n_warns = len(warns)

    for warn_num, script_line in enumerate(warns, 1):
        wrn = script_line.replace("{}".format(py_file), "")
        # Print PEP 8 issues
        line_num = int(wrn.split(":")[1])
        col_num = int(wrn.split(":")[2])
        print("PEP8 error {} of {}".format(warn_num, n_warns))
        print("PEP8 error found at line {}, column {}".format(line_num, col_num))
        print(script[(int(wrn.split(":")[1])) - 1].replace("\n", "")) # print line of code with PEP8 error
        print(" "*(col_num - 1)+"\u25B2") # point to error
        print(wrn.split(":")[3].strip()+"\n")

    # remove temp files created earlier in run
    remove_temp_files(warn_file)
    return 99


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('script_filename', type=str, help='The filename of the notebook to be checked')
    args = parser.parse_args()

    py_ext = '.py'
    try:
        script_filename = pathlib.Path(args.script_filename)
        if not script_filename.suffix == py_ext:
            raise ValueError(f"file extension must be {script_filename}")

    except Exception as err:
        parser.print_help()
        raise err

    rv = script_style_checker(script_filename)
    sys.exit(rv)
