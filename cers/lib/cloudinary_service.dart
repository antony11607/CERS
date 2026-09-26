import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Cloudinary configuration
  static const String _cloudName = 'io0a38tp';
  static const String _uploadPreset = 'cers-app';
  static const String _uploadUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';

  /// Uploads a file to Cloudinary and returns the secure URL
  /// Returns null if upload fails
  static Future<String?> uploadDocument(File file) async {
    try {
      // Validate file type
      String filePath = file.path;
      
      // Log the file path and extension for debugging
      print('Uploading file: $filePath');
      print('File exists: ${file.exists()}');
      
      // Remove any query parameters from the path (e.g., "?id=..." or "?extra=...")
      if (filePath.contains('?')) {
        filePath = filePath.split('?').first;
        print('Cleaned file path: $filePath');
      }
      
      // Extract file extension more carefully
      String fileExtension = '';
      if (filePath.contains('.')) {
        // Get everything after the last dot
        int lastDotIndex = filePath.lastIndexOf('.');
        fileExtension = filePath.substring(lastDotIndex + 1).toLowerCase();
      }
      
      print('File extension: "$fileExtension"');
      
      // Check if we got an extension
      if (fileExtension.isEmpty) {
        throw Exception('File has no extension. Please select a valid file.');
      }
      
      // Validate file type (case-insensitive)
      List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
      bool isValidFile = allowedExtensions.contains(fileExtension);
      
      if (!isValidFile) {
        // Show all allowed extensions for debugging
        print('Allowed extensions: $allowedExtensions');
        print('File extension detected: "$fileExtension"');
        print('File path: ${file.path}');
        throw Exception('Invalid file type: .$fileExtension. Only JPG, JPEG, PNG, and PDF are allowed.');
      }

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      
      // Add the file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      // Add upload preset
      request.fields['upload_preset'] = _uploadPreset;

      // Send request
      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        // Parse response
        String responseBody = await response.stream.bytesToString();
        Map<String, dynamic> responseData = json.decode(responseBody);
        
        // Return secure URL
        return responseData['secure_url'];
      } else {
        String errorBody = await response.stream.bytesToString();
        throw Exception('Upload failed: ${response.statusCode} - $errorBody');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }
}