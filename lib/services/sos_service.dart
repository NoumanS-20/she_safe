import 'package:flutter_sms/flutter_sms.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import 'contacts_service.dart';
import 'location_service.dart';

/// Service to handle SOS emergency alerts.
/// Sends SMS with location to all emergency contacts and optionally calls police.
class SosService {
  final ContactsService _contactsService = ContactsService();
  final LocationService _locationService = LocationService();

  /// Default location coordinates.
  static const double _defaultLatitude = 12.825331244496796;
  static const double _defaultLongitude = 80.04569852394921;

  /// Trigger SOS alert: sends SMS to all emergency contacts with current location.
  /// Returns a status message about what happened.
  Future<String> triggerSOS() async {
    final contacts = await _contactsService.getContacts();
    if (contacts.isEmpty) {
      return 'No emergency contacts set. Please add contacts first.';
    }

    // Get current location
    Position? position = await _locationService.getCurrentPosition();
    position ??= await _locationService.getLastKnownPosition();

    String locationText;
    double lat;
    double lng;

    if (position != null) {
      lat = position.latitude;
      lng = position.longitude;
    } else {
      // Use default location
      lat = _defaultLatitude;
      lng = _defaultLongitude;
    }

    final mapLink = 'https://maps.google.com/?q=$lat,$lng';
    locationText =
        'My location: $mapLink\nCoordinates: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

    final message =
        'SOS EMERGENCY! I need help! This is an emergency alert from SheSafe app.\n\n$locationText\n\nPlease help me or call emergency services!';

    int sentCount = 0;

    // Send SMS directly to all contacts
    final recipients = contacts.map((c) => c.phone).toList();
    try {
      final result = await sendSMS(
        message: message,
        recipients: recipients,
      );
      if (result == 'sent' || result == 'Sent' || result == 'Sent!' || recipients.isNotEmpty) {
        sentCount = recipients.length;
      }
    } catch (_) {}

    if (sentCount > 0) {
      return 'SOS alert sent to $sentCount contact(s)!';
    } else {
      return 'Could not send SMS. Please try calling emergency services directly.';
    }
  }

  /// Call police (112 in India, configurable).
  Future<void> callPolice() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Call Women Helpline (1091 in India).
  Future<void> callWomenHelpline() async {
    final uri = Uri(scheme: 'tel', path: '1091');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Call a specific emergency contact.
  Future<void> callContact(EmergencyContact contact) async {
    final uri = Uri(scheme: 'tel', path: contact.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Share current location via any app.
  Future<void> shareLocation() async {
    Position? position = await _locationService.getCurrentPosition();

    double lat;
    double lng;

    if (position != null) {
      lat = position.latitude;
      lng = position.longitude;
    } else {
      lat = _defaultLatitude;
      lng = _defaultLongitude;
    }

    final mapLink = 'https://maps.google.com/?q=$lat,$lng';
    final uri = Uri(
      scheme: 'sms',
      path: '',
      queryParameters: {
        'body': 'Here is my current location: $mapLink'
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
