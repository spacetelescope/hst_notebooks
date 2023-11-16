"""
This script generates .github/dependabot.yml. It assumes github-actions workflows are stored in
.github/workflows/
"""

import argparse
import glob
import os

def generate_file_content_from_template(ecosystem, directory):
    """
    Generates sections of yml code from template.

    Parameters
    ----------
    ecosystem : str
        Package manager to use

    directory : str
        Location of package manifests

    Returns
    -------
    yml_content : list
        List of code lines to add to output list.
    """
    yml_content = []
    template_content = ['  - package-ecosystem: "{}"'.format(ecosystem),
                        '    directory: "{}"'.format(directory),
                        '    schedule:',
                        '     interval: "weekly"',
                        '     day: "sunday"',
                        '     time: "12:00"']
    for line in template_content:
        yml_content.append(line)
    return yml_content

def make_file(req_file_search_string="notebooks/*/*/requirements.txt"):
    """
    Generates the dependabot.yml file.

    Parameters
    ----------
    req_file_search_string : string
        Search pattern used to locate notebook-level requirements.txt files. The path in the search string is
        assumed to start from the repository root. If not explicitly specified by the user, the default value
        is "notebooks/*/*/requirements.txt".

    Returns
    -------
    Nothing!
    """
    output_file_name = ".github/dependabot.yml"
    output_file_content = ['version: 2',
                           'updates:']
    # 0: Add lines of code for github actions coverage.
    output_file_content += generate_file_content_from_template("github-actions", "/")

    # 1: locate all paths with notebook-level requirements.txt files.
    req_file_list = glob.glob(req_file_search_string)

    # 2: Dynamically generate the dependabot.yml file content based on the paths identified by the above glob command.
    for rf_list_item in sorted(req_file_list):
        rf_path = rf_list_item.replace("requirements.txt", "")
        output_file_content += generate_file_content_from_template("pip", rf_path)

    # 3: Write yml file content only if generated content and content of current file are not identical
    if os.path.isfile(output_file_name):
        with open(output_file_name, 'r') as f_in:
            old_file_content = f_in.readlines()
    else:
        old_file_content = []
    output_file_content = [line + "\n" for line in output_file_content]  # add carriage returns to all lines.
    if old_file_content != output_file_content:
        with open(output_file_name, 'w') as f_out:
            f_out.writelines(output_file_content)
        print("Successfully generated file {}.".format(output_file_name))
    else:
        print("No new changes found in comparison with current {} file. File generation skipped.".format(
            output_file_name))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('req_file_search_string', type=str, help='Search pattern used to locate '
                                                                 'notebook-level requirements.txt files. '
                                                                 'The path in the search string is assumed to '
                                                                 'start from the repository root.')
    args = parser.parse_args()
    make_file(req_file_search_string=args.req_file_search_string)

