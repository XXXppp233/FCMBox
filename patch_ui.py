with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

start_marker = "// Dynamic Icon (Favicon or default)"
end_marker = "        const SizedBox(height: 16),"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker, start_idx)

if start_idx != -1 and end_idx != -1:
    new_ui = """// Dynamic Icon (Favicon or default)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: _isConnected
                    ? Icon(
                        Icons.cloud_done,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ) // Example for connected
                    : Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ), // No network icon
              ),
            ),

    """
    content = content[:start_idx] + new_ui + content[end_idx:]

with open('lib/pages/cloud_page.dart', 'w') as f:
    f.write(content)
