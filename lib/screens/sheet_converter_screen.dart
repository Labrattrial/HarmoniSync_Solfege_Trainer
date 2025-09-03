import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;
import 'package:path/path.dart' as p;

class SheetConverterScreen extends StatefulWidget {
  const SheetConverterScreen({super.key});

  @override
  State<SheetConverterScreen> createState() => _SheetConverterScreenState();
}

class _SheetConverterScreenState extends State<SheetConverterScreen> with SingleTickerProviderStateMixin {
  // Converted items (persisted on device)
  final List<Map<String, String>> _convertedItems = [];
  
  // Brand colors
  static const Color _brandPrimary = Color(0xFF070372);
  static const Color _brandAccent = Color(0xFFD6A83D);
  
  // Conversion settings (hardcode your server host here)
  static const String _serverUrl = 'http://192.168.1.10:5000'; // e.g., http://192.168.1.50:5000 or http://10.0.2.2:5000
  bool _isConverting = false; // Track conversion status
  String? _conversionError; // Store any conversion errors
  
  // Holds the last picked file to display during conversion
  String? _currentConvertingName;
  
  // Temp buffer (not shown anymore)
  final Map<String, String> _conversionResults = {};

  // Loader animation
  late final AnimationController _loaderController;

  @override
  void initState() {
    super.initState();
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _loaderController.dispose();
    super.dispose();
  }

  Future<String> _saveMusicXml(String content, String pdfFileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final xmlFileName = pdfFileName.replaceAll('.pdf', '.musicxml');
    final file = File('${directory.path}/$xmlFileName');
    await file.writeAsString(content);
    return file.path;
  }

  Future<void> _pickPdfFile() async {
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Storage permission is required to select PDF files'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false, // single file per flow
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path == null) return;
        setState(() {
          _currentConvertingName = file.name;
          _isConverting = true;
          _conversionError = null;
        });
        // auto-start conversion
        await _convertPdfToMusicXml(File(file.path!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removePdf(int index) {
    setState(() {
      _convertedItems.removeAt(index);
    });
  }

  // ==========================================================================
  // PDF TO MUSICXML CONVERSION - Connect to local Python Flask server
  // ==========================================================================
  
  /// Convert a PDF file to MusicXML using the local Flask server with Audiveris
  Future<void> _convertPdfToMusicXml(File pdfFile) async {
    try {
      setState(() {
        _isConverting = true;
        _conversionError = null;
      });

      final uri = Uri.parse('$_serverUrl/convert');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', pdfFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final musicXml = (result['musicxml'] as String?) ?? '';
        final savedPath = await _saveMusicXml(musicXml, p.basename(pdfFile.path));

        setState(() {
          final fileName = p.basename(pdfFile.path);
          _conversionResults[fileName] = savedPath;
          _convertedItems.insert(0, {'name': fileName, 'path': savedPath});
          _isConverting = false;
          _currentConvertingName = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved as: $savedPath'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _conversionError = 'Server error: ${response.statusCode} - ${response.body}';
          _isConverting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversion failed: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _conversionError = 'Connection error: $e';
        _isConverting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Convert all PDF files in the list (placeholder for future multi-select)
  Future<void> _convertAllPdfs() async {
    // For this UX, we convert on pick; keep for potential batch mode
    if (_currentConvertingName != null) return;
  }

  /// Show server settings dialog
  void _showServerSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server Settings'),
        content: const Text(
          'The server URL is hardcoded in the app. Update _serverUrl in SheetConverterScreen to change it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Test connection to the Flask server
  Future<void> _testServerConnection() async {
    try {
      final response = await http.get(Uri.parse('$_serverUrl/health'));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server connection successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server responded with status: ${response.statusCode}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot connect to server: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF070372),
        foregroundColor: Colors.white,
        title: const Text('Sheet Converter'),
        centerTitle: true,
      ),
      floatingActionButton: _convertedItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isConverting ? null : _pickPdfFile,
              backgroundColor: _brandPrimary,
              foregroundColor: Colors.white,
              icon: _isConverting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isConverting ? 'Converting...' : 'Upload PDF'),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.9, -0.8),
            end: Alignment(1.0, 0.9),
            colors: [
              Color(0xFFFFF9C4),
              Color(0xFFFFECB3),
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _convertedItems.isEmpty
                      ? Column(
                          key: const ValueKey('initial'),
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                              Icons.library_music,
                              size: 120,
                              color: _brandPrimary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'PDF to MusicXML',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: _brandPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a PDF to begin conversion',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.black.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 28),
                            ElevatedButton.icon(
                              onPressed: _isConverting ? null : _pickPdfFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brandPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          key: const ValueKey('results'),
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                children: [
                                  Text(
                                    'Converted Files',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: _brandPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('${_convertedItems.length}', style: theme.textTheme.labelLarge),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                itemCount: _convertedItems.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.07)),
                                itemBuilder: (context, index) {
                                  final item = _convertedItems[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _brandPrimary.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _brandPrimary.withOpacity(0.08)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: _brandPrimary.withOpacity(0.12),
                                          child: Icon(Icons.music_note, color: _brandPrimary),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'] ?? 'Unknown',
                                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item['path'] ?? '',
                                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.open_in_new),
                                              color: _brandAccent,
                                              tooltip: 'Open',
                                              onPressed: () {
                                                // open hook
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.ios_share),
                                              color: _brandAccent,
                                              tooltip: 'Share',
                                              onPressed: () {
                                                // share hook
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              color: Colors.red,
                                              tooltip: 'Delete',
                                              onPressed: () => _removePdf(index),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                ),
              ],
            ),
          ),
              ),
            ),
            if (_isConverting) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: Colors.black.withOpacity(0.25),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated equalizer bars
                      SizedBox(
                        width: 96,
                        height: 48,
                        child: AnimatedBuilder(
                          animation: _loaderController,
                          builder: (context, _) {
                            // 5 bars with phase offsets
                            final phases = [0.0, 0.15, 0.3, 0.45, 0.6];
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(phases.length, (i) {
                                final t = (_loaderController.value + phases[i]) % 1.0;
                                // Smooth wave (0.4..1.0)
                                final h = 12 + 36 * (0.5 + 0.5 * math.sin(2 * 3.1415926 * t));
                                return Container(
                                  width: 10,
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: _brandAccent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Subtle progress line
                      SizedBox(
                        width: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.black.withOpacity(0.07),
                            color: _brandAccent,
                            minHeight: 4,
                            value: (_loaderController.value * 0.6) + 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Converting',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (_currentConvertingName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _currentConvertingName!,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
