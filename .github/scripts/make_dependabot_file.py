"""
This script generates .github/dependabot.yml. It assumes 1) github-actions workflows are stored in
.github/workflows/ and 2) notebook-level requirements.txt files are found in notebooks/*/*/requirements.txt
"""

import glob

output_file_name = ".github/dependabot.yml"
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

# 3: Write yml file content
with open(output_file_name, 'w') as f:
  f.writelines([line + "\n" for line in output_file_content])
print("Successfully generated file {}.".format(output_file_name))