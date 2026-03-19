import re

with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

content = re.sub(
    r"subtitle: Text\(\s*_isConnected \? _backendUrl : 'None',\s*maxLines: 1,\s*overflow: TextOverflow\.ellipsis,\s*\),",
    "subtitle: Text(\n                _backendStatusCode != null ? 'HTTP $_backendStatusCode' : 'None',\n                maxLines: 1,\n                overflow: TextOverflow.ellipsis,\n              ),",
    content
)

with open('lib/pages/cloud_page.dart', 'w') as f:
    f.write(content)
