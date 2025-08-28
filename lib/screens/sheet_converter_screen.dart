import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class SheetConverterScreen extends StatefulWidget {
  const SheetConverterScreen({super.key});

  @override
  State<SheetConverterScreen> createState() => _SheetConverterScreenState();
}

class _SheetConverterScreenState extends State<SheetConverterScreen> {
  List<Map<String, dynamic>> pdfFiles = []; // List to store PDF files

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

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true, // Allow multiple file selection
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            // Check if file is not already in the list
            bool isDuplicate = pdfFiles.any((pdf) => pdf['name'] == file.name);
            if (!isDuplicate) {
              pdfFiles.add({
                'name': file.name,
                'path': file.path!,
                'file': File(file.path!),
              });
            }
          }
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} PDF file(s) added to list'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
      pdfFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF070372), // Top bar background (gold). Change this to alter the AppBar background.
        foregroundColor: Colors.white, // Top bar text/icons color. Change this for AppBar title and icons.
        title: const Text('Sheet Converter'),
        centerTitle: true,
      ),
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  size: 100,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _pickPdfFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Add PDF Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                if (pdfFiles.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDF Files (${pdfFiles.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 300,
                          child: ListView.builder(
                            itemCount: pdfFiles.length,
                            itemBuilder: (context, index) {
                              final pdf = pdfFiles[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.picture_as_pdf,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                  title: Text(
                                    pdf['name'],
                                    style: theme.textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removePdf(index),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
