import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_contact.dart';
import 'contacts_service.dart';
import 'location_service.dart';

/// Service to handle SOS emergency alerts.
/// Sends SMS with location to all emergency contacts and optionally calls police.
class SosService {
  final ContactsService _contactsService = ContactsService();
  final LocationService _locationService = LocationService();

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
    if (position != null) {
      final mapLink =
          'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      locationText =
          'My location: $mapLink\nCoordinates: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } else {
      locationText = 'Location could not be determined.';
    }

    final message =
        'SOS EMERGENCY! I need help! This is an emergency alert from SheSafe app.\n\n$locationText\n\nPlease help me or call emergency services!';

    int sentCount = 0;

    // Send SMS to each contact
    for (final contact in contacts) {
      try {
        final smsUri = Uri(
          scheme: 'sms',
          path: contact.phone,
          queryParameters: {'body': message},
        );
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          sentCount++;
        }
      } catch (_) {}
    }

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
    if (position != null) {
      final mapLink =
          'https://maps.google.com/?q=${position.latitude},${position.longitude}';
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
}
