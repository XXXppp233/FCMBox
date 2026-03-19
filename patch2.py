import re

with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

# We'll regex replace the whole showDialog call up to `return AlertDialog(...) ... );\n        },\n      );`

# Find the start of the showDialog
start_idx = content.find('showDialog(\n        context: context,\n        builder: (context) {\n          return StatefulBuilder(')
if start_idx == -1:
    print("Start not found")
else:
    # Find the end of this showDialog block
    end_str = ");\n        },\n      );"
    end_idx = content.find(end_str, start_idx) + len(end_str)
    
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
    
    content = content[:start_idx] + new_dialog + content[end_idx:]
    with open('lib/pages/cloud_page.dart', 'w') as f:
        f.write(content)
