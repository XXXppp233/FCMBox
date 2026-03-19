import re

with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

# Replace the GET Favicon block
content = re.sub(
    r"// 2\. GET Favicon\s*// Construct favicon URL\s*Uri faviconUri = targetUri\.replace\(path: '/favicon\.ico'\);\s*final prefs = await SharedPreferences\.getInstance\(\);\s*await prefs\.setString\('cloud_favicon_url', faviconUri\.toString\(\)\);\s*setState\(\(\) \{\s*_faviconUrl = faviconUri\.toString\(\);\s*\}\);",
    "",
    content,
    flags=re.DOTALL
)

# And capture status code
content = re.sub(
    r"final response = await http\.get\(targetUri, headers: headers\);",
    r"final response = await http.get(targetUri, headers: headers);\n      final prefs = await SharedPreferences.getInstance();\n      setState(() { _backendStatusCode = response.statusCode; });\n      await prefs.setInt('backend_status_code', response.statusCode);",
    content
)

# Replace the avatar UI
avatar_old = r"if \(_faviconUrl != null && _faviconUrl!\.isNotEmpty\).*?else\s*CircleAvatar\(\s*radius: 48,"
avatar_new = r"CircleAvatar(\n                radius: 48,"
content = re.sub(avatar_old, avatar_new, content, flags=re.DOTALL)

with open('lib/pages/cloud_page.dart', 'w') as f:
    f.write(content)
