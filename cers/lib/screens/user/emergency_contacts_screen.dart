import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final relationshipController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Emergency Contact',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter full name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : v.trim().length < 2 ? 'Name must be at least 2 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: relationshipController,
                  decoration: InputDecoration(
                    labelText: 'Relationship',
                    hintText: 'e.g. Spouse, Parent, Friend',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.people_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Relationship is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. +1 234 567 8900',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : v.trim().length < 10 ? 'Enter a valid phone number' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await _addContact(nameController.text.trim(), relationshipController.text.trim(), phoneController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE31E24), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
            child: const Text('Save Contact', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog(String docId, String currentName, String currentRelationship, String currentPhone) {
    final nameController = TextEditingController(text: currentName);
    final relationshipController = TextEditingController(text: currentRelationship);
    final phoneController = TextEditingController(text: currentPhone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Emergency Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.person_outline)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: relationshipController,
                  decoration: InputDecoration(labelText: 'Relationship', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.people_outline)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Relationship is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.phone_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Phone number is required' : v.trim().length < 10 ? 'Enter a valid phone number' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await _updateContact(docId, nameController.text.trim(), relationshipController.text.trim(), phoneController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066CC), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
            child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        content: Text('Are you sure you want to remove $name from your emergency contacts?', style: const TextStyle(fontSize: 15, color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await _deleteContact(docId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE31E24), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _addContact(String name, String relationship, String phone) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('emergencyContacts').add({
        'userId': user.uid, 'name': name, 'relationship': relationship, 'phone': phone, 'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        String message = _getFriendlyErrorMessage(e, 'add');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _updateContact(String docId, String name, String relationship, String phone) async {
    try {
      await FirebaseFirestore.instance.collection('emergencyContacts').doc(docId).update({
        'name': name, 'relationship': relationship, 'phone': phone, 'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        String message = _getFriendlyErrorMessage(e, 'update');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteContact(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('emergencyContacts').doc(docId).delete();
    } catch (e) {
      if (mounted) {
        String message = _getFriendlyErrorMessage(e, 'delete');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    }
  }

  String _getFriendlyErrorMessage(Object error, String operation) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('permission-denied') || errorString.contains('permission_denied')) {
      return 'Unable to $operation contact. Please check your permissions and try again.';
    }
    if (errorString.contains('unavailable') || errorString.contains('network')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    return 'An error occurred while trying to $operation the contact. Please try again.';
  }

  void _callContact(String phone) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling $phone...')));
  }

  void _textContact(String phone) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Texting $phone...')));
  }

  void _openMap(String name) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening location for $name...')));
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Emergency Contacts', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.more_vert, color: Colors.black87), onPressed: () {})],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: Colors.grey.shade400), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('All Contacts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600))]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: user == null
                ? const Center(child: Text('Please sign in to view contacts'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('emergencyContacts').where('userId', isEqualTo: user.uid).snapshots(),
                    builder: (context, snapshot) {
                      // Handle loading state
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Handle errors with user-friendly messages
                      if (snapshot.hasError) {
                        final errorMessage = snapshot.error.toString().toLowerCase();
                        String displayMessage;
                        IconData displayIcon;
                        Color iconColor;

                        if (errorMessage.contains('permission-denied') || errorMessage.contains('permission_denied')) {
                          displayMessage = 'Unable to load contacts due to permission restrictions. Please sign out and sign in again.';
                          displayIcon = Icons.lock_outline;
                          iconColor = Colors.orange;
                        } else if (errorMessage.contains('index')) {
                          displayMessage = 'A database index needs to be created. Please check the Firebase Console or contact support.';
                          displayIcon = Icons.storage_outlined;
                          iconColor = Colors.orange;
                        } else if (errorMessage.contains('unavailable') || errorMessage.contains('network')) {
                          displayMessage = 'Network error. Please check your internet connection and try again.';
                          displayIcon = Icons.wifi_off_outlined;
                          iconColor = Colors.grey;
                        } else {
                          displayMessage = 'Error: ${snapshot.error}';
                          displayIcon = Icons.error_outline;
                          iconColor = Colors.red;
                        }

                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(displayIcon, size: 64, color: iconColor),
                                const SizedBox(height: 16),
                                Text(
                                  displayMessage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Handle empty data
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.contacts_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(_searchQuery.isNotEmpty ? 'No contacts found' : 'No emergency contacts yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                              const SizedBox(height: 8),
                              Text('Tap + to add your first emergency contact', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                            ],
                          ),
                        );
                      }

                      final contacts = snapshot.data!.docs.toList()
                        ..sort((a, b) {
                          final aTime = (a.data() as Map<String, dynamic>)['createdAt'];
                          final bTime = (b.data() as Map<String, dynamic>)['createdAt'];
                          if (aTime is Timestamp && bTime is Timestamp) {
                            return bTime.compareTo(aTime);
                          }
                          return 0;
                        });
                      final filteredContacts = contacts.where((doc) {
                        if (_searchQuery.isEmpty) return true;
                        final d = doc.data() as Map<String, dynamic>;
                        final n = (d['name'] as String? ?? '').toLowerCase();
                        final r = (d['relationship'] as String? ?? '').toLowerCase();
                        final p = (d['phone'] as String? ?? '').toLowerCase();
                        return n.contains(_searchQuery) || r.contains(_searchQuery) || p.contains(_searchQuery);
                      }).toList();

                      if (filteredContacts.isEmpty && _searchQuery.isNotEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('No contacts found', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                              const SizedBox(height: 8),
                              Text('Try a different search term', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final doc = filteredContacts[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['name'] as String? ?? '';
                          final relationship = data['relationship'] as String? ?? '';
                          final phone = data['phone'] as String? ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFFFFEBEE),
                                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE31E24))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(6)),
                                                child: Text(relationship, style: const TextStyle(fontSize: 11, color: Color(0xFF1967D2), fontWeight: FontWeight.w600)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(onPressed: () => _showEditContactDialog(doc.id, name, relationship, phone), icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                    const SizedBox(width: 8),
                                    IconButton(onPressed: () => _showDeleteConfirmDialog(doc.id, name), icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Text(phone, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: OutlinedButton.icon(onPressed: () => _callContact(phone), icon: const Icon(Icons.phone, size: 16), label: const Text('Call'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0066CC), side: const BorderSide(color: Color(0xFF0066CC)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                                    const SizedBox(width: 8),
                                    Expanded(child: OutlinedButton.icon(onPressed: () => _textContact(phone), icon: const Icon(Icons.message_outlined, size: 16), label: const Text('Text'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0066CC), side: const BorderSide(color: Color(0xFF0066CC)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                                    const SizedBox(width: 8),
                                    Expanded(child: OutlinedButton.icon(onPressed: () => _openMap(name), icon: const Icon(Icons.location_on_outlined, size: 16), label: const Text('Map'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0066CC), side: const BorderSide(color: Color(0xFF0066CC)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: const Color(0xFFE31E24),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}