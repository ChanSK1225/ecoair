import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class AQIGauge extends StatelessWidget {
  final int aqi;
  final String status;
  final Color color;

  const AQIGauge({
    super.key,
    required this.aqi,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: 100.0,
      lineWidth: 15.0,
      percent: aqi > 500 ? 1.0 : aqi / 500,
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$aqi',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const Text('AQI', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      circularStrokeCap: CircularStrokeCap.round,
      progressColor: color,
      backgroundColor: Colors.grey[200]!,
      animation: true,
      animationDuration: 1000,
    );
  }
}
