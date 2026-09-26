import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cers/cloudinary_service.dart';
import 'package:cers/screens/volunteer/volunteer_service.dart';
import 'dart:io';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _documentNumberController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _selectedDocumentType;
  File? _documentFile;
  // File picker instance removed - using static methods instead

  final List<String> _documentTypes = [
    'Aadhaar Card',
    'Passport',
    'Voter ID',
    'Driving License',
    'PAN Card',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _documentNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      print('Opening file picker...');
      
      // Use file_picker to support both images and PDFs
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: false,
      );

      print('File picker result: $result');

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.single;
        print('Selected file name: ${file.name}');
        print('Selected file extension: ${file.extension}');
        print('Selected file path: ${file.path}');
        print('Selected file size: ${file.size}');
        
        // Try to get file from path or bytes
        File? selectedFile;
        
        if (file.path != null) {
          // Try to create File from path
          try {
            selectedFile = File(file.path!);
            if (await selectedFile.exists()) {
              print('File exists at path: ${selectedFile.path}');
            } else {
              print('File does not exist at path: ${selectedFile.path}');
              selectedFile = null;
            }
          } catch (e) {
            print('Error creating file from path: $e');
            selectedFile = null;
          }
        }
        
        // If path doesn't work, try to use bytes (for web or content URIs)
        if (selectedFile == null && file.bytes != null) {
          print('Using file bytes instead of path');
          // For platforms that provide bytes but not path
          // We'll need to save to a temporary file
          try {
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/${file.name}');
            await tempFile.writeAsBytes(file.bytes!);
            selectedFile = tempFile;
            print('Created temp file: ${selectedFile.path}');
          } catch (e) {
            print('Error creating temp file: $e');
          }
        }
        
        if (selectedFile != null) {
          setState(() {
            _documentFile = selectedFile;
          });
          
          // Show success message
          if (mounted) {
            String fileName = file.name;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected: $fileName'),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          print('Could not access file');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not access file. Please try again.'),
                backgroundColor: Color(0xFFFFA726),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // User cancelled the picker
        print('No file selected or picker cancelled');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No file selected.'),
              backgroundColor: Color(0xFFFFA726),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking document: $e');
      if (mounted) {
        String errorMessage = 'Failed to pick document.';
        if (e.toString().contains('Permission denied')) {
          errorMessage = 'Permission denied. Please grant file access permission in settings.';
        } else if (e.toString().contains('No file selected')) {
          errorMessage = 'No file selected.';
        } else {
          errorMessage = 'Failed to pick document: ${e.toString().replaceAll('Exception: ', '')}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFE31E24),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String> _uploadDocument() async {
    if (_documentFile == null) {
      throw Exception('No document selected');
    }

    // Verify file exists before upload
    if (!await _documentFile!.exists()) {
      throw Exception('File no longer exists. Please select the file again.');
    }

    print('Uploading file: ${_documentFile!.path}');
    print('File size: ${await _documentFile!.length()} bytes');
    
    // Upload to Cloudinary
    String? documentUrl = await CloudinaryService.uploadDocument(_documentFile!);
    
    if (documentUrl == null) {
      throw Exception('Failed to upload document');
    }

    print('Upload successful: $documentUrl');
    return documentUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                      // Title
                      const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      // More options icon
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.black54,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Personal Information Section
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Full Name Field
                const Text(
                  'Full Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    hintText: 'John Doe',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Colors.grey,
                      size: 22,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Email Field
                const Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'john@example.com',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.grey,
                      size: 22,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 20),

                // Mobile Number Field
                const Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _mobileController,
                  decoration: InputDecoration(
                    hintText: '+91 98765 43210',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      color: Colors.grey,
                      size: 22,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 20),

                // Password Field
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Create password',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.grey,
                      size: 22,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 22,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Confirm Password Field
                const Text(
                  'Confirm Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Re-type password',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.grey,
                      size: 22,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 22,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Identity Verification Section
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Identity Verification',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Document Type Dropdown
                const Text(
                  'Document Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1.5,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDocumentType,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Select document type',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                      isExpanded: true,
                      items: _documentTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              type,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDocumentType = newValue;
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Document Number Field
                const Text(
                  'Document Number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _documentNumberController,
                  decoration: InputDecoration(
                    hintText: 'Enter ID number',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.description_outlined,
                      color: Colors.grey,
                      size: 22,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Upload Document Section
                const Text(
                  'Upload Verification Document',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                GestureDetector(
                  onTap: _pickDocument,
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _documentFile != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF4CAF50),
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Document selected',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _documentFile!.path.split('/').last,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF5F5F5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.upload_outlined,
                                  color: Colors.black87,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tap to upload',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'JPG, PNG or PDF (Max 10MB)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Info text
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ensure the document is clearly legible and contains your photo and address.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Terms Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreedToTerms = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFFE31E24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'I confirm that the information provided is true and I agree to be verified by the administrator.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _agreedToTerms && !_isLoading ? _submitRegistration : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _agreedToTerms && !_isLoading
                          ? const Color(0xFFE31E24)
                          : Colors.grey[300],
                      foregroundColor: _agreedToTerms && !_isLoading
                          ? Colors.white
                          : Colors.grey[600],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text(
                            'Submit Registration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0066CC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitRegistration() async {
    if (!_agreedToTerms) {
      return;
    }

    // Validate required fields
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _mobileController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _selectedDocumentType == null ||
        _documentNumberController.text.isEmpty ||
        _documentFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and upload a document.'),
          backgroundColor: Color(0xFFE31E24),
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          backgroundColor: Color(0xFFE31E24),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Create user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      String uid = userCredential.user!.uid;

      // Step 2: Upload document to Cloudinary
      String documentUrl;
      try {
        documentUrl = await _uploadDocument();
      } catch (e) {
        // Delete the Firebase Auth user if document upload fails
        await userCredential.user!.delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: const Color(0xFFE31E24),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Step 3: Create volunteer application in Firestore
      try {
        VolunteerService volunteerService = VolunteerService();
        bool success = await volunteerService.createVolunteerApplication(
          name: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _mobileController.text.trim(),
          documentType: _selectedDocumentType!,
          documentNumber: _documentNumberController.text.trim(),
          documentUrl: documentUrl,
        );

        if (success) {
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registration submitted successfully. Your application has been sent for administrator verification.'),
                backgroundColor: Color(0xFF4CAF50),
                duration: Duration(seconds: 3),
              ),
            );
            
            // Navigate back to login page
            Navigator.pop(context);
          }
        } else {
          throw Exception('Failed to create application');
        }
      } catch (e) {
        // Delete the Firebase Auth user if Firestore write fails
        await userCredential.user!.delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save application: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: const Color(0xFFE31E24),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account already exists for this email.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is invalid.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your internet connection.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFE31E24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFFE31E24),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}