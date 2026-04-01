import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentPreviewPage extends StatelessWidget {
  final String fileUrl;
  final String title;

  const DocumentPreviewPage({
    super.key,
    required this.fileUrl,
    required this.title,
  });

  bool get _isPdf {
    final path =
        Uri.tryParse(fileUrl)?.path.toLowerCase() ?? fileUrl.toLowerCase();
    return path.endsWith('.pdf');
  }

  bool get _isImage {
    final path =
        Uri.tryParse(fileUrl)?.path.toLowerCase() ?? fileUrl.toLowerCase();
    return path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.bmp');
  }

  Future<void> _openExternally(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(fileUrl),
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the file')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isImage ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          title.isEmpty ? 'Document Preview' : title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () => _openExternally(context),
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open externally',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isPdf) {
      return SfPdfViewer.network(fileUrl);
    }

    if (_isImage) {
      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Center(
          child: Image.network(
            fileUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Unable to load image',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              final expectedBytes = loadingProgress.expectedTotalBytes;
              final loadedBytes = loadingProgress.cumulativeBytesLoaded;
              final progress = expectedBytes == null
                  ? null
                  : loadedBytes / expectedBytes;

              return Center(child: CircularProgressIndicator(value: progress));
            },
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Preview is available for PDF and image files only.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openExternally(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open File'),
            ),
          ],
        ),
      ),
    );
  }
}
