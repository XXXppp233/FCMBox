import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

content = re.sub(r'Icon\(\s*Icons\.rss_feed,\s*size:\s*32,', r'Icon(\n                          _getNetworkIcon(),\n                          size: 32,', content)

with open('lib/main.dart', 'w') as f:
    f.write(content)
