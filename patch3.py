import re

with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

pattern = r'showDialog\(\s*context: context,\s*builder: \(context\) \{\s*return StatefulBuilder\(.*?actions: \[\s*TextButton\(.*?Navigator\.pop\(context\).*?child: const Text\(\'Save\'\),\s*\),\s*\],\s*\);\s*\},\s*\);\s*\},\s*\);'

# Replace the block
new_dialog = """showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AlertDialog(
              title: Text(
                AppLocalizations.of(context)?.backend_status ?? 'Backend Status',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'Backend URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: authController,
                        decoration: const InputDecoration(
                          labelText: 'Authorization',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ExpansionTile(
                        title: const Text('Advanced options'),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                        children: [
                          TextField(
                            controller: ipController,
                            decoration: const InputDecoration(
                              labelText: 'IP Address (Optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('Use HTTPS'),
                            value: tempHttps,
                            onChanged: (val) {
                              setSheetState(() => tempHttps = val);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            deviceName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _backendUrl = urlController.text;
                      _authKey = authController.text;
                      _ipAddress = ipController.text;
                      _useHttps = tempHttps;
                    });
                    _saveSettings();
                    Navigator.pop(context);
                    _checkBackend();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );"""

new_content = re.sub(pattern, new_dialog, content, flags=re.DOTALL)
if new_content == content:
    print("Failed to replace via regex")
else:
    with open('lib/pages/cloud_page.dart', 'w') as f:
        f.write(new_content)
