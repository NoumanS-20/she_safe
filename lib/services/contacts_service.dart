import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';

/// Service to manage emergency contacts using SharedPreferences.
class ContactsService {
  static const String _key = 'emergency_contacts';

  /// Get all saved emergency contacts.
  Future<List<EmergencyContact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    return jsonList.map((e) => EmergencyContact.fromJson(e)).toList();
  }

  /// Add a new emergency contact.
  Future<void> addContact(EmergencyContact contact) async {
    final contacts = await getContacts();
    contacts.add(contact);
    await _saveContacts(contacts);
  }

  /// Update an existing contact.
  Future<void> updateContact(EmergencyContact contact) async {
    final contacts = await getContacts();
    final index = contacts.indexWhere((c) => c.id == contact.id);
    if (index >= 0) {
      contacts[index] = contact;
      await _saveContacts(contacts);
    }
  }

  /// Remove a contact by ID.
  Future<void> removeContact(String id) async {
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.id == id);
    await _saveContacts(contacts);
  }

  /// Save contacts list.
  Future<void> _saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = contacts.map((c) => c.toJson()).toList();
    await prefs.setStringList(_key, jsonList);
  }
}
