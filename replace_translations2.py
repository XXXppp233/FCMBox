import os
import re
import glob

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Pattern: AppLocalizations.of(something)?.translate('key') with optional newlines
    pattern = r"AppLocalizations\.of\(\s*([^)]+)\s*\)\?\.translate\('([^']+)'\)"
    new_content = re.sub(pattern, r"AppLocalizations.of(\1)?.\2", content)
    
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
