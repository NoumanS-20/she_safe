import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_contact.dart';
import '../services/contacts_service.dart';

class ImportContactsScreen extends StatefulWidget {
  const ImportContactsScreen({super.key});

  @override
  State<ImportContactsScreen> createState() => _ImportContactsScreenState();
}

class _ImportContactsScreenState extends State<ImportContactsScreen> {
  final ContactsService _contactsService = ContactsService();
  List<Contact> _deviceContacts = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _permissionDenied = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadContacts();
  }

  Future<void> _requestPermissionAndLoadContacts() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      await _loadContacts();
    } else {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
    }
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      setState(() {
        _deviceContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
    }
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _deviceContacts;
    final query = _searchQuery.toLowerCase();
    return _deviceContacts.where((c) {
      return c.displayName.toLowerCase().contains(query) ||
          c.phones.any((p) => p.number.replaceAll(RegExp(r'\D'), '').contains(query.replaceAll(RegExp(r'\D'), '')));
    }).toList();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _addSelectedContacts() async {
    if (_selectedIds.isEmpty) return;

    int added = 0;
    for (final id in _selectedIds) {
      final contact = _deviceContacts.firstWhere((c) => c.id == id);
      if (contact.phones.isNotEmpty) {
        final emergencyContact = EmergencyContact(
          id: DateTime.now().millisecondsSinceEpoch.toString() + added.toString(),
          name: contact.displayName,
          phone: contact.phones.first.number,
          relationship: 'Other',
        );
        await _contactsService.addContact(emergencyContact);
        added++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $added contact(s) to emergency contacts')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Import Contacts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton.icon(
              onPressed: _addSelectedContacts,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add (${_selectedIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
              ? _buildPermissionDenied(theme)
              : _buildContactsList(theme),
    );
  }

  Widget _buildPermissionDenied(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.contacts,
                size: 64,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Contacts Permission Required',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please grant contacts permission to import your phone contacts.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        if (_selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_selectedIds.length} contact${_selectedIds.length > 1 ? 's' : ''} selected',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedIds.clear()),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _filteredContacts.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No contacts found on your phone'
                        : 'No contacts match your search',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    final isSelected = _selectedIds.contains(contact.id);
                    final hasPhone = contact.phones.isNotEmpty;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? theme.colorScheme.primary
                            : Colors.grey.shade300,
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : Text(
                                contact.displayName.isNotEmpty
                                    ? contact.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                      ),
                      title: Text(
                        contact.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: hasPhone
                          ? Text(contact.phones.first.number)
                          : Text(
                              'No phone number',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                      trailing: hasPhone
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(contact.id),
                              activeColor: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: hasPhone ? () => _toggleSelection(contact.id) : null,
                      enabled: hasPhone,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
