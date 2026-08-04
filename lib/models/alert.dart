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

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'severity': severity,
      'city': city,
      'aqiValue': aqiValue,
      'isRead': isRead,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AirAlert.fromJson(Map<String, dynamic> json) {
    return AirAlert(
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String,
      city: json['city'] as String,
      aqiValue: json['aqiValue'] as int? ?? 0,
      isRead: json['isRead'] as bool? ?? false,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
