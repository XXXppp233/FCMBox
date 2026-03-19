import re

with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

# Modify _showConfigSheet start
old_start = """  void _showConfigSheet() async {
    final urlController = TextEditingController(text: _backendUrl);"""
new_start = """  void _showConfigSheet() async {
    String tempBackendUrl = _backendUrl;
    if (tempBackendUrl != 'https://fcmbackend.wepayto.win' &&
        tempBackendUrl != 'https://fcmbox.firebase.wepayto.win/api') {
      tempBackendUrl = 'https://fcmbackend.wepayto.win';
    }
    final authController = TextEditingController(text: _authKey);"""
content = content.replace(old_start, new_start)

# Replace the text field
old_textfield = """                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'Backend URL',
                          border: OutlineInputBorder(),
                        ),
                      ),"""

new_segmented_button = """                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment<String>(
                              value: 'https://fcmbackend.wepayto.win',
                              label: const Text('Cloudflare'),
                              icon: Image.asset('assets/icon/Cloudflare.png', width: 24, height: 24),
                            ),
                            ButtonSegment<String>(
                              value: 'https://fcmbox.firebase.wepayto.win/api',
                              label: const Text('Firebase'),
                              icon: Image.asset('assets/icon/Firebase.png', width: 24, height: 24),
                            ),
                          ],
                          selected: {tempBackendUrl},
                          onSelectionChanged: (Set<String> newSelection) {
                            setSheetState(() {
                              tempBackendUrl = newSelection.first;
                            });
                          },
                        ),
                      ),"""
content = content.replace(old_textfield, new_segmented_button)

# Update the Save button
old_save = """                    setState(() {
                      _backendUrl = urlController.text;"""
new_save = """                    setState(() {
                      _backendUrl = tempBackendUrl;"""
content = content.replace(old_save, new_save)

with open('lib/pages/cloud_page.dart', 'w') as f:
    f.write(content)
