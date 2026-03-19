import re

with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

# Replace _faviconUrl with _backendStatusCode
content = content.replace("String? _faviconUrl;", "int? _backendStatusCode;")

# In _loadSettings
load_old = """      _deleteOldData = prefs.getBool('delete_old_data') ?? false;
    });
    _loadFavicon();"""
load_new = """      _deleteOldData = prefs.getBool('delete_old_data') ?? false;
      _backendStatusCode = prefs.getInt('backend_status_code');
    });"""
content = content.replace(load_old, load_new)

# Remove _loadFavicon method
favicon_method = r"  Future<void> _loadFavicon\(\) async \{.*?\n  \}"
content = re.sub(favicon_method, "", content, flags=re.DOTALL)

with open('lib/pages/cloud_page.dart', 'w') as f:
    f.write(content)
