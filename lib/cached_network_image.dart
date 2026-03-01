import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fcm_box/db/notes_database.dart';
import 'dart:convert';
import 'dart:typed_data';

class CachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  Future<Uint8List?>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  void _loadImage() {
    _imageFuture = _processImage();
  }

  Future<Uint8List?> _processImage() async {
    try {
      final cached = await DatabaseHelper.instance.getImage(widget.imageUrl);
      if (cached != null) {
        return base64Decode(cached);
      }

      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final base64String = base64Encode(bytes);
        // Save in background
        DatabaseHelper.instance.saveImage(widget.imageUrl, base64String);
        return bytes;
      }
    } catch (e) {
      debugPrint('Image process failed: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.isEmpty) {
      return widget.errorWidget ?? const SizedBox();
    }

    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              errorBuilder: (context, error, stackTrace) {
                return widget.errorWidget ?? const Icon(Icons.error);
              },
            );
          } else {
            // Fallback to network directly if caching failed
            return Image.network(
              widget.imageUrl,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              errorBuilder: (context, error, stackTrace) {
                return widget.errorWidget ?? const Icon(Icons.broken_image);
              },
            );
          }
        } else {
          return widget.placeholder ??
              SizedBox(
                width: widget.width,
                height: widget.height,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        }
      },
    );
  }
}
