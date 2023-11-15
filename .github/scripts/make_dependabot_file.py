"""
This script generates .github/dependabot.yml. It assumes 1) github-actions workflows are stored in
.github/workflows/ and 2) notebook-level requirements.txt files are found in notebooks/*/*/requirements.txt
"""

import glob
import os
output_file_name = ".github/dependabot_test.yml"
output_file_content = ['version: 2',
                       'updates:',
                       '  - package-ecosystem: "github-actions"',
                       '    directory: "/"',
                       '    schedule:',
                       '     interval: "weekly"',
                       '     day: "sunday"',
                       '     time: "12:00"',
                       '    target-branch: dependabot_sandbox']

#1: locate all paths with notebook-level requirements.txt files.
req_file_list = glob.glob("notebooks/*/*/requirements.txt")

# 2: Dynamically generate the dependabot.yml file content based on the paths identified by the above glob command.
for rf_list_item in sorted(req_file_list):
    rf_path = rf_list_item.replace("requirements.txt", "")
    template_content = ['  - package-ecosystem: "pip"',
                        '    directory: "{}"'.format(rf_path),
                        '    schedule:',
                        '     interval: "weekly"',
                        '     day: "sunday"',
                        '     time: "12:00"',
                        '    target-branch: dependabot_sandbox']
    for line in template_content:
        output_file_content.append(line)


# 3: Write yml file content only if generated content and content of current file are not identical
if os.path.isfile(output_file_name):
    with open(output_file_name, 'r') as f_in:
        old_file_content = f_in.readlines()
else:
    old_file_content = []
output_file_content = [line + "\n" for line in output_file_content] # add carriage returns to all lines.
if old_file_content != output_file_content:
    with open(output_file_name, 'w') as f_out:
        f_out.writelines(output_file_content)
    print("Successfully generated file {}.".format(output_file_name))
else:
    print("No new changes found in comparison with current {} file. File generation skipped.".format(output_file_name))
