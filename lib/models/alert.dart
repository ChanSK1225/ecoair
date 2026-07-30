class AirAlert {
  final String title;
  final String message;
  final String type;
  final String severity; // High, Medium, Low
  final String city;
  final int aqiValue;
  final bool isRead;
  final DateTime timestamp;

  AirAlert({
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    required this.city,
    required this.aqiValue,
    this.isRead = false,
    required this.timestamp,
  });
}
