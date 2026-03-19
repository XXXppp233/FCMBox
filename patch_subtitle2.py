with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

old_sub = """              subtitle: Text(
                _isConnected ? _backendUrl : 'None',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),"""
new_sub = """              subtitle: Text(
                _backendStatusCode != null ? 'HTTP $_backendStatusCode' : 'None',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),"""

content = content.replace(old_sub, new_sub)

with open('lib/pages/cloud_page.dart', 'w') as f:
    f.write(content)
