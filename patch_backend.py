import re

with open('lib/pages/cloud_page.dart', 'r') as f:
    content = f.read()

old_check = """      try {
        // 1. GET Root
        final response = await http.get(targetUri, headers: headers);
        if (response.statusCode == 200) {
          final document = html_parser.parse(response.body);
          String title =
              document.head?.querySelector('title')?.text ?? 'The Backend Title';
          String info =
              document.body?.querySelector('h1')?.text ?? 'The backend info';

          // 2. GET Favicon
          // Construct favicon URL
          Uri faviconUri = targetUri.replace(path: '/favicon.ico');

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cloud_favicon_url', faviconUri.toString());
          setState(() {
            _faviconUrl = faviconUri.toString();
          });

          // Update UI state
          setState(() {
            _backendTitle = title;
            _backendInfo = info;
            _isConnected = true;
          });

          // Save to prefs
          await prefs.setString('cloud_title', title);
          await prefs.setString('cloud_version', info);
          await prefs.setBool('backend_active', true);

          // 3. PUT Token
          await _registerToken(targetUri, headers);
        } else {
          throw Exception('Status code ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Backend check failed: $e');
        setState(() {
          // Keep old title/info if failed
        });
      } finally {"""

new_check = """      try {
        // 1. GET Root
        final response = await http.get(targetUri, headers: headers);
        final prefs = await SharedPreferences.getInstance();
        
        setState(() {
          _backendStatusCode = response.statusCode;
        });
        await prefs.setInt('backend_status_code', response.statusCode);

        if (response.statusCode == 200) {
          final document = html_parser.parse(response.body);
          String title =
              document.head?.querySelector('title')?.text ?? 'The Backend Title';
          String info =
              document.body?.querySelector('h1')?.text ?? 'The backend info';

          // Update UI state
          setState(() {
            _backendTitle = title;
            _backendInfo = info;
            _isConnected = true;
          });

          // Save to prefs
          await prefs.setString('cloud_title', title);
          await prefs.setString('cloud_version', info);
          await prefs.setBool('backend_active', true);

          // 2. PUT Token
          await _registerToken(targetUri, headers);
        } else {
          setState(() {
             _isConnected = false;
          });
          await prefs.setBool('backend_active', false);
          throw Exception('Status code ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Backend check failed: $e');
        setState(() {
          _isConnected = false;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('backend_active', false);
      } finally {"""
content = content.replace(old_check, new_check)

with open('lib/pages/cloud_page.dart', 'w') as f:
    f.write(content)
