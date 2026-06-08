import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class GreetingPreviewPage extends StatefulWidget {
  final String url;

  const GreetingPreviewPage({super.key, required this.url});

  @override
  State<GreetingPreviewPage> createState() => _GreetingPreviewPageState();
}

class _GreetingPreviewPageState extends State<GreetingPreviewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // אתחול ה-WebViewController עם הגדרות חסינות-מובייל והאצת חומרה
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // מאפשר ל-JS לרוץ חלק ב-100%
      ..setBackgroundColor(Colors.white) // מניעת ריצודים שחורים בזמן הטעינה
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("שגיאת WebView: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url)); // טעינת ה-URL עם ה-Base64 שיוצר בפלאטר
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "תצוגה מקדימה של הגלויה",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5565)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        // כפתור חזרה ברור שסוגר את המסך ומשמיד את ה-WebView מהזיכרון מיד
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1B5565)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // ה-WebViewWidget הרשמי שמציג את הרינדור של הדף
          WebViewWidget(controller: _controller),

          // אינדיקטור טעינה מעוצב שמופיע כל עוד הדף נבנה ברקע
          if (_isLoading) const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5565)))),
        ],
      ),
    );
  }
}
