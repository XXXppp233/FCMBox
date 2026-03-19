import re

with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

# We need to rewrite the showDialog call.
# Let's extract the exact substring and replace it.

old_code = """      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF202124),
                title: Text(
                  AppLocalizations.of(context)?.backend_status ??
                      'Backend Status',
                  style: const TextStyle(color: Colors.white),
                ),
                contentPadding: const EdgeInsets.all(24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
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
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Backend URL',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: authController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Authorization',
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ExpansionTile(
                          title: const Text(
                            'Advanced options',
                            style: TextStyle(color: Colors.white),
                          ),
                          iconColor: Colors.white,
                          collapsedIconColor: Colors.grey[400],
                          children: [
                            TextField(
                              controller: ipController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'IP Address (Optional)',
                                labelStyle: TextStyle(color: Colors.grey[400]),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.grey[600]!,
                                  ),
                                ),
                              ),
                            ),
                            SwitchListTile(
                              title: const Text(
                                'Use HTTPS',
                                style: TextStyle(color: Colors.white),
                              ),
                              value: tempHttps,
                              activeThumbColor: Colors.blue[200],
                              onChanged: (val) {
                                setSheetState(() => tempHttps = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              deviceName,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
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
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA8C7FA),
                      foregroundColor: const Color(0xFF062E6F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );"""

new_code = """      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return AlertDialog(
                title: Text(
                  AppLocalizations.of(context)?.backend_status ??
                      'Backend Status',
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

# Replace exact match or use regex
content = content.replace(old_code, new_code)
with open('lib/pages/cloud_page.dart', 'w') as f:
    f.write(content)
