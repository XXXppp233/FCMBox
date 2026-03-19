with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

content = content.replace(
    "final authController = TextEditingController(text: _authKey);\n    final authController = TextEditingController(text: _authKey);",
    "final authController = TextEditingController(text: _authKey);"
)

with open('lib/pages/cloud_page.dart', 'w') as f:
    f.write(content)
