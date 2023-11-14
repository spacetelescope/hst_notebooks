"""
This script finds all paths in notebooks/*/*/ that contain notebook-level requirements.txt files and
generates the
"""
import glob
import pdb

file_content = ['version: 2',
                'updates:',
                '  - package-ecosystem: "github-actions"',
                '    directory: "/"',
                '    schedule:',
                '     interval: "weekly"',
                '     time: "12:00"',
                '    target-branch: dependabot_sandbox']

#1: locate all paths with notebook-level requirements.txt files.
req_file_list = glob.glob("notebooks/*/*/requirements.txt")

for item in sorted(req_file_list):
    rf_path = item.replace("requirements.txt", "")
    template_content = ['  - package-ecosystem: "pip"',
                        '    directory: "{}"'.format(rf_path),
                        '    schedule:',
                        '     interval: "weekly"',
                        '     day: "sunday"',
                        '     time: "12:00"',
                        '    target-branch: dependabot_sandbox']
    for line in template_content:
        file_content.append(line)

for line in file_content:
    print(line)

